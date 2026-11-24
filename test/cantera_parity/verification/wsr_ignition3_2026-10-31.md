# WSR ignition3 acceptance (2026-10-31)

The [authorized plan](../zeroD_coverage.md#authorized-wsr-ignition3-plan-2026-10-31) is complete. Only ignition3 changes from missing to covered: **41/278/104 -> 42/277/104**. Initialization and HO2 remain suspended. No production API, numerical policy, integration tolerance or original physical assertion changed.

## Source, input and mapping

Pinned `726522be4e2a13454d8415b7ef799d621f665cf3`, `test/python/test_reactor.py:1481-1485`, calls setup_reactor(900,10*one_atm,1,80), sets max_time_step=0.5, steps to the first t>=100 s and asserts final T<910 K. The shared setup and sampling loop are at lines1385-1440. Existing WellStirredReactor, Reservoir, MassFlowController, Valve, ReactorNetwork, QNDF init/step! and dtmax express this contract. Constructor configuration is used before solving; no native mutable setter equivalence is claimed.

Both sides use the preserved raw 24-species/129-reaction WSR export, phase gas, SHA-256 `6295aa137d97648dc7fb5edcb2a6d3dd8d70842813fe652f0e6e3a0500f30bad`. No regeneration, normalization, mechanism substitution or NPZ is used. Species/reaction order and six duplicate flags are unchanged. The [formal fixture equivalence record](wsr_nonreacting_2026-10-30.md) remains applicable. The fixture manifest identifies its originating nonreacting case; the new reference JSON separately identifies the actual ignition3 upstream test. Each reference run rechecks pinned clean source, imported build, phase and input hashes.

Initial T=900 K and P=10 atm for all nodes. A 1 m3 N2 vessel receives pure CH4 at 1 kg/s and O2:N2=1:3.76 at 80 kg/s, draining to an N2 reservoir through a valve with K=1 kg/(s Pa). Normal unit reaction multipliers, chemistry and adiabatic energy remain enabled. Transport defaults to none in the reference; native zeroD does not invoke transport. Integration rtol=1e-9 and atol=1e-15 remain unchanged.

Only ignition3 receives source max_time_step=0.5 s, mapped to the existing QNDF dtmax=0.5 option. This is a test-specific upstream setting, not a production solver-policy change. Previous modes retain their previous settings. Native nominal endpoint is 200 s; the loop stops immediately at the first accepted t>=100 s, and a guard excludes endpoint clipping. Every post-step t,T,P,Y is saved; no forced landing, interpolated output, ignition-delay gate, whole-trajectory temperature ceiling or temperature comparison tolerance is added. The source assertion is exactly final T<910 K.

Cantera retains max_err_test_fails=10: the binding/ReactorNet/CVodesIntegrator path calls CVodeSetMaxErrTestFails, limiting error-test failures within one internal step; see the [existing call-chain evidence](const_pressure_closed_2026-10-30.md). QNDF failure handling is unchanged and has no configured equivalent. Success here establishes the original nonignition criterion, not equal internal failure protection or full-trajectory numerical accuracy between solvers.

## Observed results

| Measurement | Cantera | Julia |
|---|---:|---:|
| Accepted samples | 833 | 5577 |
| Penultimate time (s) | 99.74395179930374 | 99.79813352458952 |
| Final time (s) | 100.24395179930374 | 100.29813352458952 |
| Final T (K), required <910 | 900.0252853357654 | 900.0252853357678 |
| Configured maximum step (s) | 0.5 | 0.5 |
| Largest saved time increment (s) | 0.5000000000000004 | 0.5 |

The independent audit rechecks final T, first crossing of100 s, finite complete samples and the exact configured 0.5-s bound. Its output-time subtraction check permits one Float64 ULP for representing the difference of rounded timestamps; this is not a relaxation of dtmax or the physical temperature assertion. Native target has six assertions: crossing, no endpoint clipping, finite data, increasing times, configured bound and original final-temperature gate.

Native recorded retcode is `ReturnCode.Success = 1` at the final accepted step. The loop exits before its nominal endpoint, with every step having passed the Default/Success running-status gate. Cantera Python does not expose a corresponding return code. Full reference statistics, native solver counters, recoverable internal failures and complete trajectories are retained; unavailable statistics are not filled with zero. All physical and solver gates passed. The first independent audit misattributed ignition2 flow metadata to ignition3 because stdout summaries interleaved with stderr log events. Its original script and failure are preserved. The corrected audit locates the unique nonignition event and associates WSR counters by mode; it passes on the unchanged logs/data. No test, tolerance or numerical strategy was modified for this audit repair.

## Regression and provenance

All four Cantera WSR references pass. Native targets pass nonreacting235/235, ignition1 6/6, ignition2 7/7 and ignition3 6/6, plus comparator selfchecks5/5. The three old WSR modes retain identical trajectories and recorded counters on each solver. New ignition3 was added to all only after these target gates passed.

Full **35 integration scenarios pass 8748/8748** including five comparator selfchecks; core guard **1/1**. This is the optional zeroD suite, not a claim of full Pkg.test(). All ten previously saved native curves and previous solver-counter blocks match the accepted34-case baseline. The new target/full curve is byte-identical. Production sources, network adapter, fixed environment and mechanism inputs retain baseline hashes.

Target four-mode process: 114.344923 s. Complete suite: 699.5322261 s. Reference and core timings are recorded separately, with exit statuses. Timing includes startup/loading/compilation and is not a controlled performance comparison. Reference environment is pinned Cantera4.0.0a2 / Python3.12.3 / SUNDIALS7.5 in WSL; native environment is Julia1.12.7 and the unchanged example/reactors manifest. Source checkpoints retain the exact executed inputs and code.

Only the ignition3 row is updated; old mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced with `reactor_wsr.jl :: Cantera parity: TestWellStirredReactorIgnition.test_ignition3`. Coverage totals **42 covered / 277 missing / 104 not_applicable**,423 rows. The pre-update CSV is archived to prove the one-row change. [Initialization](initialization_diagnosis_2026-10-30.md) and [HO2 failure](pulse_failure_2026-10-29.md) remain missing and suspended.

## Reproduction and evidence

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl wsr_ignition3
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-python> test/cantera_parity/reactor_reference.py --case wsr_ignition3 --source-dir <clean-pinned-source> --output <new-reference.json>
```

Use JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1 with a fresh CANTERA_PARITY_RESULTS folder. [Raw evidence](wsr_ignition3_2026-10-31/) contains four references, target/full/core logs and timings, all trajectories, source checkpoints, independent audits, baseline code, executed runner/audit/acceptance helpers and [artifact SHA-256 values](wsr_ignition3_2026-10-31/artifact_sha256.json). Earlier evidence is preserved.
