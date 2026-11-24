# Connector heat-transfer Jacobian acceptance (2026-10-31)

The [review and authorized plan](../zeroD_coverage.md#remaining-case-review-and-authorized-connector-heat-jacobian-plan-2026-10-31) is complete. Only TestConnectorJacobians.test_wall_heat_transfer_cross_reactor_temperature changes to covered: **42/277/104 ->43/276/104**. Initialization and HO2 remain suspended. No production API, numerical policy or tolerance changes.

## Why this candidate

The remaining-case review distinguishes complete contracts from similar existing physics. The reviewed constant-pressure heat/inflow variants require wall/flow support absent from the existing closed constant-pressure model. WSR steady tests have grouped reactor-class parameters and convergence/history semantics not supplied by the existing terminal-residual API. Mole/surface/nonideal variants require further mapping. No new coverage is inferred for them.

The selected pinned test_reactor.py:1980-2010 checks just two cross-temperature Jacobian entries and their analytical heat-transfer values. Existing WellStirredReactor, HeatTransferWall, ReactorNetwork, network_rhs and network_jacobian! supply that complete observable contract. The production Jacobian is finite-difference based; Cantera's is analytical. This port tests the exposed derivatives, without claiming the algorithms or full mole-coordinate matrix are equivalent.

## Inputs, coordinates and independent oracle

Both sides use the unchanged pinned h2o2.yaml/ohmech fixture, SHA-256 `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`,10 species. Left:1200 K,1 atm,H2:2,O2:1,AR:8. Right:800 K,1 atm,H2:1,O2:1,AR:8. Both volumes1 m3, energy enabled. The chemistry flag remains true, but every reaction multiplier is zero, so chemical source terms and their Jacobian contributions are zero. This follows upstream `_make_h2o2_gas` (test_reactor.py:1887-1891), called at1987-1988 to isolate connector terms; it is not a configuration deviation. No active-chemistry or within-reactor kinetics-derivative coverage is claimed. Wall A=2 m2,U=50 W/(m2 K),K=0; no flow or wall motion. Reference source-default transport is mixture-averaged; native zeroD does not invoke transport. No transport switch is added.

| Mapping | Cantera | Julia |
|---|---|---|
| Node state | [T,V,n_1,...,n_10] | [m_1,...,m_10,T] |
| Network size |24 |22 |
| Left/right T positions |0,12 (zero-based) |11,22 (one-based) |
| Perturbation constraint |fixed species moles and V |fixed species masses and V |

Because m_k=MW_k*n_k is temperature independent, the two T partials are unchanged under this coordinate conversion. No omitted volume/species row is fabricated or credited.

The native test calls the existing production network_jacobian! unchanged. A separate RHS workspace evaluates the two independent centered FD columns using pinned ReactorNet.cpp:481-508: dy=atol+abs(T)*rtol, denominator2*dy, defaults rtol=1e-9,atol=1e-15. These are oracle perturbations, not a change to the production Jacobian step rule. The independent oracle does not call network_jacobian!.

All four original comparisons are retained: each cross entry versus FD at rel=1e-3,abs=1e-10; each versus UA/(m cv) at rel=1e-6,default abs=1e-12. Expected-side pytest.approx scaling is used: abs(a-b)<=max(atol,rtol*abs(b)). Native additionally checks unchanged input state and finite matrices, yielding6 assertions. No artificial integration, trajectory, retcode or zero solver counts is invented for this static source test.

## Measurements

Entries are ordered [d(T_left_dot)/dT_right, d(T_right_dot)/dT_left], in s^-1.

| Quantity | Left from right | Right from left |
|---|---:|---:|
| Cantera production J |0.6279864731562407 |0.4480639381748892 |
| Cantera FD |0.6279864620461484 |0.4480639500133812 |
| Cantera UA/(m cv) |0.627986473156241 |0.4480639381748892 |
| Native production J |0.6279864731570429 |0.44806393817407897 |
| Native independent FD |0.6279864620461484 |0.4480639500133812 |
| Native UA/(m cv) |0.627986473156241 |0.4480639381748893 |

Full matrices, initial states, native perturbed RHS vectors/step sizes, masses,cv and settings are archived in reference JSON and native TOML. Independent Python audit recomputes the FD columns, verifies all four numerical gates and the coordinate mapping, and checks source/input hashes. Both target and full-suite native data are identical.

## Execution, regression and failure record

Cantera reference and native target pass; native target **6/6**. Full optional suite contains **35 integration scenarios +1 static Jacobian scenario**, **8754/8754 assertions** including comparator selfchecks5/5. Core guard1/1. Full Pkg.test() is not claimed. All11 previous saved trajectories and every prior recorded solver-counter block match the accepted35-case baseline. Existing production sources, solver adapter, fixed environment and input fixtures retain baseline hashes.

The first native attempt failed before numerical testing because the new include guard was placed outside the parity module (case_selected undefined in Main). This test-entry placement error was corrected without changing the test equations, thresholds or production code. Initial entry, log, timing and checkpoint are retained. Corrected target and full regression both pass.

Corrected target process elapsed 25.1398011 s; full suite 681.7115837 s. Reference/core and failed-entry timings are archived separately. Times include startup/compilation and are not controlled performance comparisons. Reference JSON records actual pinned Cantera4.0.0a2,Python3.12.3,SUNDIALS7.5,WSL paths/source commit and clean-source gate; native uses Julia1.12.7 and unchanged example/reactors environment, one Julia/BLAS thread.

Only the selected coverage row changes. Its provisional missing-row layer A is corrected to actual execution layer B because the shared fixture/optional entry requires the pinned example environment. It remains a static test, is not added to default runtests/CI, and replaces old related mapping `test/moving_wall_native.jl:5 :: native variable-volume and pressure-work balances` with the new exact testset. Totals: **43 covered /276 missing /104 not_applicable**,423 rows. The prior CSV is archived for one-row verification. Initialization and HO2 remain unchanged and suspended; this stage does not close issue5.

## Reproduction and raw evidence

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl connector_heat_jacobian
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-python> test/cantera_parity/reactor_reference.py --case connector_heat_jacobian --source-dir <clean-pinned-source> --output <new-reference.json>
```

Use JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1 with a fresh CANTERA_PARITY_RESULTS folder. [Raw evidence](connector_heat_jacobian_2026-10-31/) retains original failure/corrected target/full/core logs, timings, full data, checkpoints and executed helpers. [Artifact hashes](connector_heat_jacobian_2026-10-31/artifact_sha256.json) protect the archive. All earlier evidence remains intact.
