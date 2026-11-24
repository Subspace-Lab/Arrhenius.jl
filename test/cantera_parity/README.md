# Cantera parity tests and diagnostics

## Zero-dimensional tests (ForgeKinetic issue #5)

The [zeroD coverage inventory](zeroD_coverage.md) maps the frozen Cantera
`test/python/test_reactor.py` and `test/zeroD/test_zeroD.cpp` to native evidence.
The [CSV](zeroD_coverage.csv) records each effective upstream test, source
definition, grouped parameters, status, layer, related native test, and
validation state. A related RHS test does not cover an integration test.

Two execution environments already exist in this repository:

| Layer | Environment / command (from the repository root) | Purpose |
|---|---|---|
| A | `julia --project=. -e 'using Pkg; Pkg.test()'` | Default native tests; no required ODE solver dependency. |
| B | `julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl` | Optional integrations and accompanying static checks using the pinned example solver environment. |

A test does not have to be split into both layers. The integration ports are
Layer B tests in [reactor.jl](reactor.jl) and its selected fragments. That file is not included in
`runtests.jl` and the core package gains no dependency. The new solver-regression
entry point registers the cases below; the pre-existing optional structured/plasma
integration suites retain their own entry points. The lightweight empty-network
guard in [reactor_core.jl](reactor_core.jl) is included in `runtests.jl`; it can
also run alone with `julia --project=. test/cantera_parity/reactor_core.jl`.

Of these new zeroD parity checks, only that lightweight guard is included in
the default test suite run by the current CI workflow. The optional integration
group is not invoked by CI; its coverage relies on the linked explicit runs.

With no argument (or `all`), the entry point runs all verified registered cases.
Append one or more names to run selected cases in one process. The Python reference uses `--case` with the same names,
defaulting to `disable_chemistry` for compatibility with the first run.
Every reference record identifies its selected effective upstream test.

### Bounded Windows runs and timing reports

PowerShell 7 users can run the same Julia entry under an external process deadline:

```powershell
& ./test/cantera_parity/run_solver_regressions.ps1 -Cases @('connector_heat_jacobian','connector_mfc_energy') -TimeoutSeconds 300 -OutputDirectory ./test/cantera_parity/local-results/connectors-new
& ./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 3600 -OutputDirectory ./test/cantera_parity/local-results/all-new
```

Supply the deadline explicitly and choose a fresh output directory. These are
operational examples, not solver defaults: the accepted full process took1226.9 s;
allow for startup, compilation and machine load. A group or `all` keeps its original
single-process ordering and has one shared deadline. For a separate limit per case,
invoke the wrapper separately with one selector and a fresh directory for each.
No internal step, iteration cap, tolerance or physics assertion is changed.
The original `.jl` command remains available without an external timeout.

The wrapper sets one Julia/BLAS thread, restores its caller's environment, and
records stdout/stderr, `process.json`, `report.json`, native results, and
`case_timings.csv`. A timeout terminates the child process tree and exits124;
other unsuccessful runs exit1. Logs and completed summaries survive a timeout.
Cleanup can extend measured wall time beyond the deadline. Testset timings may
include compilation and exclude some startup; they are not controlled benchmarks.
Partial timing rows never establish complete coverage; the report records the
process outcome, and acceptance still checks expected cases and numerical data.

The [37-case timing table](verification/maintenance_guards_2026-11-02/historical_all37_timings.csv)
is extracted from the **previous accepted all37 run**, including the comparator
as a separate row. [Current targeted timings](verification/maintenance_guards_2026-11-02/location_native_target/case_timings.csv)
and [maintenance evidence](verification/maintenance_guards_2026-11-02.md) are separate;
this maintenance does not claim a newly executed full-suite run. Future full-run
records should retain their generated table rather than overwrite old measurements.

Runner control-path checks: `pwsh -File test/cantera_parity/runner_checks.ps1 -OutputDirectory <fresh-directory>`.
Layout negative checks: `julia --project=example/reactors test/cantera_parity/connector_layout_checks.jl`.

### Latest complete regression

Latest accepted run: **35 integration + 4 static Jacobian scenarios, 8781/8781 assertions** including
five comparator selfchecks, plus the separate lightweight guard **1/1**.
Coverage is **46 covered / 273 missing / 104 not_applicable**; see the
[constant-flow MFC acceptance record](verification/connector_mfc_constant_2026-11-02.md).

