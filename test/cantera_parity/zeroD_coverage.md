# Zero-dimensional Cantera coverage inventory

Frozen Cantera source: [`726522be4e2a13454d8415b7ef799d621f665cf3`](https://github.com/Cantera/cantera/tree/726522be4e2a13454d8415b7ef799d621f665cf3).
Scope is the complete two source files below, not all Cantera test directories.
The [CSV](zeroD_coverage.csv) is the per-test audit; the source links point to
the exact definition and line. The roster comes from a static source audit;
runtime verification is claimed only for rows with linked observed evidence.

Historical verification records are linked at their original locations inside the archived
ForgeKinetic patches. Each patch header identifies the record by filename. Batch commands,
reference environments and receipts are in the [reproduction guide](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/README.md).

## Source census and counting rule

| Source | Explicit declarations | Effective rows in CSV |
|---|---:|---:|
| `test/python/test_reactor.py` | 176 (including 5 module functions) | 400 |
| `test/zeroD/test_zeroD.cpp` | 23 `TEST` macros | 23 |
| Total | 199 | 423 |

This snapshot has 171 class test methods plus five module-level tests. The
issue's approximate count is not used as a collection count. Python rows
expand class inheritance and test-method
aliases. Overridden definitions are resolved to the effective method. The two
explicit `= None` overrides are retained as disabled audit rows:

- `TestIdealGasMoleReactor.test_preconditioner_unsupported`
- `TestIdealGasConstPressureMoleReactor.test_preconditioner_unsupported`

These two rows are `upstream_enabled=no`, not runnable test candidates. Thus
there are 398 enabled Python method/function groups.
Parameter decorators are preserved verbatim (with AST formatting) in
`parameters` and `upstream_marks`; each effective method is one grouped row,
not one row per parameter value. Skip/xfail/Graphviz marks are recorded, not
evaluated. Parameter-list constants remain named as in the source. No pytest
collection was executed, so these numbers must not be described as collected,
executed, or passing test counts. Helper/fixture methods are not test rows.

## Status, layer, and evidence

| Status | Rows | Meaning |
|---|---:|---|
| `covered` | 53 | Full upstream behavior with linked user-run or authorized agent-run evidence. |
| `missing` | 266 | Complete parity coverage is not established; may have related native functionality or a written but unrun port. |
| `not_applicable` | 104 | Specific binding/factory/internal or Graphviz contract, or an explicitly disabled upstream row; each has a reason. |

`missing` does **not** mean the native feature is absent or that a test has
failed. It means the full upstream scenario/assertions are not established by
the cited native regression. No baseline tests were executed during this audit.
`native_test` contains related evidence where present, not a claim that its
setup, coordinates, chemistry, or expected values match. `upstream_assertions`
shows up to three source assertions with AST formatting for orientation; follow the source
link for the complete test and its helper methods.

- **A**: a lightweight state, operator, validation, or Jacobian test can be run
  with the core environment; for missing rows it is a proposed placement.
- **B**: complete integration or solver-dependent behavior needs the optional
  `example/reactors` environment. These tests are not implicitly in `Pkg.test()`.
- **-**: not applicable; no native execution layer proposed.
- `validation=not_run`: no reference/native runtime verification is claimed.
  `validation=not_applicable` refers to the specific exclusion, not a passing run.
- `validation=user_verified: <path>`: the user supplied passing reference and
  native outputs, retained in the linked verification record.
- `validation=user_confirmed: <path>`: the reference JSON is retained and the
  user confirmed the native run passed; the record identifies missing raw logs.
- `validation=verification_withdrawn: <path>`: prior full-coverage evidence is invalidated pending correction; the row is missing.
- `validation=agent_failed: <path>`: a retained reference/native failure with actual outputs; the row remains missing.
- `validation=agent_verified: <path>`: the agent executed the reference and
  native runs under user authorization; the record retains their actual outputs.

RHS conservation, finite-difference directional checks, callback stubs, and
integrator-independent property tests are not counted as the upstream time
integration, sensitivity, solver-error, or steady-state regressions. Tests of
public physics/capabilities (including nonideal networks, radiative walls,
sensitivities, advance limits, surface integration, and mole tolerance scaling)
remain `missing` when the complete scenario is unported; lack of an implemented
capability is not a reason for N/A. ExtensibleReactor's numeric custom-equation cases
remain missing; only exact language-bridge registration/exception contracts are
excluded. State/component naming tests with numerical state-layout implications
also remain missing; factory label strings alone can be N/A.

## First port and acceptance

The selected row is
`test/python/test_reactor.py::TestIdealGasReactor::test_disable_chemistry`,
inherited from `TestReactor` at source line 584. Its new full regression is
`test/cantera_parity/reactor.jl` / testset
`Cantera parity: TestIdealGasReactor.test_disable_chemistry` (**B**).

This row is **covered**, based on the user's passing Cantera reference and
Julia **5/5** result on 2026-10-29. See the retained
[verification record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1960).
No other inherited reactor class is covered by that one port.
See [README](README.md) for commands and
[pinned reference environment](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/README.md) for the environment handoff.

`TestIdealGasReactor.test_disjoint` is also **covered**, based on the saved
passing reference and the user's confirmation that the Windows single-case
Julia run passed. Its [record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2078) explicitly
notes that the native stdout, assertion count and final numbers were not supplied.

The third port, `TestIdealGasReactor.test_disable_energy`, is **covered**.
The authorized [agent-run batch](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1207) records
the new pinned Cantera reference and all three native regressions (**21/21**).
It also supplies a subsequent independent raw log for the first two cases;
their earlier user-run records remain unchanged. No other inherited class is
covered by any of these three ideal-gas variants.

The next three ideal-gas ports, `test_heat_transfer1`, `test_heat_transfer2`,
and `test_heat_flux_func`, are also **covered**. The
[thermal batch record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L4331) preserves all
three passing Cantera references and the complete **41/41** six-case native
log. It documents the fresh-volume constructor mapping and retains every
upstream thermal/pressure/power/volume/energy assertion. Other inherited
reactor classes remain separate, unverified rows.

The valve batch adds **covered** ideal-gas variants of `test_valve1`,
`test_valve2` and `test_valve_timing`. Its
[verification record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L4999) retains three
passing Cantera references and the complete **274/274** nine-case native log.
All 50 isothermal analytical samples and the four timing-edge samples are
checked. Constructor configuration and existing network endpoint views map
the upstream pre-initialization settings/topology checks without adding APIs.

## Reproducibility and limits

SHA-256 of each downloaded source after CRLF-to-LF normalization:

| Source | SHA-256 (LF) |
|---|---|
| `test/python/test_reactor.py` | `ea2e6d791201ce3936a51c7e0445c5a735d10c877281171484d7fc02f7d15ffd` |
| `test/zeroD/test_zeroD.cpp` | `18cec1895658b480216c66cb6d52688bb76ab5f1a44f097b1b06af0f9da66233` |

The audit used direct source/AST reading and targeted native source/test reads.
The codebase-memory graph tools were unavailable; graph coverage/freshness is
unknown. No external Cantera/Python test module was imported or executed. The
inventory does not prove absence of equivalent tests outside the cited native
paths; these conservative gaps can be reclassified when a complete matching
regression and user-confirmed evidence are supplied. Inheritance is resolved
statically for the local named bases/aliases in this snapshot, not arbitrary
dynamic pytest collection or fixture-generated parameter instances.

## Restart, boundary and moving-wall ports

The agent verified `TestIdealGasReactor.test_reinitialize`, `test_reservoir_sync`, `test_wall_velocity`, and `test_equalize_pressure` (25/25 Layer B assertions), plus the class-independent empty-network construction guard (1/1 Layer A assertion). The guard covers its four effective inherited rows because the identical source body has no reactor-class dependence. Eight additional rows are covered; physics variants in other classes remain missing. The [complete verification record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L3805) retains each reference, full native logs, checkpoint/reconstruction mappings, and executed-source hashes.

## Combustion equilibrium and initial-time ports

The agent verified UV and HP combustion equilibrium and shifted initial time (20/20 native assertions), retaining the original scalar/elementwise comparisons. UV and initial-time coverage apply to the selected IdealGasReactor variants. HP's source body constructs IdealGasConstPressureReactor explicitly without accessing `self`, so its four effective inherited rows share one verified scenario. Six more rows are covered; see the [reference outputs, native log and source hashes](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2196).

## Accepted-step nonlinear flow ports

`TestIdealGasReactor.test_valve3` and `test_pressure_controller2` now preserve their upstream accepted-step loops. All flow/conservation assertions passed (7505/7505 native assertions); solver step counts and crossing times are recorded separately rather than asserted equal. See the [complete two-case verification](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2486).

## Retained pulse failure

The full `TestIdealGasReactor.test_mass_flow_controller` candidate is written and reproducible by explicit selector. Cantera passes, while native runs fail only the final HO2 mass comparison (4.5831e-12 kg against the original 1e-12 kg absolute threshold; 15/16 assertions pass). It remains `missing / agent_failed`, outside the verified `all` group. The [failure record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2917) retains both native runs, the passing reference, diagnostic values and executed-source hashes. No numerical-policy fix or relaxed tolerance is included.

## Time-control, derivative and failure-guard ports

Five further TestIdealGasReactor cases are verified: `test_timestepping`, `test_maxsteps`, `test_tolerances`, `test_derivative`, and `test_advance_reverse` (319/319 native assertions). Their [verification record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L4692) preserves all references, accepted-step counts, expected failure-state mapping, native derivative coordinates and full log. The maxsteps mapping is verified for the original idle scenario; it does not claim a universal equivalence between CVODE max_steps and SciML maxiters with rejected steps.

## Reacting-state finite-difference Jacobian

The original 10/10 proof for `TestIdealGasReactor.test_finite_difference_jacobian` was withdrawn because its energy-disabled native descriptor froze T at the initial 900 K rather than the advanced temperature. The [historical record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L3131) preserves the original text and raw outputs with a supersession notice.

The [corrected record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L3252) restores this row after the pinned reference, 21/21 targeted native assertions, the complete 24-case native group (8164/8164), and the 1/1 core guard passed. Both energy/chemistry toggles now explicitly preserve T, P, Y, mass and volume from an independent advanced-state snapshot. Coverage temporarily changed to 30/289/104 and returns to 31/288/104 after acceptance. Native coordinates and elimination of constant mass/volume rows remain explicit; component metadata APIs are unported. No production policy or wall regression is included in this correction.

## TestWall profile regressions

Both TestWall time-series methods are verified using the exact air/ohmech inputs and original pinned CSV. The [wall record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L6049) retains all Cantera/native trajectories, logs, comparison selfchecks, independent original-comparator checks and source/input hashes. Step preserves accepted-step crossing; Advance preserves all 199 sample times and original profile thresholds. The complete 26-case optional suite passes 8175/8175 including five helper checks; the separate core guard passes1/1. These two rows raise coverage to33/286/104 and satisfy the prerequisite for the planned closed constant-pressure comparison.

## Closed constant-pressure comparison

Only `TestIdealGasConstPressureReactor.test_closed` is added after the accepted wall prerequisite. The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1817) retains the original and normalized 18-species/74-reaction mechanism, the exact 14-entry conversion, four-state structural/numerical gates, the Cantera reference, all native samples and solver counters. Both physical branches reach 49.5 s and preserve every original scalar Y/T/P comparison at all 50 times (255/255 native target assertions). Cantera max_err_test_fails=10 is recorded with its per-internal-step meaning and remains unmapped to QNDF. The complete optional 27-case group passes 8430/8430 including five comparator checks; the separate core guard passes 1/1. This one new row raises coverage to **34/285/104**. Other inherited class variants remain separate, and the deferred HO2 pulse failure remains missing.

