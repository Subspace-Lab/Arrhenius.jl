module CanteraReactorParity

using Arrhenius
using SHA
using TOML
using Test

include(joinpath(@__DIR__, "..", "..", "example", "reactors", "network_solver.jl"))

selected_cases = isempty(ARGS) ? ("all",) : Tuple(ARGS)
available_cases = ("all", "disable_chemistry")
all(name -> name in available_cases, selected_cases) ||
    error("Unknown case; select all or disable_chemistry")
case_selected(name) = "all" in selected_cases || name in selected_cases

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

end # module