| Case | Upstream behavior |
|---|---|
| `connector_mfc_constant` | Constant-flow MFC: full forward10x12 and reverse12x12 T/V/species blocks, all24 coordinate probes; preserves all3 original assertions. |
| `connector_species_subset` | Three-species upstream MFC into ten species: full T/V/species cross rows, including actual volume perturbations, preserving all13 original assertions. |
| `connector_mfc_energy` | Static energy-enabled MFC temperature and mole-coordinate species cross derivatives versus independent source-scaled finite differences, preserving all three original assertions. |
| `connector_heat_jacobian` | Static heat-wall cross-temperature derivatives versus independent finite differences and UA/(m cv), preserving all four original assertions. |
| `disable_chemistry` | Disabled chemistry preserves temperature and composition through 11 s. |
| `combustor_step` | Hydrogen combustor with a Gaussian radical pulse: accepted steps through 0.25 s, compared to the pinned full temperature/mole-fraction profile. |
| `combustor_advance` | The same combustor at the original100 output times through0.25 s, using Advance's stricter profile limits. |
| `combustor_invasive` | A mass-flow callback reads the igniter density during integration, then satisfies the same 100-point profile criterion. |
| `wsr_nonreacting` | A 24-species CH4/air vessel with zero reaction multipliers preserves T at every accepted step through the first t>=100 s and reaches Y_CH4=1/6. |
| `wsr_ignition1` | The same 1/5 kg/s feed setup with normal chemistry reaches T>1200 K and the original accepted-step ignition time near 2.2249 s. |
| `wsr_ignition2` | With 1/20 kg/s feeds, final T>1200 K and the original first accepted-step ignition time near 1.4856 s. |
| `wsr_ignition3` | With 1/80 kg/s feeds and maximum step 0.5 s, stop at first accepted t>=100 s and require final T<910 K. |
| `disjoint` | Disconnected O2 vessels retain their separate temperatures and pressures. |
| `disable_energy` | A vessel with disabled energy heats its neighbor through a wall. |
| `heat_transfer1` | Closed vessels reach thermal equilibrium while retaining different pressures. |
| `heat_transfer2` | Matched volume/conductance scaling preserves temperatures and the wall-power law. |
| `heat_flux_func` | Prescribed time-dependent wall flux transfers 18000 J between vessels. |
| `valve1` | Adiabatic valve flow preserves total/species mass and upstream composition. |
| `valve2` | Isothermal valve flow matches the analytical mass solution at 50 sample times. |
| `valve_timing` | A valve opens just after 0.01 s and obeys its pressure/time flow law. |
| `reinitialize` | Reset temperatures at unchanged density and repeat the thermal trajectory. |
| `reservoir_sync` | Preserve vessel state while changing the reservoir from 900 to 700 K. |
| `wall_velocity` | A triangular prescribed velocity produces final volumes 2.2 and 4.8 m3. |
| `equalize_pressure` | A pressure-driven wall equalizes pressure while temperatures differ. |
| `equilibrium_UV` | Constant-volume H2/O2/Ar combustion reaches independently computed UV equilibrium. |
| `equilibrium_HP` | Constant-pressure combustion reaches HP equilibrium at the initial pressure. |
| `set_initial_time` | Fresh equivalent valve networks at t0=0/0.2 agree after 0.5 s. |
| `valve3` | At each accepted step, nonlinear valve flow preserves composition and species mass. |
| `pressure_controller2` | At each accepted step, a custom pressure controller follows the primary and pressure laws. |
| `timestepping` | Initial time and the maximum step are retained and every accepted step respects its bound. |
| `maxsteps` | The expected step-limit failure preserves its last reachable time and configured limit. |
| `tolerances` | Loosening either tolerance reduces the reacting integration's accepted-step count. |
| `derivative` | After advance and one accepted step, the solver derivative agrees with the state/time increment. |
| `advance_reverse` | An already-advanced integrator rejects a backward target time. |
| `finite_difference_jacobian` | At a reacting state, disabled energy/chemistry gives the expected zero Jacobian blocks. |
| `wall_step` | Accepted-step wall motion/heat transfer matches the pinned seven-column profile through the first time >=0.01 s. |
| `wall_advance` | The same wall setup matches the pinned profile at the 199 original advance times. |
| `const_pressure_closed` | Closed constant-pressure chemistry agrees with a rapidly expanding-wall vessel at all 50 original sample times. |
| `zerodim_simple` | The C++ methane/air smoke test completes and preserves T >= 1050 K at its 20 pre-advance samples. |

`invalid_empty_network` is available in the Python reference script; run its
native counterpart through the Layer A command above. Its identical source body
has no reactor-class dependence, so the four inherited coverage rows share one
guard. The HP source body likewise explicitly constructs a constant-pressure
reactor without accessing `self`, so its four inherited rows share one scenario.
Other physics variants are not inferred from a different reactor class's run.

The `mass_flow_controller` pulse candidate has a passing Cantera reference and
a reproducible native species-mass assertion failure. It remains `missing` in
the coverage table and runs **only when explicitly named**, outside `all`:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl mass_flow_controller
```

Do not weaken the upstream comparison tolerances to accept this candidate.

For example, run a selected group with:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl reinitialize reservoir_sync wall_velocity equalize_pressure
```

For the combustor single-step profile, use `combustor_step` with the same entry
point (and `--case combustor_step` with the Python reference). It reuses the
fixed `ohmech` phase and the original `CombustorTest-integrateWithAdvance.csv`.
The source's fuel is H2 despite its stale methane comment. The native loop
stops at the first accepted time >=0.25 s; it does not integrate the unused
0.5 s nominal horizon. Step counts are recorded rather than matched between
solvers. Both temperature and all ten mole fractions use the original Step
profile criterion, including the default time-shift allowance.

Select `combustor_advance` for the original100-time Advance contract. It uses
the same fixture and CSV but its own profile rtol=1e-6, atol=1e-12 and default
xtol=1e-5. The0.0025 s output spacing is not an internal timestep cap. Integration
tolerances remain1e-9/1e-15 for both modes. The native saveat grid is checked
against the exact Float64 times produced by the upstream NumPy linspace.

Select `combustor_invasive` to exercise the existing `f(states,t)` mass-flow
callback with an actual `states.igniter.density` read. It retains the Advance
grid and comparison tolerances and records positive read counts and the observed
boundary density before output diagnostics. At the pinned Cantera 4.0 commit,
reactor phases are cloned by default and the density getter reads its own phase;
the source comment about mutating a shared phase describes an older behavior.
This port covers the pinned callback/query/trajectory contract, without claiming
historical shared-state side effects or a mutable native flow-device setter.

For `wsr_nonreacting`, both sides use the unmodified 24-species, 129-reaction
Cantera export in `fixtures/cantera-726522be/wsr24`. All rate multipliers are
zero while chemistry and adiabatic energy remain enabled. The original test
checks every post-step temperature with rel=1e-5 and final CH4 mass fraction
with pytest defaults rel=1e-6, abs=1e-12. It stops on the first accepted time
at or beyond 100 s, so final times and sample counts can differ between solvers.
Integration tolerances remain 1e-9/1e-15. Cantera's max_err_test_fails=10 is
recorded without claiming an equivalent QNDF failure-control setting.

