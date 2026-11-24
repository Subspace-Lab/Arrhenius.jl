# TestWall trajectory regression verification (2026-10-30)

Status: both pinned Cantera references, the native target group, and the full 26-case optional group passed; all processes exited 0. The full group passes 8175/8175 assertions including five comparator selfchecks, plus the separate core guard 1/1. Coverage is accepted at 33 covered / 286 missing / 104 not_applicable. The user authorized the dependent constant-pressure stage; this wall phase is its already-planned prerequisite.

## Complete source correspondence

Pinned Cantera commit: `726522be4e2a13454d8415b7ef799d621f665cf3`. Source definitions: TestWall.test_integrateWithStep at line 3453, test_integrateWithAdvance at line 3468; setup at line 3425. Both refer to the unmodified test/data/WallTest-integrateWithAdvance.csv (199 rows, 7 columns).

Environment: air phase, O2:0.21,N2:0.78,AR:0.01, 300 K / 1 atm. r1: pure Ar in the same air phase, 1000 K / 30 atm / 1 m3. r2: ohmech phase, H2:0.5,O2:1,AR:10, 500 K / 1.5 atm / 1 m3; reference explicitly disables transport with transport_model=None. Reference vessels retain the upstream ct.Reactor class; native vessels use WellStirredReactor with enabled chemistry and adiabatic energy. No transport term enters the native zeroD equations.

Moving/thermal wall r2 -> r1: A=1, K=2e-4, U=400. Fixed thermal wall r2 -> environment: A=1, U=2000. Native MovingWallNetwork wraps the existing base heat-transfer network. Both endpoints, including reservoir heat transfer, use existing production APIs. Direction is retained: initially r2 compresses and r1 expands.

Step uses caller-owned QNDF init/step!, collecting every accepted state until the first time >=0.01 s, with an explicit crossing assertion. The unused 0.1 s problem horizon does not cause a solve to 0.1. Advance uses the same 199 np.linspace(0,0.01,200)[1:] sample times, with native saveat interpolation. No forced stop or extra timestep schedule is added. Output columns are t,T_r1,T_r2,P_r1,P_r2,V_r1,V_r2.

## Original comparison and solver tolerances

Both integrations use pinned Cantera defaults rtol=1e-9, atol=1e-15. No ledger-specific tolerance floor or solver policy change is introduced. The existing initial-timestep fallback warning is retained; both target runs complete.

Profile comparisons preserve utilities.py:33-100: per-variable maximum amplitude/range scale, reference slopes times the reference time span, linear interpolation with endpoint values outside sample bounds, and failure only when absolute, relative and normalized coordinate errors all exceed their thresholds. This is not vector isapprox. Step comparison rtol=1e-3/atol=1e-8 comes from source line 3465; Advance rtol=2e-5/atol=1e-9 from line 3481; xtol=1e-5 is the source helper default. The pinned CSV is never regenerated.

Cantera calls the original imported compareProfiles function. Native and original Python helpers both pass the same five explicit selfcheck cases: identity, different linear grids, endpoint clamping, slope-permitted shift despite excess relative/absolute errors, and a deliberately wrong constant curve that must fail. The small synthetic selfcheck thresholds exercise branches and do not replace physical-test thresholds. Comparator helper checks do not add coverage rows.

## Targeted observed results

| Quantity | Cantera | Native |
|---|---:|---:|
| Step accepted samples | 2254 | 1829 |
| Step final time (s) | 0.010022778042391009 | 0.010019275276015796 |
| Advance samples | 199 | 199 |
| Advance final time (s) | 0.01 | 0.01 |
| Advance final r1 T (K) | 716.4033501509442 | 716.403314727297 |
| Advance final r2 T (K) | 1552.4928765534637 | 1552.4928229945833 |
| Advance final r1 V (m3) | 1.6504774441586672 | 1.650477452134651 |
| Advance final r2 V (m3) | 0.3495225558413329 | 0.34952254787089065 |

The native target group passes 3/3 Step assertions, 3/3 Advance assertions and 5/5 comparator checks. Crossing times and step counts are solver-specific; no cross-solver equality at different crossing times is asserted. Both complete profiles pass the same fixed original oracle.

## Reproduction

Use the documented pinned WSL interpreter/source with reactor_reference.py --case wall_step or --case wall_advance and a fresh --output path. Native, from repository root:

```powershell
$env:JULIA_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
$env:CANTERA_PARITY_RESULTS='test/cantera_parity/local-results/wall-rerun-unique'
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl wall_step wall_advance
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
julia --project=. test/cantera_parity/reactor_core.jl
```

