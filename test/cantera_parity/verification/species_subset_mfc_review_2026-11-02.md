# Species-subset MFC mapping review (2026-11-02)

Review only, after independent maintenance verification. No registered case or
coverage change. The pinned `TestConnectorJacobians.test_species_subset_mfc_cross_reactor`
at test_reactor.py:2084-2133 remains missing. Codebase-memory tools were unavailable;
bounded source inspection covered that source method, ReactorNetworks.jl:144-199,
315-360,385-417 and MovingWallReactors.jl:81-108,135-192,203-235.

## Original contract

Upstream gas: H2/O2/AR in that order, zero reactions,1000 K,2 atm,X=2:1:8.
Downstream: full pinned h2o2/ohmech,900 K,1 atm,H2:O2:AR=1:0.5:8,
all reaction multipliers zero. Both vessels1 m3, energy off; MFC0.02 kg/s.
The reference method was executed directly from pinned source and passed.
Three shared rows must each contain a nonzero cross entry; seven downstream-only
rows must be zero over all five upstream columns at abs1e-15; three shared rows
must match FD over those same five columns at rel1e-4/abs1e-10. This is13 source
assert statements after loop expansion. Source default comparison scaling applies.

The five columns are `[T_up,V_up,n_H2,n_O2,n_AR]`. Merely mapping the existing
fixed-volume network's four upstream coordinates would omit a tested column.
Padding the V column with a theoretical zero is not accepted.

## Existing-capability route and actual preflight

The source's self-contained three-species export contains `reactions: none`.
The existing Julia reader rejects that spelling (ArgumentError: phase reactions
must be all or a list); the failed preflight log is retained. A temporary copy
changing only that phase selector to `[]` strictly reloads in Cantera with the
same three species and zero reactions. Enthalpy/cp probes at300/1000/2500 K match.
Julia loads the copy without production edits. This is an input representation
conversion requiring formal equivalence gates, not a reason to modify the reader
inside a test-port stage. An initial reference harness unpacking error was also
corrected before the original source method ran; it was not a Cantera assertion
failure.

Existing `MovingWallNetwork(base; walls=())` accepts a network with no walls and
adds explicit constant-volume states. Preflight computes finite native RHS and
production Jacobian, confirms species map[1,4,9] and zero volume rates. No new API,
dummy physical wall or motion law is needed. Native state has20 entries:

| Quantity | Native one-based positions |
|---|---|
| Upstream species masses / T |1:3 /4 |
| Downstream species masses / T |5:14 /15 |
| Upstream/downstream V |16 /17 |
| Passive ledger states |18:20 |

Select upstream columns `[4,16,1,2,3]` and downstream species rows5:14.
Divide species RHS rows by downstream molecular weights; multiply species-input
columns by upstream molecular weights. T/V input scales are1. This maps the full
asserted10x5 block without inventing columns. Ledger variables are excluded because
they are additional bookkeeping and do not enter the asserted physical block.

## Proposed next segment and adversarial gates

1. Retain the raw upstream export and create a scripted `none -> []` copy. Gate
   exactly that parsed-data change, species order/thermodynamic parameters/zero
   reaction count, source/input hashes, Cantera strict reload and native loading.
   The present three-temperature probe is feasibility evidence, not final input
   acceptance; use the pinned roundtrip comparison policy for formal measurements.
2. Use existing no-wall MovingWallNetwork with explicit layout checks suited to
   unequal3/10 species counts. Do not broaden the current equal-size connector
   guard silently. Preserve isothermal settings, mass flow and all source criteria.
3. Evaluate all five input columns using actual native states, including V. An
   independent FD oracle uses source T/V steps atol+abs(value)*rtol and species
   steps atol*total_upstream_moles+abs(n_j)*rtol, default1e-9/1e-15. Map each output
   by molecular weight and retain all perturbations/matrices. Prove the V column
   is evaluated rather than padded. No solver-step changes or tolerance relaxation.
4. Re-run the original Cantera method and complete native13-assertion contract;
   finite-RHS/J feasibility alone does not pass this gate. Then register the case
   and run35 integration +3 static Jacobian scenarios plus existing lightweight
   checks, comparing prior trajectories/counters and both prior connector results.
5. Only full acceptance updates this one row to45/274/104. Any unmet gate keeps
   current44/275/104. New API/strategy needs or a major numerical failure return
   to discussion. Initialization and HO2 stay suspended.

Recommendation: this remains a viable next candidate using existing capabilities,
conditional on the explicit input conversion and complete V-column gates above.
No complete native derivative comparison has been performed in this review.

The [preflight data](maintenance_guards_2026-11-02/subset_review/),
[initial raw-input rejection](maintenance_guards_2026-11-02/subset_preflight.log),
and [empty-list native preflight](maintenance_guards_2026-11-02/subset_empty_list_preflight.log)
are retained separately from coverage acceptance.
