# impact.jl — which flame kinds a diff's changed methods can reach.
#
# Usage:
#   julia --project=<Arrhenius worktree> test/tools/impact.jl <base> <head> [options]
#
# Options:
#   --paths=src       comma-separated path prefixes included in the diff
#                     (default "src": package code only, not tests)
#   --no-trace        skip the per-kind small-solve trace (static dispatch only)
#   --kinds=A,B,...   analyse only these kinds (default: every discovered kind)
#   --steps=N         time-step budget per traced solve (default 8)
#   --out=FILE        also write the report to FILE
#
# What it does (the head package is the one this script is run from):
#   1. `git diff <base> <head> -- <paths>`; parse the hunks into +/- line
#      ranges per file.
#   2. Scan the head and base sources for method definitions (long and short
#      form; strings, docstrings, #= comments and end-in-brackets skipped).
#      A definition is changed when its span intersects a hunk; head spans are
#      linked to the loaded Method objects through the definition line.
#   3. Discover the concrete flame kinds: subtypes of the abstract flame roots
#      plus CounterflowDiffusionFlame; internal types (leading underscore) are
#      skipped.  Each kind is constructed from a small recipe (h2o2, 5 points;
#      an Ar/He ion fixture; a one-site catalytic surface).
#   4. Static column: would a call passing this kind select the changed
#      method — which(f, Tuple{..., K, ...}) === m, substituting K at every
#      argument position whose declared type admits it.
#   5. Trace column: every changed method is re-defined in the package module
#      with a call counter prepended to its exact head source, then each kind
#      runs one tiny solve (default options) and, where a coverage recipe
#      exists, a second solve on a fresh instance with non-default solve
#      options that exercise paths the defaults skip (e.g. the time-step
#      growth residual is only evaluated when growth_strategy != fixed_growth
#      and the step consumed no Jacobian).  A kind reaches the method when its
#      counter moved in either pass; "^" marks coverage-pass-only hits.
#      "dispatch" without a count means selectable-but-never-called (e.g. the
#      catalytic jet runs its own Newton loop, so the shared counterflow
#      steppers are never entered there despite being dispatchable).
#
# Output: a markdown table kind x changed method; cells are
#   REACH(n)                          traced, called n times
#   no(dispatch)/no(other)/no(noslot) traced, never called; static verdict
#   dispatch/other/noslot             not traced, static verdict only
#   "noslot" = no argument position of the method can hold this kind.

using Arrhenius
using YAML, NPZ, SHA
using InteractiveUtils

const M = Arrhenius
const ROOT = dirname(dirname(pathof(M)))

# ---------------------------------------------------------------- diff parsing

"""git diff base head over the path prefixes; raw unified diff."""
git_diff(base, head, prefixes) =
    read(`git -C $ROOT diff --no-color --no-renames $base $head -- $prefixes`, String)

"""git show ref:path ("" when the path does not exist at ref)."""
function git_show(ref, path)
    io = IOBuffer()
    p = run(pipeline(`git -C $ROOT show $(string(ref) * ":" * path)`; stdout=io, stderr=devnull))
    wait(p)
    return p.exitcode == 0 ? String(take!(io)) : ""
end

struct FileRanges
    path::String                    # head-side path (base-side if deleted)
    oldpath::Union{String,Nothing}  # base-side path when renamed
    plus::Vector{UnitRange{Int}}    # changed line ranges in head
    minus::Vector{UnitRange{Int}}   # changed line ranges in base
end

"""Parse a unified diff into per-file head/base changed-line ranges."""
function parse_diff(text)
    files = FileRanges[]
    oldpath = newpath = nothing
    plus = UnitRange{Int}[]; minus = UnitRange{Int}[]
    oldline = newline = 0
    pstart = mstart = 0
    in_hunk = false
    function commit()
        if newpath !== nothing || oldpath !== nothing
            path = newpath === nothing ? oldpath : newpath
            push!(files, FileRanges(path,
                newpath === nothing ? oldpath : (oldpath == newpath ? nothing : oldpath),
                plus, minus))
        end
        oldpath = newpath = nothing
        plus = UnitRange{Int}[]; minus = UnitRange{Int}[]
        in_hunk = false
    end
    for line in split(text, '\n')
        if startswith(line, "diff --git ")
            commit()
        elseif startswith(line, "--- ")
            t = line[5:end]
            oldpath = t == "/dev/null" ? nothing : replace(t, r"^a/" => "")
        elseif startswith(line, "+++ ")
            t = line[5:end]
            newpath = t == "/dev/null" ? nothing : replace(t, r"^b/" => "")
        elseif startswith(line, "@@ ")
            m = match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            m === nothing && continue
            oldline = parse(Int, m[1]); newline = parse(Int, m[3])
            pstart = mstart = 0
            in_hunk = true
        elseif in_hunk && (oldpath !== nothing || newpath !== nothing)
            if startswith(line, "+")
                pstart == 0 && (pstart = newline)
                newline += 1
            elseif startswith(line, "-")
                mstart == 0 && (mstart = oldline)
                oldline += 1
            else
                pstart > 0 && (push!(plus, pstart:newline-1); pstart = 0)
                mstart > 0 && (push!(minus, mstart:oldline-1); mstart = 0)
                startswith(line, "\\") || (oldline += 1; newline += 1)
            end
        end
    end
    commit()
    return files
