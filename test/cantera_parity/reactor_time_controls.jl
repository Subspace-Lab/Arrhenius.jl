# Existing QNDF configuration exposed as a caller-owned integrator, so tests
# can inspect options, accepted steps, derivatives and expected failure state.
function control_integrator(network, tspan; save_everystep=false, kwargs...)
    problem = network_problem(network, tspan)
    f = ODEFunction(problem.f; jac=problem.jac, tgrad=problem.tgrad)
    ode = ODEProblem(f, problem.u0, problem.tspan, problem.p)
    return SciMLBase.init(ode, QNDF(); isoutofdomain=problem.isoutofdomain,
        save_everystep, kwargs...)
end

if case_selected("finite_difference_jacobian")
    @testset "Cantera parity: TestIdealGasReactor.test_finite_difference_jacobian" begin
        gas, provenance, digest = thermal_fixture()
        composition = Dict("H2"=>0.4, "O2"=>0.4, "N2"=>0.2)
        vessel(; temperature=900.0, energy=:adiabatic, chemistry=true) = WellStirredReactor(gas;
            temperature, pressure=one_atm, mole_fractions=composition,
            volume=1.0, energy, chemistry)
        network = ReactorNetwork((vessel=vessel(),))
        diagnostic_rhs = network_rhs(network)
        initial_mass = network_diagnostics(diagnostic_rhs, network_state(network)).nodes.vessel.mass
        integrator = control_integrator(network, (0.0, 100.0);
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"])
        index_h2 = something(findfirst(==("H2"), gas.species_names))
        x_h2, steps = 0.4, 0
        while x_h2 > 0.3
            previous_time = integrator.t
            SciMLBase.step!(integrator)
            integrator.t > previous_time || error("Jacobian test stopped before the reacting state")
            state = network_diagnostics(diagnostic_rhs, integrator.u, integrator.t).nodes.vessel
            molar = state.mass_fractions ./ gas.MW
            x_h2 = molar[index_h2] / sum(molar)
            steps += 1
        end
        @test x_h2 <= 0.3
        @test integrator.t > 0.0
        @test all(isfinite, integrator.u)
        advanced_state = copy(integrator.u)
        # Diagnostics own their mass-fraction copy; this physical-state snapshot
        # and the checkpoint vector are independent of later Jacobian workspaces.
        state = network_diagnostics(diagnostic_rhs, advanced_state, integrator.t).nodes.vessel
        # Total mass is derived from species masses and volume is a descriptor;
        # native coordinates eliminate Cantera's two constant state rows.
        @test thermal_approx(state.mass, initial_mass, provenance)
        @test state.volume == 1.0
        jacobian = zeros(length(integrator.u), length(integrator.u))
        network_jacobian!(jacobian, advanced_state, diagnostic_rhs, integrator.t)
        @test size(jacobian) == (gas.n_species + 1, gas.n_species + 1)
        @test all(isfinite, jacobian)
        @test any(!iszero, jacobian[end, :])
        energy_off = ReactorNetwork((vessel=vessel(temperature=state.temperature, energy=:isothermal),))
        chemistry_off = ReactorNetwork((vessel=vessel(chemistry=false),))
        for (mode, configured) in ((:energy_off, energy_off), (:chemistry_off, chemistry_off))
            configured_rhs = network_rhs(configured)
            restored = network_diagnostics(configured_rhs, advanced_state, integrator.t).nodes.vessel
            for field in (:temperature, :pressure, :mass, :volume)
                @test thermal_approx(getproperty(restored, field), getproperty(state, field), provenance)
            end
            @test all(thermal_approx(a, b, provenance) for (a, b) in
                      zip(restored.mass_fractions, state.mass_fractions))
            @info "Jacobian toggle preserves advanced state" mode temperature=restored.temperature pressure=restored.pressure mass=restored.mass volume=restored.volume mass_fractions=repr(restored.mass_fractions)
            network_jacobian!(jacobian, advanced_state, configured_rhs, integrator.t)
            if mode === :energy_off
                @test all(iszero, jacobian[end, :])
            else
                @test all(iszero, jacobian[1:gas.n_species, 1:gas.n_species])
            end
        end
        @test advanced_state == integrator.u
        @info "Jacobian advanced-state checkpoint" temperature=state.temperature pressure=state.pressure mass=state.mass volume=state.volume mass_fractions=repr(state.mass_fractions)
        @info "Reacting-state finite-difference Jacobian" time=integrator.t steps temperature=state.temperature pressure=state.pressure x_h2 jacobian_size=size(jacobian) mechanism_sha256_lf=digest
    end
end

function idle_native_network(gas; n=2)
    vessel() = WellStirredReactor(gas; temperature=300.0, pressure=one_atm,
        mole_fractions=Dict("O2"=>1.0), volume=1.0, chemistry=true)
    return n == 1 ? ReactorNetwork((left=vessel(),)) :
                    ReactorNetwork((left=vessel(), right=vessel()))
end

if case_selected("timestepping")
    @testset "Cantera parity: TestIdealGasReactor.test_timestepping" begin
        gas, provenance, digest = thermal_fixture()
        network = idle_native_network(gas)
        integrator = control_integrator(network, (0.3, 100.0); dtmax=0.07, save_everystep=true,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"])
        @test integrator.opts.dtmax == 0.07
        @test first(integrator.sol.prob.tspan) == 0.3
        @test thermal_approx(integrator.t, 0.3, provenance)
        steps, maximum_step = 0, 0.0
        while integrator.t < 10.0
            previous_time = integrator.t
            SciMLBase.step!(integrator)
            integrator.t > previous_time || error("Time-stepping test stopped before 10 s")
            dt = integrator.t - previous_time
            @test dt <= 1.0001 * 0.07
            @test thermal_approx(integrator.t, integrator.sol.t[end], provenance)
            maximum_step = max(maximum_step, dt)
            steps += 1
        end
        @test all(isfinite, integrator.u)
        @info "Maximum time-step bound" time=integrator.t steps maximum_step mechanism_sha256_lf=digest
    end
end

if case_selected("maxsteps")
    @testset "Cantera parity: TestIdealGasReactor.test_maxsteps" begin
        gas, provenance, digest = thermal_fixture()
        integrator = control_integrator(idle_native_network(gas), (0.0, 1e-4);
            dtmax=1e-7, maxiters=10, reltol=provenance["integration_rtol"],
            abstol=provenance["integration_atol"])
        solution = SciMLBase.solve!(integrator)
        @test solution.retcode == SciMLBase.ReturnCode.MaxIters
        @test integrator.t <= 10 * 1e-7
        @test integrator.opts.maxiters == 10
        @info "Expected maximum-step failure" time=integrator.t retcode=solution.retcode maxiters=integrator.opts.maxiters mechanism_sha256_lf=digest
    end
end

if case_selected("tolerances")
    @testset "Cantera parity: TestIdealGasReactor.test_tolerances" begin
        gas, provenance, digest = thermal_fixture()
        counts = Int[]
        for (rtol, atol) in ((1e-10, 1e-20), (1e-8, 1e-20), (1e-10, 1e-5))
            vessel = WellStirredReactor(gas; temperature=1100.0, pressure=10one_atm,
                mole_fractions=Dict("H2"=>1.0, "O2"=>0.5, "AR"=>8.0), chemistry=true)
            integrator = control_integrator(ReactorNetwork((vessel=vessel,)), (0.0, 100.0);
                reltol=rtol, abstol=atol)
            @test integrator.opts.reltol == rtol
            @test integrator.opts.abstol == atol
            steps = 0
            while integrator.t < 1.0
                previous_time = integrator.t
                SciMLBase.step!(integrator)
                integrator.t > previous_time || error("Tolerance test stopped before 1 s")
                steps += 1
            end
            @test all(isfinite, integrator.u)
            push!(counts, steps)
            @info "Tolerance accepted-step count" rtol atol time=integrator.t steps mechanism_sha256_lf=digest
        end
        @test counts[1] > counts[2]
        @test counts[1] > counts[3]
    end
end

if case_selected("derivative")
    @testset "Cantera parity: TestIdealGasReactor.test_derivative" begin
        gas, provenance, digest = thermal_fixture()
        integrator = control_integrator(idle_native_network(gas; n=1), (0.0, 100.0);
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"])
        SciMLBase.step!(integrator, 1.0, true)
        @test thermal_approx(integrator.t, 1.0, provenance)
        derivative = copy(SciMLBase.get_du(integrator))
        before, initial_time = copy(integrator.u), integrator.t
        SciMLBase.step!(integrator)
        @test integrator.t > initial_time
        finite_difference = (integrator.u - before) / (integrator.t - initial_time)
        for (a, b) in zip(derivative, finite_difference)
            @test thermal_approx(a, b, provenance)
        end
        @info "Integrated state derivative" initial_time time=integrator.t derivative=repr(derivative) finite_difference=repr(finite_difference) mechanism_sha256_lf=digest
    end
end

if case_selected("advance_reverse")
    @testset "Cantera parity: TestIdealGasReactor.test_advance_reverse" begin
        gas, provenance, digest = thermal_fixture()
        integrator = control_integrator(idle_native_network(gas; n=1), (0.0, 100.0);
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"])
        SciMLBase.step!(integrator, 0.1, true)
        @test thermal_approx(integrator.t, 0.1, provenance)
        caught = try
            SciMLBase.step!(integrator, 0.09 - integrator.t, true)
            nothing
        catch error
            error
        end
        @test caught isa ErrorException
        @test occursin("Cannot step backward", sprint(showerror, caught))
        @test thermal_approx(integrator.t, 0.1, provenance)
        @info "Backward advance rejected" time=integrator.t requested_time=0.09 error=sprint(showerror, caught) mechanism_sha256_lf=digest
    end
end
