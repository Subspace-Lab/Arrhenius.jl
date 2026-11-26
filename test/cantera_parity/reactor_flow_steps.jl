# Use the same QNDF function/domain configuration as native_network_bdf, with
# caller-owned stepping to inspect every accepted step as upstream net.step()
# does. The unused 2 s horizon lets the first step crossing 1 s finish normally.
function flow_step_integrator(network; reltol, abstol)
    problem = network_problem(network, (0.0, 2.0))
    f = ODEFunction(problem.f; jac=problem.jac, tgrad=problem.tgrad)
    ode = ODEProblem(f, problem.u0, problem.tspan, problem.p)
    return SciMLBase.init(ode, QNDF(); isoutofdomain=problem.isoutofdomain,
        reltol, abstol, save_everystep=false)
end

if case_selected("mass_flow_controller")
    @testset "Cantera parity: TestIdealGasReactor.test_mass_flow_controller" begin
        gas, provenance, digest = thermal_fixture()
        vessel = WellStirredReactor(gas; temperature=300.0, pressure=one_atm,
            mole_fractions=Dict("O2"=>1.0), volume=1.0, chemistry=true)
        inlet = Reservoir(gas; temperature=300.0, pressure=10one_atm, mole_fractions=Dict("H2"=>1.0))
        mdot(t) = 0.2 <= t < 1.2 ? 0.2 - 0.4 * abs(t - 0.7) : 0.0
        mfc = MassFlowController(:inlet, :vessel; mdot)
        network = ReactorNetwork((vessel=vessel, inlet=inlet); flows=(mfc,))
        @test mfc isa MassFlowController
        # Native mdot is the complete rate: its implicit unit coefficient is
        # checked at the pulse peak, without inventing a coefficient getter.
        @test thermal_approx(network_diagnostics(network, network_state(network), 0.7).mass_flow_rates[1], 0.2, provenance)
        inlet_inlets = [f for (f, (_, down)) in zip(network.flows, network.flow_endpoints) if down == 2]
        inlet_outlets = [f for (f, (up, _)) in zip(network.flows, network.flow_endpoints) if up == 2]
        vessel_inlets = [f for (f, (_, down)) in zip(network.flows, network.flow_endpoints) if down == 1]
        vessel_outlets = [f for (f, (up, _)) in zip(network.flows, network.flow_endpoints) if up == 1]
        @test isempty(inlet_inlets)
        @test length(inlet_outlets) == 1
        @test only(inlet_outlets) === mfc
        @test isempty(vessel_outlets)
        @test length(vessel_inlets) == 1
        @test only(vessel_inlets) === mfc
        initial = network_diagnostics(network).nodes
        times = [0.1, 0.3, 1.0, 1.2, 2.5]
        solution = solve_network(network, (0.0, 2.5); integrator=native_network_bdf,
            reltol=1e-11, abstol=provenance["integration_atol"], dtmax=0.05,
            saveat=times, save_start=false, save_everystep=false)
        @test solution.t == times
        @test all(state -> all(isfinite, state), solution.u)
        for (i, expected) in enumerate((0.0, 0.04, 0.08, 0.0))
            diagnostic = network_diagnostics(network, solution.u[i], times[i])
            @test thermal_approx(diagnostic.mass_flow_rates[1], expected, provenance)
        end
        final = network_diagnostics(network, last(solution.u), last(solution.t)).nodes.vessel
        @test thermal_approx(initial.vessel.mass + 0.1, final.mass, provenance)
        expected_species = initial.vessel.mass .* initial.vessel.mass_fractions +
                           0.1 .* initial.inlet.mass_fractions
        for (name, expected, actual) in zip(gas.species_names, expected_species,
                                           final.mass .* final.mass_fractions)
            if !thermal_approx(expected, actual, provenance)
                @info "Pulse species mass mismatch" species=name expected_mass=expected actual_mass=actual absolute_error=abs(expected-actual) allowed_error=max(provenance["assertion_atol"], provenance["assertion_rtol"]*abs(actual))
            end
        end
        @test all(thermal_approx(a, b, provenance) for (a, b) in
                  zip(expected_species, final.mass .* final.mass_fractions))
        @info "Triangular mass-flow pulse" time=last(solution.t) initial_mass=initial.vessel.mass final_mass=final.mass injected_mass=final.mass-initial.vessel.mass temperature=final.temperature pressure=final.pressure mechanism_sha256_lf=digest
    end
end