end

# ------------------------------------------------- Julia definition scanning

"""One method/function definition found in a source file."""
struct Def
    name::String      # possibly qualified, e.g. "Base.getproperty"
    startline::Int    # line of the `function` keyword / short-form line
    endline::Int
    form::Symbol      # :long or :short
end

const OPENERS = ("macro", "begin", "let", "if", "for", "while", "try",
    "do", "quote", "module", "baremodule", "struct")
const RESERVED = ("function", "macro", "begin", "let", "if", "for", "while",
    "try", "do", "quote", "module", "baremodule", "struct", "mutable", "abstract",
    "primitive", "const", "local", "global", "using", "import", "export", "return",
    "elseif", "else", "catch", "finally", "end", "in", "isa", "where", "new", "ccall")

"""byte-equal prefix check at a (valid) byte index; no index errors."""
function _at(s::AbstractString, prefix::AbstractString, i::Int)
    n = ncodeunits(prefix)
    i + n - 1 <= ncodeunits(s) || return false
    for k in 1:n
        codeunit(s, i + k - 1) == codeunit(prefix, k) || return false
    end
    return true
end

"""Blank comments and string/char literals, preserving line structure."""
function blank_code(text)
    out = IOBuffer()
    in_str3 = false
    lastcode = '\0'   # last code character emitted (for the `'` disambiguation)
    i = 1; n = length(text)
    emit(c) = (print(out, c); lastcode = c)
    while i <= n
        c = text[i]
        if in_str3
            if c == '"' && _at(text, "\"\"\"", i)
                i += 3                                 # quotes are ASCII
                in_str3 = false; lastcode = '"'
            else
                emit(c == '\n' ? '\n' : ' '); i = nextind(text, i)
            end
        elseif c == '#' && _at(text, "#=", i)          # #= ... =# (nests)
            depth = 1; j = i + 2
            while j <= n && depth > 0
                if _at(text, "#=", j)
                    depth += 1; j += 2
                elseif _at(text, "=#", j)
                    depth -= 1; j += 2
                else
                    print(out, text[j] == '\n' ? '\n' : ' '); j = nextind(text, j)
                end
            end
            i = j
            lastcode = ' '
        elseif c == '#'
            j = findnext(isequal('\n'), text, i)
            j === nothing && (j = n + 1)
            while i < j; print(out, ' '); i += 1; end
            lastcode = ' '
        elseif c == '"'
            if _at(text, "\"\"\"", i)
                in_str3 = true; print(out, "   "); i = nextind(text, i + 2)
            else
                k = nextind(text, i)
                while k <= n && text[k] != '"'
                    text[k] == '\\' && (k = nextind(text, k))
                    k = nextind(text, k)
                end
                while i <= min(k, n); print(out, ' '); i += 1; end
                i = min(k + 1, n + 1)
            end
            lastcode = '"'
        elseif c == '\'' && (lastcode == '\0' || lastcode in "([{:;,=<>+-*/^&|.% \n")
            # a char literal only starts after an operator or an opening token;
            # after an identifier/`)`/`]` a `'` is the adjoint
            k = nextind(text, i)
            while k <= n && text[k] != '\''
                text[k] == '\\' && (k = nextind(text, k))
                k = nextind(text, k)
            end
            while i <= min(k, n); print(out, ' '); i += 1; end
            i = min(k + 1, n + 1)
            lastcode = '\''
        else
            emit(c); i = nextind(text, i)
        end
    end
    return String(take!(out))
end

isident(c::Char) = isascii(c) && (isletter(c) || isdigit(c) || c == '_' || c == '!')
indent_of(line) = something(findfirst(!isspace, line), length(line) + 1) - 1

"""Read a (possibly dotted) qualified name at line[pos:end]; "" if none."""
function read_name(line, pos)
    L = length(line)
    j = pos
    while j <= L && (isident(line[j]) || line[j] == '.')
        j += 1
    end
    name = strip(line[pos:j-1], '.')
    # the name must start with a letter/underscore, not a digit or dot
    s = String(name)
    isempty(s) && return ""
    first = s[1]
    (isletter(first) || first == '_') || return ""
    return s
