# Energy-enabled MFC connector Jacobian acceptance (2026-11-02)

The [bounded candidate review and plan](../zeroD_coverage.md#remaining-connector-review-and-authorized-mfc-energy-jacobian-plan-2026-11-02) is complete. Only `TestConnectorJacobians.test_mfc_energy_enabled_cross_reactor` changes to covered: **43/276/104 ->44/275/104**. Initialization and HO2 remain suspended. No production API, numerical policy or tolerance change.

## Selection and exact source contract

Pinned Cantera commit `726522be4e2a13454d8415b7ef799d621f665cf3`, `test/python/test_reactor.py:2202-2228`, with shared compositions at1884-1885. This test asserts only one cross-temperature entry and the complete species cross block. Existing WellStirredReactor, MassFlowController, ReactorNetwork, network_rhs and network_jacobian! express all of those observations. Tests requiring volume columns, species-subset fixtures, constant-pressure coupling or derivative switches remain separate candidates; they receive no inferred coverage.

Both sides use unchanged `h2o2.yaml`, phase `ohmech`,10 species/29 reactions, LF SHA-256 `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`.

| Input | Upstream vessel | Downstream vessel |
|---|---|---|
| Temperature |1200 K |900 K |
| Pressure |2 atm |1 atm |
| Volume |1 m3 |1 m3 |
| Composition |H2:2,H:0.01,O:0.005,O2:1,OH:0.01,H2O:0.05,HO2:0.001,H2O2:0.001,AR:8,N2:0.1 |H2:1,H:0.005,O:0.002,O2:0.5,OH:0.005,H2O:0.1,HO2:0.001,H2O2:0.001,AR:8,N2:0.1 |

Energy is enabled. The reactor chemistry flag remains true, but every reaction multiplier is zero, so chemical source terms and their Jacobian contributions are zero. This exactly follows the upstream `_make_h2o2_gas` helper (test_reactor.py:1887-1891), called by this test at2209-2210; it is not a configuration deviation. The upstream class documentation (1871-1876) explicitly isolates connector terms this way. MFC upstream->downstream0.02 kg/s; no wall. Cantera uses source-default mixture-averaged transport; native zeroD does not invoke transport. The source test is static: no integration, time-step counter or terminal retcode is applicable. Coverage concerns the asserted cross-reactor blocks, not active-chemistry or within-reactor kinetics derivatives.

## Coordinates and independent finite differences

Cantera uses `[T,V,n_1,...,n_10]` per vessel,24 network entries. Native uses `[m_1,...,m_10,T]`,22 entries. Native T indices11/22 (one-based) correspond to Cantera0/12 (zero-based). Species order and molecular weights match. With `m_k=W_k*n_k`, the asserted species derivative transforms as `J_n[k,j]=J_m[k,j]*W_j/W_k`; the T-T entry is unchanged at fixed composition amounts and volume. No missing volume row/column is fabricated. Cantera's analytical Jacobian and native production FD Jacobian retain their respective algorithms.

The independent native oracle uses a separate RHS workspace, never calls production network_jacobian!, and follows pinned ReactorNet.cpp:481-508 central differences. ReactorNet.cpp:233-244 and MoleReactor.cpp:64-75 apply the base absolute tolerance to T/V and multiply it by reactor total moles for species. Defaults remain rtol=1e-9,atol=1e-15. Thus `h_T=atol+abs(T)*rtol`; `h_nj=atol*sum(n_up)+abs(n_j)*rtol`. Native mass perturbation is `W_j*h_nj`; divide RHS difference by `2*h_nj` and species outputs by `W_k`. Oracle steps do not alter production differentiation or solver policy.

All three original assertions are preserved: `abs(J[T_down,T_up])>1e-20`; that entry versus FD with rel1e-2/abs1e-10; every entry in the10x10 species block versus FD with the same limits. Each comparison uses `abs(actual-expected)<=max(atol,rtol*abs(expected))`. Native unchanged-state and finite-matrix guards give5 assertions. This establishes the source derivative checks, not full-matrix or cross-solver trajectory equivalence.

## Measured results

| Side | Production T-T derivative | Independent FD T-T derivative | Max species absolute difference | Max species error / allowed limit |
|---|---:|---:|---:|---:|
| native | 0.07684967172547115 | 0.076849670267053999 | 1.7375097213331164e-05 | 0.25640571277656909 |
| cantera | 0.07684967172457792 | 0.076849667306459271 | 2.2693767609414245e-05 | 0.76696554836630881 |

The last column is the maximum of each element's own error divided by its original allowed bound; both are below1. No absolute-only species limit or relaxed tolerance was introduced. Full matrices, initial states, molecular weights, native perturbation steps and RHS vectors are retained. Independent Python audit reconstructs both mapped blocks and native FD, and rechecks all original assertions. One representation-only1e-15 relative check accommodates the last bit of Python/Julia total-mole summation; it does not change saved native steps or any physical assertion.

## Verification and regression

Both Cantera references pass; prior heat-wall reference results are exactly unchanged. Both native static targets pass (heat6/6,MFC5/5); prior heat native data are exactly unchanged. Complete optional regression: **35 integration +2 static Jacobian scenarios**, **8759/8759 assertions**, including comparator5/5. Separate lightweight guard1/1. Full Pkg.test() is not claimed. All11 prior saved trajectories are byte-identical, prior solver-counter blocks match, and new target/full native data are identical.

The first independent audit failed due to a Python loop variable shadowing the parsed command-line argument (`AttributeError: float has no attribute mode`). Its script and failure description are retained. Renaming the loop variables fixed the audit; Cantera/Julia tests themselves had passed, and no numerical assertion was changed. Corrected target and full audits pass.

Process elapsed seconds: Cantera heat 5.3045414, Cantera MFC 1.1025296, combined native target 53.0700892, full regression 1226.9079778, lightweight guard 2.521472. Timings include startup/loading/compilation and are not controlled performance comparisons. These five timed reference/test processes all exited0; the initial audit exited1 as recorded above. Static solver statistics are not applicable, not reported as zero.

Reference JSON retains clean pinned source checks, actual Cantera4.0.0a2/Python3.12.3/SUNDIALS7.5 and import/executable paths. Native runtime is recorded separately; example/reactors Project/Manifest and production sources preserve their accepted hashes. Julia/BLAS threads1. Target and full source checkpoints distinguish only the subsequent registration into all; executed test and reference copies are archived.

Only the selected coverage row changes, from provisional layer A to actual optional layer B. Its old related mapping was `test/reactor_networks_native.jl:5 :: native reactor network balances and devices`; the new exact mapping is `reactor_connector_mfc.jl :: Cantera parity: TestConnectorJacobians.test_mfc_energy_enabled_cross_reactor`. Totals are **44 covered /275 missing /104 not_applicable**,423 rows. Initialization and HO2 records remain unchanged; issue5 stays open.

## Reproduction and evidence

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl connector_mfc_energy
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-python> test/cantera_parity/reactor_reference.py --case connector_mfc_energy --source-dir <clean-pinned-source> --output <new-reference.json>
```

Set JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1; choose a fresh CANTERA_PARITY_RESULTS directory. [Raw evidence](connector_mfc_energy_2026-11-02/) includes logs, timings, complete data, audits, source checkpoints, executed helpers and previous coverage. [Artifact hashes](connector_mfc_energy_2026-11-02/artifact_sha256.json) protect that archive. Earlier evidence remains intact.
