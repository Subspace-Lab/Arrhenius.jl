module CanteraReactorParity

using Arrhenius
using SHA
using TOML
using Test

include("reactor_connector_layout.jl")

include(joinpath(@__DIR__, "..", "..", "example", "reactors", "network_solver.jl"))

# Multiple names select a sequence in one process; no argument runs verified
# cases, including the repaired mass-flow pulse.
selected_cases = isempty(ARGS) ? ("all",) : Tuple(ARGS)
available_cases = ("all", "rk_cv_ignition", "surface_tolerances", "surface_coverages", "hydrogen_const_pressure", "hydrogen_single_jacobian", "connector_mfc_constant", "connector_species_subset", "connector_mfc_energy", "connector_heat_jacobian", "disable_chemistry", "disjoint", "disable_energy",
                   "heat_transfer1", "heat_transfer2", "heat_flux_func",
                   "valve1", "valve2", "valve_timing", "reinitialize",
                   "reservoir_sync", "wall_velocity", "equalize_pressure",
                   "equilibrium_UV", "equilibrium_HP", "set_initial_time",
                   "valve3", "pressure_controller2", "mass_flow_controller",
                   "timestepping", "maxsteps", "tolerances", "derivative", "advance_reverse",
                   "finite_difference_jacobian", "wall_step", "wall_advance", "const_pressure_closed",
                   "zerodim_simple", "combustor_step", "combustor_advance", "combustor_invasive", "wsr_nonreacting", "wsr_ignition1", "wsr_ignition2", "wsr_ignition3")
all(name -> name in available_cases, selected_cases) ||
    error("Unknown case; select all or a case documented in README.md")
case_selected(name) = name in selected_cases ||
    ("all" in selected_cases)

