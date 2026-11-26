for mode in ("step", "advance", "invasive")
    case_selected("combustor_$mode") || continue
    method = mode == "step" ? "test_integrateWithStep" :
             mode == "advance" ? "test_integrateWithAdvance" : "test_invasive_mdot_function"
    @testset "Cantera parity: TestCombustor.$method" begin
        gas, provenance, digest = thermal_fixture()
        folder = joinpath(@__DIR__, "fixtures", "cantera-726522be")
        inputs = TOML.parsefile(joinpath(folder, "combustor_provenance.toml"))
        inputs["cantera_commit"] == provenance["cantera_commit"] || error("Combustor commit mismatch")
        digest == inputs["mechanism_sha256_lf"] || error("Combustor mechanism mismatch")
        (gas.n_species == inputs["species_count"] && gas.n_reactions == inputs["reaction_count"] &&
            gas.species_names == inputs["species_names"]) || error("Combustor phase/order/count mismatch")
        profile = joinpath(folder, inputs["profile_file"])
        bytes2hex(sha256(replace(read(profile,String), "\r\n"=>"\n"))) == inputs["profile_sha256_lf"] ||
            error("Combustor reference profile mismatch")
        reference = wall_matrix([parse.(Float64,split(line,',')) for line in readlines(profile)
                                if !isempty(strip(line))])
        size(reference) == (100,12) || error("Unexpected combustor reference dimensions")
        fuel = Reservoir(gas; temperature=300.0, pressure=one_atm, mole_fractions=Dict("H2"=>1.0))
        oxidizer = Reservoir(gas; temperature=300.0, pressure=one_atm, mole_fractions=Dict("O2"=>1.0,"AR"=>3.0))
        igniter = Reservoir(gas; temperature=300.0, pressure=one_atm, mole_fractions=Dict("H"=>1.0))
        exhaust = Reservoir(gas; temperature=300.0, pressure=one_atm, mole_fractions=Dict("AR"=>1.0))
        vessel = WellStirredReactor(gas; temperature=300.0, pressure=one_atm,
            mole_fractions=Dict("AR"=>1.0), volume=1.0, energy=:adiabatic, chemistry=true)
        iH2 = something(findfirst(==("H2"),gas.species_names))
        iO2 = something(findfirst(==("O2"),gas.species_names))
        iAr = something(findfirst(==("AR"),gas.species_names))
        fuel_mdot = 0.1 * gas.MW[iH2]
        oxidizer_mw = (gas.MW[iO2]+3gas.MW[iAr])/4
        oxidizer_mdot = 4 * 0.1 * oxidizer_mw
        # Gaussian1 width is FWHM, not standard deviation. No truncation or tstop.
        igniter_mdot(t) = 0.1 * exp(-4log(2.0)*(t-0.1)^2/0.05^2)
        density_reads = Ref(0)
        density_min, density_max = Ref(Inf), Ref(-Inf)
        function invasive_mdot(states,t)
            # Existing public callback states are read-only. Observe the actual
            # upstream reservoir, not a captured constant or the reacting vessel.
            density = states.igniter.density
            density_reads[] += 1
            density_min[] = min(density_min[],density)
            density_max[] = max(density_max[],density)
            # Preserve the source callback's operation order, separately from
            # the ordinary Gaussian callback used by the earlier modes.
            return 0.1 * exp(-(t-0.1)^2 * 4 * log(2.0) / 0.05^2)
        end
        model = ReactorNetwork((vessel=vessel,fuel=fuel,oxidizer=oxidizer,igniter=igniter,exhaust=exhaust);
            flows=(MassFlowController(:fuel,:vessel;mdot=fuel_mdot),
                   MassFlowController(:oxidizer,:vessel;mdot=oxidizer_mdot),
                   MassFlowController(:igniter,:vessel;mdot=mode == "invasive" ? invasive_mdot : igniter_mdot),
                   Valve(:vessel,:exhaust;K=1.0)))
        rows = Vector{Float64}[]
        diagnostic_rhs = network_rhs(model)
        if mode == "step"
            problem = network_problem(model,(0.0,0.5))
            f = ODEFunction(problem.f; jac=problem.jac,tgrad=problem.tgrad)
            ode = ODEProblem(f,problem.u0,problem.tspan,problem.p)
            integrator = SciMLBase.init(ode,QNDF();isoutofdomain=problem.isoutofdomain,
                reltol=inputs["integration_rtol"],abstol=inputs["integration_atol"],save_everystep=false)
            previous = 0.0
            started = time_ns()
            try
                while integrator.t < 0.25
                    previous = integrator.t
                    SciMLBase.step!(integrator)
                    integrator.t > previous || error("Combustor integration did not advance")
                    integrator.sol.retcode in (SciMLBase.ReturnCode.Default,SciMLBase.ReturnCode.Success) ||
                        error("Combustor integration failed: $(integrator.sol.retcode)")
                    state = network_diagnostics(diagnostic_rhs,integrator.u,integrator.t).nodes.vessel
                    X = state.mass_fractions ./ gas.MW
                    X ./= sum(X)
                    push!(rows,vcat(integrator.t,state.temperature,X))
                end
            catch error
                @error "Combustor solver failed" failure_kind="solver_failed" exception=sprint(showerror,error) retcode=integrator.sol.retcode last_time=integrator.t stats=integrator.sol.stats
                isempty(rows) || save_wall_trajectory("combustor_step_partial",wall_matrix(rows))
                rethrow()
            end
            @info "Combustor accepted-step solve" steps=length(rows) previous_time=previous final_time=integrator.t retcode=integrator.sol.retcode stats=integrator.sol.stats stepping_elapsed_seconds=(time_ns()-started)/1e9 fuel_mdot oxidizer_mdot
            @test previous < 0.25 <= integrator.t
        else
            # Match NumPy linspace's Float64 spacing; these are output times, not
            # internal step bounds. Dense output preserves the existing QNDF policy.
            times = [i * (0.25 / 100) for i in 1:100]
            started = time_ns()
            solution = try
                solve_network(model,(0.0,0.25);integrator=native_network_bdf,
                    reltol=inputs["integration_rtol"],abstol=inputs["integration_atol"],
                    saveat=times,save_start=false,save_everystep=false)
            catch error
                @error "Combustor advance solver failed" failure_kind="solver_failed" exception=sprint(showerror,error) last_time="not exposed by existing adapter" stats="not exposed by existing adapter"
                rethrow()
            end
            @info "Combustor advance solve" samples=length(solution.t) final_time=last(solution.t) retcode=solution.retcode stats=solution.stats solve_elapsed_seconds=(time_ns()-started)/1e9 fuel_mdot oxidizer_mdot
            @test SciMLBase.successful_retcode(solution)
            @test solution.t == times
            @test last(solution.t) == 0.25
            if mode == "invasive"
                # Snapshot before post-solve diagnostics invoke the RHS again.
                @info "Invasive callback during solve" density_reads=density_reads[] min_density=density_min[] max_density=density_max[] expected_density=igniter.initial.density
                @test density_reads[] > 0
                @test (density_min[],density_max[]) == (igniter.initial.density,igniter.initial.density)
            end
            for (t,u) in zip(solution.t,solution.u)
                state = network_diagnostics(diagnostic_rhs,u,t).nodes.vessel
                X = state.mass_fractions ./ gas.MW
                X ./= sum(X)
                push!(rows,vcat(t,state.temperature,X))
            end
        end
        data = wall_matrix(rows)
        @test all(isfinite,data)
        @test all(diff(data[:,1]) .> 0)
        save_wall_trajectory("combustor_$mode",data)
        rtol = inputs[mode == "step" ? "profile_rtol" : "advance_profile_rtol"]
        atol = inputs[mode == "step" ? "profile_atol" : "advance_profile_atol"]
        report = compare_wall_profiles(reference,data;rtol,atol,xtol=inputs["profile_xtol"])
        report !== nothing && @info "Combustor profile comparison failure" failure_kind="profile_exceeded" report
        @test isnothing(report)
        @info "Combustor profile result" mode rtol atol final_row=repr(rows[end]) profile_sha256_lf=inputs["profile_sha256_lf"] mechanism_sha256_lf=digest
    end
end