## Original C++ basic combustion smoke regression

The single `zerodim.simple` row replaces its old related RHS mapping with the dedicated native regression. The [record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L6402) preserves that old mapping, exact original GRI30 input, formal build, unchanged filtered C++ gtest (1/1), native target (46/46), all 21 output rows, counters and measured timings. The original numerical contract is 20 pre-advance T>=1050 checks; this coverage does not claim Cantera trajectory accuracy. Complete optional acceptance passes 28 scenarios/8476 assertions including five comparator checks, plus core 1/1. Inventory is **35/284/104**; no other C++ row or deferred HO2 failure is reclassified.

## Initialization diagnostic: absolute energy criterion

The original C++ initialization gtest passes, while an unregistered native physical-state diagnostic misses only the total-U absolute bound. The [bounded diagnosis](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2684) identifies energy drift in the temperature-coordinate integration: U differs from its initial value by about1.33e-3 J; independent UV equilibrium differs by only3.49e-10 J. Same-state thermodynamic evaluation agrees to roundoff, and pre-preparation leaves saved states/counters bit-identical. This is not evidence of an initialization or energy-evaluator defect in these checks. The row remains missing, now with agent_failed diagnostic evidence; this label does not imply a registered full initialization port was executed. No tolerance, state-coordinate or solver-policy change is included. Counts remain35/284/104 and the accepted optional suite remains28 scenarios.

User disposition (2026-10-30): suspend work on this initialization item and retain its failed diagnostic evidence. Resume only under a separately discussed plan; it is not added to the accepted suite.

## Next-candidate mapping review (2026-10-30; not execution evidence)

Execution prerequisite accepted: the [independent small maintenance record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2829) verifies the GRI30 tolerance-source correction (46/46; identical trajectory bytes and all printed solver counters), explicit CI documentation, and the strict-loading negative control. No broad helper refactor or policy change is included. The user authorized the combustor plan below after this maintenance; its acceptance is tracked separately.

This bounded review screened the remaining inventory and inspected the relevant pinned source bodies and native implementations. Codebase graph tools were unavailable, so the evidence is direct source inspection; this is not an exhaustive proof that other candidates are unsupported.

