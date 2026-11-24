@testset "Cantera parity: zerodim.simple" begin
    fixture = joinpath(@__DIR__, "fixtures", "cantera-726522be")
    provenance = TOML.parsefile(joinpath(fixture, "provenance.toml"))
    manifest = TOML.parsefile(joinpath(fixture, "gri30_provenance.toml"))
    manifest["cantera_commit"] == provenance["cantera_commit"] || error("C++ fixture commit mismatch")
    path = joinpath(fixture, manifest["mechanism_file"])
    digest = bytes2hex(sha256(replace(read(path,String), "\r\n"=>"\n")))
    digest == manifest["mechanism_sha256_lf"] || error("C++ fixture digest mismatch")
    gas = CreateSolution(path; phase=manifest["phase"])
    (gas.n_species == manifest["species_count"] && gas.n_reactions == manifest["reaction_count"] &&
     gas.species_names == manifest["species_names"]) || error("C++ fixture phase/order/count mismatch")
    Base.pkgversion(SciMLBase) == v"2.155.2" || error("SciMLBase 2.155.2 required")
    Base.pkgversion(OrdinaryDiffEqBDF) == v"1.26.0" || error("OrdinaryDiffEqBDF 1.26.0 required")
    vessel = WellStirredReactor(gas; temperature=1050.0, pressure=5one_atm,
        mole_fractions=Dict("CH4"=>1.0,"O2"=>2.0,"N2"=>7.52), volume=1.0,
        energy=:adiabatic, chemistry=true)
    model = ReactorNetwork((simple=vessel,))
    # The existing node identifier maps the source reactor name; this is not
    # a new general reactor-name or explicit-initialize API.
    @test keys(model.nodes) == (:simple,)
    times = Float64[0.0]
    while last(times) < 0.1
        push!(times, last(times) + 5e-3)
    end
    @test length(times) == 21
    started = time_ns()
    solution = try
        solve_network(model, (0.0,last(times)); integrator=native_network_bdf,
            reltol=manifest["integration_rtol"], abstol=manifest["integration_atol"],
            saveat=times[2:end], save_start=true, save_everystep=false)
    catch error
        @error "C++ simple native solver failed" failure_kind="solver_failed" exception=sprint(showerror,error) last_time="not exposed by existing adapter" stats="not exposed by existing adapter" elapsed_seconds=(time_ns()-started)/1e9
        rethrow()
    end
    elapsed = (time_ns()-started)/1e9
    @info "C++ simple native solver completed" retcode=solution.retcode last_time=last(solution.t) solve_elapsed_seconds=elapsed stats=solution.stats
    @test SciMLBase.successful_retcode(solution)
    @test solution.t == times
    @test last(solution.t) >= 0.1
    rhs = network_rhs(model)
    states = []
    rows = Vector{Float64}[]
    for (t,u) in zip(solution.t,solution.u)
        @test all(isfinite,u)
        state = network_diagnostics(rhs,u,t).nodes.simple
        push!(states,state)
        push!(rows,vcat(t,state.temperature,state.pressure,state.mass_fractions))
    end
    output = get(ENV,"CANTERA_PARITY_RESULTS",nothing)
    if output !== nothing
        mkpath(output)
        csv = joinpath(output,"zerodim_simple.native.csv")
        isfile(csv) && error("Select a fresh CANTERA_PARITY_RESULTS directory to preserve evidence")
        open(csv,"w") do io
            for row in rows
                println(io,join(row,','))
            end
        end
        @info "Saved C++ simple native samples" path=csv sha256_lf=bytes2hex(sha256(read(csv))) columns="t,T,P,Y[53]"
    end
    # Source asserts before advancing, so the final sample is not another
    # temperature-floor assertion. No comparison tolerance or monotonicity rule.
    for state in states[1:end-1]
        @test state.temperature >= 1050.0
    end
    @info "C++ simple native result" samples=length(times) upstream_temperature_checks=length(states)-1 initial_mass=first(states).mass final_T=last(states).temperature final_P=last(states).pressure min_checked_T=minimum(s.temperature for s in states[1:end-1]) mechanism_sha256_lf=digest validation_scope="temperature floor and successful integration; no trajectory-accuracy claim"
end
