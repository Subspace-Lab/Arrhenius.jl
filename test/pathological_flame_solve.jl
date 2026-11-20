using Arrhenius, LinearAlgebra, SHA, Test

function _pathomech_flame_fixture(source, path, sidecar_source)
    cp(source, path; force=true)
    npz = Arrhenius.npzread(sidecar_source * ".npz")
    if haskey(npz, "source_sha256_utf8")
        npz["source_sha256_utf8"] = collect(codeunits(bytes2hex(SHA.sha256(read(path)))))
    end
    Arrhenius.npzwrite(path * ".npz", npz)
    path
end
function _pathomech_flame_counts(path, jacobian_mode)
    gas = CreateSolution(path)
    X = mole_fractions(gas, "H2:1.1,O2:1,AR:5")
    flame = FreeFlame(gas; X, width=0.03)
    outcome = "converged"
    try
        solve!(flame; jacobian_mode)
    catch err
        outcome = "failed: " * sprint(showerror, err)
    end
    stats = solver_stats(flame)
    sumY_max = nothing
    if outcome == "converged"
        Y = mass_fractions(flame)
        sumY_max = maximum(abs.(vec(sum(Y; dims=1)) .- 1))
    end
    (fixture=basename(path), jacobian_mode, outcome, iterations=stats.newton_iterations,
     jacobians=stats.jacobians, steps=stats.time_steps,
     failures=stats.time_step_failures, points=length(flame.grid),
     sumY_max)
end

@testset "pathological free-flame count report" begin
    group = get(ENV, "PATHOMECH_FLAME_GROUP", "nasa7")
    group in ("nasa7", "other", "all") || error("PATHOMECH_FLAME_GROUP must be nasa7, other, or all")
    base = joinpath(@__DIR__, "..", "mechanism", "h2o2.yaml")
    fixture_dir = joinpath(@__DIR__, "data", "pathological_mechanisms")
    mktempdir() do dir
        baseline = _pathomech_flame_counts(base, :finite_difference)
        function copied_case(source_name, target_name=source_name)
            source = joinpath(fixture_dir, source_name * ".yaml")
            target = joinpath(dir, target_name * ".yaml")
            _pathomech_flame_fixture(source, target, base)
        end
        reports = Any[]
        if group in ("nasa7", "all")
            push!(reports, _pathomech_flame_counts(copied_case("nasa7_small"), :finite_difference))
            large = copied_case("nasa7_large")
            push!(reports, _pathomech_flame_counts(large, :finite_difference))
            push!(reports, _pathomech_flame_counts(copied_case("nasa7_large", "nasa7_large_auto"), :auto))
        end
        if group in ("other", "all")
            for name in ("extreme_Ea", "collision_limit")
                push!(reports, _pathomech_flame_counts(copied_case(name), :finite_difference))
            end
        end
        @info "pathological flame counts" group baseline reports
    end
end