end

"""
    scan_definitions(text) -> Vector{Def}

Find every function/method definition in Julia source: long `function ... end`
blocks (nested and anonymous included) and short `name(args) = ...` forms with
macro prefixes, `where {...}` clauses, `begin ... end` bodies and indented
continuation lines.  Best-effort: docstrings, strings, char literals, #= =#
comments and `end` inside brackets are handled.
"""
function scan_definitions(text)
    lines = split(blank_code(text), '\n')
    defs = Def[]
    # stack of (opener, startline, name); the name of :function / short-:begin
    # openers is filled in when it is known so the matching `end` finalizes
    # the right Def (nested functions each get their own name).
    stack = Tuple{Symbol,Int,Any}[]
    paren = sq = 0
    pending = false        # saw `function`, waiting for its name
    function set_top_name!(nm)
        k, s, _ = stack[end]
        stack[end] = (k, s, nm)
    end
    for (ln, line) in enumerate(lines)
        # short form first (only at bracket depth 0, so multi-line signatures
        # are not half-matched); on a match the line is fully accounted for.
        if paren == 0 && sq == 0
            sf = match_shortform(line)
            if sf !== nothing
                name, mode = sf   # mode: :line | :begin | :continue
                if mode == :begin
                    push!(stack, (:begin, ln, name))
                elseif mode == :continue
                    # body on indented continuation lines: extend the span
                    endline = ln
                    while endline < length(lines) && endline < ln + 30 &&
                           (isempty(strip(lines[endline+1])) ||
                            indent_of(lines[endline+1]) > indent_of(line))
                        endline += 1
                    end
                    push!(defs, Def(name, ln, endline, :short))
                else
                    push!(defs, Def(name, ln, ln, :short))
                end
                continue
            end
        end
        L = length(line)
        pos = 1
        while pos <= L
            c = line[pos]
            if c == '('
                paren += 1
                if pending                     # `function (x)...`: anonymous
                    set_top_name!("__anon__")
                    pending = false
                end
                pos += 1
            elseif c == ')'
                paren = max(paren - 1, 0); pos += 1
            elseif c == '['
                sq += 1; pos += 1
            elseif c == ']'
                sq = max(sq - 1, 0); pos += 1
            elseif isspace(c) || c == ',' || c == ';' || c == '\r'
                pos = nextind(line, pos)
            elseif (isascii(c) && isletter(c)) || c == '_'
                j = pos
                while j <= L && isident(line[j]); j += 1; end
                word = line[pos:j-1]
                prev = pos > 1 ? line[prevind(line, pos)] : ' '
                if prev != '.'
                    if word == "function" && sq == 0
                        push!(stack, (:function, ln, nothing))
                        pending = true
                        # try the name on the same line
                        k = j
                        while k <= L && isspace(line[k]); k = nextind(line, k); end
                        nm = read_name(line, k)
                        if !isempty(nm)
                            set_top_name!(nm)
                            pending = false
                            pos = k + length(nm)
                            continue
                        end
                    elseif word == "end"
                        if sq == 0 && !isempty(stack)
                            kind, start, nm = pop!(stack)
                            if kind == :function && nm isa String &&
                                    nm != "__pending__" && nm != "__anon__"
                                push!(defs, Def(nm, start, ln, :long))
                            elseif kind == :begin && nm isa String
                                push!(defs, Def(nm, start, ln, :short))
                            end
                            pending = false
                        end
                    elseif word in OPENERS && sq == 0
                        if word == "struct" && !isempty(stack) && stack[end][1] == :mutable
                            stack[end] = (:struct, stack[end][2], nothing)
                        else
                            push!(stack, (Symbol(word), ln, nothing))
                        end
                    elseif word == "mutable" && sq == 0
                        push!(stack, (:mutable, ln, nothing))
                    elseif pending && !(word in RESERVED)
                        nm = read_name(line, pos)
                        set_top_name!(isempty(nm) ? word : nm)
                        pending = false
                    end
                end
                pos = j
            else
                pos = nextind(line, pos)
            end
        end
    end
    return sort(unique(defs); by=d -> (d.startline, d.endline))
end