For `wsr_ignition1`, stop at the first accepted time >=10 s and require final
T>1200 K. The ignition threshold is the mean of the first **post-step** T and
the final T; ignition time is the first accepted sample strictly above it.
Compare that time to 2.2249 s with rel=1e-3 and abs=1e-12. No interpolation,
forced output time or extra maximum-step constraint is used.

`wsr_ignition2` uses the same rule with oxidizer flow 20 kg/s and ignition-time
baseline 1.4856 s (rel=1e-3, abs=1e-12). Its 100-s nominal native horizon is
only a finite solver interval: the loop stops at the first accepted time >=10 s
and asserts that the nominal endpoint did not truncate that step. The initial
20-s-horizon run and the correction are retained in the verification evidence.
`wsr_ignition3` uses normal chemistry, oxidizer flow 80 kg/s and the explicit
upstream maximum time step 0.5 s (native `dtmax=0.5`). Stop on the first accepted
time >=100 s and require final T<910 K, with no added temperature tolerance,
whole-trajectory ceiling or ignition-delay assertion. Its nominal 200-s native
endpoint must not clip the crossing step. Old WSR modes keep their settings.

`connector_heat_jacobian` is a static check in the optional suite, counted
separately from integration scenarios. Its shared fixture/entry point uses the
fixed example environment (execution layer B); it is not added to default CI.
It uses two 1 m3 vessels at 1200/800 K
and one atmosphere, zero reaction multipliers, and a heat-only wall A=2,U=50.
The existing native Jacobian's two cross-temperature entries are checked
against independently evaluated source-formula FD columns (rel=1e-3,abs=1e-10)
and UA/(m cv) (rel=1e-6,abs=1e-12). Fixed species masses and fixed moles define
the same temperature partial here; no full mole-coordinate matrix equivalence
is claimed. No integration is added to this source test.

### First port: `TestIdealGasReactor.test_disable_chemistry`

The inherited [upstream test](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_reactor.py)
sets an ideal-gas constant-volume reactor to 1000 K and one atmosphere, with
`H2:2, O2:1`. It disables chemistry and advances to **11 seconds of physical
time**, then checks `T = 1000 K`, `X_H2 = 2/3`, and `X_O2 = 1/3`. Eleven seconds
is not a wall-clock runtime target.

The Julia port uses an explicitly constant-volume, adiabatic `IdealGasReactor`,
`WellStirredReactor(...; chemistry=false)`, `ReactorNetwork`, and the existing
`native_network_bdf` QNDF adapter. The state is species masses followed by
temperature; the test converts masses to mole fractions for the upstream
assertions. It also checks finite values and arrival at the final time.

Both languages read the same pinned [h2o2.yaml](fixtures/cantera-726522be/h2o2.yaml),
select its `ohmech` ideal-gas phase, and verify its SHA-256 after CRLF-to-LF
normalization. Its ten species include N2; the repository's older, nine-species
`mechanism/h2o2.yaml` is not substituted. [Provenance](fixtures/cantera-726522be/provenance.toml)
records the source commit, Git blob, digest, and tolerances; the original
[Cantera license](fixtures/cantera-726522be/License.txt) accompanies the input.

Nominal integration tolerances are `rtol=1e-9`, `atol=1e-15`, from the pinned
[ReactorNet.h](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/include/cantera/zeroD/ReactorNet.h).
CVODE and QNDF have different coordinates and error norms: equal nominal
tolerances do not imply identical trajectories or solver counts. Result
assertions preserve `pytest.approx`'s default scalar rule,
`abs(actual-expected) <= max(1e-12, 1e-6*abs(expected))`.

### Second port: `TestIdealGasReactor.test_disjoint`

Two disconnected constant-volume, adiabatic reactors contain pure O2 with
chemistry enabled. Left starts at 300 K / 101325 Pa, right at 500 K / 300000 Pa;
both volumes are 1 m3. The reference clones the gas state for each reactor,
puts both in one network without walls or flow devices, and advances to 1 s.
The native port uses two `WellStirredReactor` nodes in one `ReactorNetwork`.

Both ports check the four initial temperatures/pressures as a diagnostic, then
the four upstream final-state assertions. The Julia test also checks arrival
at 1 s and finite state values (10 assertions total). This upstream test writes
`nominal == approx(computed)`; preserve its comparison direction, using
`max(1e-12, 1e-6*abs(computed))`. Chemistry is not disabled to force invariance.
Both sides reuse the pinned mechanism, environment gate, and integration
tolerances from the first port. This case is covered based on the retained
passing reference and the user's confirmation of the Windows native run;
see the [verification record](verification/disjoint_2026-10-29.md). The native
raw log and numeric output were not supplied, which the record distinguishes
from the full stdout retained for the first port.

First run the reference in **WSL** (the absolute interpreter path avoids shell
activation/PATH ambiguity):

```bash
"$HOME/.venvs/cantera-726522be/bin/python" /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case disjoint --source-dir "$HOME/src/cantera-726522be" --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/reactor-disjoint.cantera.json
```

Review `result.initial`, `result.actual`, and the four temperature/pressure
values before continuing. The expected reference status is
`reference_passed_native_not_verified`. If it fails, retain the full error and
diagnose it together; do not weaken tolerances.

