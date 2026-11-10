# Differences table for c10wdot: explicit pressure vs the removed sum(C)*R*T inference.
#
# The removed inference computed the pressure as sum(C)*R*T of the *trial*
# concentration vector. That value is not a state property, so it is easy to
# reproduce the old behaviour on the new code by passing exactly that value as
# an explicit pressure argument. This script does that and tabulates the
# difference against the true state pressure.
#
# Run: julia --startup-file=no --project=<repo> scripts/wdot_differences.jl <repo-root>
using Arrhenius, Printf
const ROOT = ARGS[1]

function table(mech, label; T=1200.0, P=one_atm)
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

    println("### ", label, "  mech=", mech, "  T=", T, "  P=", P)
    println("| case | inferred P = sum(C)*R*T (Pa) | rel. error of inferred P | rates differing | PLOG rates differing | non-PLOG rates differing | max rel. diff of kf |")
    println("|---|---|---|---|---|---|---|")
    for (tag, Cc) in (("unperturbed", C), ("perturbed", Cpert))
        inferred = sum(Cc) * R * T
        ws_explicit = KineticsWorkspace(reaction)
        ws_inferred = KineticsWorkspace(reaction)
        ke = wdot!(similar(Cc), reaction, T, Cc, entropy, h_mole, ws_explicit;
            get_rate_constants=true, pressure=P).forward
        ki = wdot!(similar(Cc), reaction, T, Cc, entropy, h_mole, ws_inferred;
            get_rate_constants=true, pressure=inferred).forward
        differing = [i for i in eachindex(ke) if !(ke[i] == ki[i])]
        plog_diff = [i for i in differing if i in plog_idx]
        nonplog_diff = [i for i in differing if !(i in plog_idx)]
        rel = isempty(differing) ? 0.0 :
            maximum(abs.(ki[differing] .- ke[differing]) ./ max.(abs.(ke[differing]), floatmin()))
        @printf("| %s | %.6f | %+.6e | %d | %d | %d | %.6e |\n", tag, inferred,
            (inferred - P) / P, length(differing), length(plog_diff),
            length(nonplog_diff), rel)
    end
    println()
end

table("h2o2.yaml", "H2O2 (control: no PLOG reactions)")
table("stagni_2023.yaml", "STAGNI (has PLOG reactions)")
