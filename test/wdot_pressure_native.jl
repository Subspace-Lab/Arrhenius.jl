using Arrhenius, Test

# Regression test for the removed pressure inference in the kinetics wrappers.
#
# `wdot_func`/`wdot!` used to infer the pressure from `sum(C)*R*T` when the
# caller passed no pressure. That is wrong for an unnormalised or negative
# trial concentration vector: the PLOG rate constants silently moved with the
# trial composition. The pressure must come from the thermodynamic state, and
# the wrappers must refuse to evaluate a PLOG rate without it.

@testset "PLOG rates need the thermodynamic pressure" begin
    gas = CreateSolution(joinpath(@__DIR__, "..", "mechanism", "stagni_2023.yaml"))
    reaction = gas.reaction
    @test !isempty(reaction.plog.reaction_indices)

    temperature = 2164.6519745633973
    pressure = 10one_atm
    X = mole_fractions(gas, Dict("NH3" => 0.7, "H2" => 0.3, "O2" => 0.675,
        "N2" => 0.675 * 3.76, "HNO" => 0.02, "H" => 0.01, "NO" => 0.02))
    h_mole = cal_h_RT(gas, temperature, pressure, X) .* (R * temperature)
    entropy = cal_s0_R(gas, temperature, pressure, X) .* R
    plog = collect(reaction.plog.reaction_indices)

    # Normalised concentrations: sum(C)*R*T equals the true pressure, so the
    # old inference was exact here. The explicit-pressure call must reproduce
    # the reference rate constants of the unperturbed state.
    C = pressure / (R * temperature) .* X
    reference = wdot_func(reaction, temperature, C, entropy, h_mole;
        get_qdot=true, pressure)
    @test all(isfinite, reference)
    reference_rates = reaction_rate_constants(gas; T=temperature, P=pressure, X)
    @test all(reference_rates.forward[plog] .> 0)

    # Perturbed trial state: one species negative, another scaled by three.
    # sum(C)*R*T no longer matches the true pressure.
    Cpert = copy(C)
    Cpert .*= 0.5
    he = something(findfirst(==("HE"), gas.species_names))
    Cpert[he] = -1e-7 * pressure / (R * temperature)
    n2 = something(findfirst(==("N2"), gas.species_names))
    Cpert[n2] *= 3
    inferred_pressure = sum(Cpert) * R * temperature
    @test !isapprox(inferred_pressure, pressure; rtol=1e-6)

    # With the thermodynamic pressure the PLOG rate constants are the ones of
    # the state, not of the perturbed concentration vector: they must not move
    # with the perturbation. Falloff and three-body constants DO depend on the
    # collider concentrations, so only the PLOG rows are compared here.
    perturbed = wdot_func(reaction, temperature, Cpert, entropy, h_mole;
        get_qdot=true, pressure)
    @test all(isfinite, perturbed)
    workspace = KineticsWorkspace(reaction)
    perturbed_rates = wdot!(zeros(gas.n_species), reaction, temperature, Cpert,
        entropy, h_mole, workspace; get_rate_constants=true, pressure)
    @test perturbed_rates.forward[plog] ≈ reference_rates.forward[plog] rtol=1e-12

    # Without a pressure the PLOG rate cannot be evaluated: the wrapper must
    # fail loudly instead of guessing a pressure from the trial vector.
    # Omitting the keyword is a missing required argument; passing `nothing`
    # explicitly is an invalid argument. Both must be errors.
    @test_throws UndefKeywordError wdot_func(reaction, temperature, Cpert,
        entropy, h_mole; get_qdot=true)
    @test_throws ArgumentError wdot_func(reaction, temperature, Cpert,
        entropy, h_mole; get_qdot=true, pressure=nothing)
    @test_throws UndefKeywordError wdot!(zeros(gas.n_species), reaction,
        temperature, Cpert, entropy, h_mole, KineticsWorkspace(reaction);
        get_qdot=true)
    @test_throws ArgumentError wdot!(zeros(gas.n_species), reaction,
        temperature, Cpert, entropy, h_mole, KineticsWorkspace(reaction);
        get_qdot=true, pressure=nothing)
    # The internal factor helper refuses the same way for a PLOG mechanism.
    @test_throws ArgumentError Arrhenius._rate_factors!(reaction, temperature,
        Cpert, entropy, h_mole, KineticsWorkspace(reaction))
end

@testset "mechanisms without PLOG keep working" begin
    # h2o2 has falloff and three-body reactions but no PLOG, so the pressure
    # never enters the rate evaluation. The public wrappers still require the
    # keyword (it is part of the contract), and the rates are unchanged.
    gas = CreateSolution(joinpath(@__DIR__, "..", "mechanism", "h2o2.yaml"))
    @test isempty(gas.reaction.plog.reaction_indices)
    temperature = 1200.0
    pressure = one_atm
    X = mole_fractions(gas, Dict("H2" => 0.1, "O2" => 0.05, "AR" => 0.85))
    h_mole = cal_h_RT(gas, temperature, pressure, X) .* (R * temperature)
    entropy = cal_s0_R(gas, temperature, pressure, X) .* R
    C = pressure / (R * temperature) .* X
    rates = wdot_func(gas.reaction, temperature, C, entropy, h_mole;
        get_qdot=true, pressure)
    @test all(isfinite, rates)

    # The internal helper keeps its optional pressure for a non-PLOG mechanism.
    workspace = KineticsWorkspace(gas.reaction)
    @test Arrhenius._rate_factors!(gas.reaction, temperature, C, entropy, h_mole,
        workspace) === nothing
    @test all(isfinite, workspace.kf)
end