CANTERA_PARITY_RESULTS is optional. When supplied, it retains full native trajectories and refuses to overwrite existing case CSVs; use a new directory for each run. With it unset, the same assertions run without writing trajectory artifacts. Native is Windows Julia 1.12.7, SciMLBase 2.155.2 / OrdinaryDiffEqBDF 1.26.0, one Julia/OpenBLAS thread. Each reference validates clean fixed HEAD, imported runtime/version/path and all three shared fixture digests. This is optional zeroD verification, not full Pkg.test() or a performance comparison.

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `5f18effaf78f9a31c9509127666fc36871861c73cc979e5ad94db8e7e5d17a58`
- `test/cantera_parity/reactor_wall.jl`: `8be5f965f1f9851fa2ad25b384d6ee8874356d3ee1e023b82a76ccc2bd267c48`
- `test/cantera_parity/reactor_reference.py`: `e415c7d6efc527bf6837089267efad6e4ddd15b4422c22da9472cbca9b77ee44`
- `test/cantera_parity/reactor_wall_reference.py`: `63ed30f5444a22818182a096f8b3527c4437cf45bc4e52fd2fbb5b7fa43fc975`
- `test/cantera_parity/profile_comparison_cases.toml`: `5d305ad1544b6ce238595e59fbde1c5dbbf71224907bdc0514b76afb8b5e9a84`
- `test/cantera_parity/fixtures/cantera-726522be/wall_provenance.toml`: `5c6bbb4bed62324d7844a0d7171a943a2636bd7978d1d3511a8a53059a3780f3`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`

## Durable raw evidence

- [cantera_advance.json](wall_batch_2026-10-30/cantera_advance.json): SHA256 `38386af148a9828266edbf44b285e93170649d4f6b2c2f896cdfb3679d82f9e0`
- [cantera_step.json](wall_batch_2026-10-30/cantera_step.json): SHA256 `4096addba1ab9a8ec432477a1618ff0d909909af8b17ab8cd172bde3d188ece0`
- [native_advance.csv](wall_batch_2026-10-30/native_advance.csv): SHA256 `a8da1e9ef62044be9c7d6de38fc0ef014fac8adddf5879388183af7bd4ed208c`
- [native_core.log](wall_batch_2026-10-30/native_core.log): SHA256 `55e2643f8ff7ff166fc72759096da393e85faf7bfdacc2a42432c95871c79126`
- [native_step.csv](wall_batch_2026-10-30/native_step.csv): SHA256 `81781ec79506090a8010b36e4654162c67bf604203d44f0c52291bf371e0e297`
- [native_target.log](wall_batch_2026-10-30/native_target.log): SHA256 `fafadf0ea44aac26d38af898d3bb7804f8e001edf7a1b4a25d7604364aeb00fb`

## Independent original comparator audit

The original pinned Python compareProfiles also passes both complete native target CSVs directly, independently of the Julia implementation. See [audit log](wall_batch_2026-10-30/original_oracle_native.log), SHA256 `dc648fc5f40fba705a25dcc11260c8c4693bcf848f841ded0362b31640226342`.

## Complete 26-case acceptance

| Case | Pass / total |
|---|---:|
| `TestIdealGasReactor.test_disable_chemistry` | 5 / 5 |
| `TestIdealGasReactor.test_disjoint` | 10 / 10 |
| `TestIdealGasReactor.test_disable_energy` | 6 / 6 |
| `TestIdealGasReactor.test_heat_transfer1` | 5 / 5 |
| `TestIdealGasReactor.test_heat_transfer2` | 8 / 8 |
| `TestIdealGasReactor.test_heat_flux_func` | 7 / 7 |
| `TestIdealGasReactor.test_valve1` | 11 / 11 |
| `TestIdealGasReactor.test_valve2` | 205 / 205 |
| `TestIdealGasReactor.test_valve_timing` | 17 / 17 |
| `TestIdealGasReactor.test_reinitialize` | 6 / 6 |
| `TestIdealGasReactor.test_reservoir_sync` | 4 / 4 |
| `TestIdealGasReactor.test_wall_velocity` | 7 / 7 |
| `TestIdealGasReactor.test_equalize_pressure` | 8 / 8 |
| `TestIdealGasReactor.test_set_initial_time` | 8 / 8 |
| `TestIdealGasReactor.test_equilibrium_UV` | 6 / 6 |
| `TestIdealGasReactor.test_equilibrium_HP` | 6 / 6 |
| `TestIdealGasReactor.test_valve3` | 5487 / 5487 |
| `TestIdealGasReactor.test_pressure_controller2` | 2018 / 2018 |
| `TestIdealGasReactor.test_finite_difference_jacobian` | 21 / 21 |
| `TestIdealGasReactor.test_timestepping` | 288 / 288 |
| `TestIdealGasReactor.test_maxsteps` | 3 / 3 |
| `TestIdealGasReactor.test_tolerances` | 11 / 11 |
| `TestIdealGasReactor.test_derivative` | 13 / 13 |
| `TestIdealGasReactor.test_advance_reverse` | 4 / 4 |
| `TestWall.test_integrateWithStep` | 3 / 3 |
| `TestWall.test_integrateWithAdvance` | 3 / 3 |
| Profile comparator selfchecks | 5 / 5 |
| Total | 8175 / 8175 |

[Complete full-group log](wall_batch_2026-10-30/native_all26.log), SHA256 `6ea195688d00950af29a45985537ac66837069c022a1595899dcd39b91e1764e`. Both full-run native wall CSVs are byte-for-byte identical to the retained target trajectories, so the independent original-comparator audit also covers these exact data. The two TestWall rows are now covered; no other inherited variant or production feature is inferred. The dependent constant-pressure stage may now start.
