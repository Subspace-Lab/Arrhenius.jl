using Arrhenius, LinearAlgebra, Test, YAML

@testset "pathological mechanism diagnostics and finite evaluation" begin
    fixture_dir = joinpath(@__DIR__, "data", "pathological_mechanisms")
    cases = Dict(name => joinpath(fixture_dir, "$name.yaml") for name in (
        "clean", "nasa7_small", "nasa7_large", "nasa7_slope_only", "plog_underflow",
        "duplicate_unflagged", "unbalanced", "negative_A", "extreme_Ea",
        "collision_limit"))
    expected = Dict(
        "nasa7_large" => (:nasa_continuity, :warning),
        "nasa7_slope_only" => (:nasa_continuity, :warning),
        "plog_underflow" => (:plog_zero_rate, :error),
        "duplicate_unflagged" => (:duplicate_unflagged_candidates, :error),
        "unbalanced" => (:element_balance, :error),
        "negative_A" => (:negative_A, :error))
    for (name, path) in cases
        report = audit_mechanism(path)
        if haskey(expected, name)
            check, level = expected[name]
            matching = filter(x -> x.check == check && x.level == level, report.issues)
            @test !isempty(matching)
            @test all(x -> !hasproperty(x, :detail) || !isempty(x.detail), matching)
            if name == "plog_underflow"
                @test all(x -> x.pressure == maximum(y.pressure for y in matching), matching)
                @test !any(x -> x.temperature in (5000.0, 10000.0), matching)
            end
        end
        if name == "nasa7_slope_only"
            issue = only(filter(x -> x.check == :nasa_continuity && x.species == "H2", report.issues))
            @test abs(issue.delta_cp_R) < 1e-6
            @test abs(issue.delta_h_RT) < 1e-6
            @test abs(issue.delta_s_R) < 1e-6
            @test abs(issue.delta_dcp_R_dT) > 1e-6
        elseif name == "collision_limit"
            @test !any(x -> x.check == :collision_limit_screen, report.issues)
        end
        gas = CreateSolution(path)
        Y = ones(gas.n_species) ./ gas.n_species
        for T in (250.0, 999.999, 1000.0, 1000.001, 2500.0, 3500.0)
            source = set_states(gas, T, one_atm, Y)
            @test all(isfinite, source)
            X = Y2X(gas, Y, 1 / dot(Y, 1 ./ gas.MW))
            @test all(isfinite, Arrhenius.cal_cp_R(gas, T, one_atm, X))
            @test all(isfinite, Arrhenius.cal_h_RT(gas, T, one_atm, X))
            @test all(isfinite, Arrhenius.cal_s0_R(gas, T, one_atm, X))
        end
    end
end