After the user accepts the reference, run only the new case in **Windows
PowerShell**, from the repository root:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl disjoint
```

The two languages use the same checkout via Windows and `/mnt/c` paths.
Cross-platform tolerance-based behavior verification is intended here; elapsed
times across the two environments are not a controlled speed comparison.

### Third port: `TestIdealGasReactor.test_disable_energy`

Two pure-O2, constant-volume vessels start at one atmosphere: left at 500 K,
right at 300 K. Only the left energy equation is disabled; chemistry remains
enabled in both. A wall of area 1 m2 and heat-transfer coefficient
2500 W/(m2 K) connects them. At 11 s, the upstream assertions require both
temperatures to be 500 K within `max(1e-12, 1e-6*500)` K.

The native port maps the left energy setting to `energy=:isothermal`, keeps
the right vessel `:adiabatic`, and uses `HeatTransferWall` with the unchanged
network/QNDF adapter. It also checks the initial temperatures, finite state,
and arrival at 11 s. No production numerical policy changes are part of this
test port.

Use `--case disable_energy` with the reference script and append
`disable_energy` to the Julia entry point to run this case alone. Save reference
records under fresh names to retain earlier evidence.

The authorized [agent-run verification](verification/agent_batch_2026-10-29.md)
retains this reference and the complete three-case native log: **21/21**
assertions passed on Julia 1.12.7. Only these three effective ideal-gas methods
are covered; their inherited generic/mole counterparts remain separate rows.

### Thermal batch: `heat_transfer1`, `heat_transfer2`, `heat_flux_func`

All three preserve the complete assertions of their corresponding inherited
`TestIdealGasReactor` methods at the frozen commit. Chemistry and both energy
equations remain enabled, with pure O2 and the same pinned ten-species fixture.

- `heat_transfer1`: two 1-m3 vessels start at 300/1000 K and one atmosphere;
  U=500 W/(m2 K), area=1 m2. At 10 s the temperatures must agree within the
  upstream relative tolerance 5e-7, while the pressures must differ under the
  default approximate comparison. The equilibrium temperature is not assumed
  to be the arithmetic average of the initial temperatures.
- `heat_transfer2`: compare two fresh networks at 1 s: volumes 1/1 m3 with
  U=200 and area=1, versus volumes 0.25/0.25 m3 with U=100 and area=0.5.
  Check both final temperatures agree across configurations and verify
  `U*area*(T_left-T_right)` equals the signed wall heat rate before and after
  the scaled run. Upstream assigns volumes on fresh reactors before network
  initialization; native constructor volumes express the same setup. No
  assertion of a live setter is omitted or claimed by this adaptation.
- `heat_flux_func`: initial temperatures 500/300 K, volumes 0.5/1 m3, area
  0.3 m2, and zero conductance. Prescribe `90000*(1-t^2)` W/m2 until 1 s and
  zero thereafter. At 1.1 s check the final flux, unchanged volumes, and each
  vessel's total internal energy against its initial value minus/plus 18000 J
  with the original 1e-6 relative tolerance. Native diagnostics supply full
  thermodynamic internal energy, rather than an approximation based on `cv*T`.

Each reference uses a fresh output name, for example:

```bash
"$HOME/.venvs/cantera-726522be/bin/python" /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case heat_flux_func --source-dir "$HOME/src/cantera-726522be" --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/heat_flux_func.cantera.json
```

Use the corresponding case name with the native entry point for a single-case
run, or omit it to run all registered regressions. The default `Pkg.test()`
environment remains independent of these optional solver dependencies.

All three reference runs and the full six-case native batch passed; see the
[thermal verification record](verification/thermal_batch_2026-10-29.md) for
the original results, complete **41/41** native log, and executed-source hashes.

### Valve batch: `valve1`, `valve2`, `valve_timing`

The two 1-m3 vessels initially contain gas at 300 K, with pressures 10/1 atm.
The coefficient is K=2e-5. Chemistry stays enabled. These ports retain the
full upstream checks and use the upstream case-specific integration rtol:
1e-12 for `valve1` and `valve_timing`, 1e-11 for `valve2`; atol stays 1e-15.
These are test inputs, not changes to production solver defaults.

- `valve1`: pure Ar flows into pure O2, both energy equations enabled. At 0.1 s,
  check the flow law, total and species mass conservation (species-mass
  comparison atol=1e-10), and unchanged upstream composition. Also retain the
  initial coefficient, energy flags, flow law and outlet/inlet topology checks.
- `valve2`: both vessels contain pure O2 with disabled energy equations. At
  all 50 evenly spaced times from 1e-5 to 0.5 s, compare receiver mass with
  `(m2a-A/B)*exp(-B*t)+A/B`, conserve total mass, and preserve upstream Y.
  A and B are computed from the upstream expressions using initial pressures,
  masses and K. The native solve saves the same sample-time grid.
- `valve_timing`: use Ar/O2, enabled energy, and `time_function(t) = t > 0.01`.
  At 0, 0.01, 0.010000001, and 0.02 s, check activity, pressure-function value,
  and the closed/open flow law. No forced stop or changed timestep schedule is
  introduced at the discontinuity.

Cantera's coefficient and energy settings are assigned before initialization;
native constructors supply the same initial settings. For `valve1`, existing
network flow/endpoint data provide the outlet/inlet views used by the topology
assertion. No public setter, attachment-list API or mid-run mutation support is
added or claimed. Missing tests of such capabilities remain separate rows.

Use `--case valve1` (or the other names) with `reactor_reference.py`; append
the same name to `run_solver_regressions.jl` for a single native test, or run
without a name to execute all registered cases.

All three Cantera references and the full nine-case native suite passed
(**274/274** assertions). The [valve batch record](verification/valve_batch_2026-10-29.md)
retains the 50 reference mass samples, four opening-edge samples, full native
log, runtime provenance and executed-source hashes.

### Restarts, moving walls, equilibrium and nonlinear flow

The [restart/wall record](verification/restart_wall_batch_2026-10-29.md)
retains passing references and 25/25 native integration assertions for
`reinitialize`, `reservoir_sync`, `wall_velocity`, and `equalize_pressure`,
plus the 1/1 lightweight empty-network guard. Resetting an existing native
integrator uses an explicit checkpoint state; changing an immutable reservoir
uses a fresh boundary/network descriptor and the preserved vessel checkpoint.
These are existing native operations, with no live phase-mutation API added.
Moving-wall tests use `MovingWallNetwork` and the existing QNDF adapter with
the upstream rtol=1e-9 / atol=1e-15. Prescribed motion retains the upstream
rel=1e-7 volume assertions. Pressure equalization retains the topology,
pressure-agreement and temperature-difference assertions.

The [equilibrium/time record](verification/equilibrium_batch_2026-10-29.md)
retains 20/20 native assertions for `equilibrium_UV`, `equilibrium_HP` and
`set_initial_time`. H2:1,O2:0.5,AR:8 at 1100 K / 10 atm is integrated to 1 s
and compared with independent native UV/HP equilibrium in T, density,
pressure and each mole fraction. The existing `native_bdf` adapter chooses
its supported structured or ordinary path without test overrides. The time
test starts two fresh equivalent nonlinear-valve integrations at 0 and 0.2 s
and compares their pressures after the same 0.5 s duration (rtol=1e-12).

The [accepted-step flow record](verification/flow_steps_batch_2026-10-29.md)
retains 7505/7505 native assertions for `valve3` and `pressure_controller2`.
The test-only step helper uses the same QNDF function/domain configuration as
the existing network adapter and checks every accepted step until the first
time >=1 s. It uses an unused 2 s horizon so the last step crosses 1 s
normally. Step counts and crossing times differ across solvers and are not
asserted equal. `valve3` retains rtol=1e-12 / atol=1e-20; the pressure
controller retains the default rtol=1e-9 / atol=1e-15.

The [retained pulse failure](verification/pulse_failure_2026-10-29.md)
documents `mass_flow_controller`: Cantera passes, and two native runs reach
2.5 s with the correct injected mass, but HO2 mass is 4.5831e-12 kg against
the original 1e-12 kg absolute threshold. The final assertion remains strict.
The explicit candidate remains outside the verified `all` group following the
user's decision to defer this diagnosis and continue other ports; it is not recorded as covered.

The [18-case group checkpoint](verification/verified_group_2026-10-29.md)
retains the no-argument entry point run: 7824/7824 assertions, plus the separate
1/1 core guard. Full UV/HP mole fractions are also checked against the retained
Cantera outputs at the original comparison precision.

The [time-control record](verification/time_controls_batch_2026-10-29.md)
adds five passing references and 319/319 native assertions. The
[historical Jacobian record](verification/reacting_jacobian_2026-10-29.md)
retains its original 10/10 output with a supersession notice. The
[corrected verification](verification/reacting_jacobian_corrected_2026-10-29.md)
passes 21/21, including T/P/Y/mass/volume checks for both toggles. Native solver derivative/state checks use species-mass/T
coordinates; constant total mass and fixed volume are derived/descriptive
quantities. The Jacobian record documents their correspondence with Cantera's
13-state layout. Expected `MaxIters` in the idle step-limit test is a passing
guard check; it does not equate rejected-step counting across solvers.

The complete 24-case optional group before the wall additions passes **8164/8164** assertions
in one run after the Jacobian fixture correction, including its 21/21 checks.
All cases retain pinned Cantera reference evidence. The separate core guard passes 1/1. This is not
a claim that the full default `Pkg.test()` suite was run. The Jacobian correction restored coverage to 31 rows before the wall additions
because two class-independent source bodies each share four inherited rows.

### TestWall profile regressions

`wall_step` and `wall_advance` preserve the two TestWall methods at the fixed
commit. The air/ohmech chambers and environmental reservoir use the original
initial states, wall directions, K/U/A and enabled chemistry/energy. The
reference retains `ct.Reactor` and explicitly sets `transport_model=None` for
the combustible gas. The shared air YAML and original 199-row CSV have a
separate [input manifest](fixtures/cantera-726522be/wall_provenance.toml).

Step calls QNDF init/step! and stops after the first accepted crossing of
0.01 s. Its 0.1 s problem horizon is unused; no forced time stop is added.
Advance uses the same 199 times as np.linspace(0,0.01,200)[1:]. Both retain
rtol=1e-9 / atol=1e-15 without a ledger tolerance floor. Profile comparisons
faithfully retain upstream compareProfiles, including endpoint clamping and
the joint absolute/relative/coordinate-error criterion. Step comparison uses
rtol=1e-3, atol=1e-8; Advance uses rtol=2e-5, atol=1e-9; xtol=1e-5 is the
source default. Five shared synthetic cases include a curve that must fail.

To retain full native trajectories, set `CANTERA_PARITY_RESULTS` to a fresh
directory before running. Existing per-case CSVs are never overwritten. Without
this variable, the same tests run without writing trajectory files. The
[wall verification record](verification/wall_batch_2026-10-30.md) retains both
reference trajectories, native trajectories and an independent check of the
native data using the original Python comparator. The complete 26-case group passes **8175/8175** assertions (including five
comparator checks), plus the separate core guard 1/1. Both wall rows are covered;
the wall checkpoint inventory is **33 covered / 286 missing / 104 not_applicable**.

### Closed constant-pressure comparison

`const_pressure_closed` ports only
`TestIdealGasConstPressureReactor.test_closed`. Both branches start at 1200 K,
25 atm and `CH4:0.5,H2O:0.2,CO:0.3`, with chemistry and energy enabled. The
moving-wall branch starts at 0.2 m3 and connects to a 900 K / 25 atm pure-H2
reservoir through A=0.1, K=1e3, U=0. The closed constant-pressure branch uses
the existing specific Y/T equations; its initial mass is recorded from the
same initial volume without adding a volume API.

Both branches retain maximum time step 0.05 s and rtol=1e-9 / atol=1e-15.
At all 50 times `0.5,1.5,...,49.5` s, each species Y uses rel=5e-4 / abs=1e-6,
T uses rel=5e-5 / abs=1e-12, and P uses rel=1e-6 / abs=1e-12, preserving the
upstream scalar comparisons. The wall profile CSV and its xtol are not used.

The [shared 18-species fixture](fixtures/cantera-726522be/const_pressure_18/fixture.toml)
retains the legitimate original Cantera export with its explicit skip flag.
The separate normalized input explicitly selects all reactions, disables the
skip flag and removes exactly 14 out-of-phase C2H6 efficiency keys. All 74
reactions, their order, other parameters, species order and six duplicate
markings are preserved. This adapts the input to the existing reader.
The [generator](export_const_pressure_fixture.py) extracts the exact pinned
`gas_def`, resolves that checkout's `gri30.yaml`, exports at precision 17,
records every deletion and refuses an existing output directory. To reproduce
in a fresh directory with the configured WSL environment:

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/export_const_pressure_fixture.py --source-dir /home/subspace/src/cantera-726522be --output-dir /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/const-pressure-regenerate-unique
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --source-dir /home/subspace/src/cantera-726522be --case const_pressure_closed --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/const-pressure-reference-unique.json
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl const_pressure_closed
```

