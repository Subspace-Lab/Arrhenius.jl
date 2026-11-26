# Included in CanteraReactorParity only when an equilibrium case is selected.
include(joinpath(@__DIR__, "..", "..", "example", "reactors", "ode_solver.jl"))

for mode in (:UV, :HP)
    case_selected("equilibrium_$(mode)") || continue
    @testset "Cantera parity: TestIdealGasReactor.test_equilibrium_$(mode)" begin
        gas, provenance, digest = thermal_fixture()
        composition = Dict("H2"=>1.0, "O2"=>0.5, "AR"=>8.0)
        constraint = mode === :UV ? :constant_volume : :constant_pressure
        reactor = IdealGasReactor(gas; temperature=1100.0, pressure=10one_atm,
            mole_fractions=composition, constraint, energy=:adiabatic)
        solution = solve_reactor(reactor, (0.0, 1.0); integrator=native_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test last(solution.t) == 1.0
        @test all(isfinite, last(solution.u))
        final = reactor_properties(reactor, last(solution.u))
        equilibrium = equilibrate(gas; T=1100.0, P=10one_atm, X=composition, mode)
        equilibrium_reactor = IdealGasReactor(gas; temperature=equilibrium.T,
            pressure=equilibrium.P, mole_fractions=equilibrium.X, constraint)
        expected = reactor_properties(equilibrium_reactor)
        @test thermal_approx(final.temperature, expected.temperature, provenance)
        @test thermal_approx(final.density, expected.density, provenance)
        expected_pressure = mode === :UV ? expected.pressure : 10one_atm
        @test thermal_approx(final.pressure, expected_pressure, provenance)
        # pytest.approx compares compositions element by element, including traces.
        @test all(thermal_approx(a, b, provenance) for (a, b) in
                  zip(final.mole_fractions, expected.mole_fractions))
        @info "Reactive equilibrium" mode time=last(solution.t) temperature=final.temperature pressure=final.pressure density=final.density mole_fractions=repr(final.mole_fractions) equilibrium_T=expected.temperature equilibrium_P=expected.pressure equilibrium_rho=expected.density equilibrium_X=repr(expected.mole_fractions) mechanism_sha256_lf=digest
    end
end