| Candidate | Mapping decision |
|---|---|
| `TestCombustor.test_integrateWithStep` | Recommended: existing fixed-volume vessel, reservoirs, constant/callback mass flows, valve, QNDF accepted-step path and profile comparator express the complete source assertion contract. No new production API is needed. Numerical acceptance remains untested. |
| `TestCombustor.test_integrateWithAdvance` | Same physical mapping is available; defer its distinct fixed-time, tighter-profile contract to a subsequent stage. |
| `TestWellStirredReactorIgnition.test_nonreacting` | Physical ingredients are available, including zero reaction multipliers; needs a separately audited 24-species GRI-derived input. Do not substitute the existing 18- or 53-species fixture. |
| `TestIdealGasReactor.test_pressure_controller1` | Coefficient alias mutation is not represented by immutable native K; testing only the flow law is incomplete. |
| `TestExtensibleReactor.test_extra_variable` / `test_heat_addition` | Inertial-wall / heat-flow physics alone does not verify custom component metadata or the extension heat-rate hook. |
| `TestIdealGasConstPressureReactor.test_with_heat_transfer` / `test_with_mdot` | The existing closed constant-pressure IdealGasReactor excludes wall/flow terms; the fixed-volume network is not an exact constant-pressure replacement. |

The recommended source is `test/python/test_reactor.py:3289-3364` at the fixed commit. Its reference is `test/data/CombustorTest-integrateWithAdvance.csv`, SHA-256 `7e21a86c82ae905150edab14d7f7f88c046fd1d6c4dec4d4dfb10440f73cd7b6`, shape100x12: time, T, then X in `[H2,H,O,O2,OH,H2O,HO2,H2O2,AR,N2]` order. Reuse the unchanged ohmech fixture (10 species/29 reactions; SHA-256 `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`). The source tree was clean at the pinned commit during this review.

All inlet/reactor/exhaust initial temperatures are300 K and pressures1 atm. The 1 m3 adiabatic, reacting vessel and exhaust start as pure AR; fuel is pure H2 (the source comment mentioning methane is stale), oxidizer O2:AR=1:3, and igniter pure H. Fuel flow is0.1*MW(H2)=0.2016 kg/s; oxidizer flow is0.4*MW(oxidizer)=15.184800000000003 kg/s. The igniter is `0.1*exp(-4*log(2)*(t-0.1)^2/0.05^2)` kg/s, with FWHM0.05 s; the valve has K=1 kg/(s Pa). Source `Gaussian1` constructor/evaluation confirms the width convention. Cantera explicitly disables transport; native zeroD does not use it.

Native mapping sources: `src/ReactorNetworks.jl` (vessel/reservoir constructors, mass-flow and valve callbacks, enthalpy-flow and reacting energy balance, diagnostics); `example/reactors/network_solver.jl` (QNDF configuration); `reactor_flow_steps.jl` (accepted-step loop); `reactor_wall.jl` (existing general matrix comparator). Convert species masses to mole fractions using `X=(m./MW)/sum(m./MW)` in mechanism order. Use a separate diagnostic RHS workspace when sampling, as in existing flow tests.

Proposed next stage: add explicit selector `combustor_step`, dedicated `reactor_combustor.jl` and reference runner, and the unchanged source CSV with provenance. Load the existing comparator for this selector without implicitly running wall scenarios or duplicating its five selfchecks in `all`. Use `init`/`step!` with the existing QNDF settings, nominal horizon0.5 s, and stop immediately after the first accepted step at or beyond0.25 s; do not solve to the nominal horizon or force a0.25-s stop. Record every post-step row, no initial row, require forward progress and valid running retcodes, and check the crossing explicitly. Integration tolerances remain1e-9/1e-15. Apply the original Step profile limits rtol1e-3, atol1e-9, default xtol1e-5, including its normalization, interpolation, endpoint handling and joint-failure rule. The reference CSV has100 rows; native accepted-step row count need not be100.

Formal execution must recheck the environment/input gate, run the Cantera reference and native target, and cross-check the saved native curve using the unchanged upstream comparator. Retain all curves, solver status/counters, crossing time, source/input hashes, elapsed times and failure details. Manual termination after the crossing may leave SciML retcode Default; report it honestly rather than claiming a terminal Success. Only after targeted acceptance add the case to `all`, run29 integration scenarios plus the five comparator checks and the separate core guard, then update only the selected coverage row to36/283/104. Assertion totals are measured, not predicted, because accepted-step counts can differ. Any required failure leaves35/284/104 and the candidate outside accepted `all`; no tolerance, mechanism, pulse, valve or solver-policy change is permitted to force acceptance. Initialization and the HO2 pulse remain deferred.


## Combustor accepted-step profile acceptance

The [complete accepted record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1505) verifies only TestCombustor.test_integrateWithStep. Both solvers pass the original temperature/all-species profile bounds; the saved native curve also passes the unchanged upstream Python comparator. Target4/4 plus comparator5/5; complete29 scenarios pass8480/8480, with separate core1/1. Target/full combustor rows and all four previously saved regression trajectories are byte-identical to their relevant baselines. Coverage is now **36/283/104**. The initialization diagnostic and HO2 failure remain missing and deferred; no new API, numerical policy or tolerance change is included.

## Authorized next stage: combustor Advance (2026-10-30)

Port only TestCombustor.test_integrateWithAdvance (source3366-3381), reusing the accepted physical fixture and unchanged100x12 CSV. Preserve100 output times from numpy.linspace(0,0.25,101)[1:], integration rtol1e-9/atol1e-15, and the distinct original Advance profile rtol1e-6/atol1e-12/default xtol1e-5. Native solve_network with the existing QNDF adapter uses saveat; the0.0025 s sampling interval is not an internal timestep cap. No reference regeneration, mechanism conversion, pulse change or tolerance relaxation is allowed.

Reuse the test-local setup for Step/Advance with fresh models for each. This is test-code organization only; no production API or numerical-policy change. Re-run both Step and Advance targets and reference paths, checking that Step trajectory bytes and all reported solver counters are identical to accepted evidence. Independently apply the original Python compareProfiles to native Advance output. Keep the new candidate explicit-only until targeted gates pass, then run all30 integration scenarios, five comparator selfchecks and the separate core guard. Archive sources, input hashes, full output, exit status/retcode, counters and actual timings; unavailable statistics remain unavailable. Only after all required acceptance update one row to37/282/104. Failure leaves36/283/104 and requires a recorded diagnosis before any larger repair. Initialization and HO2 remain deferred.


## Combustor Advance acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1404) verifies the original100-point Advance profile on both solvers and independently with the upstream Python comparator. The shared Step setup retains bit-identical states and counters. Target Step4/4,Advance6/6,comparator5/5; full30 suite8486/8486,core1/1. All five previously saved trajectories remain byte-identical to the accepted29-case baseline. Only one row is newly covered: **37/282/104**. Initialization and HO2 remain deferred; no new production API or numerical-policy change.

## Authorized invasive-callback mapping and plan (2026-10-30)

Pinned TestCombustor.test_invasive_mdot_function (3383-3407) reads igniter.density inside the Gaussian flow callback, assigns it before integration, and compares100 output rows with the same CSV and Advance limits1e-6/1e-12/default xtol1e-5. The source comment says the query changes shared ThermoPhase state; however pinned interfaces/cython/cantera/reactor.py defaults clone=True, phase returns _phase directly, and density returns phase.density. Do not claim reproduction of a historical shared-state mutation that this pinned path no longer performs.