"""Match `name(args) [= ...]` short forms on one blanked line.

Returns (name, mode) with mode :line, :begin (RHS is a begin block) or
:continue (`=` at end of line, body on the next indented lines), or nothing.
"""
function match_shortform(line)
    s = String(strip(line))
    isempty(s) && return nothing
    while true                                   # strip macro prefixes
        m = match(r"^@[A-Za-z_][A-Za-z0-9_!.]*\s*", s)
        m === nothing && break
        s = lstrip(s[ncodeunits(m.match)+1:end])
        isempty(s) && return nothing
    end
    m = match(r"^([A-Za-z_][A-Za-z0-9_!]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*\(", s)
    m === nothing && return nothing
    name = m[1]
    name in RESERVED && return nothing
    depth = 1; i = nextind(s, m.offset + ncodeunits(m.match) - 1)
    L = length(s)
    while i <= L && depth > 0
        c = s[i]
        c == '(' && (depth += 1)
        c == ')' && (depth -= 1)
        i = nextind(s, i)
    end
    depth > 0 && return nothing                   # signature spans lines
    rest = lstrip(s[i:end])
    wm = match(r"^where\s*\{[^}]*\}\s*", rest)
    wm === nothing || (rest = lstrip(rest[ncodeunits(wm.match)+1:end]))
    startswith(rest, "=") || return nothing
    length(rest) > 1 && (rest[2] == '=' || rest[2] == '>') && return nothing
    rhs = lstrip(rest[2:end])
    mode = startswith(rhs, "begin") ? :begin : (isempty(rhs) ? :continue : :line)
    return (name, mode)
end

# ----------------------------------------------------- diff -> changed defs

struct ChangedDef
    path::String
    def::Def
    status::Symbol              # :added :modified :removed
    methods::Vector{Any}        # Method objects (head); empty for :removed
end

function defs_touching(defs, ranges)
    out = Def[]
    for d in defs
        any(r -> d.startline <= r.stop && d.endline >= r.start, ranges) && push!(out, d)
    end
    return out
end

"""Resolve a (possibly qualified) function name from the package module."""
function resolve_function(name)
    obj = M
    for p in split(name, '.')
        sym = Symbol(p)
        isdefined(obj, sym) || return nothing
        obj = getfield(obj, sym)
    end
    return obj isa Function ? obj : nothing
end

"""Link a head-side Def to the loaded Method objects (by file + line + name)."""
function methods_for(d::Def, path)
    fn = resolve_function(d.name)
    fn === nothing && return Any[]
    base = splitdir(path)[2]
    want = Symbol(split(d.name, '.')[end])
    inspan = [m for m in methods(fn)
              if occursin(base, string(m.file)) && d.startline <= m.line <= d.endline]
    named = [m for m in inspan if m.name == want]
    return isempty(named) ? inspan : named
end

"""
    changed_definitions(base, head, prefixes) -> (Vector{ChangedDef}, notes)

A definition is changed when its span intersects a diff hunk.  Head spans get
their Method objects; base-only spans whose name vanished from head are
reported :removed.
"""
function changed_definitions(base, head, prefixes)
    out = ChangedDef[]
    notes = String[]
    for fr in parse_diff(git_diff(base, head, prefixes))
        endswith(fr.path, ".jl") || continue
        disk = joinpath(ROOT, fr.path)
        head_text = isfile(disk) ? read(disk, String) : git_show(head, fr.path)
        base_text = fr.oldpath === nothing ? git_show(base, fr.path) :
            git_show(base, fr.oldpath)
        if isfile(disk) && git_show(head, fr.path) != head_text
            push!(notes, "worktree differs from $head in $(fr.path); scanning the worktree file")
        end
        head_defs = scan_definitions(head_text)
        base_defs = isempty(base_text) ? Def[] : scan_definitions(base_text)
        head_names = Set(d.name for d in head_defs)
        touched_head = defs_touching(head_defs, fr.plus)
        touched_base = defs_touching(base_defs, fr.minus)
        base_all_names = Set(d.name for d in base_defs)
        for d in touched_head
            status = d.name in base_all_names ? :modified : :added
            push!(out, ChangedDef(fr.path, d, status, methods_for(d, fr.path)))
        end
        for d in touched_base
            d.name in head_names && continue
            push!(out, ChangedDef(fr.path, d, :removed, Any[]))
        end
    end
    return out, notes
end

# ------------------------------------------------------------- flame kinds

"""All concrete subtypes under an abstract root, recursively."""
function leaf_subtypes(T)
    isabstracttype(T) || return Any[T]
    return reduce(vcat, (leaf_subtypes(S) for S in subtypes(T)); init=Any[])
end

function discover_kinds()
    kinds = Tuple{Symbol,Any}[]
    seen = Set{Symbol}()
    for root in (:AbstractPremixedFlame, :AbstractPremixedCounterflow)
        isdefined(M, root) || continue
        for T in leaf_subtypes(getfield(M, root))
            name = Base.typename(T).name
            startswith(string(name), "_") && continue
            name in seen || (push!(kinds, (name, T)); push!(seen, name))
        end
    end
    if isdefined(M, :CounterflowDiffusionFlame) && :CounterflowDiffusionFlame ∉ seen
        push!(kinds, (:CounterflowDiffusionFlame, M.CounterflowDiffusionFlame))
    end
    return kinds
