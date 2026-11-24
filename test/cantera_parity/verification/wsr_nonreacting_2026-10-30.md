# WSR nonreacting acceptance (2026-10-30)

The [authorized plan](../zeroD_coverage.md#authorized-wsr-nonreacting-stage-2026-10-30) is complete. Only `TestWellStirredReactorIgnition.test_nonreacting` is newly covered. The agent performed the authorized routine validation. Initialization and HO2 remain suspended. No production API, solver policy, integration tolerance or original assertion changed.

## Candidate and interface review

Pinned `test/python/test_reactor.py:1385-1453` supplies the full fixture, accepted-step loop and two numerical assertions. The native `IdealGasReactor.rate_multipliers` vector (`src/Reactors.jl`) reaches `wdot!` through `NetworkRHS` (`src/ReactorNetworks.jl`); the existing `WellStirredReactor`, `Reservoir`, two `MassFlowController` objects and `Valve` express its topology. Configuration is supplied before solving, corresponding to the source assignments before its first step. Same-object setters after initialization are not part of this test. Graph tools were unavailable; mapping used direct source inspection.

Other screened candidates remain separate: ignition1/2 need their ignition-delay assertions; ignition3 has its own timestep ceiling; steady-state tests need their convergence/API contracts mapped. Component indexing, mutable coefficient tests, advance limits and mole-coordinate Jacobian checks are not covered by this port. This is a bounded review, not an exhaustive claim that all other missing tests lack support.

## Input provenance and equivalence

Use the pinned commit `726522be4e2a13454d8415b7ef799d621f665cf3` and its `data/gri30.yaml`, SHA-256 `06650b1e0ee0012f6903d5328b1bb218cb6007d07f8ebe375d18f24811039345`. Extract the source gas_def by AST; SHA-256 `a07a7bf3b424469e681b2060da41b0bee7802c860680428cd6dc018f754a5a90`. Cantera `write_yaml(precision=17)` creates the unchanged self-contained [24-species export](../fixtures/cantera-726522be/wsr24/gri30-24.raw.yaml), SHA-256 `6295aa137d97648dc7fb5edcb2a6d3dd8d70842813fe652f0e6e3a0500f30bad`. Both solvers load that exact preserved file and phase `gas`, without a sidecar, normalization or efficiency deletion. All 129 reactions and six duplicate flags remain. Export metadata includes a generation timestamp, so a fresh export need not have the preserved file's byte hash.

Species order: `H2, H, O, O2, OH, H2O, HO2, H2O2, CH2, CH2(S), CH3, CH4, CO, CO2, HCO, CH2O, CH2OH, CH3O, CH3OH, C2H4, C2H5, C2H6, N2, AR`. No efficiency references an off-phase species. A validation-only reload with `skip-undeclared-third-bodies=false` succeeds; it is not the integration input. Source/export reaction ordering, keys, string/boolean fields and list structure are checked exactly. All numeric reaction parameters use the planned upstream write/reload rule `abs(a-b) <= max(1e-12,1e-6*abs(expected))`.

The initial exporter incorrectly imposed bitwise numerical parameter equality and stopped before creating its output directory. [Initial failure](wsr_nonreacting_2026-10-30/export.log), [original checker](wsr_nonreacting_2026-10-30/export_initial.py.txt), and [complete parameter differences](wsr_nonreacting_2026-10-30/export_parameter_differences.json) are retained. There are 28 differing scalar parameters across 27 reactions; maximum relative difference is 2.1403022839192305e-16. Correcting that extra checker to the already planned roundtrip rule changed no mechanism or physical-test gate. Export exit statuses were 1 (initial checker) and 0 (corrected checker); export elapsed time was not measured.

Formal [equivalence data](../fixtures/cantera-726522be/wsr24/equivalence.json) retain all forward/reverse rates, net reaction progress, net production, partial molar enthalpies and effective concentrations for all 29 third-body reactions. States are 900 K/10 atm with pure N2, pure CH4 and O2:N2=1:3.76, plus 2000 K/10 atm with all 24 species equimolar. All source/export/strict-probe comparisons pass; largest nonzero-expected relative metric is 3.4869494964601055e-15. Per-field absolute/relative maxima and full inputs/results are preserved. The gate is the upstream serialization rule, not a tightened observed-error threshold.

## Physical test and original criteria

All boundaries and the vessel start at 900 K and 10 atm. The 1 m3 vessel and exhaust contain pure N2; fuel is pure CH4 at 1 kg/s, oxidizer is O2:N2=1:3.76 at 5 kg/s, outlet valve K=1 kg/(s Pa). Chemistry and adiabatic energy remain enabled. All 129 reaction multipliers are zero, matching `combustor.phase.set_multiplier(0.0)` rather than freezing temperature or bypassing the chemistry path. Source transport defaults to none; native zeroD does not call transport.

Cantera uses `step()` and native uses `init`/`step!` with the existing QNDF adapter ingredients at rtol=1e-9 and atol=1e-15. Stop at the first accepted t>=100 s. Native's nominal horizon is 200 s but is not solved in full; there is no forced tstop, output grid or added internal dtmax. Each post-step T is checked against 900 K using rel=1e-5 and abs=1e-12. Final Y_CH4 is checked against 1/6 with pytest defaults rel=1e-6 and abs=1e-12. Guards additionally check crossing, progress, allowed running return code and finite output. No inter-solver trajectory or step-count criterion is added.

Cantera retains max_err_test_fails=10. The binding -> ReactorNet -> CVodesIntegrator -> CVodeSetMaxErrTestFails call chain and per-internal-step semantics are documented in the [prior constant-pressure record](const_pressure_closed_2026-10-30.md). Existing QNDF has no mapped setting here. No maxiters substitution or failure-protection equivalence is claimed.

## Measured single-case results

| Quantity | Cantera | Julia |
|---|---:|---:|
| Accepted post-step samples | 375 | 231 |
| Penultimate time (s) | 74.82221681730748 | 48.98289203511038 |
| First time >=100 s | 108.94265210287648 | 170.60006236774575 |
| Maximum absolute T error (K) | 0.001517253742349567 | 0.0015176743290794548 |
| Final Y_CH4 | 0.16666666666664295 | 0.16666666672268762 |

Native target passes **235/235**, plus comparator selfchecks 5/5. Native running return code is `ReturnCode.Success = 1`: a manually stopped accepted-step loop need not receive terminal Success. Cantera exposes no corresponding retcode here. All counters and full t,T,P,Y trajectories are retained, with no zeros fabricated for unavailable fields. Independent audit rechecks every saved original assertion on both solvers. Target elapsed time is 106.6432664 s; full regression elapsed time is 1062.1435057 s. These include loading/compilation and are not controlled performance comparisons; reference timing is recorded separately.

## Full acceptance and coverage

After target gates passed, `wsr_nonreacting` joined `all`. Complete **32 integration scenarios pass 8729/8729**, including five comparator selfchecks. The separate lightweight guard passes 1/1. Full Pkg.test() is not claimed. All seven previous saved trajectories and every previously printed solver-counter block match the accepted 31-case baseline. New target/full trajectories are byte-identical.

Only this coverage row changes, **38/281/104 -> 39/280/104**, total 423. Its old mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced by `reactor_wsr.jl :: Cantera parity: TestWellStirredReactorIgnition.test_nonreacting`. Initialization and HO2 remain missing/deferred.

## Reproduction and evidence

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl wsr_nonreacting
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-python> test/cantera_parity/reactor_reference.py --case wsr_nonreacting --source-dir <clean-pinned-source> --output <new-reference.json>
<pinned-python> test/cantera_parity/export_wsr_fixture.py --source-dir <clean-pinned-source> --output-dir <new-fixture-folder>
```

Use JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1, and set CANTERA_PARITY_RESULTS to a fresh directory for CSV retention. [Raw proof](wsr_nonreacting_2026-10-30/) contains all logs, timings, reference data, native curves, target/full audits, source checkpoints, archived helpers and initial checker failure. [Artifact hashes](wsr_nonreacting_2026-10-30/artifact_sha256.json) cover the preserved evidence. Prior evidence was not overwritten.