Existing native MassFlowController supports f(states,t) and exposes density as a documented read-only callback field. network_rhs allocates per-node workspaces; _update_network_states! populates them before _network_signal calls the flow function. Read states.igniter.density and return the exact source callback expression, with test-local read counters/extrema used only for observation. This maps the public behavior (query upstream state during flow evaluation without disturbing integration), not Cantera object layout or post-initialization setter support. Constructing the native immutable device with its callback before solving is equivalent configuration for this test; setter round trips are not asserted upstream. No new API is required. Graph tools were unavailable; this bounded mapping uses direct source reads.

Keep the accepted physical setup, fixed mechanism/CSV, output times and integration1e-9/1e-15 unchanged. Record callback reads/density extrema immediately after solving, before output diagnostics can invoke it again, and require the observed density to equal the initial pure-H reservoir density. Run both references and native target for all three combustor modes; Step and ordinary Advance must retain bit-identical trajectories and recorded counters. Independently apply unchanged upstream compareProfiles to the new native curve. Keep the candidate explicit-only until targeted gates pass; then run31 integration scenarios plus comparator selfchecks and the separate core guard. After all acceptance only this row may change37/282/104 ->38/281/104. Any failure is preserved without widening limits or changing policy. Initialization and HO2 remain deferred.


## Combustor invasive callback acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1448) verifies actual solve-time igniter-density queries and the full original100-point curve. The pinned4.0 clone/getter behavior is explicitly distinguished from its stale shared-state comment; no new API is introduced. Target8/8 plus old-mode controls and comparator5/5; full31 suite8494/8494,core1/1. Previous Step/Advance states and counters and all six saved regression curves remain unchanged. Coverage is **38/281/104**; initialization and HO2 remain deferred.

## Authorized WSR nonreacting stage (2026-10-30)

Bounded remaining-case review recommends TestWellStirredReactorIgnition.test_nonreacting (pinned test_reactor.py:1385-1453). Existing rate_multipliers, fixed-volume adiabatic vessel, two constant mass-flow controllers, valve and accepted-step QNDF interface express all physical settings and assertions. Ignition1/2 add an ignition-delay gate and remain separate candidates; ignition3 has a separate timestep ceiling; steady-state cases require distinct convergence/API mapping. Existing component indexing, mutable volume/coefficients, advance limits and mole-coordinate derivative cases cannot be credited from the current physics checks alone. Graph tools are unavailable; this mapping uses direct source inspection, not an exhaustive absence claim.

Export the original gas_def from the pinned source using its data/gri30.yaml (SHA-256 06650b1e0ee0012f6903d5328b1bb218cb6007d07f8ebe375d18f24811039345). Preliminary inspection finds 24 species, 129 reactions, 6 duplicates and no off-phase efficiency species. Use the untouched self-contained precision-17 export on both sides, without normalization or NPZ. Record hashes, species/reaction order, and complete forward/reverse rates, net progress/production rates, partial molar enthalpies and effective third-body concentrations at N2, CH4, O2/N2 initial states and an all-species 2000-K state. Use the upstream roundtrip max(1e-12,1e-6*abs(expected)) rule. Strict loading with only the skip flag disabled is a validation probe, not the integration input.

Both sides: 900 K, 10 atm, 1 m3 N2 vessel and N2 exhaust; pure CH4 inlet at 1 kg/s, O2:N2=1:3.76 inlet at 5 kg/s, valve K=1 kg/(s Pa). Keep adiabatic energy and chemistry enabled, but set all 129 reaction multipliers to zero, matching phase.set_multiplier(0). Transport is none by the source phase default; the native zeroD path does not call transport. Native immutable construction configures multipliers and devices before solving; no post-initialization setter contract is claimed.

Use init/step! with the unchanged network adapter ingredients and rtol=1e-9,atol=1e-15. Step until first t>=100 s (nominal horizon 200 s, never solve to that horizon); no forced landing or added dtmax. Save every post-step T/P/Y state, check T against 900 K with upstream rel=1e-5,abs=1e-12 and final Y_CH4 against 1/6 with pytest defaults rel=1e-6,abs=1e-12. Also guard progress, running return code, finite output and crossing. No trajectory or step-count matching is added. Retain Cantera max_err_test_fails=10; CVodeSetMaxErrTestFails bounds error-test failures for one internal step, and the existing QNDF has no configured equivalent. No maxiters/tolerance change or failure-control equivalence claim.

Keep wsr_nonreacting explicit-only until input and both single-case gates pass. Then run all 32 scenarios, five comparator checks and the core guard. Archive full data, actual counters/status/timings, sources and inputs. Compare existing saved curves to the accepted 31-case baseline. Only after all required acceptance update this one row from 38/281/104 to 39/280/104. Required failure leaves coverage unchanged, preserves evidence and triggers discussion for a major error/new API/policy change. Initialization and HO2 remain suspended.


## WSR nonreacting acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L6339) verifies the original 24-species / 129-reaction input and all accepted-step temperature / final CH4 assertions on both solvers. Target 235/235; full 32 scenarios 8729/8729, core 1/1. All seven earlier saved curves and prior solver-counter blocks are unchanged. Coverage is **39/280/104**. Initialization and HO2 remain suspended. The input-checker roundoff correction and original failed check are retained; no physical assertion, integration tolerance or numerical strategy changed.

## Authorized WSR ignition review and ignition1 plan (2026-10-30)

Review scope is the three remaining TestWellStirredReactorIgnition ignition cases at the pinned commit. The already validated raw 24-species/129-reaction fixture (SHA-256 6295aa137d97648dc7fb5edcb2a6d3dd8d70842813fe652f0e6e3a0500f30bad) and existing adiabatic fixed-volume network express all three physical setups. Existing init/step! supports accepted-step sampling; existing dtmax supports ignition3's explicit bound. Graph tools remain unavailable; source and previously verified interface paths are used directly.

| Candidate | Source settings and full numerical contract | Mapping decision |
|---|---|---|
| ignition1 (1455-1466) | Fuel/oxidizer 1/5 kg/s; first t>=10 s; final T>1200 K; first accepted T strictly above (T_first_poststep+T_final)/2 gives tIg≈2.2249 s with rel=1e-3, default abs=1e-12. | Recommended next: same flow setup as nonreacting, enables normal chemistry and adds the original ignition-delay criterion. No new API. |
| ignition2 (1468-1479) | Fuel/oxidizer 1/20 kg/s; first t>=10 s; same threshold construction; tIg≈1.4856 s with rel=1e-3, abs=1e-12; final T>1200 K. | Interfaces support the complete contract; numerical acceptance remains untested and separate. |
| ignition3 (1481-1485) | Fuel/oxidizer 1/80 kg/s; first t>=100 s; max_time_step=0.5 s; final T<910 K. | Existing dtmax maps the explicit source ceiling; no ignition-delay assertion or whole-trajectory temperature ceiling should be invented. Separate candidate. |

