# Unit tests for the parsing layer of test/tools/impact.jl (changed-definition
# extraction feeding the kind x changed-method impact table).  Pure string/git
# logic: no flame solves here.  The scanner's spans are the regression surface
# — a wrong span maps a hunk to the wrong method and the impact table lies.
include(joinpath(@__DIR__, "impact.jl"))

@testset "impact tool parsing" begin
    @testset "match_shortform" begin
        @test match_shortform("foo(x) = x + 1") == ("foo", :line)
        @test match_shortform("@inline foo(x::T) where {T} = zero(T)") == ("foo", :line)
        @test match_shortform("Base.length(f::F) = f.n") == ("Base.length", :line)
        @test match_shortform("a == b") === nothing          # comparison, not def
        @test match_shortform("x => y") === nothing          # pair syntax
        @test match_shortform("d[k] = v") === nothing        # index assignment
        @test match_shortform("# foo(x) = 1") === nothing
        @test match_shortform("  cont(x) = 3") == ("cont", :line)
    end

    @testset "scan_definitions spans" begin
        src = """
        # comment mentioning end
        module M
        function outer(f; kw=1)
            inner(x) = x^2             # short form inside
            s = "string with end and function"
            begin
                y = f + 1
            end
            return inner(y)
        end
        _helper(x) = 2x
        Base.show(io::IO, p::Point) = print(io, "Point")  # end in string
        function kw!(f,
                     a,
                     b)
            f + a + b
        end
        end # module
        """
        defs = scan_definitions(src)
        spans = Dict(d.name => (d.startline, d.endline) for d in defs)
        @test Set(keys(spans)) == Set(["outer", "inner", "_helper", "Base.show", "kw!"])
        lines = split(src, '\n')
        # `end` inside strings/comments must not close the function: outer's
        # span runs to its own end, past the begin/end pair and the string.
        @test spans["outer"] == (3, 10)
        @test occursin("function outer", lines[spans["outer"][1]])
        @test strip(lines[spans["outer"][2]]) == "end"
        @test spans["inner"] == (4, 4)            # nested closure captured
        @test spans["kw!"] == (13, 17)            # multi-line signature
        @test occursin("function kw!", lines[spans["kw!"][1]])
    end

    @testset "blank_code keeps line structure" begin
        src = "a = 1 # end comment\nb = \"str with # and =#\"\nc = 2\n"
        blanked = blank_code(src)
        @test blanked == "a = 1 " * " "^13 * "\n" * "b = " * " "^19 * "\nc = 2\n"
        @test length(split(src, '\n')) == length(split(blanked, '\n'))
    end

    @testset "parse_diff ranges" begin
        text = """
        diff --git a/src/A.jl b/src/A.jl
        index 111..222 100644
        --- a/src/A.jl
        +++ b/src/A.jl
        @@ -2,4 +2,5 @@
         ctx
        -old1
        -old2
        +new1
        +new2
        +new3
         ctx
        diff --git /dev/null b/src/B.jl
        new file mode 100644
        --- /dev/null
        +++ b/src/B.jl
        @@ -0,0 +1,2 @@
        +b1
        +b2
        """
        frs = parse_diff(text)
        @test length(frs) == 2
        a = only(fr for fr in frs if occursin("A.jl", fr.path))
        # Ranges are FILE-LINE coordinates in the head (plus) / base (minus)
        # file, so they can be intersected with method.line directly.
        @test a.plus == [3:5]
        @test a.minus == [3:4]
        b = only(fr for fr in frs if occursin("B.jl", fr.path))
        @test b.plus == [1:2] && isempty(b.minus)
    end

    @testset "changed_definitions on package history" begin
        # Same ref twice: no diff, no changed defs (git plumbing round trip).
        changed, _ = changed_definitions("HEAD", "HEAD", ["src"])
        @test isempty(changed)
        # The regression the tool exists for: #36 added the diffusion-specific
        # growth residual.  Skip when history is unavailable (shallow clone).
        if success(run(`git -C $ROOT cat-file -e 4644508`))
            changed, _ = changed_definitions("4644508", "2250285", ["src"])
            names = [d.def.name for d in changed]
            @test "_counterflow_growth_residual!" in names
            @test "_counterflow_newton!" in names
            gr = filter(d -> d.def.name == "_counterflow_growth_residual!" &&
                d.status == :added, changed)
            @test length(gr) == 2          # generic + ::CounterflowDiffusionFlame
            # Added defs' spans lie inside the head file's plus ranges.
            headsrc = git_show("2250285", "src/CounterflowFlames.jl")
            for d in gr
                lines = split(headsrc, '\n')
                @test occursin("_counterflow_growth_residual!", lines[d.def.startline])
            end
        else
            @warn "impact test: commit 4644508 absent, skipping history check"
        end
    end
end