end

# --- constructor recipes: the smallest instance of each kind --------------

h2o2() = joinpath(ROOT, "mechanism", "h2o2.yaml")

function ion_gas(dir)
    path = joinpath(dir, "ion.yaml")
    names = ["Ar", "He", "Ar+", "E"]
    comps = [Dict("Ar" => 1), Dict("He" => 1), Dict("Ar" => 1, "E" => -1), Dict("E" => 1)]
    specs = [Dict("name" => n, "composition" => c, "thermo" => Dict("model" => "NASA7",
        "temperature-ranges" => [200., 6000.], "data" => [[2.5, 0., 0., 0., 0., 0., 0.]]))
        for (n, c) in zip(names, comps)]
    YAML.write_file(path, Dict("phases" => [Dict("name" => "gas", "thermo" => "ideal-gas",
        "transport" => "ionized-gas", "elements" => ["Ar", "He", "E"], "species" => names)],
        "species" => specs))
    mu = zeros(5, 4); mu[1, :] = [1e-3, 2e-3, 1.5e-3, 1e-4]
    lam = zeros(5, 4); lam[1, :] = [.01, .02, .03, .04]
    binary = zeros(5, 16); binary[1, :] .= .001
    npzwrite(path * ".npz", Dict{String,Any}(
        "molecular_weights" => [39.95, 4.002602, 39.95 - M._ION_ELECTRON_MW, M._ION_ELECTRON_MW],
        "species_viscosities_poly" => mu, "thermal_conductivity_poly" => lam,
        "binary_diff_coeffs_poly" => binary,
        "transport_model_utf8" => collect(codeunits("ionized-gas")),
        "source_sha256_utf8" => collect(codeunits(bytes2hex(sha256(read(path))))),
        "sidecar_format_utf8" => collect(codeunits("arrhenius-sidecar-v2"))))
    return M.CreateSolution(path)
end

"""One catalytic site (H2 + PT -> 2 H + PT) on an h2o2 gas, as in the tests."""
function catalytic_surface(dir)
    gas = M.CreateSolution(h2o2())
    ng = gas.n_species
    kH = findfirst(==("H"), gas.species_names)
    kH2 = findfirst(==("H2"), gas.species_names)
    elements = vcat(["Pt"], gas.elements)
    elemental = zeros(length(elements), ng + 1); elemental[1, 1] = 1.
    elemental[2:end, 2:end] = gas.ele_matrix
    reactants = zeros(ng + 1, 1); products = zeros(ng + 1, 1)
    reactants[1, 1] = products[1, 1] = 1.
    reactants[kH2+1, 1] = 1.; products[kH+1, 1] = 2.
    coefficients = zeros(ng + 1, 15); coefficients[:, 1] .= 298.15
    path = joinpath(dir, "catalyst.npz")
    npzwrite(path, Dict{String,Any}(
        "surface_format_utf8" => collect(codeunits("arrhenius-surface-v1")),
        "phase_name_utf8" => collect(codeunits("site")),
        "species_names_utf8" => collect(codeunits(join(vcat(["PT"], gas.species_names), '\n'))),
        "element_names_utf8" => collect(codeunits(join(elements, '\n'))),
        "n_surface" => [1], "n_gas" => [ng], "site_density" => [2e-5],
        "site_sizes" => [1.], "molecular_weights" => vcat([195.084], gas.MW),
        "elemental_matrix" => elemental, "reactants" => reactants, "products" => products,
        "orders" => reactants, "arrhenius" => reshape([10., 0., 0.], 1, 3),
        "reversible" => [false], "coverage_a" => zeros(1, 1), "coverage_m" => zeros(1, 1),
        "coverage_energy" => zeros(1, 1, 4), "sticking_species" => [0],
        "sticking_order" => [0.], "sticking_factor" => [0.], "motz_wise" => [false],
        "thermo_type" => fill(2, ng + 1), "thermo_coefficients" => coefficients,
        "reference_pressure" => fill(M.one_atm, ng + 1), "initial_coverages" => [1.],
        "initial_mole_fractions" => ones(ng) ./ ng, "initial_temperature" => [900.],
        "initial_pressure" => [M.one_atm]))
    return gas, M.SurfaceMechanism(path)
end

struct Recipe
    make::Function      # () -> flame instance
    kw::NamedTuple      # solve! kwargs for the bounded trace solve
    kw2::NamedTuple     # extra kwargs for the coverage pass (empty = no pass)
end
Recipe(make, kw) = Recipe(make, kw, ())

