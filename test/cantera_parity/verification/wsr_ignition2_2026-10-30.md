# WSR ignition2 acceptance (2026-10-30)

The [authorized ignition2 plan](../zeroD_coverage.md#authorized-wsr-ignition2-plan-2026-10-30) is complete. The agent performed the authorized reference and native runs. Only ignition2 becomes covered: **40/279/104 -> 41/278/104**. Ignition3 remains unverified; initialization and HO2 remain suspended. No production API, numerical policy, integration tolerance or original assertion changed.

## Source and interface mapping

Pinned `726522be4e2a13454d8415b7ef799d621f665cf3`, `test/python/test_reactor.py:1468-1479`, uses the shared WSR setup with CH4/oxidizer flows of 1/20 kg/s and the ignition-time baseline 1.4856 s. Existing `WellStirredReactor`, `Reservoir`, `MassFlowController`, `Valve`, `ReactorNetwork` and QNDF init/step! interfaces express the complete physical/assertion contract. The [earlier three-case review](wsr_ignition1_2026-10-30.md) records the sibling distinctions. Configuration is supplied before integration; no mutable post-initialization setter equivalence is asserted.

Both solvers load the preserved 24-species/129-reaction `wsr24/gri30-24.raw.yaml`, phase `gas`, SHA-256 `6295aa137d97648dc7fb5edcb2a6d3dd8d70842813fe652f0e6e3a0500f30bad`. No regeneration, normalization or NPZ is used. Species/reaction order and six duplicate flags remain unchanged. The [fixture provenance and formal equivalence](wsr_nonreacting_2026-10-30.md) apply unchanged. The shared fixture manifest retains its originating nonreacting test label; each reference record identifies the actually executed case separately. Reference environment gates recheck the clean pinned checkout, imported Cantera build and input hashes.

## Settings and source criterion

All initial temperatures are 900 K and pressures 10 atm. The 1 m3 vessel and exhaust contain N2; fuel is pure CH4 at 1 kg/s; oxidizer is O2:N2=1:3.76 at 20 kg/s; outlet valve K=1 kg/(s Pa). Normal unit reaction multipliers, enabled chemistry and adiabatic energy are retained. Source transport defaults to none; native zeroD does not use transport. Integration rtol=1e-9 and atol=1e-15 are unchanged.

Cantera retains max_err_test_fails=10. This maps through the binding, ReactorNet and CVodesIntegrator to CVodeSetMaxErrTestFails, limiting error-test failures for one internal step; the [call-chain evidence](const_pressure_closed_2026-10-30.md) remains applicable. Existing QNDF failure control is not replaced, and trajectory success is not evidence of equal internal failure protection.

Both solvers save every post-step t,T,P,Y and stop at the first accepted t>=10 s. Native initializes a nominal 100-s horizon but stops on the first crossing; an extra guard requires that crossing to lie strictly below the nominal endpoint. No dtmax, forced landing, initial-state sample or interpolation is added. Require final T>1200 K. Compute threshold=(T_first_poststep+T_final)/2, then select the time of the first strictly greater accepted T sample. Check `abs(tIg-1.4856)<=max(1e-12,1e-3*1.4856)`. A missing crossing fails. The source calls this an empirical regression without an external basis; no stronger physical-validation claim is made.

| Measurement | Cantera | Julia |
|---|---:|---:|
| Accepted post-step samples | 3649 | 7570 |
| Penultimate time (s) | 8.562302668251288 | 7.454312819227594 |
| Final time (s) | 11.91811272155873 | 35.126217188860444 |
| First post-step T (K) | 900.0000000000075 | 900.0 |
| Final T (K) | 2498.9424120396225 | 2498.94241203948 |
| Ignition threshold (K) | 1699.4712060198149 | 1699.47120601974 |
| Crossing index (1-based) | 2463 | 6670 |
| Ignition time (s) | 1.486125518492426 | 1.4861254766507541 |
| Absolute ignition-time error (s) | 0.0005255184924259915 | 0.0005254766507540864 |

Full trajectories and the exact preceding/crossing states are retained in the reference JSON, native CSVs and independent audits. Native recorded return code is `ReturnCode.Success = 1`; Cantera does not expose a corresponding code here. Actual accepted/rejected-step and nonlinear-solver counters are retained, including recoverable internal failures; unavailable values are not replaced by zero. The independent audit recomputes the first strict crossing and both original physical assertions from the saved data, and confirms the 1/20 kg/s settings.

## Initial endpoint correction

The first native target passed the original physical assertions but landed exactly at its artificial 20-s nominal endpoint, after t=7.454312819227594 s. Its logs, target CSVs, source checkpoint and initial audit remain preserved. Since upstream step() has no terminal bound, that attempt was not used for final acceptance. Existing network_problem requires a finite increasing tspan; only ignition2's test horizon was moved to 100 s and a no-endpoint-clipping guard was added. The loop still stops on its first t>=10 s. This adjusts the test interval representation, not the production solver's decision rules, original physical assertions or tolerances. The other two modes retain their old horizons. Corrected target data and complete regression both satisfy the added guard.

## Validation and coverage

Three Cantera reference runs pass. Native target passes nonreacting **235/235**, ignition1 **6/6**, ignition2 **7/7**, plus comparator selfchecks **5/5**. The two prior WSR modes retain identical trajectories and every recorded solver counter on both solvers. After target acceptance, ignition2 joins `all`.

Complete **34 integration scenarios pass 8742/8742**, including five comparator selfchecks. The separate core guard passes **1/1**. Full Pkg.test() is not claimed. All nine previously saved native curves and all prior solver-counter blocks match the accepted 33-case baseline; new target/full curves are byte-identical. The target three-mode process takes 163.9645931 s and the full group 812.117801 s, including loading/compilation. Separate reference timings and per-test solve timings are retained; these are not controlled performance comparisons.

Coverage changes only this row to **41 covered / 278 missing / 104 not_applicable**, total 423. Old related mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced by `reactor_wsr.jl :: Cantera parity: TestWellStirredReactorIgnition.test_ignition2`. Ignition3, initialization and HO2 remain missing. No evidence was inferred for them from this success.

## Reproduction and raw evidence

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl wsr_nonreacting wsr_ignition1 wsr_ignition2
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-python> test/cantera_parity/reactor_reference.py --case wsr_ignition2 --source-dir <clean-pinned-source> --output <new-reference.json>
```

Use JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1; select a fresh CANTERA_PARITY_RESULTS directory. [Raw evidence](wsr_ignition2_2026-10-30/) preserves three reference runs, initial and corrected target/full/core logs, timings and exit statuses, all native curves, baseline code, source checkpoints, independent audits and executed audit/acceptance helpers. [Artifact hashes](wsr_ignition2_2026-10-30/artifact_sha256.json) cover these files. Previous evidence is preserved.
