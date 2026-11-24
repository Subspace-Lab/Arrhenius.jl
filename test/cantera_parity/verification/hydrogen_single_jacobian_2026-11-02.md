# Single-reaction constant-volume hydrogen Jacobian

## Plan and acceptance boundary

Port `TestReactorJacobians.test_const_volume_hydrogen_single` from Cantera commit
`726522be4e2a13454d8415b7ef799d621f665cf3`, after the accepted 46/273/104 inventory.
Use the existing pinned `h2o2.yaml`, phase `ohmech`, 1000 K, one atmosphere,
H2:H:H2O = 1:2:2, volume 2 m3, adiabatic chemistry with only zero-based reaction
14 enabled. The reaction is `H + OH + M <=> H2O + M`.

1. Run the unmodified upstream method and the shared-input Cantera reference.
2. Advance the existing native QNDF network exactly one accepted step, using
   rtol=1e-9 and atol=1e-15. The two solvers need not choose the same step/time.
3. Map native `[m...,T]` to `[T,n...]`, using `n=m/W` and
   `J_n[i,j] = J_m[i,j] * scale[j]/scale[i]`. Volume is constant and absent
   from all three upstream asserted blocks; no asserted volume column is dropped.
4. Use the reactor-level **forward** difference rule from
   `src/zeroD/Reactor.cpp::finiteDifferenceJacobian`: `h=max(abs(y),1000*atol)*sqrt(eps)`.
   This differs from the centered, total-moles-scaled ReactorNet rule used by
   the connector ports. Keep all 10 T/species, 10 species/T and 100 species/species
   entries, with respective rel/abs limits 1e-2/1e-3, 1e-3/1e-4, 1e-3/1e-4.
5. Run the individual native test, complete 40-scenario suite (36 integrations,
   4 static checks), comparator checks and existing lightweight guards. Audit
   the retained matrix values with an independent Python calculation and a
   deliberately out-of-bound entry in each block.
6. Only after all gates pass, update this one coverage row to 47/272/104 and
   publish an incremental ForgeKinetic PR based on the delivered inventory.

The native Jacobian remains the production finite-difference implementation;
this port validates the observable derivative contract, not equivalence to
Cantera's analytical algorithm or a matched cross-solver trajectory. Cantera's
default transport model is recorded; native zeroD does not call transport.
No production code, solver policy or assertion tolerance changes are planned.
Initialization #59 and HO2 #60 stay suspended.

## Candidate review

The isothermal wall-expansion candidate is deferred. At the original two-reactor
state, Cantera reports d(V_left dot)/d(T_right) = -1.1258333333333334e-4 m3/(s K),
matching -A*K*P_right/T_right; the native isothermal RHS holds physical temperature
at its descriptor value and returns zero even when its temperature coordinate is
perturbed. A native-Jacobian-versus-native-FD zero/zero comparison would conceal
this mapping difference. Resolving it requires a separate semantic/numerical
discussion; no production fix or covered claim is made here.

## Execution

Accepted under the user's authorization. The unmodified original method and
shared-input Cantera record pass. Julia target: **125/125**, including all 120
asserted matrix elements. Complete suite: **8906/8906** in
40 scenarios plus comparator checks (41 testsets); core 1/1, layout 8/8 and
runner 11/11 pass. [Portable execution evidence](https://github.com/Subspace-Lab/forgekinetic/tree/codex/zerodim-12-hydrogen-jacobian/tools/zerodim-parity/batches/12-hydrogen-jacobian/evidence) accompanies the incremental
ForgeKinetic delivery; the exact input and source hashes are retained there.

| Run | Seconds, including startup / compilation where applicable |
|---|---:|
| Cantera original method + shared-input reference | 12.112 |
| Julia individual | 26.940 |
| Complete native suite | 734.035 |

These are execution timings, not controlled performance comparisons. Environment:
Julia 1.12.7, SciMLBase 2.155.2, OrdinaryDiffEqBDF 1.26.0, one Julia/OpenBLAS
thread; Cantera 4.0.0a2 / Python 3.12.3 at the pinned clean source. The historical
locked example environment and installed caches were reused. No full Pkg.test()
or fresh-machine installation is claimed.

One accepted step reached 1.0218574113398374e-09 s natively and
0.00014872958275895994 s in Cantera. The native returned code is
`Success`; Cantera exposes no retcode here. Both report exactly one
accepted step; full available counters are saved. Cantera transport is
`mixture-averaged` as selected by the original default.

| Original block | Entries | Native max error / allowed bound | Cantera max error / allowed bound |
|---|---:|---:|---:|
| temperature_species | 10 | 5.165009e-05 | 1.3215553e-07 |
| species_temperature | 10 | 1.1558962e-14 | 0 |
| species_species | 100 | 1.4861524e-10 | 3.8020942e-13 |

All 11 historical trajectory files and four connector records are byte-identical
to the preceding clean-replay acceptance; all 144 logged solver-counter records
match in order. The individual and suite records for this new case also match
byte-for-byte.

## Adversarial review

The independent Python audit reconstructs every FD column from the saved physical
perturbations and RHS values, checks the exact source perturbation formula, input
species order/multipliers and scale mapping, then uses pytest.approx with the
original three predicates. It rejects six corruptions: one over-limit entry in
each block, a missing column, omitted molecular-weight scaling and a fabricated
unchanged perturbation. A separate Julia recomputation applies the diagonal
matrix transform directly; its maximum rounding difference from the test's
indexed transform is 4.6566129e-10. This auxiliary
roundoff check does not replace any upstream criterion.

Source review confirms that no asserted volume column is dropped, no centered
network FD rule is substituted, reaction 14 alone remains enabled, and the new
entry reuses the existing caller-owned integrator. Runtime/production files,
defaults and numerical policies are unchanged. Historical evidence is retained.

The source predicate can legitimately accept tiny/zero temperature-column
derivatives under its absolute bound; no stronger sensitivity claim is made.
The native production Jacobian is finite-difference based and its oracle also
evaluates the native RHS. This does not validate an analytical algorithm or prove
cross-implementation kinetics/trajectory accuracy.

Only `TestReactorJacobians.test_const_volume_hydrogen_single` changes to covered,
layer B. Its previous related mapping was `test/reactors_native.jl:20 :: closed
native ideal-gas reactors`, without a complete port. Inventory: **47 covered /
272 missing / 104 not applicable**, 423 rows.
The wall-temperature mapping gap is [ForgeKinetic #72](https://github.com/Subspace-Lab/forgekinetic/issues/72);
it remains missing. Initialization #59 and HO2 #60 remain suspended.

## Reproduce

After applying the ForgeKinetic patch series and using its locked example environment:

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases hydrogen_single_jacobian -TimeoutSeconds 300 -OutputDirectory <fresh-directory>
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 3600 -OutputDirectory <another-fresh-directory>
```

Inside the pinned WSL reference environment:

```sh
python test/cantera_parity/reactor_reference.py --case hydrogen_single_jacobian --source-dir "$CANTERA_SOURCE" --output "$NEW_REFERENCE_JSON"
python test/cantera_parity/hydrogen_jacobian_audit.py "$NATIVE_RESULT_TOML" "$NEW_REFERENCE_JSON"
```

The process deadlines are wall-clock safeguards, not numerical solver limits.
An initial local probe launch through the Windows process wrapper failed before
Python started (exit 127); direct WSL invocation succeeded. That launch log remains
local and is not reported as a Cantera numerical failure.