const PREMIXED_X = "H2:1.1,O2:1,AR:5"
const CF_X = "H2:1.6,O2:1,AR:7"

function kind_recipes(steps)
    recipes = Dict{Symbol,Recipe}(
        :FreeFlame => Recipe(() -> M.FreeFlame(M.CreateSolution(h2o2()); X=PREMIXED_X,
                width=.06),
            (; refine_grid=false, max_time_steps=200)),
        :BurnerFlame => Recipe(() -> M.BurnerFlame(M.CreateSolution(h2o2()); X=PREMIXED_X,
                mdot=.06, grid=[0., .001, .002, .004, .006]),
            (; refine_grid=false, max_time_steps=50)),
        :CounterflowDiffusionFlame => Recipe(() -> M.CounterflowDiffusionFlame(
                M.CreateSolution(h2o2()); fuel="H2:1,AR:1", oxidizer="O2:.2,AR:.8",
                mdot_fuel=.24, mdot_oxidizer=.72, T_fuel=300., T_oxidizer=300., width=.02),
            (; refine_grid=false, auto=false, max_time_steps=steps, initial_time_step=1e-6),
            (; time_step_growth_strategy=:transient_residual)),
        :CounterflowPremixedFlame => Recipe(() -> M.CounterflowPremixedFlame(
                M.CreateSolution(h2o2()); reactants=CF_X, mdot_reactants=.12,
                mdot_products=.06, T_reactants=373., P=.05 * M.one_atm,
                grid=collect(range(0., .2; length=5))),
            (; refine_grid=false, auto=false, max_time_steps=steps, initial_time_step=1e-6),
            (; time_step_growth_strategy=:transient_residual)),
        :CounterflowTwinPremixedFlame => Recipe(() -> M.CounterflowTwinPremixedFlame(
                M.CreateSolution(h2o2()); reactants=CF_X, mdot=.12, T=373.,
                P=.05 * M.one_atm, grid=collect(range(0., .1; length=5))),
            (; refine_grid=false, auto=false, max_time_steps=steps, initial_time_step=1e-6),
            (; time_step_growth_strategy=:transient_residual)),
        :ImpingingJet => Recipe(() -> M.ImpingingJet(M.CreateSolution(h2o2());
                reactants=CF_X, mdot=.06, T_inlet=373., T_surface=500.,
                P=.05 * M.one_atm, grid=collect(range(0., .05; length=5))),
            (; refine_grid=false, auto=false, max_time_steps=steps, initial_time_step=1e-6),
            (; time_step_growth_strategy=:transient_residual)),
        :IonizedFlame => Recipe(() -> M.FreeFlame(ion_gas(mktempdir()); T=900.,
                X="Ar:0.7,He:0.3", grid=[0., .001, .003, .007, .01]),
            (; refine_grid=false, max_time_steps=50)),
        :CatalyticImpingingJet => Recipe(() -> begin
                gas, surf = catalytic_surface(mktempdir())
                f = M.CatalyticImpingingJet(gas, surf; reactants="H2:1,AR:4", mdot=.06,
                    T_inlet=900., T_surface=900.)
                M.set_catalytic_reactions!(f; gas_multiplier=0., surface_multiplier=0.,
                    coverage_enabled=false)
                f
            end,
            (; refine_grid=false, max_time_steps=steps)),
    )
    return recipes
end

# ------------------------------------------------------------ static dispatch

"""
    static_dispatch(fn, m, K, allkinds) -> "dispatch" | "other" | "noslot"

Would a call that passes a `K`-typed flame select method `m`?  K is
substituted at one positional-argument slot at a time; the other slots keep
their declared types.  Slots are the "flame slots": positions whose declared
type admits one of the flame kinds and is not `Any` (e.g. `f::AbstractPremixed-
Counterflow`, `f::CounterflowDiffusionFlame`); if a method declares none, its
untyped (`Any`) positions are tried — so fully generic steppers count as
dispatchable for every kind, which is exactly what the trace column must then
confirm or refute.
"""
function static_dispatch(fn, m, K, allkinds)
    sig = Base.unwrap_unionall(m.sig)
    (sig isa DataType && sig <: Tuple) || return "noslot"
    # declared argument types, RAW: unwrapping a UnionAll parameter (e.g.
    # `f::CounterflowDiffusionFlame`) would leave a free TypeVar and break
    # the subtype tests below.
    params = collect(sig.parameters)[2:end]   # drop typeof(fn)
    slots = [i for i in eachindex(params)
             if params[i] isa Type && params[i] !== Any &&
                any(Kp -> Kp <: params[i], allkinds)]
    isempty(slots) && (slots = [i for i in eachindex(params) if params[i] === Any])
    hit = other = false
    for i in slots
        (K <: params[i]) || continue
        tt_params = [j == i ? K : params[j] for (j, _) in enumerate(params)]
        any(p -> !(p isa Type), tt_params) && continue
        sel = try
            which(fn, Tuple{tt_params...})
        catch
            nothing
        end
        sel === m && (hit = true; break)
        sel === nothing || (other = true)
    end
    return hit ? "dispatch" : (other ? "other" : "noslot")
