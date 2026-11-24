for mode in ("nonreacting", "ignition1", "ignition2", "ignition3")
    case_selected("wsr_$mode") || continue
    @testset "Cantera parity: TestWellStirredReactorIgnition.test_$mode" begin
        folder = joinpath(@__DIR__, "fixtures", "cantera-726522be", "wsr24")
        inputs = TOML.parsefile(joinpath(folder, "fixture.toml"))
        mechanism = joinpath(folder, inputs["mechanism_file"])
        digest = bytes2hex(sha256(replace(read(mechanism,String), "\r\n"=>"\n")))
        digest == inputs["mechanism_sha256_lf"] || error("WSR mechanism mismatch")
        gas = CreateSolution(mechanism; phase=inputs["phase"])
        (gas.species_names == inputs["species_names"] && gas.n_reactions == 129 &&
            gas.n_species == 24) || error("WSR phase/order/count mismatch")
        fuel = Reservoir(gas; temperature=900.0, pressure=10one_atm, mole_fractions=Dict("CH4"=>1.0))
        oxidizer = Reservoir(gas; temperature=900.0, pressure=10one_atm, mole_fractions=Dict("O2"=>1.0,"N2"=>3.76))
        exhaust = Reservoir(gas; temperature=900.0, pressure=10one_atm, mole_fractions=Dict("N2"=>1.0))
        # Only nonreacting disables rates; ignition cases use unit multipliers.
        vessel = WellStirredReactor(gas; temperature=900.0, pressure=10one_atm,
            mole_fractions=Dict("N2"=>1.0), volume=1.0, energy=:adiabatic,
            chemistry=true, rate_multipliers=mode == "nonreacting" ? zeros(gas.n_reactions) : nothing)
        oxidizer_mdot = mode == "ignition3" ? 80.0 : mode == "ignition2" ? 20.0 : 5.0
        model = ReactorNetwork((vessel=vessel,fuel=fuel,oxidizer=oxidizer,exhaust=exhaust);
            flows=(MassFlowController(:fuel,:vessel;mdot=1.0),
                   MassFlowController(:oxidizer,:vessel;mdot=oxidizer_mdot),
                   Valve(:vessel,:exhaust;K=1.0)))
        final_time = mode in ("nonreacting", "ignition3") ? 100.0 : 10.0
        # network_problem requires a finite interval. Keep ignition2's endpoint
        # beyond its natural crossing step, and verify it did not truncate it.
        nominal_end = mode == "ignition2" ? 100.0 : 2final_time
        problem = network_problem(model,(0.0,nominal_end))
        ode = ODEProblem(ODEFunction(problem.f; jac=problem.jac,tgrad=problem.tgrad),
            problem.u0,problem.tspan,problem.p)
        step_options = mode == "ignition3" ? (;dtmax=0.5) : (;)
        integrator = SciMLBase.init(ode,QNDF();isoutofdomain=problem.isoutofdomain,
            reltol=inputs["integration_rtol"],abstol=inputs["integration_atol"],save_everystep=false,
            step_options...)
        diagnostic_rhs = network_rhs(model)
        rows = Vector{Float64}[]
        previous = 0.0
        started = time_ns()
        try
            while integrator.t < final_time
                previous = integrator.t
                SciMLBase.step!(integrator)
                integrator.t > previous || error("WSR integration did not advance")
                integrator.sol.retcode in (SciMLBase.ReturnCode.Default,SciMLBase.ReturnCode.Success) ||
                    error("WSR integration failed: $(integrator.sol.retcode)")
                state = network_diagnostics(diagnostic_rhs,integrator.u,integrator.t).nodes.vessel
                push!(rows,vcat(integrator.t,state.temperature,state.pressure,state.mass_fractions))
            end
        catch error
            @error "WSR solver failed" failure_kind="solver_failed" exception=sprint(showerror,error) retcode=integrator.sol.retcode last_time=integrator.t stats=integrator.sol.stats
            isempty(rows) || save_wall_trajectory("wsr_$(mode)_partial",wall_matrix(rows))
            rethrow()
        end
        data = wall_matrix(rows)
        save_wall_trajectory("wsr_$mode",data)
        @info "WSR accepted-step result" mode steps=length(rows) previous_time=previous final_time=integrator.t retcode=integrator.sol.retcode stats=integrator.sol.stats stepping_elapsed_seconds=(time_ns()-started)/1e9 max_temperature_error=maximum(abs.(data[:,2].-900.0)) final_CH4=data[end,3+something(findfirst(==("CH4"),gas.species_names))] mechanism_sha256_lf=digest reference_max_err_test_fails=10 native_equivalent="none; existing QNDF failure policy retained"
        @test previous < final_time <= integrator.t
        if mode in ("ignition2", "ignition3")
            @test integrator.t < nominal_end
        end
        @test all(isfinite,data)
        @test all(diff(data[:,1]) .> 0)
        if mode == "nonreacting"
            for T in data[:,2]
                @test abs(T-900.0) <= max(inputs["assertion_atol"],inputs["temperature_rtol"]*900.0)
            end
            iCH4 = something(findfirst(==("CH4"),gas.species_names))
            @test abs(data[end,3+iCH4]-1/6) <= max(inputs["assertion_atol"],inputs["assertion_rtol"]*(1/6))
        elseif mode == "ignition3"
            @info "WSR nonignition criterion" oxidizer_mdot max_time_step=integrator.opts.dtmax largest_saved_time_increment=maximum(diff(vcat(0.0,data[:,1]))) final_temperature=data[end,2]
            @test integrator.opts.dtmax == 0.5
            @test data[end,2] < 910.0
        else
            @test data[end,2] > 1200.0
            # Source T[0] is the first POST-step sample, not the nominal initial T.
            threshold = 0.5 * (data[1,2] + data[end,2])
            crossing = findfirst(>(threshold),data[:,2])
            @test crossing !== nothing
            if crossing !== nothing
                tIg = data[crossing,1]
                expected_time = mode == "ignition2" ? 1.4856 : 2.2249
                @info "WSR ignition criterion" mode oxidizer_mdot threshold crossing ignition_time=tIg preceding_row=(crossing > 1 ? repr(rows[crossing-1]) : "none") crossing_row=repr(rows[crossing]) final_temperature=data[end,2] expected_ignition_time=expected_time assertion_rtol=1e-3 assertion_atol=1e-12
                @test abs(tIg-expected_time) <= max(1e-12,1e-3*expected_time)
            end
        end
    end
end
