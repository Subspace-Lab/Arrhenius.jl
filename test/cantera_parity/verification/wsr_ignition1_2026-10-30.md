# WSR ignition1 acceptance (2026-10-30)

The [three-candidate review and authorized plan](../zeroD_coverage.md#authorized-wsr-ignition-review-and-ignition1-plan-2026-10-30) are complete for ignition1 only. The agent performed the authorized reference and native runs. Coverage changes **39/280/104 -> 40/279/104**. Ignition2 and ignition3 remain unverified; initialization and HO2 remain suspended. No production API, numerical policy or upstream assertion/tolerance changed.

## Review and selected mapping

At pinned commit `726522be4e2a13454d8415b7ef799d621f665cf3`, `test/python/test_reactor.py:1455-1466` defines ignition1. It uses the same 1/5 kg/s feeds as the accepted nonreacting case, with normal chemistry. Ignition2 (1468-1479) instead uses 1/20 kg/s and a 1.4856-s ignition target. Ignition3 (1481-1485) uses 1/80 kg/s, a 0.5-s maximum timestep, integration through the first t>=100 s, and final T<910 K. All three map to existing physical/step interfaces, but only ignition1 is executed and accepted in this stage. Source review is bounded; graph tools were unavailable.

Reuse `WellStirredReactor`, independent reservoirs, two constant `MassFlowController` feeds, `Valve`, `ReactorNetwork` and the existing QNDF accepted-step path. Defaults give unit reaction multipliers for ignition1; only nonreacting receives a zero vector. Both retain enabled chemistry and adiabatic energy. Existing native `dtmax` can express ignition3's explicit bound when separately ported; it is deliberately not applied to ignition1/2 because their source tests do not set it.

## Frozen inputs and settings

Both solvers use the exact [preserved 24-species export](../fixtures/cantera-726522be/wsr24/gri30-24.raw.yaml), phase `gas`, 129 reactions, six duplicate flags, SHA-256 `6295aa137d97648dc7fb5edcb2a6d3dd8d70842813fe652f0e6e3a0500f30bad`. The source GRI30 and gas_def hashes, strict-load probe and formal roundtrip equivalence remain in the [nonreacting acceptance](wsr_nonreacting_2026-10-30.md) and fixture manifest; the input is not regenerated or normalized. That manifest's upstream_test field records the case that originally established the shared fixture; each new reference record separately identifies its actual selected test.

Initial state: 900 K, 10 atm, a 1 m3 N2 vessel and N2 exhaust; pure CH4 inlet at 1 kg/s and O2:N2=1:3.76 oxidizer at 5 kg/s; valve K=1 kg/(s Pa). Source phase transport defaults to none; native zeroD does not call transport. Integration rtol=1e-9 and atol=1e-15 are unchanged. Cantera retains max_err_test_fails=10. Its binding -> ReactorNet -> CVodesIntegrator -> CVodeSetMaxErrTestFails call chain and per-internal-step semantics are documented in the [constant-pressure record](const_pressure_closed_2026-10-30.md). QNDF retains its existing failure behavior; no equivalent failure cap, maxiters substitution or policy parity is claimed.

## Exact source ignition criterion

Step until the first accepted time >=10 s, saving every post-step state. Native initializes a nominal 20-s horizon but does not solve it in full; no added dtmax or forced landing is used. Source T[0] means the first post-step temperature, not the nominal initial 900 K. Require final T>1200 K, compute threshold=(T_first_poststep+T_final)/2, and select the first accepted state with T strictly greater than that threshold. Use its actual time, with no interpolation or derivative-based ignition definition. Compare against 2.2249 s with `abs(error)<=max(1e-12,1e-3*2.2249)`. Absence of a crossing fails. This is the source's empirical regression criterion, not a claim that its number is an external physical standard.

| Measurement | Cantera | Julia |
|---|---:|---:|
| Accepted post-step samples | 3527 | 9689 |
| Previous time before final crossing (s) | 9.89277578952319 | 8.83450205707027 |
| Final time (s) | 10.666982004504652 | 10.477134921481104 |
| First post-step T (K) | 900.0000000000047 | 900.0 |
| Final T (K) | 1759.876266060936 | 1759.8762660416523 |
| Threshold (K) | 1329.9381330304702 | 1329.9381330208262 |
| Ignition sample index (1-based) | 2077 | 8823 |
| Ignition time (s) | 2.2266718203354814 | 2.2266731963958426 |
| Absolute ignition-time error (s) | 0.001771820335481511 | 0.0017731963958427244 |

Full t,T,P,Y trajectories, the preceding/crossing states, solver counters and return codes are retained. Native target passes **6/6** (two original physical assertions plus crossing/finite/progress guards), old nonreacting **235/235**, and comparator selfchecks **5/5**. Native recorded return code is `ReturnCode.Success = 1`; accepted-step loops may retain a running status, so no terminal-success status is invented. Cantera has no corresponding public retcode here. Its two reference runs pass. Independent audit recomputes the threshold and first strict crossing from every saved native/reference curve and checks the original error bound.

## Regression and coverage acceptance

The shared test setup was extended with two fresh-model modes. Nonreacting states and every recorded counter remain identical on both solvers. Ignition1 was explicit-only until the target gates passed, then joined `all`. Complete **33 integration scenarios pass 8735/8735**, including five comparator selfchecks; the separate lightweight guard passes **1/1**. Full Pkg.test() is not claimed. All eight previously saved native curves and all prior counter blocks match the accepted 32-case baseline. The new target/full trajectories are byte-identical.

Target two-mode process: 108.6824972 s. Full group: 689.3294232 s. These include loading/compilation and are not controlled performance comparisons. Cantera timings are retained separately. No unavailable statistic is filled with zero.

Only ignition1 becomes covered: **40 covered / 279 missing / 104 not_applicable**, total 423. Previous related mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced by `reactor_wsr.jl :: Cantera parity: TestWellStirredReactorIgnition.test_ignition1`. Passing ignition1 does not establish either sibling's distinct assertions. Initialization and HO2 remain missing/deferred.

## Reproduction and evidence

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl wsr_nonreacting wsr_ignition1
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-python> test/cantera_parity/reactor_reference.py --case wsr_ignition1 --source-dir <clean-pinned-source> --output <new-reference.json>
```

Use JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1, plus a fresh CANTERA_PARITY_RESULTS directory. [Raw evidence](wsr_ignition1_2026-10-30/) contains both Cantera runs, all native logs and curves, timing/exit records, source checkpoints, baseline code, independent audits and executed audit/acceptance scripts. [Artifact hashes](wsr_ignition1_2026-10-30/artifact_sha256.json) cover the preserved files. Prior evidence was not overwritten.