This stage implements only ignition1. Preserve 900 K, 10 atm, 1 m3 initially N2 vessel/exhaust, pure CH4 fuel, O2:N2=1:3.76 oxidizer, valve K=1 kg/(s Pa), adiabatic energy and chemistry enabled. Use default unit reaction multipliers (not the prior zero multipliers), source transport default none, integration rtol=1e-9 and atol=1e-15. Retain Cantera max_err_test_fails=10 without a claimed QNDF equivalent or maxiters substitution.

Reuse the WSR test setup in two explicit modes with fresh models. Native ignition1 uses a 20-s nominal horizon but stops after the first accepted t>=10 s. Do not add dtmax, forced landing, interpolated ignition time or initial-state sample. Preserve all post-step T/P/Y; compute the threshold from first and last saved T, find the first strict crossing, and assert its actual time against 2.2249±max(1e-12,1e-3*2.2249). Record threshold, crossing index, preceding state, final temperature/time, return code and available counters. Guard progress, finite output and successful running status. A missing crossing is a failure, not a substitute value.

Run both Cantera reference modes and the native nonreacting/ignition1 targets. Nonreacting must preserve trajectory bytes and solver counters on each solver. Independently recompute the original ignition criterion from both saved curves. Keep wsr_ignition1 explicit-only until target acceptance; then run all 33 scenarios, the existing five comparator checks and the core guard. Require previous eight saved curves and existing counter blocks to match the accepted 32-case baseline. Record input/source hashes, actual timing and failures. Only after complete acceptance update one row:39/280/104 ->40/279/104. Any required failure leaves coverage unchanged; a major error/new API/numerical policy need triggers discussion. Initialization and HO2 remain suspended. Ignition2/3 are not counted from ignition1's success.


## WSR ignition1 acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L6164) verifies final T>1200 K and the exact first accepted-step midpoint-temperature crossing criterion on both solvers. Target 6/6 plus unchanged nonreacting 235/235 and comparator 5/5; full 33 scenarios 8735/8735, core 1/1. All eight prior saved curves and prior counter blocks remain unchanged. Coverage is **40/279/104**. Ignition2/3 remain separate unverified candidates; initialization and HO2 remain suspended.

## Authorized WSR ignition2 plan (2026-10-30)

Port only pinned TestWellStirredReactorIgnition.test_ignition2, test_reactor.py:1468-1479. Reuse the accepted 24-species/129-reaction raw export (SHA-256 6295aa137d97648dc7fb5edcb2a6d3dd8d70842813fe652f0e6e3a0500f30bad), phase gas, unchanged species/reaction order and six duplicates. The existing WSR/reservoir/flow/valve/network and QNDF accepted-step interfaces already map this case; no additional API exploration or production change is required.

Preserve 900 K, 10 atm, 1 m3 initially N2 vessel and exhaust, pure CH4 fuel at 1 kg/s, O2:N2=1:3.76 oxidizer now at 20 kg/s, valve K=1 kg/(s Pa). Use normal unit reaction multipliers with chemistry and adiabatic energy enabled. Transport remains the source default none; native zeroD does not call it. Integration rtol=1e-9 and atol=1e-15 remain unchanged. Reference max_err_test_fails=10 remains recorded without a mapped QNDF failure-cap claim or maxiters substitution.

Step to the first accepted t>=10 s and retain every post-step t,T,P,Y. Native has a nominal 20-s horizon but stops immediately on the first crossing. No added dtmax, forced landing or interpolation. Require final T>1200 K, set threshold=(first POST-step T+final T)/2, then use the time of the first strictly greater T sample as tIg. The exact gate is abs(tIg-1.4856)<=max(1e-12,1e-3*1.4856), matching source pytest.approx. Missing crossing fails. Preserve the preceding/crossing states, threshold, times, status and actual counters; success does not imply equivalent internal failure protection.

Extend the shared setup to a third mode, leaving the two accepted modes' constants unchanged. Run all three Cantera references and native WSR targets, independently recompute ignition2's source criterion, and require old nonreacting/ignition1 trajectories and counters to match their accepted evidence on each solver. Keep wsr_ignition2 explicit-only until target gates pass. Then run all 34 integration scenarios, five comparator selfchecks and the separate core guard; require all nine prior saved curves and all prior solver-counter blocks unchanged. Retain source/input hashes, timing, exit/return status, complete data and failures. Only full acceptance updates one coverage row:40/279/104 ->41/278/104. Any mandatory failure leaves the row missing; discuss a major error, new API or policy change before proceeding. Ignition3 remains unverified; initialization and HO2 stay suspended.

Ignition2 plan correction after initial target audit: both solvers passed the original assertions, but native's last step was clipped to the 20-s nominal endpoint (previous t=7.454312819227594 s). The initial target data/logs/source checkpoint and audit remain preserved and do not constitute final acceptance. Source step() has no such terminal bound. network_problem requires finite increasing tspan (ReactorNetworks.jl:445-447), so no Inf endpoint or API bypass is used. Correct only ignition2's test nominal horizon to 100 s, keep the stopping condition first t>=10 s, and add a guard that the crossing time is strictly below the nominal endpoint. This changes the test interval representation, not production time-step rules, rtol/atol, dtmax, failure handling or original physical assertions. Re-run all three native targets into a fresh corrected evidence set and independently recheck them. The added no-clipping guard makes ignition2 seven native assertions. Complete regression and coverage update still require every gate; the old two modes retain their previous horizons and must remain bit-identical.


## WSR ignition2 acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L6222) verifies the 1/20 kg/s case and original first accepted-step ignition criterion on both solvers. Native new target 7/7, unchanged nonreacting 235/235 and ignition1 6/6; full 34 scenarios 8742/8742, core 1/1. All nine previous saved curves and all prior counters remain unchanged. Coverage is **41/278/104**. Ignition3 remains unverified; initialization and HO2 remain suspended.

## Authorized WSR ignition3 plan (2026-10-31)

Port pinned TestWellStirredReactorIgnition.test_ignition3 (test_reactor.py:1481-1485) using the accepted, unchanged raw WSR24 fixture, phase gas, 24 species/129 reactions/six duplicates. Existing network and accepted-step interfaces map the case without production changes. Keep 900 K, 10 atm, initially N2 in a 1 m3 adiabatic vessel and exhaust; pure CH4 fuel at 1 kg/s, O2:N2=1:3.76 oxidizer at 80 kg/s, valve K=1 kg/(s Pa), normal unit reaction multipliers. Source transport default is none; native zeroD does not invoke transport.

Use source max_time_step=0.5 s, mapped to existing QNDF dtmax=0.5 only for ignition3. Keep integration rtol=1e-9,atol=1e-15. Step until first accepted t>=100 s; nominal native endpoint 200 s must not clip that crossing. Save every post-step t,T,P,Y. Preserve the original strict final T<910 K assertion without a whole-trajectory ceiling, ignition-delay gate or extra temperature tolerance. Guard progress, running status, finite output, increasing sample times, configured dtmax and endpoint non-clipping; record observed time increments. Cantera max_err_test_fails=10 retains its per-internal-step meaning; no QNDF equivalent or failure-policy equivalence is claimed.