The [four-state input audit](fixtures/cantera-726522be/const_pressure_18/equivalence.json)
retains original/raw-reloaded/normalized-strict snapshots of all forward and
reverse rate constants, net progress/production rates, partial molar enthalpies
and 22 effective third-body concentrations. Its elementwise bound is the
upstream serialization rule `abs(a-b) <= max(1e-12,1e-6*abs(b))`.
The existing Julia reader also loads the normalized 18-species/74-reaction
input. Supporting the full skip option in production is a separate future task.

Cantera's constant-pressure network retains `max_err_test_fails=10`, passed
to `CVodeSetMaxErrTestFails`. It limits local error-test failures while
attempting one internal step. Julia retains existing QNDF behavior; `maxiters`
is not substituted. Trajectory agreement and cumulative failure counts do not
establish equivalent failure protection. Input rejection, solver failure and
completed-trajectory mismatch are recorded separately; unavailable statistics
are identified as unavailable. The
[verification record](verification/const_pressure_closed_2026-10-30.md) retains
full input evidence, reference results, native samples, counters and source hashes.
Set `CANTERA_PARITY_RESULTS` to a fresh directory to save the 50-row native CSV.

The targeted native test passes **255/255** assertions. The complete **27-case** optional
group passes **8430/8430**, including five profile-comparator selfchecks; the
separate core guard passes **1/1**. That checkpoint's inventory totals are **34 covered / 285 missing /
104 not_applicable**. The deferred HO2 pulse candidate remains outside `all`.