end

# ------------------------------------------------------------- instrumentation

"""Find the definition expression inside macro/doc wrappers, else nothing."""
function find_def_expr(ex)
    ex isa Expr || return nothing
    (ex.head == :function || ex.head == :(=)) && return ex
    if ex.head == :macrocall
        for a in ex.args
            r = find_def_expr(a)
            r !== nothing && return r
        end
    end
    return nothing
end

"""
    instrument!(cd, counters) -> Bool

Re-define the changed method in the package module with a call counter
prepended to its exact head source.  counters is keyed by "path:startline".
"""
function instrument!(cd::ChangedDef, counters)
    d = cd.def
    src = join(readlines(joinpath(ROOT, cd.path))[d.startline:d.endline], "\n")
    ex = try
        Meta.parse(src)
    catch
        return false
    end
    fex = find_def_expr(ex)
    fex === nothing && return false
    cn = Symbol(:__impact_cnt_, string(abs(hash(cd.path)) % 100000), :_, d.startline)
    Core.eval(M, :(global $cn = Ref(0)))
    cex = :($cn[] = $cn[] + 1)
    if fex.head == :function
        body = fex.args[2]
        (body isa Expr && body.head == :block) || return false
        pushfirst!(body.args, cex)
    elseif fex.head == :(=)
        fex.args[2] = Expr(:block, cex, fex.args[2])
    else
        return false
    end
    try
        Core.eval(M, ex)
    catch
        return false
    end
    counters[string(cd.path, ":", d.startline)] = Base.invokelatest(getfield, M, cn)
    return true
end

# --------------------------------------------------------------------- main

function parseargs(args)
    opts = Dict(:paths => ["src"], :trace => true, :kinds => String[],
        :steps => 8, :out => "")
    pos = String[]
    for a in args
        startswith(a, "--") || (push!(pos, a); continue)
        body = a[3:end]
        k, v = occursin('=', body) ? split(body, '='; limit=2) : (body, nothing)
        if k == "no-trace"; opts[:trace] = false
        elseif k == "paths"; opts[:paths] = split(v, ',')
        elseif k == "kinds"; opts[:kinds] = split(v, ',')
        elseif k == "steps"; opts[:steps] = parse(Int, v)
        elseif k == "out"; opts[:out] = String(v)
        else; error("unknown option $a")
        end
    end
    length(pos) == 2 || error("usage: impact.jl <base> <head> [--paths=src] [--no-trace] [--kinds=A,B] [--steps=8] [--out=FILE]")
    return pos[1], pos[2], opts
end