Keep new selector explicit-only until targets pass. Run all four Cantera WSR references and all four native WSR modes. Independently recheck the saved ignition3 final temperature, crossing and timestep configuration; require the three accepted modes' states and counters unchanged on each solver. Then register in all and run 35 integration scenarios, five comparator selfchecks and the separate core guard. Require all ten prior saved curves and previous counter blocks unchanged. Archive input/source hashes, full data, elapsed time, status and available statistics. Only complete acceptance updates this one row:41/278/104 ->42/277/104. Mandatory failure preserves missing status and evidence; discuss a major error, new API or numerical policy need. Initialization and HO2 remain suspended. This case establishes the upstream nonignition assertion, not cross-solver full-trajectory precision or failure-control equivalence.


## WSR ignition3 acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L6282) verifies 1/80 kg/s feeds, the source 0.5-s maximum step, first accepted t>=100 s and strict final T<910 K on both solvers. New target6/6; full35 scenarios 8748/8748, core1/1. The three old WSR modes retain identical states and counters on each solver; all ten prior native curves and prior counter blocks are unchanged. Coverage is **42/277/104**. Initialization and HO2 remain suspended.

## Remaining-case review and authorized connector heat Jacobian plan (2026-10-31)

Baseline:42 covered/277 missing/104 not_applicable;35 accepted integration scenarios,8748 assertions including five comparator selfchecks,core guard1/1. Review is bounded to the remaining inventory, pinned upstream definitions and relevant existing source paths; graph tools are unavailable, so codebase-memory's source-read fallback is used. This is not a claim that all missing rows have been exhaustively proven unsupported.

| Candidate group | Mapping review and decision |
|---|---|
| WSR advance_to_steady_state / solve_steady | Source parameterizes four reactor classes, returns residual history for advance_to_steady_state and uses specific convergence behavior. Existing solve_network_steady returns a terminal state/time and a differently normalized derivative residual. Do not silently substitute it or credit a grouped row from one class. Defer. |
| IdealGasConstPressureReactor heat transfer / mass inflow | Moving-wall branch exists, but the native closed IdealGasReactor explicitly excludes walls and inlet/outlet flow; ReactorNetwork supports constant-volume vessels. Replacing the actual constant-pressure branch with another expanding-wall model would not test the original contrast. Requires a capability decision; defer. |
| Mole-coordinate/surface/nonideal variants and derivative-setting flags | Require individual state/API/parameter mapping. Existing mass-coordinate or ideal-gas checks do not establish those full contracts. The reviewed native RK reactor is constant-volume closed; surface-flow is isothermal and surface-specific. Do not infer complete coverage. |
| Connector heat-transfer temperature cross entries | Recommended: source test_reactor.py:1980-2010 checks only two temperature derivatives and their analytic UA/(m cv) values. Both correspond directly under the existing fixed-volume mass-coordinate network. No missing volume derivative or molecule-index API is asserted by this test. |

Implement only TestConnectorJacobians.test_wall_heat_transfer_cross_reactor_temperature. Reuse the pinned h2o2.yaml/ohmech fixture unchanged (same file/hash/species order on both sides). Initial states:1200 K,one atmosphere,H2:2,O2:1,AR:8 and800 K,one atmosphere,H2:1,O2:1,AR:8. Each volume is the source default1 m3; energy is enabled and all reaction multipliers are zero, with chemistry left enabled. Connect a heat-only wall A=2 m2,U=50 W/(m2 K),K=0, no flows or motion. Record upstream default transport versus the native zeroD path's absence of transport calls.

State mapping: Cantera each node [T,V,n_1,...,n_10], network24 entries; native each node [m_1,...,m_10,T],network22 entries. Cantera0-based T columns0,12 map to native1-based11,22. Perturbing T at fixed species masses and fixed volume is the same partial derivative as at fixed species moles and volume, since m_k=MW_k*n_k is T-independent. Only these two cross-temperature entries are compared; no full-matrix/mole-reactor implementation equivalence is claimed.

Use existing production network_jacobian! unchanged. It is finite-difference based, while Cantera's network jacobian is analytical; the contract being ported is the two observable derivatives, not the algorithm used to construct them. Independently evaluate two centered finite-difference RHS columns in test code using the pinned ReactorNet.cpp:481-508 rule dy=atol+abs(T)*rtol, denominator2*dy, with default1e-9/1e-15. This test-only oracle does not change the production Jacobian policy. Compare each production cross entry to independent FD with source rel=1e-3,abs=1e-10, then to UA/(m cv) with source rel=1e-6,default abs=1e-12. Also check finite matrix and unchanged input state. No integration or artificial trajectory is added.

Save complete initial states, matrix, independent FD columns/perturbations, masses,cv,analytic values, source/input hashes and actual process timings. Solver retcodes/time-step counts are not applicable because this source test does not integrate; do not manufacture zero solver statistics. Cantera reference executes the original four comparisons and records full matrices. Native gets selector connector_heat_jacobian, initially explicit-only, then joins all after both target gates and independent audit pass. Run all35 prior integration scenarios plus this static Jacobian scenario, comparator5/5 and core1/1. Require all11 prior saved curves and existing solver counters unchanged. Only full acceptance updates this one row to43/276/104; failures preserve missing status and evidence. Initialization and HO2 remain suspended. No production API, solver policy or tolerance change is authorized by this plan.

Execution-layer clarification before full acceptance: this static candidate was provisionally layer A while missing. This port deliberately reuses thermal_fixture and the existing optional parity entry, whose dependency/version checks require the fixed example/reactors environment. Therefore its verified execution layer is B; this does not turn the static evaluation into an integration or add it to default runtests/CI. The final one-row update will correct the layer together with the concrete mapping and evidence. Splitting a standalone core runner is outside this small port and is not needed for numerical acceptance.


## Connector heat Jacobian acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1564) verifies all four original cross-temperature assertions on the pinned input. Native target6/6; full35 integration +1 static Jacobian scenarios 8754/8754 including comparator5/5, core1/1. All11 prior curves and prior counters are unchanged. Coverage is **43/276/104**. Initial test-entry placement failure and its repair are retained; no production API, policy or threshold changed. Initialization and HO2 remain suspended.

## Remaining connector review and authorized MFC energy Jacobian plan (2026-11-02)

Baseline:43 covered/276 missing/104 not_applicable;35 integration +1 static Jacobian scenarios,8754 assertions including comparator5/5,core1/1. codebase-memory graph tools remain unavailable; bounded review uses pinned test_reactor.py:1870-2302 and native ReactorNetworks.jl:263-417. No unsupported row is reclassified as not applicable.

