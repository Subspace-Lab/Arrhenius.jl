# Pinned utilities.py::compareProfiles, including its independent x-error test.
function compare_wall_profiles(reference, sample; rtol, atol, xtol=1e-5)
    size(reference, 2) == size(sample, 2) || throw(ArgumentError("Profile column mismatch"))
    all(isfinite, reference) && all(isfinite, sample) || throw(ArgumentError("Non-finite profile"))
    rt, st = reference[:, 1], sample[:, 1]
    all(diff(rt) .> 0) && all(diff(st) .> 0) || throw(ArgumentError("Non-increasing profile time"))
    bad = NamedTuple[]
    for column in 2:size(reference, 2)
        ref, val = reference[:, column], sample[:, column]
        scale = max(maximum(abs, ref), maximum(ref)-minimum(ref),
                    maximum(abs, val), maximum(val)-minimum(val))
        slope = vcat(0.0, diff(ref) ./ diff(rt) .* (maximum(rt)-minimum(rt)))
        for j in eachindex(rt)
            k = searchsortedlast(st, rt[j])
            actual = if k == 0
                val[1]
            elseif k >= length(st)
                val[end]
            else
                val[k] + (val[k+1]-val[k]) / (st[k+1]-st[k]) * (rt[j]-st[k])
            end
            abserr = abs(ref[j]-actual)
            relerr = abserr / (scale+atol)
            xerr = abserr / (abs(slope[j])+atol)
            if abserr > atol && relerr > rtol && xerr > xtol
                push!(bad, (; time=rt[j], column=column-1, reference=ref[j], actual, abserr, relerr, xerr))
            end
        end
    end
    isempty(bad) && return nothing
    count = length(bad)
    count > 10 && sort!(bad; by=row -> -row.relerr)
    return "Failed series comparisons ($count points):\n" *
        join(string.(bad[1:min(count, 10)]), "\n")
end

wall_matrix(rows) = [Float64(rows[i][j]) for i in eachindex(rows), j in eachindex(first(rows))]

@testset "Cantera parity: profile comparator selfchecks" begin
    checks = TOML.parsefile(joinpath(@__DIR__, "profile_comparison_cases.toml"))
    for case in checks["cases"]
        report = compare_wall_profiles(wall_matrix(case["reference"]), wall_matrix(case["sample"]);
            rtol=checks["rtol"], atol=checks["atol"], xtol=checks["xtol"])
        @test isnothing(report) == case["passes"]
    end
end

function wall_fixture()
    gas, provenance, digest = thermal_fixture()
    folder = joinpath(@__DIR__, "fixtures", "cantera-726522be")
    inputs = TOML.parsefile(joinpath(folder, "wall_provenance.toml"))
    inputs["cantera_commit"] == provenance["cantera_commit"] || error("Wall fixture commit mismatch")
    for (name, key) in (("air.yaml", "air_sha256_lf"),
                        ("WallTest-integrateWithAdvance.csv", "profile_sha256_lf"))
        bytes2hex(sha256(replace(read(joinpath(folder, name), String), "\r\n"=>"\n"))) == inputs[key] ||
            error("Pinned wall input mismatch: $name")
    end
    air = CreateSolution(joinpath(folder, "air.yaml"); phase=inputs["air_phase"])
    air.n_species == 8 && air.n_reactions == 8 || error("Unexpected air phase")
    r1 = WellStirredReactor(air; temperature=1000.0, pressure=30one_atm,
        mole_fractions=Dict("AR"=>1.0), volume=1.0, energy=:adiabatic, chemistry=true)
    r2 = WellStirredReactor(gas; temperature=500.0, pressure=1.5one_atm,
        mole_fractions=Dict("H2"=>0.5,"O2"=>1.0,"AR"=>10.0), volume=1.0, energy=:adiabatic, chemistry=true)
    env = Reservoir(air; temperature=300.0, pressure=one_atm,
        mole_fractions=Dict("O2"=>0.21,"N2"=>0.78,"AR"=>0.01))
    base = ReactorNetwork((r1=r1,r2=r2,env=env); walls=(HeatTransferWall(:r2,:env; area=1.0,U=2000.0),))
    model = MovingWallNetwork(base; walls=(MovingWall(:r2,:r1; area=1.0,K=2e-4,U=400.0),))
    reference = wall_matrix([parse.(Float64, split(line, ',')) for line in
        readlines(joinpath(folder, "WallTest-integrateWithAdvance.csv")) if !isempty(strip(line))])
    size(reference) == (199, 7) || error("Unexpected pinned wall profile dimensions")
    return model, provenance, inputs, reference