if case_selected("valve3")
    @testset "Cantera parity: TestIdealGasReactor.test_valve3" begin
        gas, provenance, digest = thermal_fixture()
        mdot(dp) = dp > 0 ? 5e-3 * sqrt(dp) : 0.0
        network, valve = valve_pair(gas; left_composition=Dict("AR"=>0.5, "O2"=>0.5),
            K=1.0, pressure_function=mdot)
        @test valve.K == 1.0
        initial = network_diagnostics(network).nodes
        indices = [something(findfirst(==(s), gas.species_names)) for s in ("AR", "O2")]
        initial_mass = [initial.left.mass * initial.left.mass_fractions[k] +
                        initial.right.mass * initial.right.mass_fractions[k] for k in indices]
        integrator = flow_step_integrator(network; reltol=1e-12, abstol=1e-20)
        steps = 0
        while integrator.t < 1.0
            previous_time = integrator.t
            SciMLBase.step!(integrator)
            integrator.t > previous_time || error("Valve integration stopped before 1 s")
            @test all(isfinite, integrator.u)
            diagnostic = network_diagnostics(network, integrator.u, integrator.t)
            nodes = diagnostic.nodes
            @test thermal_approx(mdot(nodes.left.pressure - nodes.right.pressure),
                                 diagnostic.mass_flow_rates[1], provenance)
            @test all(thermal_approx(a, b, provenance) for (a, b) in
                      zip(initial.left.mass_fractions, nodes.left.mass_fractions))
            for (k, expected) in zip(indices, initial_mass)
                mass = nodes.left.mass * nodes.left.mass_fractions[k] +
                       nodes.right.mass * nodes.right.mass_fractions[k]
                @test thermal_approx(mass, expected, provenance)
            end
            steps += 1
        end
        @test integrator.t >= 1.0
        final = network_diagnostics(network, integrator.u, integrator.t)
        @info "Nonlinear valve accepted steps" time=integrator.t steps left_P=final.nodes.left.pressure right_P=final.nodes.right.pressure mdot=final.mass_flow_rates[1] mechanism_sha256_lf=digest
    end
end

if case_selected("pressure_controller2")
    @testset "Cantera parity: TestIdealGasReactor.test_pressure_controller2" begin
        gas, provenance, digest = thermal_fixture()
        vessel = WellStirredReactor(gas; temperature=300.0, pressure=one_atm,
            mole_fractions=Dict("O2"=>1.0), volume=1.0, chemistry=true)
        inlet = Reservoir(gas; temperature=500.0, pressure=2one_atm, mole_fractions=Dict("H2"=>1.0))
        outlet = Reservoir(gas; temperature=300.0, pressure=one_atm, mole_fractions=Dict("H2"=>1.0))
        mdot(t) = exp(-100 * (t - 0.5)^2)
        pfunc(dp) = 1e-5 * sqrt(abs(dp))
        mfc = MassFlowController(:inlet, :vessel; mdot)
        pc = PressureController(:vessel, :outlet; primary=mfc, K=1.0, pressure_function=pfunc)
        @test pc.K == 1.0
        network = ReactorNetwork((vessel=vessel, inlet=inlet, outlet=outlet); flows=(mfc, pc))
        integrator = flow_step_integrator(network; reltol=provenance["integration_rtol"],
                                         abstol=provenance["integration_atol"])
        steps = 0
        while integrator.t < 1.0
            previous_time = integrator.t
            SciMLBase.step!(integrator)
            integrator.t > previous_time || error("Pressure controller integration stopped before 1 s")
            @test all(isfinite, integrator.u)
            diagnostic = network_diagnostics(network, integrator.u, integrator.t)
            @test thermal_approx(mdot(integrator.t), diagnostic.mass_flow_rates[1], provenance)
            dp = diagnostic.nodes.vessel.pressure - diagnostic.nodes.outlet.pressure
            @test thermal_approx(mdot(integrator.t) + pfunc(dp), diagnostic.mass_flow_rates[2], provenance)
            steps += 1
        end
        @test integrator.t >= 1.0
        final = network_diagnostics(network, integrator.u, integrator.t)
        @info "Custom pressure controller accepted steps" time=integrator.t steps temperature=final.nodes.vessel.temperature pressure=final.nodes.vessel.pressure mass=final.nodes.vessel.mass primary_flow=final.mass_flow_rates[1] controller_flow=final.mass_flow_rates[2] mechanism_sha256_lf=digest
    end
end
