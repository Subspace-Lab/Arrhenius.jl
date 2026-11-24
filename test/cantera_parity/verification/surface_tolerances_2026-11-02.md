# Pt surface tolerance comparison

Status: accepted after original reference, native target, full regression, clean
replay and adversarial audit passed under user authorization.
Upstream: `TestAdvanceCoverages.test_different_tolerances`, L3589, frozen commit
`726522be4e2a13454d8415b7ef799d621f665cf3`.

## Selection and plan

This fixed-gas surface test uses existing `IdealSurface`, `equilibrate(:HP)` and
`solve_surface` capabilities. The other two TestAdvanceCoverages cases require
separate review of failure limits or steady-state stopping criteria. They remain
missing. Energy-enabled surface coupling, initialization, HO2 and the isothermal
connector mapping remain suspended; no numerical rule is changed to complete
this test.

Plan: verify original fixture/method and fixed mechanism inputs; integrate the
native surface from the same reset coverage twice; run full regression, negative
controls and clean checkout; update exactly one coverage row only after all pass.

## Physical and interface mapping

- Pinned ptcombust.yaml gas has32 species and186 reactions; Pt_surf has11 species
  and24 reactions. Raw input imports the already pinned data/gri30.yaml. Species
  and reaction orders are retained in the existing exporter.
- Original fixture starts gas at300 K,101325 Pa, CH4:0.095,O2:0.21,AR:0.79 and
  calls HP equilibrium. Julia independently calls its existing HP solver on the
  same normalized initial composition. The native HP temperature and all32 mole
  fractions are checked against the fixed Cantera input with pytest's default
  elementwise rel1e-6/abs1e-12 rule. This is a setup consistency gate.
- Surface temperature remains900 K. Before each advance the gas temperature is
  reset to900 K and pressure to101325 Pa, retaining the HP-equilibrated gas X.
  Gas composition is fixed during the surface solve, as in Interface.advance_coverages;
  no gas reaction multipliers are changed or reaction definitions removed.
- Both runs start from O(S):0.1,PT(S):0.5,H(S):0.4; all other coverages are zero.
  Julia passes an independent restart state through the existing API. Coverage
  fractions are dimensionless; no volume or gas-mass network is introduced.
- Each run reaches1.0 s. Numerical pairs are exactly `(1e-5,1e-12)` and
  `(1e-7,1e-14)` for rtol/atol. Both results must have11 finite components.
- Original assertions: every loose/tight component satisfies
  `abs(loose-tight)<=max(1e-12,1e-6*abs(tight))`, and at least one component differs
  exactly. No array-norm comparison replaces pytest's elementwise behavior.

## Solver-control boundary

Pinned `interfaces/cython/cantera/kinetics.py:1055` forwards max_step_size=0.0,
max_steps=20000 and max_error_test_failures=7 to InterfaceKinetics.advanceCoverages.
The original method overrides only rtol/atol. These failure controls are not
emulated using QNDF maxiters or changed tolerances.

The existing `example/reactors/surface_solver.jl` requests an initial step
`min(1e-12,span/100)` because adsorption can have much shorter timescales than the
horizon, then lets QNDF adapt. That pre-existing strategy is unchanged, with no
caller dt override. The requested starting step is not necessarily an accepted
step. The test establishes tolerance-pair behavior, not identical time stepping,
error weights, failure limits or solver algorithms.

## Inputs and execution

`fixtures/cantera-726522be/pt_coverages/fixture.toml` records source commit,
mechanism digests, species order, initial and equilibrium gas states, surface T/P
and exported mechanism digests. The gas transport sidecar is not needed and is
excluded. Original ptcombust and GRI30 inputs are checked against the pinned
source. Export uses the existing mechanism/export_surface.py without production
changes. The reference re-executes the original fixture and test method bodies;
only the pytest fixture-registration decorator is removed for direct execution.
A separate reference run captures both results. Exported/original surface forward
and reverse rate constants and net progress rates are checked at two states with
the established Cantera roundtrip rule max(1e-12,1e-6*abs(expected)).

```sh
python test/cantera_parity/reactor_surface_tolerance_reference.py --source-dir "$CANTERA_SOURCE" --output-dir "$NEW_REFERENCE"
python test/cantera_parity/surface_tolerance_audit.py "$NATIVE_TOML" "$REFERENCE_JSON" "$NEW_AUDIT_JSON"
```

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases surface_tolerances -TimeoutSeconds 300 -OutputDirectory <new-output>
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory <another-new-output>
```

To regenerate in a new directory only:
`python test/cantera_parity/export_pt_surface_fixture.py <pinned-source> <new-output>`.
Creation dates affect exported YAML hashes; reproduce acceptance with the
committed files. The preparation replay checks numeric arrays and HP metadata,
not timestamp byte identity. Preserve LF in byte-sensitive fixtures.

## Adversarial review and limits

An independent pytest-based audit checks all11 species, both tolerance pairs,
restart coverage, output times, retcodes and gas-temperature reset. It rejects
identical copied results, major-species excess, trace absolute excess, an omitted
species, wrong species order, changed tolerance, missing initial-state reset,
unfinished time, missing gas-temperature reset and NaN.

The original assertion compares results within each solver. Observed cross-solver
coverage differences are retained as diagnostics, with no new acceptance bound;
this case does not establish complete trajectory accuracy against Cantera.
Native available counters are recorded. The Interface API does not provide a
retcode or solver statistics for these calls; they are marked not provided,
not zero. No full Pkg.test(), fresh-machine install or controlled speed benchmark
is claimed. Installed caches and the pinned dependency lock are reused.

## Observed acceptance

- Native target **33/33**. Full **43 scenarios**, **9134/9134 assertions in44
  testsets**, including comparator5, in **702.421 s**.
- Core1/layout8/runner11 and all10 corruption controls pass.
- Native target process **27.881 s**,
  clean target **37.197 s**, including
  startup/compilation. Verification processes overlapped briefly with the full
  run; these are operational timings, not controlled speed comparisons.
- Both native solves return **Success** at **1.0 s**. Loose run has465 accepted
  and22 rejected steps; tight run877 and32. Full available counters are archived.
- Native maximum error/original bound: **0.000372951909069**.
  The two results are not identical. Observed native/Cantera maximum absolute
  coverage differences are1.3688170153e-8 (loose) and5.5087845396e-10 (tight);
  these are diagnostic observations, not additional acceptance criteria.
- All18 preceding numeric records are byte-identical;156 prior counter records
  match in order. The new record and both runs' counters agree in individual,
  full-suite and clean-checkout runs.
- New record SHA-256: `3c0d72de3d067fff17217e98ee216e2d99d1a87f87269c0c9f1f43abaac80089`.
- Preparation reproduces33 parameter/metadata arrays and the complete HP input
  state; creation-date hashes are excluded from regeneration identity claims.
- Coverage updates exactly one row to **50/269/104**.

Portable evidence accompanies the ForgeKinetic incremental patch under
`tools/zerodim-parity/batches/15-surface-tolerances/evidence`. #59/#60/#72/#75/#76
remain open; no production API, dependency or numerical strategy changed.