### Original C++ `zerodim.simple`

This case uses the pinned **data/gri30.yaml**, phase `gri30`, with 53 species
and 325 reactions. The [input manifest](fixtures/cantera-726522be/gri30_provenance.toml)
records its original Git blob, digest, species order and C++ source hash. The
shared YAML is byte-identical to the source file; the repository's older
mechanism/gri30.yaml is not substituted. No mechanism normalization is performed.

The reference runs the unchanged upstream C++ test, including its explicit
reactor/network initialization. The runner checks the pinned environment and
linked source-tree library, sets CANTERA_DATA to the shared fixture directory,
and requires exactly one executed, passing XML testcase. It does not replace
the C++ program with a Python rewrite. Build and run with the configured WSL
environment, selecting a fresh output filename:

```powershell
wsl -d Ubuntu-24.04 -u subspace --exec /home/subspace/.venvs/cantera-726522be/bin/python -m SCons -C /home/subspace/src/cantera-726522be build-zeroD
wsl -d Ubuntu-24.04 -u subspace --exec /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case zerodim_simple --source-dir /home/subspace/src/cantera-726522be --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/zerodim-simple-reference-unique.json
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl zerodim_simple
```

Both setups use a closed, adiabatic constant-volume vessel at 1050 K, 5 atm,
CH4:O2:N2=1:2:7.52 and volume 1 m3, with enabled chemistry. Cantera explicitly
uses transport model `none`; the Julia zero-dimensional RHS does not call
transport. The source name `simple` maps to the existing network node `:simple`;
this does not add a general reactor-name or initialize API.

The source repeatedly adds 0.005 s to the reported output time. Internal CVODE
steps may overshoot, but advance interpolates back to the requested time. Native
targets preserve sequential Float64 addition, ending at 0.10000000000000002 s.
The maximum internal time step is not set to the sampling interval. Nominal
rtol=1e-9 / atol=1e-15 retain the pinned source defaults and existing QNDF behavior.

The original numerical assertion is **T >= 1050 K** at all 20 pre-advance
states, including the initial state. The final sample has no extra temperature
floor assertion. Native also checks successful completion, finite states and
arrival at every target. This is a combustion smoke regression, not a claim of
trajectory accuracy against Cantera. Set CANTERA_PARITY_RESULTS to a fresh
directory to retain all 21 native rows as `t,T,P,Y[53]`.

The [verification record](verification/zerodim_simple_2026-10-30.md) retains
the original gtest log/XML, build/runtime evidence, native data and the prior
coverage mapping. The original C++ case passes 1/1 and native target 46/46.
The complete **28-case** optional group passes **8476/8476**, including five
comparator selfchecks; the separate core guard passes **1/1**. Totals at that stage
were **35 covered / 284 missing / 104 not_applicable**. The deferred HO2 failure
remains explicit-only and missing.