if case_selected("disable_chemistry")
    # This ports the inherited TestIdealGasReactor case, not the other reactor
    # classes which also inherit TestReactor.test_disable_chemistry.
    @testset "Cantera parity: TestIdealGasReactor.test_disable_chemistry" begin
        # The optional environment already pins these versions. Fail explicitly if
        # the script is launched in a different solver environment.
        Base.pkgversion(SciMLBase) == v"2.155.2" || error("SciMLBase 2.155.2 required")
        Base.pkgversion(OrdinaryDiffEqBDF) == v"1.26.0" || error("OrdinaryDiffEqBDF 1.26.0 required")

        fixture = joinpath(@__DIR__, "fixtures", "cantera-726522be")
        provenance = TOML.parsefile(joinpath(fixture, "provenance.toml"))
        mechanism = joinpath(fixture, "h2o2.yaml")
        digest = bytes2hex(sha256(replace(read(mechanism, String), "\r\n" => "\n")))
        digest == provenance["mechanism_sha256_lf"] || error("Pinned h2o2 fixture digest mismatch")
        gas = CreateSolution(mechanism; phase=provenance["phase"])

        # Cantera's IdealGasReactor is constant-volume. Arrhenius's same-named
        # constructor defaults to constant-pressure, so select the constraint.
        initial = IdealGasReactor(gas; temperature=1000.0, pressure=one_atm,
            mole_fractions=Dict("H2" => 2.0, "O2" => 1.0),
            constraint=:constant_volume, energy=:adiabatic)
        vessel = WellStirredReactor(initial; volume=1.0, chemistry=false)
        network = ReactorNetwork((vessel=vessel,))
        solution = solve_network(network, (0.0, 11.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)

        @test last(solution.t) == 11.0
        final = last(solution.u)
        @test all(isfinite, final)
        # Network coordinates are species masses followed by temperature. Convert
        # masses to moles before comparing the upstream mole-fraction assertions.
        X = final[1:gas.n_species] ./ gas.MW
        X ./= sum(X)
        iH2 = something(findfirst(==("H2"), gas.species_names))
        iO2 = something(findfirst(==("O2"), gas.species_names))
        for (actual, expected) in ((final[end], 1000.0), (X[iH2], 2 / 3), (X[iO2], 1 / 3))
            @test abs(actual - expected) <= max(provenance["assertion_atol"],
                provenance["assertion_rtol"] * abs(expected))
        end
        @info "Disabled chemistry: final state" time=last(solution.t) temperature=final[end] X_H2=X[iH2] X_O2=X[iO2] mechanism_sha256_lf=digest
    end
end

if case_selected("disjoint")
    @testset "Cantera parity: TestIdealGasReactor.test_disjoint" begin
        Base.pkgversion(SciMLBase) == v"2.155.2" || error("SciMLBase 2.155.2 required")
        Base.pkgversion(OrdinaryDiffEqBDF) == v"1.26.0" || error("OrdinaryDiffEqBDF 1.26.0 required")
        fixture = joinpath(@__DIR__, "fixtures", "cantera-726522be")
        provenance = TOML.parsefile(joinpath(fixture, "provenance.toml"))
        mechanism = joinpath(fixture, "h2o2.yaml")
        digest = bytes2hex(sha256(replace(read(mechanism, String), "\r\n" => "\n")))
        digest == provenance["mechanism_sha256_lf"] || error("Pinned h2o2 fixture digest mismatch")
        gas = CreateSolution(mechanism; phase=provenance["phase"])

        left_initial = IdealGasReactor(gas; temperature=300.0, pressure=101325.0,
            mole_fractions=Dict("O2" => 1.0), constraint=:constant_volume, energy=:adiabatic)
        right_initial = IdealGasReactor(gas; temperature=500.0, pressure=300000.0,
            mole_fractions=Dict("O2" => 1.0), constraint=:constant_volume, energy=:adiabatic)
        left = WellStirredReactor(left_initial; volume=1.0, chemistry=true)
        right = WellStirredReactor(right_initial; volume=1.0, chemistry=true)
        # No flow devices or walls connect these nodes.
        network = ReactorNetwork((left=left, right=right))
        initial = network_diagnostics(network).nodes
        @info "Disjoint reactors: initial state" left_T=initial.left.temperature left_P=initial.left.pressure right_T=initial.right.temperature right_P=initial.right.pressure
        for (nominal, computed) in ((300.0, initial.left.temperature),
                (101325.0, initial.left.pressure), (500.0, initial.right.temperature),
                (300000.0, initial.right.pressure))
            @test abs(nominal - computed) <= max(provenance["assertion_atol"],
                provenance["assertion_rtol"] * abs(computed))
        end

        solution = solve_network(network, (0.0, 1.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test last(solution.t) == 1.0
        @test all(isfinite, last(solution.u))
        final = network_diagnostics(network, last(solution.u), last(solution.t)).nodes
        # Preserve upstream's nominal == approx(computed) assertion direction.
        for (nominal, computed) in ((300.0, final.left.temperature),
                (101325.0, final.left.pressure), (500.0, final.right.temperature),
                (300000.0, final.right.pressure))
            @test abs(nominal - computed) <= max(provenance["assertion_atol"],
                provenance["assertion_rtol"] * abs(computed))
        end
        @info "Disjoint reactors: final state" time=last(solution.t) left_T=final.left.temperature left_P=final.left.pressure right_T=final.right.temperature right_P=final.right.pressure mechanism_sha256_lf=digest
    end
end

if case_selected("disable_energy")
    @testset "Cantera parity: TestIdealGasReactor.test_disable_energy" begin
        Base.pkgversion(SciMLBase) == v"2.155.2" || error("SciMLBase 2.155.2 required")
        Base.pkgversion(OrdinaryDiffEqBDF) == v"1.26.0" || error("OrdinaryDiffEqBDF 1.26.0 required")
        fixture = joinpath(@__DIR__, "fixtures", "cantera-726522be")
        provenance = TOML.parsefile(joinpath(fixture, "provenance.toml"))
        mechanism = joinpath(fixture, "h2o2.yaml")
        digest = bytes2hex(sha256(replace(read(mechanism, String), "\r\n" => "\n")))
        digest == provenance["mechanism_sha256_lf"] || error("Pinned h2o2 fixture digest mismatch")
        gas = CreateSolution(mechanism; phase=provenance["phase"])

        # Upstream disables only the left energy equation. Chemistry remains
        # enabled in both vessels, and the right vessel still evolves its T.
        left_initial = IdealGasReactor(gas; temperature=500.0, pressure=one_atm,
            mole_fractions=Dict("O2" => 1.0), constraint=:constant_volume, energy=:isothermal)
        right_initial = IdealGasReactor(gas; temperature=300.0, pressure=one_atm,
            mole_fractions=Dict("O2" => 1.0), constraint=:constant_volume, energy=:adiabatic)
        left = WellStirredReactor(left_initial; volume=1.0, chemistry=true)
        right = WellStirredReactor(right_initial; volume=1.0, chemistry=true)
        wall = HeatTransferWall(:left, :right; area=1.0, U=2500.0)
        network = ReactorNetwork((left=left, right=right); walls=(wall,))
        initial = network_diagnostics(network).nodes
        @test initial.left.temperature == 500.0
        @test initial.right.temperature == 300.0

        solution = solve_network(network, (0.0, 11.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test last(solution.t) == 11.0
        @test all(isfinite, last(solution.u))
        final = network_diagnostics(network, last(solution.u), last(solution.t)).nodes
        for actual in (final.left.temperature, final.right.temperature)
            @test abs(actual - 500.0) <= max(provenance["assertion_atol"],
                provenance["assertion_rtol"] * 500.0)
        end
        @info "Disabled left energy equation: final state" time=last(solution.t) left_T=final.left.temperature right_T=final.right.temperature mechanism_sha256_lf=digest
    end
end

# Shared setup for the thermal ports below. Each call creates a fresh gas and
# each pair creates independent reactor states; nothing is cached across cases.
function thermal_fixture()
    Base.pkgversion(SciMLBase) == v"2.155.2" || error("SciMLBase 2.155.2 required")
    Base.pkgversion(OrdinaryDiffEqBDF) == v"1.26.0" || error("OrdinaryDiffEqBDF 1.26.0 required")
    fixture = joinpath(@__DIR__, "fixtures", "cantera-726522be")
    provenance = TOML.parsefile(joinpath(fixture, "provenance.toml"))
    mechanism = joinpath(fixture, "h2o2.yaml")
    digest = bytes2hex(sha256(replace(read(mechanism, String), "\r\n" => "\n")))
    digest == provenance["mechanism_sha256_lf"] || error("Pinned h2o2 fixture digest mismatch")
    return CreateSolution(mechanism; phase=provenance["phase"]), provenance, digest
end

function thermal_pair(gas; temperatures=(300.0, 1000.0), volumes=(1.0, 1.0),
                      area=1.0, U=0.0, heat_flux=0.0)
    left = WellStirredReactor(gas; temperature=temperatures[1], pressure=one_atm,
        mole_fractions=Dict("O2" => 1.0), volume=volumes[1], energy=:adiabatic, chemistry=true)
    right = WellStirredReactor(gas; temperature=temperatures[2], pressure=one_atm,
        mole_fractions=Dict("O2" => 1.0), volume=volumes[2], energy=:adiabatic, chemistry=true)
    wall = HeatTransferWall(:left, :right; area, U, heat_flux)
    return ReactorNetwork((left=left, right=right); walls=(wall,)), wall
end

function thermal_approx(actual, expected, provenance;
                        rtol=provenance["assertion_rtol"], atol=provenance["assertion_atol"])
    return isfinite(actual) && isfinite(expected) &&
        abs(actual - expected) <= max(atol, rtol * abs(expected))
end

if case_selected("heat_transfer1")
    @testset "Cantera parity: TestIdealGasReactor.test_heat_transfer1" begin
        gas, provenance, digest = thermal_fixture()
        network, _ = thermal_pair(gas; U=500.0)
        solution = solve_network(network, (0.0, 10.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test all(isfinite, last(solution.u))
        @test thermal_approx(last(solution.t), 10.0, provenance)
        final = network_diagnostics(network, last(solution.u), last(solution.t)).nodes
        @test all(isfinite, (final.left.temperature, final.right.temperature,
                             final.left.pressure, final.right.pressure))
        @test thermal_approx(final.left.temperature, final.right.temperature,
                             provenance; rtol=5e-7)
        @test !thermal_approx(final.left.pressure, final.right.pressure, provenance)
        @info "Thermal equilibrium: final state" time=last(solution.t) left_T=final.left.temperature right_T=final.right.temperature left_P=final.left.pressure right_P=final.right.pressure mechanism_sha256_lf=digest
    end
end

if case_selected("heat_transfer2")
    @testset "Cantera parity: TestIdealGasReactor.test_heat_transfer2" begin
        gas, provenance, digest = thermal_fixture()
        first, _ = thermal_pair(gas; U=200.0)
        first_solution = solve_network(first, (0.0, 1.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test last(first_solution.t) == 1.0
        @test all(isfinite, last(first_solution.u))
        first_final = network_diagnostics(first, last(first_solution.u), 1.0).nodes

        # Upstream sets volumes on a fresh pair before initialization. The native
        # constructor supplies those same initial volumes; no live setter is omitted.
        scaled, wall = thermal_pair(gas; volumes=(0.25, 0.25), U=100.0, area=0.5)
        initial = network_diagnostics(scaled)
        initial_power = wall.U * wall.area *
            (initial.nodes.left.temperature - initial.nodes.right.temperature)
        @test thermal_approx(initial_power, initial.wall_heat_rates[1], provenance)
        scaled_solution = solve_network(scaled, (0.0, 1.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test last(scaled_solution.t) == 1.0
        @test all(isfinite, last(scaled_solution.u))
        scaled_final = network_diagnostics(scaled, last(scaled_solution.u), 1.0)
        final_power = wall.U * wall.area *
            (scaled_final.nodes.left.temperature - scaled_final.nodes.right.temperature)
        @test thermal_approx(final_power, scaled_final.wall_heat_rates[1], provenance)
        @test thermal_approx(first_final.left.temperature,
                             scaled_final.nodes.left.temperature, provenance)
        @test thermal_approx(first_final.right.temperature,
                             scaled_final.nodes.right.temperature, provenance)
        @info "Thermal scaling: final state" time=1.0 first_left_T=first_final.left.temperature first_right_T=first_final.right.temperature scaled_left_T=scaled_final.nodes.left.temperature scaled_right_T=scaled_final.nodes.right.temperature initial_power=initial.wall_heat_rates[1] final_power=scaled_final.wall_heat_rates[1] mechanism_sha256_lf=digest
    end
end

if case_selected("heat_flux_func")
    @testset "Cantera parity: TestIdealGasReactor.test_heat_flux_func" begin
        gas, provenance, digest = thermal_fixture()
        heat_flux(t) = t <= 1.0 ? 90000.0 * (1.0 - t^2) : 0.0
        network, wall = thermal_pair(gas; temperatures=(500.0, 300.0),
            volumes=(0.5, 1.0), area=0.3, heat_flux)
        initial = network_diagnostics(network).nodes
        transferred_heat = 0.3 * 60000.0
        solution = solve_network(network, (0.0, 1.1); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test last(solution.t) == 1.1
        @test all(isfinite, last(solution.u))
        final = network_diagnostics(network, last(solution.u), last(solution.t))
        @test final.wall_heat_rates[1] / wall.area == heat_flux(1.1)
        @test thermal_approx(initial.left.volume, final.nodes.left.volume, provenance)
        @test thermal_approx(initial.right.volume, final.nodes.right.volume, provenance)
        @test thermal_approx(initial.left.total_internal_energy - transferred_heat,
                             final.nodes.left.total_internal_energy, provenance)
        @test thermal_approx(initial.right.total_internal_energy + transferred_heat,
                             final.nodes.right.total_internal_energy, provenance)
        # The generic Cantera Reactor uses the same observable heat balance on
        # this ideal-gas phase. Keep a single solve in the optional suite.
        output = get(ENV, "CANTERA_PARITY_RESULTS", nothing)
        if output !== nothing
            mkpath(output)
            path = joinpath(output, "heat_flux_func.native.toml")
            isfile(path) && error("Select a fresh results directory")
            record = Dict("time_s"=>last(solution.t), "area_m2"=>wall.area,
                "final_flux_W_m2"=>only(final.wall_heat_rates) / wall.area,
                "initial_volumes_m3"=>[initial.left.volume, initial.right.volume],
                "final_volumes_m3"=>[final.nodes.left.volume, final.nodes.right.volume],
                "initial_energies_J"=>[initial.left.total_internal_energy, initial.right.total_internal_energy],
                "final_energies_J"=>[final.nodes.left.total_internal_energy, final.nodes.right.total_internal_energy])
            open(io -> TOML.print(io, record), path, "w")
        end
        @info "Prescribed heat flux: final state" time=last(solution.t) initial_left_U=initial.left.total_internal_energy initial_right_U=initial.right.total_internal_energy final_left_U=final.nodes.left.total_internal_energy final_right_U=final.nodes.right.total_internal_energy transferred_heat=transferred_heat final_heat_flux=final.wall_heat_rates[1]/wall.area mechanism_sha256_lf=digest
    end
end

function valve_pair(gas; left_composition=Dict("AR" => 1.0), energy=:adiabatic,
                    time_function=t -> 1.0, K=2e-5, pressure_function=identity)
    left = WellStirredReactor(gas; temperature=300.0, pressure=10one_atm,
        mole_fractions=left_composition, energy, volume=1.0, chemistry=true)
    right = WellStirredReactor(gas; temperature=300.0, pressure=one_atm,
        mole_fractions=Dict("O2" => 1.0), energy, volume=1.0, chemistry=true)
    valve = Valve(:left, :right; K, pressure_function, time_function)
    return ReactorNetwork((left=left, right=right); flows=(valve,)), valve
end

if case_selected("valve1")
    @testset "Cantera parity: TestIdealGasReactor.test_valve1" begin
        gas, provenance, digest = thermal_fixture()
        network, valve = valve_pair(gas)
        # Native topology is explicit in the network. These views represent
        # upstream r1.outlets and r2.inlets without adding wrapper APIs.
        left_outlets = [flow for (flow, (up, down)) in zip(network.flows, network.flow_endpoints) if up == 1]
        right_inlets = [flow for (flow, (up, down)) in zip(network.flows, network.flow_endpoints) if down == 2]
        @test left_outlets == right_inlets
        @test valve.K == 2e-5
        @test network.nodes.left.initial.energy === :adiabatic
        @test network.nodes.right.initial.energy === :adiabatic
        initial = network_diagnostics(network)
        initial_dp = initial.nodes.left.pressure - initial.nodes.right.pressure
        @test thermal_approx(initial_dp * valve.K, initial.mass_flow_rates[1], provenance)
        solution = solve_network(network, (0.0, 0.1); integrator=native_network_bdf,
            reltol=1e-12, abstol=provenance["integration_atol"], save_everystep=false)
        @test last(solution.t) == 0.1
        @test all(isfinite, last(solution.u))
        final = network_diagnostics(network, last(solution.u), last(solution.t))
        final_dp = final.nodes.left.pressure - final.nodes.right.pressure
        @test thermal_approx(final_dp * valve.K, final.mass_flow_rates[1], provenance)
        @test thermal_approx(initial.nodes.left.mass + initial.nodes.right.mass,
                             final.nodes.left.mass + final.nodes.right.mass, provenance)
        initial_species = initial.nodes.left.mass .* initial.nodes.left.mass_fractions +
                          initial.nodes.right.mass .* initial.nodes.right.mass_fractions
        final_species = final.nodes.left.mass .* final.nodes.left.mass_fractions +
                        final.nodes.right.mass .* final.nodes.right.mass_fractions
        @test all(thermal_approx(a, b, provenance; atol=1e-10)
                  for (a, b) in zip(initial_species, final_species))
        @test all(thermal_approx(a, b, provenance) for (a, b) in
                  zip(initial.nodes.left.mass_fractions, final.nodes.left.mass_fractions))
        @info "Adiabatic valve: final state" time=last(solution.t) left_mass=final.nodes.left.mass right_mass=final.nodes.right.mass left_P=final.nodes.left.pressure right_P=final.nodes.right.pressure mdot=final.mass_flow_rates[1] mechanism_sha256_lf=digest
    end
end

if case_selected("valve2")
    @testset "Cantera parity: TestIdealGasReactor.test_valve2" begin
        gas, provenance, digest = thermal_fixture()
        network, valve = valve_pair(gas; left_composition=Dict("O2" => 1.0), energy=:isothermal)
        @test valve.K == 2e-5
        @test network.nodes.left.initial.energy === :isothermal
        @test network.nodes.right.initial.energy === :isothermal
        initial = network_diagnostics(network).nodes
        m1a, m2a = initial.left.mass, initial.right.mass
        A = valve.K * initial.left.pressure * (1 + m2a / m1a)
        B = valve.K * (initial.left.pressure / m1a + initial.right.pressure / m2a)
        times = collect(range(1e-5, 0.5; length=50))
        solution = solve_network(network, (0.0, 0.5); integrator=native_network_bdf,
            reltol=1e-11, abstol=provenance["integration_atol"],
            saveat=times, save_start=false, save_everystep=false)
        @test length(solution.t) == 50
        @test last(solution.t) == 0.5
        max_analytic_error = 0.0
        for (t, state) in zip(solution.t, solution.u)
            @test all(isfinite, state)
            nodes = network_diagnostics(network, state, t).nodes
            analytic_m2 = (m2a - A / B) * exp(-B * t) + A / B
            @test thermal_approx(nodes.right.mass, analytic_m2, provenance)
            @test thermal_approx(m1a + m2a, nodes.left.mass + nodes.right.mass, provenance)
            @test all(thermal_approx(a, b, provenance) for (a, b) in
                      zip(nodes.left.mass_fractions, initial.left.mass_fractions))
            max_analytic_error = max(max_analytic_error, abs(nodes.right.mass - analytic_m2))
        end
        final = network_diagnostics(network, last(solution.u), last(solution.t)).nodes
        @info "Isothermal valve: analytic solution" time=last(solution.t) samples=length(solution.t) left_mass=final.left.mass right_mass=final.right.mass max_analytic_mass_error=max_analytic_error mechanism_sha256_lf=digest
    end
end

if case_selected("valve_timing")
    @testset "Cantera parity: TestIdealGasReactor.test_valve_timing" begin
        gas, provenance, digest = thermal_fixture()
        network, valve = valve_pair(gas; time_function=t -> t > 0.01)
        times = [0.0, 0.01, 0.01 + 1e-9, 0.02]
        solution = solve_network(network, (0.0, 0.02); integrator=native_network_bdf,
            reltol=1e-12, abstol=provenance["integration_atol"],
            saveat=times, save_everystep=false)
        @test solution.t == times
        for (t, state) in zip(solution.t, solution.u)
            @test all(isfinite, state)
            diagnostic = network_diagnostics(network, state, t)
            dp = diagnostic.nodes.left.pressure - diagnostic.nodes.right.pressure
            expected_activity = t <= 0.01 ? 0.0 : 1.0
            @test valve.time_function(t) == expected_activity
            @test thermal_approx(valve.pressure_function(dp), dp, provenance)
            if t <= 0.01
                @test diagnostic.mass_flow_rates[1] == 0.0
            else
                @test thermal_approx(diagnostic.mass_flow_rates[1], valve.K * dp, provenance)
            end
            @info "Timed valve: sample" time=t activity=valve.time_function(t) pressure_difference=dp mdot=diagnostic.mass_flow_rates[1]
        end
        @info "Timed valve: input provenance" mechanism_sha256_lf=digest
    end
end

if case_selected("reinitialize")
    @testset "Cantera parity: TestIdealGasReactor.test_reinitialize" begin
        gas, provenance, digest = thermal_fixture()
        network, _ = thermal_pair(gas; U=200.0)
        first = solve_network(network, (0.0, 1.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        before = network_diagnostics(network, last(first.u), 1.0).nodes
        reset = copy(last(first.u))
        reset[network.offsets[1]+gas.n_species] = 300.0
        reset[network.offsets[2]+gas.n_species] = 1000.0
        restored = network_diagnostics(network, reset, 1.0).nodes
        @test thermal_approx(restored.left.temperature, 300.0, provenance)
        @test thermal_approx(restored.right.temperature, 1000.0, provenance)
        # Explicit checkpoint state restarts the caller-owned integrator, the
        # native counterpart of upstream phase synchronization/reinitialization.
        second = solve_network(network, (1.0, 2.0); integrator=native_network_bdf,
            initial_state=reset, reltol=provenance["integration_rtol"],
            abstol=provenance["integration_atol"], save_everystep=false)
        @test last(second.t) == 2.0
        @test all(isfinite, last(second.u))
        after = network_diagnostics(network, last(second.u), 2.0).nodes
        @test thermal_approx(before.left.temperature, after.left.temperature, provenance)
        @test thermal_approx(before.right.temperature, after.right.temperature, provenance)
        @info "Reinitialized thermal network" first_left_T=before.left.temperature first_right_T=before.right.temperature second_left_T=after.left.temperature second_right_T=after.right.temperature mechanism_sha256_lf=digest
    end
end

if case_selected("reservoir_sync")
    @testset "Cantera parity: TestIdealGasReactor.test_reservoir_sync" begin
        gas, provenance, digest = thermal_fixture()
        vessel = WellStirredReactor(gas; temperature=800.0, pressure=one_atm,
            mole_fractions=Dict("O2"=>1.0), volume=1.0, chemistry=true)
        hot = Reservoir(gas; temperature=900.0, pressure=one_atm, mole_fractions=Dict("O2"=>1.0))
        wall = HeatTransferWall(:vessel, :bath; U=500.0)
        hot_network = ReactorNetwork((vessel=vessel, bath=hot); walls=(wall,))
        first = solve_network(hot_network, (0.0, 1.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        first_T = network_diagnostics(hot_network, last(first.u), 1.0).nodes.vessel.temperature
        @test thermal_approx(first_T, 872.099, provenance; rtol=1e-3)
        cold = Reservoir(gas; temperature=700.0, pressure=one_atm, mole_fractions=Dict("O2"=>1.0))
        cold_network = ReactorNetwork((vessel=vessel, bath=cold); walls=(wall,))
        second = solve_network(cold_network, (1.0, 2.0); integrator=native_network_bdf,
            initial_state=last(first.u), reltol=provenance["integration_rtol"],
            abstol=provenance["integration_atol"], save_everystep=false)
        @test last(second.t) == 2.0
        @test all(isfinite, last(second.u))
        second_T = network_diagnostics(cold_network, last(second.u), 2.0).nodes.vessel.temperature
        @test thermal_approx(second_T, 747.27, provenance; rtol=1e-3)
        @info "Updated reservoir boundary" first_T=first_T second_T=second_T mechanism_sha256_lf=digest
    end
end

function moving_oxygen_pair(gas; pressures=(one_atm, one_atm), volumes=(1.0, 1.0),
                            area=1.0, K=0.0, velocity=0.0)
    left = WellStirredReactor(gas; temperature=300.0, pressure=pressures[1],
        mole_fractions=Dict("O2"=>1.0), volume=volumes[1], chemistry=true)
    right = WellStirredReactor(gas; temperature=300.0, pressure=pressures[2],
        mole_fractions=Dict("O2"=>1.0), volume=volumes[2], chemistry=true)
    wall = MovingWall(:left, :right; area, K, velocity)
    return MovingWallNetwork(ReactorNetwork((left=left, right=right)); walls=(wall,)), wall
end

if case_selected("wall_velocity")
    @testset "Cantera parity: TestIdealGasReactor.test_wall_velocity" begin
        gas, provenance, digest = thermal_fixture()
        velocity(t) = t < 0.0 ? 0.0 : t <= 1.0 ? t : t <= 2.0 ? 2.0-t : 0.0
        model, wall = moving_oxygen_pair(gas; volumes=(2.0, 5.0), area=0.2, velocity)
        solution = solve_moving_wall(model, (0.0, 2.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            saveat=[1.0, 2.0], save_start=false, save_everystep=false)
        @test solution.t == [1.0, 2.0]
        @test all(state -> all(isfinite, state), solution.u)
        at_one = moving_wall_diagnostics(model, solution.u[1], 1.0)
        at_two = moving_wall_diagnostics(model, solution.u[2], 2.0)
        @test thermal_approx(at_one.wall_velocities[1], velocity(1.0), provenance)
        @test thermal_approx(at_one.volume_rates[1], 0.2, provenance; rtol=1e-7)
        @test thermal_approx(at_two.volume_rates[1], 0.0, provenance; rtol=1e-7)
        @test thermal_approx(at_two.nodes.left.volume, 2.2, provenance; rtol=1e-7)
        @test thermal_approx(at_two.nodes.right.volume, 4.8, provenance; rtol=1e-7)
        @info "Prescribed wall motion" left_V=at_two.nodes.left.volume right_V=at_two.nodes.right.volume rate_at_one=at_one.volume_rates[1] rate_at_two=at_two.volume_rates[1] mechanism_sha256_lf=digest
    end
end

if case_selected("equalize_pressure")
    @testset "Cantera parity: TestIdealGasReactor.test_equalize_pressure" begin
        gas, provenance, digest = thermal_fixture()
        model, wall = moving_oxygen_pair(gas; pressures=(101325.0, 300000.0), K=0.1)
        left_walls = [w for (w, endpoints) in zip(model.walls, model.wall_endpoints) if 1 in endpoints]
        right_walls = [w for (w, endpoints) in zip(model.walls, model.wall_endpoints) if 2 in endpoints]
        @test length(left_walls) == 1
        @test length(right_walls) == 1
        @test only(left_walls) === wall
        @test only(right_walls) === wall
        solution = solve_moving_wall(model, (0.0, 1.0); integrator=native_network_bdf,
            reltol=provenance["integration_rtol"], abstol=provenance["integration_atol"],
            save_everystep=false)
        @test thermal_approx(last(solution.t), 1.0, provenance)
        @test all(isfinite, last(solution.u))
        final = moving_wall_diagnostics(model, last(solution.u), 1.0).nodes
        @test thermal_approx(final.left.pressure, final.right.pressure, provenance)
        @test !thermal_approx(final.left.temperature, final.right.temperature, provenance)
        @info "Pressure-driven wall equilibrium" left_P=final.left.pressure right_P=final.right.pressure left_T=final.left.temperature right_T=final.right.temperature left_V=final.left.volume right_V=final.right.volume mechanism_sha256_lf=digest
    end
end

if case_selected("set_initial_time")
    @testset "Cantera parity: TestIdealGasReactor.test_set_initial_time" begin
        gas, provenance, digest = thermal_fixture()
        pressure_function(dp) = dp > 0 ? 5e-3 * sqrt(dp) : 0.0
        pressures = []
        for initial_time in (0.0, 0.2)
            network, valve = valve_pair(gas; K=1.0, pressure_function)
            solution = solve_network(network, (initial_time, initial_time + 0.5);
                integrator=native_network_bdf, reltol=1e-12,
                abstol=provenance["integration_atol"], save_everystep=false)
            @test thermal_approx(last(solution.t), initial_time + 0.5, provenance)
            @test all(isfinite, last(solution.u))
            final = network_diagnostics(network, last(solution.u), last(solution.t)).nodes
            dp = final.left.pressure - final.right.pressure
            @test thermal_approx(valve.pressure_function(dp), pressure_function(dp), provenance)
            push!(pressures, (final.left.pressure, final.right.pressure))
            @info "Shifted initial time" initial_time time=last(solution.t) left_P=final.left.pressure right_P=final.right.pressure pressure_function=valve.pressure_function(dp) mechanism_sha256_lf=digest
        end
        @test thermal_approx(pressures[1][1], pressures[2][1], provenance)
        @test thermal_approx(pressures[1][2], pressures[2][2], provenance)
    end
end

if case_selected("equilibrium_UV") || case_selected("equilibrium_HP")
    include("reactor_equilibrium.jl")
end

if any(case_selected, ("valve3", "pressure_controller2", "mass_flow_controller"))
    include("reactor_flow_steps.jl")
end

if any(case_selected, ("timestepping", "maxsteps", "tolerances", "derivative", "advance_reverse",
                       "finite_difference_jacobian", "hydrogen_single_jacobian"))
    include("reactor_time_controls.jl")
end

if any(case_selected, ("surface_coverages", "wall_step", "wall_advance", "combustor_step", "combustor_advance", "combustor_invasive", "wsr_nonreacting", "wsr_ignition1", "wsr_ignition2", "wsr_ignition3"))
    include("reactor_wall.jl")
end

if any(case_selected, ("combustor_step", "combustor_advance", "combustor_invasive"))
    include("reactor_combustor.jl")
end

if case_selected("const_pressure_closed")
    include("reactor_const_pressure.jl")
end

if case_selected("zerodim_simple")
    include("reactor_cpp.jl")
end

if any(case_selected, ("wsr_nonreacting", "wsr_ignition1", "wsr_ignition2", "wsr_ignition3"))
    include("reactor_wsr.jl")
end

if case_selected("connector_heat_jacobian")
    include("reactor_connector_jacobians.jl")
end

if case_selected("connector_mfc_energy")
    include("reactor_connector_mfc.jl")
end

if case_selected("connector_species_subset")
    include("reactor_connector_subset.jl")
end

if case_selected("connector_mfc_constant")
    include("reactor_connector_constant.jl")
end

if case_selected("hydrogen_single_jacobian")
    include("reactor_hydrogen_jacobian.jl")
end

if case_selected("hydrogen_const_pressure")
    include("reactor_hydrogen_const_pressure.jl")
end

if case_selected("surface_coverages")
    include("reactor_surface.jl")
end

if case_selected("surface_tolerances")
    include("reactor_surface_tolerances.jl")
end

if case_selected("rk_cv_ignition")
    include("reactor_rk_ignition.jl")
end

end # module