end

function wall_row(model, state, t)
    nodes = moving_wall_diagnostics(model, state, t).nodes
    return (Float64(t), nodes.r1.temperature, nodes.r2.temperature,
            nodes.r1.pressure, nodes.r2.pressure, nodes.r1.volume, nodes.r2.volume)
end

function save_wall_trajectory(name, data)
    folder = get(ENV, "CANTERA_PARITY_RESULTS", nothing)
    folder === nothing && return nothing
    mkpath(folder)
    path = joinpath(folder, "$name.native.csv")
    isfile(path) && error("Preserve existing trajectory; select a fresh CANTERA_PARITY_RESULTS directory")
    open(path, "w") do io
        for row in eachrow(data)
            println(io, join(row, ','))
        end
    end
    @info "Saved complete wall trajectory" path sha256_lf=bytes2hex(sha256(read(path)))
end

for mode in ("step", "advance")
    case_selected("wall_$mode") || continue
    method = mode == "step" ? "test_integrateWithStep" : "test_integrateWithAdvance"
    @testset "Cantera parity: TestWall.$method" begin
        model, provenance, inputs, reference = wall_fixture()
        rows = NTuple{7,Float64}[]
        if mode == "step"
            problem = moving_wall_problem(model, (0.0, 0.1))
            f = ODEFunction(problem.f; jac=problem.jac, tgrad=problem.tgrad)
            ode = ODEProblem(f, problem.u0, problem.tspan, problem.p)
            integrator = SciMLBase.init(ode, QNDF(); isoutofdomain=problem.isoutofdomain,
                reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
                save_everystep=false)
            previous = 0.0
            while integrator.t < 0.01
                previous = integrator.t
                SciMLBase.step!(integrator)
                integrator.t > previous || error("Wall step integration did not advance")
                integrator.sol.retcode in (SciMLBase.ReturnCode.Default, SciMLBase.ReturnCode.Success) ||
                    error("Wall step integration failed: $(integrator.sol.retcode)")
                push!(rows, wall_row(model, integrator.u, integrator.t))
            end
            @test previous < 0.01 <= integrator.t
            rtol, atol = 1e-3, 1e-8
            @info "Wall accepted-step solve" steps=length(rows) final_time=integrator.t stats=integrator.sol.stats
        else
            times = collect(range(0.0, 0.01; length=200))[2:end]
            solution = solve_moving_wall(model, (0.0, 0.01); integrator=native_network_bdf,
                reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
                saveat=times, save_start=false, save_everystep=false)
            @test solution.t == times
            for (t, state) in zip(solution.t, solution.u)
                push!(rows, wall_row(model, state, t))
            end
            rtol, atol = 2e-5, 1e-9
            @info "Wall advance solve" samples=length(rows) final_time=last(solution.t) stats=solution.stats
        end
        data = wall_matrix(rows)
        @test all(isfinite, data)
        save_wall_trajectory("wall_$mode", data)
        report = compare_wall_profiles(reference, data; rtol, atol)
        report !== nothing && @info "Wall profile comparison failure" report
        @test isnothing(report)
        @info "Wall profile result" mode samples=size(data,1) final_row=repr(rows[end]) rtol atol xtol=1e-5 profile_sha256_lf=inputs["profile_sha256_lf"]
    end
end
