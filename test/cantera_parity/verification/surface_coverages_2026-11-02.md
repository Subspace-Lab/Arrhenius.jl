# Isothermal diamond surface coverage regression

Status: accepted under user authorization after the original reference, native target,
complete regression, clean replay and adversarial checks passed. This record is for
`TestSurfaceKinetics.test_coverages_regression1` at Cantera
`726522be4e2a13454d8415b7ef799d621f665cf3`, definition L2851.

## Selection and scope

The prior Jacobian class is exhausted under existing capabilities (#75/#76).
Other screened groups have different barriers: pressure-controller setter tests
require coefficient mutation; constant-pressure heat/inflow tests need an open or
heated constant-pressure interface; steady-state tests require the upstream
residual/stopping contract. Those are not marked covered by analogous algebra.
The selected surface regression explicitly disables energy, so it matches the
existing `CatalyticNetwork` contract without weakening the original setup.
The energy-enabled surface regression remains missing.

## Mapping and original criteria

- Two distinct gas vessels, each 0.01 m3, isothermal at the original diamond gas
  default 1200 K, pressure 1000 Pa, `H:0.002,H2:1,CH4:0.01,CH3:0.0002`.
- Diamond gas: `[H,H2,CH3,CH4]`, zero homogeneous reactions. Gas chemistry is not
  artificially disabled; the pinned gas phase has no reactions.
- One surface attached to r1 with upstream default area 1 m2, eight surface
  species and 20 reactions; initial coverage indices 0 and 4 are 0.3 and 0.7.
  The diamond bulk phase remains persistent, as supported by the existing model.
- Native state: two `[four gas masses,T]` blocks, eight coverages, one signed bulk
  amount. Layout length 19 and surface offset 11 are checked before slicing.
- Same 50 output times from 1e-6 to 1e-3 s. QNDF uses the existing adapter with
  `rtol=1e-9`, `atol=1e-15`, corresponding to the pinned ReactorNet defaults.
  Output times are sampling points, not an internal maximum step size.
- Initial coverages use the upstream pytest elementwise rule (rel=1e-6,
  abs=1e-12). The curve criterion is the original utilities.py::compareProfiles,
  `rtol=1e-5, atol=1e-9, xtol=1e-12`, over all 16 columns:
  time, T, P, gas mass, four gas mole fractions, eight coverages. The existing
  Julia translation and its five self-checks are reused. An independent audit
  runs the unmodified upstream comparator on the native output.
- Pressure is derived from gas moles, T and fixed gas volume. Gas mass excludes
  surface storage and bulk deposition, matching the original Reactor.mass field.
  Signed bulk inventory is retained in integration but has no extra upstream
  trajectory assertion. No energy-conservation assertion is appropriate for
  this externally thermostatted setup.

## Inputs and reproduction

`fixtures/cantera-726522be/diamond/fixture.toml` pins the original diamond YAML,
original `WallKinetics-coverages-regression1.csv`, exported self-contained phase
YAML, native surface NPZ and gas YAML. Raw YAML and CSV are byte-identical to the
pinned source tree. Existing `mechanism/export_surface.py` supplies the parameters;
no runtime Cantera dependency is added to Julia. Its gas export appends an empty
reaction array for this inert phase. No reaction or species is removed.
The optional gas transport sidecar is not required or included.

The Cantera reference executes the original make_reactors and test method bodies
unchanged, then checks three original/reloaded input states. Species and reaction
orders are retained; forward/reverse rate constants, net rates of progress and
gas partial molar enthalpies use the established Cantera roundtrip elementwise
bound `max(1e-12,1e-6*abs(expected))`. These are input checks separate from the
original curve criterion. All original CSV columns remain mandatory.

Use the pinned Python environment in WSL and a clean source tree:

```sh
python test/cantera_parity/reactor_surface_reference.py --source-dir "$CANTERA_SOURCE" --output-dir "$NEW_REFERENCE"
python test/cantera_parity/surface_coverage_audit.py "$CANTERA_SOURCE" test/cantera_parity/fixtures/cantera-726522be/diamond "$NATIVE_CSV" "$NEW_AUDIT_JSON"
```

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases surface_coverages -TimeoutSeconds 300 -OutputDirectory <new-directory>
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory <another-new-directory>
```

Preparation, only when intentionally regenerating inputs:
`export_surface_fixture.py --source-dir <pinned-source> --output-dir <new-directory>`.
The exporter includes creation dates, so regenerated file bytes are not promised
identical. Reproduction uses the committed inputs and their recorded digests.
New input exports must be revalidated before replacing accepted artifacts.

## Adversarial review

The initial array comparison was corrected to the original elementwise rule;
Julia's array norm comparison is not used. Tolerances and integrated states did
not change. The independent audit rejects eight corruptions: excessive T, P,
gas mass, gas composition, surface coverage, an omitted column, a duplicate
sampling time and a NaN. An unrelated gas transport sidecar was deliberately
excluded from the patch; clean-checkout execution checks that it is not needed.

The native solver uses gas masses/coverages versus the reference's mass and
fractions. Equal rtol/atol values do not imply identical error weights or solver
steps. This acceptance concerns the original profile criterion, not matching
solver internals or energy-enabled surface capability. No full Pkg.test(), clean
machine installation or controlled speed comparison is claimed. #59/#60/#72
remain suspended; #75/#76 remain unresolved.

## Observed acceptance

- Native target: **69/69**, comparator self-checks **5/5** separately.
- Full **42 scenarios**, **9101/9101 assertions in43 testsets**, in **711.894 s**.
- Core1/1, layout8/8 and runner11/11 passed. Eight adverse-data controls rejected.
- Final clean target process: **60.578 s** including loading/compilation.
- Native retcode **Success**, final time **0.001 s**, 493 accepted /15 rejected steps,
  688 RHS evaluations,73 W evaluations,685 linear solves,1 Jacobian construction,
  685 nonlinear iterations and0 nonlinear convergence failures. Raw logs retain
  the other available counters; missing reference integration statistics are **not provided**.
- All17 previously saved native records are byte-identical, with144 earlier logged
  solver-counter records matching in order. Single, clean and full-suite new
  trajectory hashes agree: `18369b2b67b73d63b4de90329e3d3088fb34df3ca351a31c52b3f770aa0c19e6`.
- Coverage changes only this row to **49/270/104**.

The final fresh-checkout run includes the elementwise predicate correction.
The full-suite run includes the new target at the end. The preparation replay
reproduces34 numeric/metadata arrays; only the exported YAML creation-date hash
differs. Installed caches and the existing locked environment were reused.
Full-suite and auxiliary verification processes overlapped briefly; elapsed times
are operational measurements, not performance comparisons.

Portable evidence is delivered with the ForgeKinetic incremental patch under
`tools/zerodim-parity/batches/14-surface-coverages/evidence`.
