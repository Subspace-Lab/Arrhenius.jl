# Diagnostic for the PLOG pressure contract of the kinetics wrappers.
#
# `wdot_func`/`wdot!` used to infer the pressure from `sum(C)*R*T` when the
# caller passed none. That is wrong for an unnormalised or negative trial
# concentration vector, because the PLOG rate constants then move silently with
# the trial composition. The pressure is now required and must come from the
# thermodynamic state.
#
# Run: julia --project=<repo> scripts/wdot_pressure_probe.jl <repo-root>
using Arrhenius, Printf
const ROOT = ARGS[1]

function probe(mech, label; T=1200.0, P=one_atm)
    gas = CreateSolution(joinpath(ROOT, "mechanism", mech))
    reaction = gas.reaction
    plog_idx = collect(reaction.plog.reaction_indices)
    ns = gas.n_species
    X = fill(1.0 / ns, ns)
    C = P / (R * T) .* X
    h_mole = cal_h_RT(gas, T, P, X) .* (R * T)
    entropy = cal_s0_R(gas, T, P, X) .* R

    Cpert = copy(C)
    neg_index = something(findfirst(==("HE"), gas.species_names), 1)
    scale_index = something(findfirst(==("N2"), gas.species_names), 2)
    Cpert[neg_index] = -1e-7 * P / (R * T)
    Cpert[scale_index] = 3 * C[scale_index]
    println("  perturbed species: neg=", gas.species_names[neg_index],
            "  scaled=", gas.species_names[scale_index])

    println("### ", label, "  mech=", mech, "  T=", T, "  P=", P,
            "  nspecies=", ns, "  nreactions=", reaction.n_reactions)
    println("  plog reaction indices (1-based): ", plog_idx)
    println("  sum(C)=", sum(C), "  sum(C)*R*T=", sum(C) * R * T, "  true P=", P)
    println("  sum(Cpert)=", sum(Cpert), "  sum(Cpert)*R*T=", sum(Cpert) * R * T)

    for (tag, Cc) in (("unperturbed", C), ("perturbed", Cpert))
        ws = KineticsWorkspace(reaction)
        ke = wdot!(similar(Cc), reaction, T, Cc, entropy, h_mole, ws;
            get_rate_constants=true, pressure=P).forward
        qe = wdot_func(reaction, T, Cc, entropy, h_mole; get_qdot=true, pressure=P)
        println("  [", tag, "] sum(C)*R*T vs P: rel=",
                (sum(Cc) * R * T - P) / P)
        for i in plog_idx
            @printf("  [%s] plog rxn %4d  kf(state P)=%.10e\n", tag, i, ke[i])
        end
        println("  [", tag, "] qdot with pressure [1:3]=", qe[1:3])
        println()
    end

    # Without a pressure the wrappers must refuse to evaluate rather than
    # guess one from the trial concentration vector.
    for (what, call) in (
        ("wdot_func omitted", () -> wdot_func(reaction, T, Cpert, entropy, h_mole;
            get_qdot=true)),
        ("wdot_func pressure=nothing", () -> wdot_func(reaction, T, Cpert, entropy,
            h_mole; get_qdot=true, pressure=nothing)),
        ("wdot! omitted", () -> wdot!(similar(Cpert), reaction, T, Cpert, entropy,
            h_mole, KineticsWorkspace(reaction); get_qdot=true)),
        ("wdot! pressure=nothing", () -> wdot!(similar(Cpert), reaction, T, Cpert,
            entropy, h_mole, KineticsWorkspace(reaction); get_qdot=true,
            pressure=nothing)),
    )
        try
            call()
            println("  [", what, "] NO ERROR (unexpected)")
        catch err
            println("  [", what, "] ", typeof(err), ": ",
                    sprint(showerror, err))
        end
    end
    println()
end

probe("h2o2.yaml", "H2O2 (control: no PLOG reactions)")
probe("stagni_2023.yaml", "STAGNI (has PLOG reactions)")
