# Cross-residual tool

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
python -m unittest discover -s test/cantera_parity -p 'test_*_gates.py' -v
```

These Python checks are separate from the Julia `Pkg.test()` entry point and
run in their own Linux CI job.

`test_extinction_gates.py` covers diffusion and stagnation controls. Before
grading accuracy, both counterflow profile comparators require every temperature
to be finite and each profile's peak to exceed the hotter endpoint by at least
500 K, including the independent adaptive reference in `counterflow_compare.py`.
A refusal report records `physical_validity: false` and the measured rises in
kelvin (`null` for invalid temperature data). The held-out subset requires an
explicit `gates.physical_validity` verdict from the harness. When NumPy is
available the suite also exercises the NPZ command-line comparisons.

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

## Zero-dimensional reactor parity

The default package suite runs the [empty-network guard](reactor_core.jl). The optional runner covers 44 Cantera scenarios using the [reactor example environment](../../example/reactors/Project.toml). Its wall-profile comparator has five self-checks. The [coverage inventory](zeroD_coverage.md) maps these checks to the upstream tests and explains the 53 covered, 266 missing and 104 inapplicable rows in the [CSV](zeroD_coverage.csv).

Run from the repository root with Julia 1.12.7. For the recorded transitive dependency versions, use the [archived environment lock](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/environment/Manifest.toml). The checks use the [frozen Cantera fixtures](fixtures/cantera-726522be/) and require their original bytes. On Windows, use an LF-preserving checkout (`core.autocrlf=false`).

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=example/reactors -e 'using Pkg; Pkg.instantiate()'
julia --threads=1 --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
```

Set `OPENBLAS_NUM_THREADS=1` for single-threaded BLAS. Append one or more selectors in place of `all` to run a subset. The additional explicit selector `mass_flow_controller` reproduces a historical HO2 pulse diagnostic and sits outside the 44-scenario suite. The Python reference scripts use the pinned Cantera build described in the [ForgeKinetic reproduction guide](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/README.md).

On Windows, the PowerShell 7 wrapper accepts a process deadline and a fresh directory for logs, timings and trajectories. Run the connector layout and process-control guards separately.

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory ./test/cantera_parity/local-results/all44
julia --project=example/reactors test/cantera_parity/connector_layout_checks.jl
pwsh -File test/cantera_parity/runner_checks.ps1 -OutputDirectory ./test/cantera_parity/local-results/runner-guards
```

### Case selectors

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
| `hydrogen_single_jacobian` | Compare 120 entries in the constant-volume single-reaction hydrogen Jacobian after one accepted step. |
| `hydrogen_const_pressure` | Compare all 121 entries in the constant-pressure hydrogen Jacobian. |
| `surface_coverages` | Compare 16 gas and diamond-surface quantities at each of 50 sample times. |
| `surface_tolerances` | Compare all 11 Pt surface coverages after two integrations with different tolerances. |
| `rk_cv_ignition` | Check total internal energy at each accepted Redlich–Kwong ignition step and the final temperature rise. |

Historical commands, reference results and timing records for this 44-scenario snapshot are archived with the [ForgeKinetic batch 16 receipt](https://github.com/Subspace-Lab/forgekinetic/blob/04923f0e04e822ff806e104014a970118f8946d2/tools/zerodim-parity/batches/16-energy-and-heat/README.md).
