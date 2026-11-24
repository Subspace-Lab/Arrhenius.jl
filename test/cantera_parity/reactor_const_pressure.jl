if !isdefined(@__MODULE__, :native_bdf)
    include(joinpath(@__DIR__, "..", "..", "example", "reactors", "ode_solver.jl"))
end

function const_pressure_solve(label, solve_case)
    try
        solution = solve_case()
        @info "Constant-pressure solver completed" branch=label retcode=solution.retcode last_time=last(solution.t) stats=solution.stats
        return solution
    catch error
        # The existing adapters throw on failed retcodes and do not expose the
        # partial solution. Missing time/counters must not be invented as zero.
        @error "Constant-pressure solver failed" failure_kind="solver_failed" branch=label exception=sprint(showerror,error) last_time="not exposed by existing adapter" stats="not exposed by existing adapter"
        rethrow()
    end
end

@testset "Cantera parity: TestIdealGasConstPressureReactor.test_closed" begin
    _, provenance, _ = thermal_fixture()
    folder = joinpath(@__DIR__, "fixtures", "cantera-726522be", "const_pressure_18")
    manifest = TOML.parsefile(joinpath(folder, "fixture.toml"))
    manifest["cantera_commit"] == provenance["cantera_commit"] || error("Constant-pressure fixture commit mismatch")
    for key in ("raw", "normalized", "equivalence")
        path = joinpath(folder, manifest[key*"_file"])
        bytes2hex(sha256(replace(read(path,String), "\r\n"=>"\n"))) == manifest[key*"_sha256_lf"] ||
            error("Constant-pressure input gate failed: $key")
    end
    gas = CreateSolution(joinpath(folder, manifest["normalized_file"]); phase=manifest["phase"])
    @test gas.n_species == 18
    @test gas.n_reactions == 74
    composition = Dict("CH4"=>0.5,"H2O"=>0.2,"CO"=>0.3)
    vessel = WellStirredReactor(gas; temperature=1200.0, pressure=25one_atm,
        mole_fractions=composition, volume=0.2, energy=:adiabatic, chemistry=true)
    env = Reservoir(gas; temperature=900.0, pressure=25one_atm, mole_fractions=Dict("H2"=>1.0))
    model = MovingWallNetwork(ReactorNetwork((vessel=vessel,env=env));
        walls=(MovingWall(:vessel,:env; area=0.1,K=1e3,U=0.0),))
    reactor = IdealGasReactor(gas; temperature=1200.0, pressure=25one_atm,
        mole_fractions=composition, constraint=:constant_pressure, energy=:adiabatic)
    # The closed CP equations are specific quantities Y/T. Upstream volume
    # sets only this mass scale; the zero-K/zero-U reference wall contributes 0.
    cp_initial = reactor_properties(reactor)
    cp_mass = 0.2 * cp_initial.density
    initial_mass = moving_wall_diagnostics(model, moving_wall_state(model)).nodes.vessel.mass
    @test thermal_approx(initial_mass, cp_mass, provenance)
    @info "Closed constant-pressure setup" initial_volume=0.2 initial_mass=cp_mass normalized_sha256_lf=manifest["normalized_sha256_lf"] reference_max_err_test_fails=10 native_equivalent="none; existing QNDF failure policy retained"
    times = collect(0.5:1.0:49.5)
    moving = const_pressure_solve("moving_wall", () -> solve_moving_wall(model, (0.0,49.5);
        integrator=native_network_bdf, reltol=provenance["integration_rtol"],
        abstol=provenance["integration_atol"], dtmax=0.05, saveat=times,
        save_start=false, save_everystep=false))
    constant = const_pressure_solve("constant_pressure", () -> solve_reactor(reactor, (0.0,49.5);
        integrator=native_bdf, reltol=provenance["integration_rtol"],
        abstol=provenance["integration_atol"], dtmax=0.05, saveat=times,
        save_start=false, save_everystep=false))
    @test moving.t == times
    @test constant.t == times
    rows = Vector{Float64}[]
    states = []
    for (i,t) in enumerate(times)
        @test all(isfinite, moving.u[i])
        @test all(isfinite, constant.u[i])
        a = moving_wall_diagnostics(model, moving.u[i], t).nodes.vessel
        b = reactor_properties(reactor, constant.u[i])
        push!(states, (a,b))
        push!(rows, vcat(t,a.temperature,a.pressure,a.mass_fractions,b.temperature,b.pressure,b.mass_fractions))
    end
    output = get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output)
        path = joinpath(output,"const_pressure_closed.native.csv")
        isfile(path) && error("Select a fresh CANTERA_PARITY_RESULTS directory to preserve evidence")
        open(path,"w") do io
            for row in rows
                println(io,join(row,','))
            end
        end
        @info "Saved complete constant-pressure trajectory" path sha256_lf=bytes2hex(sha256(read(path))) columns="t,moving_T,moving_P,moving_Y[18],constant_T,constant_P,constant_Y[18]"
    end
    for (t,(a,b)) in zip(times,states)
        y_pass = all(thermal_approx(x,y,provenance;rtol=5e-4,atol=1e-6) for (x,y) in zip(a.mass_fractions,b.mass_fractions))
        t_pass = thermal_approx(a.temperature,b.temperature,provenance;rtol=5e-5)
        p_pass = thermal_approx(a.pressure,b.pressure,provenance)
        if !(y_pass && t_pass && p_pass)
            @info "Constant-pressure trajectory mismatch" failure_kind="solution_mismatch" time=t moving_T=a.temperature constant_T=b.temperature moving_P=a.pressure constant_P=b.pressure moving_Y=repr(a.mass_fractions) constant_Y=repr(b.mass_fractions)
        end
        @test y_pass
        @test t_pass
        @test p_pass
    end
    a,b = last(states)
    @info "Closed constant-pressure comparison" samples=length(times) final_time=last(times) moving_T=a.temperature constant_T=b.temperature moving_P=a.pressure constant_P=b.pressure moving_V=a.volume constant_V=cp_mass/b.density
end