| Remaining group | Assessment |
|---|---|
| MFC with energy enabled (2202-2228) | Recommended next. All assertions involve a T-T entry and species-species block. Existing adiabatic mass-coordinate network includes inlet/outlet enthalpy and composition-energy terms; a constant molecular-weight scaling maps every asserted entry. No volume entries need to be invented. |
| Constant MFC, valve and pressure-controller cross blocks | Candidates needing additional review of complete T/V/species columns. Native fixed-volume network has no V state column; pressure-driven cases need explicit moving-volume mapping. Do not silently pad untested columns with zeros. |
| Species-subset MFC | Existing species maps are promising; needs its exact three-species input export and complete coordinate/block verification. Defer to a separate stage. |
| Expansion wall | Moving-wall state exists but includes ledger states and requires a separate complete V-row mapping. Defer. |
| Constant-pressure coupled reactors | Existing closed CP reactor excludes flow/wall coupling; no complete matching CP network route established. Defer capability decision. |
| skip-flow-devices / skip-walls / connector-dependence flags | Existing numerical Jacobian computes all couplings; no matching flags established. Do not add API or derivative strategy here. |

Implement only TestConnectorJacobians.test_mfc_energy_enabled_cross_reactor, pinned commit726522be4e2a13454d8415b7ef799d621f665cf3. Use the existing unchanged h2o2.yaml/ohmech fixture and source species order. Left:1200 K,2 atm,X1=H2:2,H:0.01,O:0.005,O2:1,OH:0.01,H2O:0.05,HO2:0.001,H2O2:0.001,AR:8,N2:0.1. Right:900 K,1 atm,X2=H2:1,H:0.005,O:0.002,O2:0.5,OH:0.005,H2O:0.1,HO2:0.001,H2O2:0.001,AR:8,N2:0.1. Default volume1 m3 each, energy enabled; the chemistry flag remains true but all reaction multipliers are zero, so chemical source terms and their derivatives are zero. This matches upstream _make_h2o2_gas (1887-1891), called at2209-2210 to isolate connector terms, and is not a deviation. Active-chemistry and within-reactor kinetics derivatives are outside this test contract. Constant MFC left->right0.02 kg/s; no walls. Source transport default mixture-averaged is recorded; native zeroD does not invoke transport.

Cantera node coordinates are [T,V,n_k]; native coordinates [m_k,T]. Molecular weights W map m_k=W_k*n_k. For downstream species k/upstream species j, J_n[k,j]=J_m[k,j]*W_j/W_k. The T-T derivative is unchanged. Compare exactly the asserted10x10 species block and T-T entry, not a fabricated24x24 native matrix or untested V derivatives. Native production network_jacobian! remains its existing FD algorithm; Cantera production Jacobian remains analytical. No algorithm-equivalence claim.

Independent test-only centered FD uses fresh network_rhs and the pinned ReactorNet.cpp:481-508 rule. ReactorNet.cpp:233-244 fills base atol, then MoleReactor.cpp:64-75 scales each bulk-species atol by its reactor's total moles. With defaults rtol=1e-9,atol=1e-15, upstream T step is atol+abs(T)*rtol; species j step in kmol is atol*sum(n_up)+abs(n_j)*rtol. Apply +/-W_j*step to native species mass, divide RHS difference by2*step and downstream species output by W_k. These oracle steps do not change production Jacobian or solver tolerances.

Preserve all3 source assertions: abs(J[T_down,T_up])>1e-20; T-T versus independent FD at rel=1e-2,abs=1e-10; every species block entry versus independent FD at rel=1e-2,abs=1e-10. Add only finite-data and unchanged-input guards. Save full native production matrix, mapped blocks, upstream perturbations and RHS outputs, initial states/settings, molecular weights, mass/total moles and complete reference matrices. No time integration or artificial solver statistics are added.

Use a separate selected native fragment to leave the accepted heat test untouched. Both Cantera references and both native static targets must pass, with previous heat results identical. Keep connector_mfc_energy explicit-only until target audit passes, then include it in all. Complete regression is35 integration +2 static Jacobian scenarios (37 total), comparator5/5 pluscore1/1. Require all11 prior trajectories, prior heat data and prior solver counters unchanged. Archive all outcomes, environment/source/input hashes and actual times. Only full acceptance updates this one row to44/275/104, execution layer B matching the existing optional entry. Initialization and HO2 remain suspended. Any required failure preserves missing status; discuss a major error, new API or numerical strategy change before proceeding.


## MFC energy Jacobian acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1753) verifies all3 original assertions, including the entire species block after mass/mole conversion. Native target5/5; full35 integration +2 static Jacobian scenarios 8759/8759 including comparator5/5, core1/1. Both prior heat references/data,11 trajectories and previous counters are unchanged. Coverage is **44/275/104**. An audit variable-shadowing error and its routine repair are archived. No production API, numerical strategy or assertion changes; initialization and HO2 remain suspended.

## Independent maintenance and next-candidate review (2026-11-02)

[Maintenance acceptance](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L2844) adds test-local connector layout guards, WSR no-normalization documentation, and an optional Windows process-deadline/timing wrapper. Affected connector assertions11/11 and saved numerical data match the prior baseline; layout checks8/8, runner checks11/11 and2 real-entry control checks pass. WSR strict reload/four-state equivalence passes. The timing table identifies its historical all37 source; no new full integration run or coverage is claimed. Final adversarial review and remaining runner limitations are recorded.

[Species-subset MFC review and proposed next plan](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L4240) identifies a viable existing explicit-volume-state route, with a required `reactions: none -> []` input-equivalence gate. Original Cantera method and native interface preflight pass after the documented input representation adjustment; complete native derivative assertions are not yet ported. That row remains missing. Coverage stays **44/275/104**; initialization and HO2 remain suspended.

## Authorized species-subset MFC execution plan (2026-11-02)

Execute the linked candidate plan as its own stage. Export pinned upstream_gas with precision17; retain raw and normalized copies, allowing exactly the phase selector `reactions: none -> []`. Require identical parsed species/thermo/other fields, zero reactions and source/raw/normalized four-state equivalence at the pinned roundtrip elementwise rule abs1e-12/rel1e-6. Both formal references and native use the same normalized input; also execute the unmodified original source test. Native loading is a gate before any coverage claim.

Use existing MovingWallNetwork(base; walls=()) with explicit3/10-species layout guards. Evaluate all five upstream columns, including actual V perturbations, using the production Jacobian and a separate source-scaled central FD oracle. Retain all13 source assertions (3 shared nonzero rows,7 downstream-only zero rows,3 shared full-row FD comparisons), with original abs1e-15 and rel1e-4/abs1e-10 criteria. Archive native perturbation inputs/outputs and complete matrices so an independent audit can reconstruct the V column, not infer or pad it.

Run input gates, Cantera original/shared-input references, native subset and both existing connector targets, then full35 integration +3 static Jacobian scenarios via the bounded runner, comparator checks and lightweight/layout checks. Keep new selector explicit-only until targets pass. Require prior11 trajectories/counters and both prior connector data unchanged. Do not rerun the suspended HO2 candidate. Finish with adversarial review including corrupted-input and missing/fabricated V-column evidence checks. Only all gates passing changes this one row to45/274/104; otherwise record failure and keep44/275/104 without changing API, numerical strategy or thresholds.