### Execution and acceptance

The user controls installation and important debug/numerical decisions.
Routine reference and regression runs may be performed by the agent when
authorized, with commands and actual outputs retained. The first port was verified by user-run Cantera and Julia
executions on 2026-10-29; see the retained
[verification record](verification/disable_chemistry_2026-10-29.md).
For new ports, keep the coverage row `missing / not_run` until both reference
and native runs pass under the agreed execution authority and have retained
evidence. Record who executed them; an environment check alone is not acceptance.

1. Follow the staged [WSL Cantera 4.0 setup](WSL_CANTERA4.md). Begin with its
   inventory step; check that output before installing anything.
   The [中文配置经验记录](WSL_CANTERA4_NOTES_zh.md) documents the completed setup,
   the uv PATH issue, and the Doxygen/Jinja2 dependency fix.
2. Run `reactor_reference.py --source-dir <clean-pinned-source> --check-environment`
   with the WSL reference Python. This checks provenance without constructing or
   solving a reactor. Cantera 3.2.0, another 4.0 commit, an unknown embedded
   commit, and tracked source modifications are rejected.
3. Run the same script with `--output <new-record.json>` instead of
   `--check-environment`. This performs the Cantera reference integration and
   writes environment metadata, input digest, actual values, expected values,
   and assertion results. An existing record is not overwritten.
4. Prepare the Julia example environment (in Windows PowerShell, repository root):

   ```powershell
   julia --project=example/reactors -e 'using Pkg; Pkg.instantiate()'
   ```

5. Run the registered integrations through the unified entry point:

   ```powershell
   julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
   ```

   The test requires SciMLBase 2.155.2 and OrdinaryDiffEqBDF 1.26.0, matching the
   existing example environment. It prints the final physical state and
   mechanism digest for each case. No Cantera installation is needed by
   the Julia test itself; its analytical expectations come from the upstream
   setup, so its code can be prepared before the reference environment exists.
6. Compare both outputs and retain the reference record and Julia log. Discuss
   numerical disagreements, major errors, or required production-policy changes
   with the user before proceeding. Update coverage only after passing runs
   under the agreed authority, with the executor and evidence recorded; do not
   infer success from written code.

## Cross-residual tool

`xresid.py` compares native and Cantera residuals at two states and checks the state-transfer round trips. The native subprocess is `xresid_native.jl`; both are kept in this directory. `snapshots/xresid_adapter.py` imports the local `xresid.py`, so no separate checkout or path variable is needed. Python requires NumPy and Cantera 4; Julia resolves Arrhenius from the repository root. `XRESID_JULIA` can optionally select a Julia executable.

Run the compact h2o2 regression from the repository root:

```sh
python test/cantera_parity/xresid_h2o2.py --kinds free
python test/cantera_parity/xresid_h2o2.py
```

The first command is a single-kind smoke check; the second covers free, burner, fixed-temperature, and stagnation flames. For recorded states, run `xresid.py SPEC STATE_A.npz STATE_B.npz` or use the adapter with the same arguments.

The H2/O2 regression rejects incomplete reports and non-finite values before
aggregating round-trip errors or applying its existing numeric limits. Its report
gate tests use only the Python standard library and can run without NumPy,
Cantera, or Julia:

```sh
python -m unittest discover -s test/cantera_parity -p 'test_xresid_gates.py' -v
```

These Python checks are separate from the Julia `Pkg.test()` entry point and
run in their own Linux CI job.

Before reporting aggregates, `xresid.py` checks every non-absent physical
residual maximum, relative residual, and shared-row agreement value for finite,
nonnegative values. It also checks explicit native scales before normalization
(zero is allowed). Invalid data causes exit 2 and, with `--json`, a refusal
report with a diagnostic field path rather than partial aggregates. Structural
`None` entries and the infinity sentinel for a missing equation-type scale
retain their existing meanings; normalization and gate thresholds are unchanged.

## Free flame diffusion gradient basis

`flux_gradient_mass.jl` ports [`TestFreeFlame.test_flux_gradient_mass`](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_onedim.py) from Cantera 4.0.0a2. It runs in `Pkg.test()` with frozen [mechanism and transport data](../data/cantera_flux_gradient_mass/) and needs no Cantera runtime. It solves on a molar gradient basis, then continues the same flame on a mass gradient basis. The speeds must differ by no more than 10% of the mass-basis speed and must be unequal.

Run the single case from the repository root:

```sh
julia --project=. test/cantera_parity/flux_gradient_mass.jl
```

## Free flame at a 180 K inlet