function impact(args)
    base, head, opts = parseargs(args)
    prefixes = String.(opts[:paths])
    println("impact: package ", ROOT)
    println("diff: base ", base, " head ", head, " paths ", join(prefixes, ","))
    changed, notes = changed_definitions(base, head, prefixes)
    foreach(n -> println("note: ", n), notes)
    isempty(changed) && (println("no changed definitions"); return nothing)
    println("changed definitions: ", length(changed))
    for cd in changed
        println("  [", String(cd.status)[1], "] ", cd.path, ":", cd.def.startline, "-",
            cd.def.endline, " ", cd.def.name,
            isempty(cd.methods) ? "" : " ($(length(cd.methods)) method$(length(cd.methods) == 1 ? "" : "s"))")
    end
    analyzed = [cd for cd in changed if cd.status != :removed && !isempty(cd.methods)]
    for cd in changed
        (cd.status != :removed && isempty(cd.methods)) &&
            println("  ! no method object for ", cd.def.name, " (", cd.path, ":",
                cd.def.startline, ") — static+trace skipped")
    end

    kinds = discover_kinds()
    isempty(opts[:kinds]) || filter!(k -> String(k[1]) in opts[:kinds], kinds)
    recipes = kind_recipes(opts[:steps])
    println("kinds: ", join(first.(kinds), ", "))

    inst = Vector{Any}(undef, length(kinds))
    statuses = Vector{String}(undef, length(kinds))
    for (i, (name, _)) in enumerate(kinds)
        r = get(recipes, name, nothing)
        if r === nothing
            inst[i] = nothing
            statuses[i] = "no recipe (add one in kind_recipes)"
        else
            try
                inst[i] = r.make()
                statuses[i] = "constructed"
            catch e
                inst[i] = nothing
                statuses[i] = "construction failed: " * sprint(showerror, e)[1:min(end, 120)]
            end
        end
    end

    # static dispatch BEFORE instrumentation (which replaces the methods)
    allkinds = [T for (_, T) in kinds]
    static = Dict{String,Dict{Symbol,String}}()
    for cd in analyzed, m in cd.methods
        fn = resolve_function(cd.def.name)
        fn === nothing && continue
        key = string(cd.path, ":", cd.def.startline)
        s = get!(static, key, Dict{Symbol,String}())
        for (i, (name, _)) in enumerate(kinds)
            inst[i] === nothing && continue
            s[name] = static_dispatch(fn, m, typeof(inst[i]), allkinds)
        end
    end

    # trace: instrument, then one bounded solve per kind
    trace = opts[:trace] && !isempty(analyzed)
    counters = Dict{String,Base.RefValue{Int}}()
    failed = String[]
    if trace
        for cd in analyzed
            instrument!(cd, counters) ||
                push!(failed, string(cd.def.name, " (", cd.path, ":", cd.def.startline, ")"))
        end
        isempty(failed) || println("instrumentation failed for: ", join(failed, ", "))
    end
    counts = Dict{String,Dict{Symbol,Int}}()          # max over passes
    covonly = Set{Tuple{String,Symbol}}()             # fired only in coverage pass
    if trace
        for (i, (name, _)) in enumerate(kinds)
            inst[i] === nothing && continue
            for pass in 1:2
                pass == 2 && isempty(recipes[name].kw2) && continue
                flame = pass == 1 ? inst[i] : recipes[name].make()
                kw = pass == 1 ? recipes[name].kw : merge(recipes[name].kw, recipes[name].kw2)
                foreach(c -> c[] = 0, values(counters))
                err = nothing
                t0 = time()
                try
                    Base.invokelatest(M.solve!, flame; kw...)
                catch e
                    err = e
                end
                dtp = round(time() - t0; digits=1)
                label = err === nothing ? "solved ($(dtp)s)" :
                    "ran $(dtp)s, solve! threw $(typeof(err).name): " *
                    first(sprint(showerror, err), 90)
                statuses[i] = pass == 1 ? label : statuses[i] * "; coverage: " * label
                for (k, c) in counters
                    d = get!(counts, k, Dict{Symbol,Int}())
                    pass == 2 && c[] > 0 && get(d, name, 0) == 0 && push!(covonly, (k, name))
                    d[name] = max(get(d, name, 0), c[])
                end
            end
        end
    end

    # ---------------------------------------------------------------- output
    io = IOBuffer()
    println(io, "# impact report")
    println(io)
    println(io, "- package: `", ROOT, "`")
    println(io, "- diff: `", base, "`..`", head, "` over `", join(prefixes, ","), "`")
    println(io, "- changed definitions: ", length(analyzed), " analysed, ",
        count(cd -> cd.status == :removed, changed), " removed")
    for (i, (name, _)) in enumerate(kinds)
        println(io, "- kind ", name, ": ", statuses[i])
    end
    println(io)
    println(io, "| changed method \\ kind | ", join(first.(kinds), " | "), " |")
    println(io, "|---|", join(("---" for _ in kinds), "|"), "|")
    for cd in changed
        cd.status == :removed && continue
        key = string(cd.path, ":", cd.def.startline)
        if isempty(cd.methods)
            cells = join(("." for _ in kinds), " | ")
            println(io, "| ", cd.def.name, " (", cd.path, ":", cd.def.startline,
                ") no method object | ", cells, " |")
            continue
        end
        cells = map(first.(kinds)) do name
            st = get(get(static, key, Dict()), name, "noslot")
            c = get(get(counts, key, Dict()), name, -1)
            if !trace || c < 0
                st
            elseif c > 0
                "REACH($c)" * ((key, name) in covonly ? "^" : "")
            else
                "no($st)"
            end
        end
        println(io, "| ", cd.def.name, ":", cd.def.startline, " | ", join(cells, " | "), " |")
    end
    for cd in changed
        cd.status == :removed && println(io, "- removed: ", cd.def.name, " (",
            cd.path, ":", cd.def.startline, ")")
    end
    isempty(covonly) || println(io,
        "\n`^` = reached only in the coverage pass (non-default `time_step_growth_strategy`); ",
        "other counts are from the default-options pass. `no(...)` = 0 calls under both passes; ",
        "the parenthesized word is the static `which` verdict (dispatch / other / noslot).")
    report = String(take!(io))
    println(report)
    isempty(opts[:out]) || (write(opts[:out], report); println("written ", opts[:out]))
    return report
end

if abspath(PROGRAM_FILE) == @__FILE__
    impact(ARGS)
end