## Species-subset MFC acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L4094) verifies formal none-to-empty-list input equivalence, all13 original assertions over all5 T/V/species columns, and actual V perturbation propagation. Target16/16; full35 integration +3 static Jacobian scenarios8775/8775 including comparator5/5, core1/1 and layout8/8. Prior11 trajectories, solver counters and both connector results are unchanged. Five adversarial corruptions are rejected. Only this row becomes covered: **45/274/104**. No new production API, numerical policy or relaxed threshold; initialization and HO2 remain suspended.

## Remaining connector review and constant-MFC plan (2026-11-02)

Baseline45/274/104;35 integration +3 static Jacobian scenarios,8775 assertions including comparator5/5, core1/1, layout8/8. Graph tools remain unavailable; bounded review uses pinned TestConnectorJacobians:1870-2285 and native ReactorNetworks.jl:263-360, MovingWallReactors.jl:81-108,135-235.

Choose `test_mfc_const_flow_cross_reactor_species` (1893-1917). Constant flow needs no pressure-feedback derivative, and the existing no-wall MovingWallNetwork provides explicit volume states. Valve/pressure-controller/expansion-wall candidates require separate scrutiny: native isothermal state updates freeze T to its initial value, so one must not assume pressure-sensitive T-column semantics match Cantera merely because volume states exist. Constant-pressure coupling and derivative flags still require capability decisions. No unported row is reclassified as not applicable.

Reuse pinned h2o2.yaml/ohmech without conversion. Both vessels1 m3, energy off, chemistry flag true but every reaction multiplier zero exactly as `_make_h2o2_gas` specifies. Left1000 K/2 atm/X1 and right900 K/1 atm/X2 use the original all-nonzero10-species compositions (1884-1885); MFC0.02 kg/s. Both source and shared-input references retain the source-default transport settings; native zeroD does not invoke transport.

Use existing MovingWallNetwork(base;walls=()). Map native27 coordinates to the24 Cantera physical coordinates [T,V,n_species] per vessel, excluding3 passive ledgers. Evaluate all24 columns with actual perturbations on both vessels, including both volumes. The constant-MFC asserted blocks are independent of T, so the native isothermal T freeze does not remove a nonzero asserted pressure coupling; no equivalence of unasserted self-blocks is claimed. Preserve the original three assertions: downstream10x12 species block versus FD at rel5e-3/abs1e-10; complete reverse12x12 production block zero at abs1e-15; complete reverse12x12 FD block zero at abs1e-10. Do not omit T/V rows in the reverse blocks.

Independent FD follows pinned ReactorNet.cpp:481-508 and MoleReactor.cpp:64-75 with rtol1e-9/atol1e-15, scaling species atol by each vessel's total moles. Map both input and output coordinates by molecular weights. Save all matrices,24 plus/minus states and RHS outputs, volume/pressure propagation, source/input hashes and timings. Initial-layout guards precede index use.

Run original Cantera source method, shared-input reference and native target together with the3 prior connector targets. Initially keep selector `connector_mfc_constant` explicit-only. After target audit, run all35 integration +4 static Jacobian scenarios, comparator and lightweight/layout checks through the bounded runner. Require all11 saved trajectories/counters and all3 prior connector results unchanged. Finish with adversarial missing-volume/reverse-block/threshold checks. Only complete acceptance changes this one row to46/273/104. Failure keeps45/274/104; no new production API, strategy or relaxed criterion. Initialization and HO2 remain suspended.


## Constant-flow MFC Jacobian acceptance

The [complete record](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/11-inventory/arrhenius.patch#L1632) verifies all3 source predicates over the full forward10x12 and reverse12x12 blocks, with all24 actual coordinate probes. Target6/6; full35 integration+4 static Jacobian scenarios8781/8781 including comparator5/5, core1/1 and layout8/8. Prior11 trajectories, counters and3 connector results are unchanged. Six adversarial corruptions are rejected. Only this row changes: **46/273/104**. Initialization and HO2 remain suspended; no new production API, numerical policy or relaxed threshold.


## Single-reaction hydrogen Jacobian acceptance

The [plan, acceptance and adversarial review](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/12-hydrogen-jacobian/arrhenius.patch#L340) preserve the complete three-block contract after one accepted step, with the reactor-level forward FD rule. Native target125/125; full36 integrations +4 static scenarios8906/8906 including comparator5/5; core1/1, layout8/8 and runner11/11. All11 prior trajectories,4 connector records and144 solver-counter records remain identical. Only this row becomes covered: **47/272/104**. The isothermal pressure-sensitive connector mapping gap is tracked in ForgeKinetic #72; initialization #59 and HO2 #60 stay suspended. No API, numerical strategy or tolerance change.


## Constant-pressure single-reaction hydrogen Jacobian acceptance

The [complete plan and adversarial acceptance](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/13-cp-hydrogen/arrhenius.patch#L334) preserve all121 matrix entries, all11 physical perturbations and the full normalization/output-mass chain rule. Cantera original/shared-input and native126/126 pass; full37 integrations +4 static scenarios9032/9032 including comparator5; core1, layout8, runner11. Seven corruptions are rejected; all16 prior numerical records and144 solver-counter records stay identical. Only this row changes: **48/271/104**. #59/#60/#72 remain suspended. No production API, solver policy or threshold changes.

## Isothermal diamond surface regression (2026-11-02)

Only `TestSurfaceKinetics.test_coverages_regression1` is newly covered. The pinned original method and three input roundtrip states pass; native69/69 and full42 scenarios9101/9101 pass with all original profile columns and tolerances. Eight adverse data mutations are rejected; the clean replay preserves the trajectory. Previous17 numeric records and144 counters are unchanged. Coverage is **49/270/104**. See [verification](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/14-surface-coverages/arrhenius.patch#L901). Energy-enabled surface cases, initialization, HO2 and the isothermal connector mapping remain unresolved.

## Fixed-gas Pt surface tolerance pair (2026-11-02)

Only `TestAdvanceCoverages.test_different_tolerances` is newly covered. Original fixture/method and both1-s solves pass; native33/33 and full43 scenarios9134/9134 preserve the original two tolerance pairs and both coverage predicates. Ten adverse-data variants are rejected. Clean outputs/counters match; prior18 records and156 counters are unchanged. Coverage **50/269/104**. See [verification](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/15-surface-tolerances/arrhenius.patch#L3064). Existing suspended issues are unchanged; this is not a failure-limit or cross-solver trajectory test.

## Partial native evidence for nonideal constant-volume ignition

All four Cantera reference variants passed. Julia verified energy conservation and ignition for the native Redlich–Kwong mass-fraction/temperature formulation. The grouped row remains missing. Counts remain **50/269/104**. [Verification](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/16-energy-and-heat/arrhenius.patch#L416).

## Generic Reactor prescribed wall heat flux

The independent `TestReactor.test_heat_flux_func` reference and shared Julia thermal integration verify all five physical predicates. This adds one covered row and reuses one native scenario. Coverage **51/268/104**. [Verification](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/16-energy-and-heat/arrhenius.patch#L270).

## Generic Reactor thermal equilibrium and scaling

Both class-specific Cantera references and the existing native heat-transfer scenarios passed. Coverage **53/266/104**. [Evidence and commands](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/16-energy-and-heat/arrhenius.patch#L363).