`freeflame_low_temperature.jl` ports [`TestFreeFlame.test_mixture_averaged_case9`](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_onedim.py#L620-L622) from Cantera 4.0.0a2. It runs in `Pkg.test()` using the same frozen [mechanism and transport data](../data/cantera_flux_gradient_mass/). On the fixed nine-point grid, it checks convergence and compares mass flux at every point with the inlet mass flux for each native and recorded reference solution. The 180, 200, and 300 K inlets exercise Newton temperature lower bounds of 175, 195, and 200 K, respectively.

The 180 K case covers both solver modes, CSV initial guesses, and native snapshot restores. A dilute 100 K mixture exercises free- and burner-flame initialization when the equilibrium product temperature is below 200 K. Running the regression requires only Julia.

```sh
julia --project=. test/cantera_parity/freeflame_low_temperature.jl
```

## Burner flame blowoff

`burner_blowoff.jl` ports [`TestBurnerFlame.test_blowoff`](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_onedim.py#L2001) from Cantera 4.0.0a2. It reuses the frozen [10-species mechanism and transport data](../data/cantera_flux_gradient_mass/) and records the Cantera inlet and outlet values. `Pkg.test()` checks the original within-flame endpoint criteria for temperature, velocity, and each species mass fraction for both the recorded reference and the native solution. The test needs no Cantera runtime.

```sh
julia --project=. test/cantera_parity/burner_blowoff.jl
```



Historical full-run timing report: [38 scenarios plus comparator](verification/species_subset_mfc_2026-11-02/all38/case_timings.csv), with [process wall time and outcome](verification/species_subset_mfc_2026-11-02/all38/report.json). Earlier maintenance timing links are historical and remain intact.


Historical full-run timing report: [39 scenarios plus comparator](verification/connector_mfc_constant_2026-11-02/all39/case_timings.csv), with [process wall time and outcome](verification/connector_mfc_constant_2026-11-02/all39/report.json).


## Single-reaction constant-volume hydrogen Jacobian

Selector `hydrogen_single_jacobian` ports `TestReactorJacobians.test_const_volume_hydrogen_single`.
It uses the shared pinned h2o2 phase, only reaction14 enabled, and exactly one
accepted QNDF step. All120 original matrix entries and thresholds are retained;
the oracle uses Reactor's forward FD rule, not ReactorNet's centered rule.
See the [acceptance and reproduction commands](verification/hydrogen_single_jacobian_2026-11-02.md).
`all` at that stage contained40 scenarios (36 integrations +4 static checks), plus comparator
self-checks:8906 assertions in41 testsets. Core/layout/runner checks are separate.
That stage's full-run timings and evidence: [ForgeKinetic delivery](https://github.com/Subspace-Lab/forgekinetic/tree/codex/zerodim-12-hydrogen-jacobian/tools/zerodim-parity/batches/12-hydrogen-jacobian/evidence).
Initialization and HO2 remain excluded/suspended; no production policy changes.


## Constant-pressure single-reaction hydrogen Jacobian

Selector `hydrogen_const_pressure` checks the complete11x11 upstream matrix after
one accepted step. Mapping from native Y/T to Cantera T/n includes both composition
normalization and the derivative of total mass; it is not a diagonal rescaling.
See [acceptance and commands](verification/hydrogen_const_pressure_2026-11-02.md).
At that stage the `all` suite had41 scenarios (37 integrations +4 static checks),9032
assertions including comparator checks,42 testsets. Core/layout/runner checks are
separate. Earlier suite counts in this README describe their historical stages.

## Isothermal diamond surface coverage regression

`surface_coverages` ports `TestSurfaceKinetics.test_coverages_regression1` with
both gas energy equations disabled upstream. All50 samples include T,P,gas mass,
four gas X and eight coverages, compared against the pinned original CSV using
rtol1e-5/atol1e-9/xtol1e-12. No surface-energy capability is implied.

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases surface_coverages -TimeoutSeconds 300 -OutputDirectory <new-output>
```

The reference is `reactor_surface_reference.py --source-dir <pinned-source>
--output-dir <new-output>` in the pinned Cantera environment.
`surface_coverage_audit.py <source> <diamond-fixture-dir> <native.csv> <new-audit.json>`
independently applies the original comparator and eight negative controls.
The [acceptance record](verification/surface_coverages_2026-11-02.md) documents
inputs, preparation, state mapping and limits. Fixed byte-sensitive inputs require
LF-preserving checkouts. At that stage the optional suite had **42 scenarios** (38 integration
scenarios +4 static checks), plus comparator5: **9101 assertions in43 testsets**.
Core1/layout8/runner11 are separate. Coverage **49/270/104**.

## Fixed-gas Pt surface tolerance comparison

`surface_tolerances` ports `TestAdvanceCoverages.test_different_tolerances`.
Existing HP equilibrium prepares the fixed gas composition. Two independent1-s
surface integrations use the original `(rtol,atol)` pairs `(1e-5,1e-12)` and
`(1e-7,1e-14)`, with the same initial coverage and gas-temperature reset.
All11 components must satisfy pytest's default elementwise approx rule, and
the results must not be exactly identical. The existing surface adapter's
initial-step policy is unchanged; failure controls are not claimed equivalent.

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases surface_tolerances -TimeoutSeconds 300 -OutputDirectory <new-output>
```

Use `reactor_surface_tolerance_reference.py --source-dir <pinned-source>
--output-dir <new-output>` for Cantera, and `surface_tolerance_audit.py
<native.toml> <reference.json> <new-audit.json>` for independent checks.
See [acceptance and limits](verification/surface_tolerances_2026-11-02.md).
Current optional suite: **43 scenarios** (39 integration scenarios +4 static
checks), plus comparator5: **9134 assertions in44 testsets**. Core1/layout8/runner11
are separate. Coverage **50/269/104**; all previously suspended cases stay open.

## Nonideal constant-volume ignition

Run `rk_cv_ignition` for the Redlich–Kwong hydrogen-air energy check. The case compares total internal energy at every accepted step and requires a final temperature rise above 500 K. See the [reproduction commands, limits and results](verification/rk_cv_ignition_2026-11-02.md). The local optional suite now has 44 scenarios.

The Julia selector `heat_flux_func` also covers the prescribed-heat-flux case for the generic Cantera Reactor on the ideal-gas phase. Select `--case reactor_heat_flux_func` in the Python reference runner for that class. [Commands, measured balances and coverage scope](verification/reactor_heat_flux_2026-11-02.md).

The generic Cantera selectors `reactor_heat_transfer1` and `reactor_heat_transfer2` share the native Julia selectors `heat_transfer1` and `heat_transfer2`. [Reproduction, physical predicates and results](verification/reactor_thermal_pair_2026-11-02.md).
