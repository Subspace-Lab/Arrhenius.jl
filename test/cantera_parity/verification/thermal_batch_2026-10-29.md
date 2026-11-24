# ZeroD thermal batch verification (2026-10-29)

## Prior-plan audit and selected next scope

The original milestone is complete: the two frozen zeroD source files have a
423-row inventory, the initial full disabled-chemistry port and optional
runner exist, the fixed-input/reference provenance is recorded, and the WSL
reference environment and native tests have retained passing evidence.
The earlier three-case batch passed 21/21 assertions and its executed-source
fingerprints still matched at the beginning of this audit.

This does not complete ForgeKinetic issue #5. The user selected the next scope:
continue quick zeroD tests supported by existing native capabilities. New
production APIs, numerical-policy changes, and significant failures remain
separate decision points. This batch adds three complete inherited
`TestIdealGasReactor` cases, without claiming coverage for other reactor classes.

## Ports and preserved assertions

- `test_heat_transfer1` (upstream line 455): pure O2 vessels initially at
  300/1000 K and one atmosphere, volumes 1 m3, wall U=500 W/(m2 K), A=1 m2.
  Advance to 10 s; check time, temperatures equal within rtol=5e-7, and
  pressures unequal under the default approximate comparison.
- `test_heat_transfer2` (line 479): advance fresh networks to 1 s for
  (V_each,U,A)=(1,200,1) and (0.25,100,0.5). Check the scaled wall's signed
  U*A*(T_left-T_right) law before/after integration and both final temperature
  equalities. Upstream changes volume only on fresh reactors before network
  initialization; native constructor volume preserves that setup. No live
  property-setter assertion was removed or counted as implemented.
- `test_heat_flux_func` (line 595): pure O2 initially at 500/300 K, volumes
  0.5/1 m3, wall A=0.3 m2, U=0. Prescribe 90000*(1-t^2) W/m2 until 1 s, zero
  thereafter. Advance to 1.1 s; check final prescribed flux, unchanged volumes,
  and individual total internal energy changes of -18000/+18000 J at rtol=1e-6.
  Total internal energy comes from native thermodynamic diagnostics, not cv*T.

Chemistry and both energy equations remain enabled. All runs use the same
frozen ten-species h2o2 fixture and ohmech phase. The Cantera source is clean
at 726522be4e2a13454d8415b7ef799d621f665cf3; runtime version/import paths and
input digest appear in each verbatim reference below. Nominal integration
rtol/atol remain 1e-9/1e-15. The upstream result tolerances and assertion
directions are preserved. No production source or numerical policy changed.

## Observed result

| Native case | Assertions | Result |
|---|---:|---|
| disable_chemistry | 5/5 | pass |
| disjoint | 10/10 | pass |
| disable_energy | 6/6 | pass |
| heat_transfer1 | 5/5 | pass |
| heat_transfer2 | 8/8 | pass |
| heat_flux_func | 7/7 | pass |
| Total | 41/41 | pass |

| Selected quantity | Cantera | Native |
|---|---:|---:|
| heat_transfer1 left T (K) | 478.61792288113907 | 478.61792772303863 |
| heat_transfer1 right T (K) | 478.61792326891765 | 478.61792756510783 |
| heat_transfer2 first left T (K) | 407.6579442508551 | 407.6579430379587 |
| heat_transfer2 first right T (K) | 700.733584353149 | 700.7335828671396 |
| heat_flux_func final left U (J) | 5507.414435617845 | 5507.414881225469 |
| heat_flux_func final right U (J) | -81116.83913693417 | -81116.84054108114 |

All three reference commands and the native batch exited 0. Both codes passed
all original within-code invariants and comparisons. Their reported numbers
are close but are not claimed to be bit-identical. The older three native
cases also passed without regression. Test times include compilation and are
not performance measurements; no full-package test or solver-count equality
is claimed. The optional runner remains outside default Pkg.test(), consistent
with the agreed core/example dependency split.

The agent executed these routine checks under the user's existing authority.
Cantera ran in WSL with Python 3.12.3/Cantera 4.0.0a2/SUNDIALS 7.5.0; native
Julia ran on Windows 1.12.7 with SciMLBase 2.155.2 and OrdinaryDiffEqBDF 1.26.0.
Julia and OpenBLAS used one thread. No numerical failure required escalation.

## Reproduction

From Windows PowerShell at the repository root, run one reference at a time
with a fresh output path (replace the case name with the other two as needed):

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case heat_transfer1 --source-dir /home/subspace/src/cantera-726522be --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/heat_transfer1.cantera.agent.json
```

The three original reference statuses below remain
`reference_passed_native_not_verified`, since those records precede the native
batch. This combined verification record completes their acceptance.

Native command used (all six registered cases):

```powershell
$env:JULIA_NUM_THREADS = '1'
$env:OPENBLAS_NUM_THREADS = '1'
julia --project=example/reactors -e 'using Arrhenius, LinearAlgebra; BLAS.set_num_threads(1); println("Julia version: ", VERSION); println("Julia bindir: ", Sys.BINDIR); println("Active project: ", Base.active_project()); println("Arrhenius source: ", pathof(Arrhenius)); include("test/cantera_parity/run_solver_regressions.jl")'
```

Stdout/stderr were retained in
`local-results/reactor-thermal-batch-20261029.agent-native.log` and reproduced
verbatim below. One case can instead be run by appending its name to the
ordinary runner command, for example:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl heat_flux_func
```

## Cantera heat_transfer1 record (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T11:11:51.171947+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_heat_transfer1",
  "cantera_version": "4.0.0a2",
  "cantera_git_commit": "726522be4",
  "source_dir": "/home/subspace/src/cantera-726522be",
  "source_commit": "726522be4e2a13454d8415b7ef799d621f665cf3",
  "source_tracked_clean": true,
  "cantera_module": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/__init__.py",
  "cantera_extension": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/_utils.cpython-312-x86_64-linux-gnu.so",
  "python_executable": "/home/subspace/.venvs/cantera-726522be/bin/python",
  "python_version": "3.12.3",
  "platform": "Linux-6.18.33.2-microsoft-standard-WSL2-x86_64-with-glibc2.39",
  "sundials_version": "7.5.0",
  "mechanism": "/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/fixtures/cantera-726522be/h2o2.yaml",
  "mechanism_sha256_lf": "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4",
  "phase": "ohmech",
  "result": {
    "time": 10.0,
    "actual": {
      "left_temperature": 478.61792288113907,
      "right_temperature": 478.61792326891765,
      "left_pressure": 161653.20345310474,
      "right_pressure": 48495.96107522366
    },
    "initial_temperatures": [
      300.0,
      1000.0
    ],
    "initial_pressure_each": 101325.0,
    "initial_mole_amounts": {
      "O2": 1.0
    },
    "volume_each": 1.0,
    "energy": "adiabatic",
    "chemistry_enabled": true,
    "wall_area": 1.0,
    "wall_heat_transfer_coeff": 500.0,
    "rtol": 1e-09,
    "atol": 1e-15,
    "temperature_comparison_rtol": 5e-07,
    "assertion_rtol": 1e-06,
    "assertion_atol": 1e-12,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera heat_transfer2 record (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T11:11:56.458225+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_heat_transfer2",
  "cantera_version": "4.0.0a2",
  "cantera_git_commit": "726522be4",
  "source_dir": "/home/subspace/src/cantera-726522be",
  "source_commit": "726522be4e2a13454d8415b7ef799d621f665cf3",
  "source_tracked_clean": true,
  "cantera_module": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/__init__.py",
  "cantera_extension": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/_utils.cpython-312-x86_64-linux-gnu.so",
  "python_executable": "/home/subspace/.venvs/cantera-726522be/bin/python",
  "python_version": "3.12.3",
  "platform": "Linux-6.18.33.2-microsoft-standard-WSL2-x86_64-with-glibc2.39",
  "sundials_version": "7.5.0",
  "mechanism": "/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/fixtures/cantera-726522be/h2o2.yaml",
  "mechanism_sha256_lf": "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4",
  "phase": "ohmech",
  "result": {
    "time": 1.0,
    "first": {
      "left_temperature": 407.6579442508551,
      "right_temperature": 700.733584353149
    },
    "scaled": {
      "left_temperature": 407.65794425085534,
      "right_temperature": 700.7335843531492
    },
    "initial_temperatures": [
      300.0,
      1000.0
    ],
    "initial_pressure_each": 101325.0,
    "initial_mole_amounts": {
      "O2": 1.0
    },
    "first_configuration": {
      "volume_each": 1.0,
      "U": 200.0,
      "area": 1.0
    },
    "scaled_configuration": {
      "volume_each": 0.25,
      "U": 100.0,
      "area": 0.5
    },
    "energy": "adiabatic",
    "chemistry_enabled": true,
    "initial_wall_power": -35000.0,
    "final_wall_power": -14653.782005114695,
    "rtol": 1e-09,
    "atol": 1e-15,
    "assertion_rtol": 1e-06,
    "assertion_atol": 1e-12,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera heat_flux_func record (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T11:12:00.406338+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_heat_flux_func",
  "cantera_version": "4.0.0a2",
  "cantera_git_commit": "726522be4",
  "source_dir": "/home/subspace/src/cantera-726522be",
  "source_commit": "726522be4e2a13454d8415b7ef799d621f665cf3",
  "source_tracked_clean": true,
  "cantera_module": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/__init__.py",
  "cantera_extension": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/_utils.cpython-312-x86_64-linux-gnu.so",
  "python_executable": "/home/subspace/.venvs/cantera-726522be/bin/python",
  "python_version": "3.12.3",
  "platform": "Linux-6.18.33.2-microsoft-standard-WSL2-x86_64-with-glibc2.39",
  "sundials_version": "7.5.0",
  "mechanism": "/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/fixtures/cantera-726522be/h2o2.yaml",
  "mechanism_sha256_lf": "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4",
  "phase": "ohmech",
  "result": {
    "time": 1.1,
    "initial": {
      "left_U": 23507.4169159976,
      "right_U": -99116.83835222755,
      "left_volume": 0.5,
      "right_volume": 1.0
    },
    "actual": {
      "left_U": 5507.414435617845,
      "right_U": -81116.83913693417,
      "left_volume": 0.5,
      "right_volume": 1.0
    },
    "transferred_heat": 18000.0,
    "final_heat_flux": 0.0,
    "initial_temperatures": [
      500.0,
      300.0
    ],
    "initial_pressure_each": 101325.0,
    "initial_mole_amounts": {
      "O2": 1.0
    },
    "energy": "adiabatic",
    "chemistry_enabled": true,
    "wall_area": 0.3,
    "rtol": 1e-09,
    "atol": 1e-15,
    "assertion_rtol": 1e-06,
    "assertion_atol": 1e-12,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Native batch log (verbatim)

```text
Julia version: 1.12.7
Julia bindir: C:\Users\DELL\.julia\juliaup\julia-1.12.7+0.x64.w64.mingw32\bin
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
┌ Info: Disabled chemistry: final state
│   time = 11.0
│   temperature = 1000.0000000000025
│   X_H2 = 0.6666666666666672
│   X_O2 = 0.33333333333333276
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                              | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_chemistry |    5      5  38.9s
┌ Info: Disjoint reactors: initial state
│   left_T = 300.0
│   left_P = 101325.00000000001
│   right_T = 500.0
└   right_P = 300000.00000000006
┌ Info: Disjoint reactors: final state
│   time = 1.0
│   left_T = 300.00000000000045
│   left_P = 101325.0000000001
│   right_T = 500.0000000000008
│   right_P = 300000.0000000003
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                     | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disjoint |   10     10  31.2s
┌ Info: Disabled left energy equation: final state
│   time = 11.0
│   left_T = 500.0
│   right_T = 500.00000009908587
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_energy |    6      6  31.3s
┌ Info: Thermal equilibrium: final state
│   time = 10.0
│   left_T = 478.61792772303863
│   right_T = 478.61792756510783
│   left_P = 161653.2050879414
│   right_P = 48495.96151049812
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_heat_transfer1 |    5      5  0.9s
┌ Info: Thermal scaling: final state
│   time = 1.0
│   first_left_T = 407.6579430379587
│   first_right_T = 700.7335828671396
│   scaled_left_T = 407.65794303801124
│   scaled_right_T = 700.7335828659404
│   initial_power = -35000.0
│   final_power = -14653.78199139646
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_heat_transfer2 |    8      8  0.3s
┌ Info: Prescribed heat flux: final state
│   time = 1.1
│   initial_left_U = 23507.416915997623
│   initial_right_U = -99116.8383522275
│   final_left_U = 5507.414881225469
│   final_right_U = -81116.84054108114
│   transferred_heat = 18000.0
│   final_heat_flux = 0.0
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_heat_flux_func |    7      7  31.7s
```

## Executed source fingerprints

SHA-256 with CRLF normalized to LF:

| File | SHA-256 (LF) |
|---|---|
| `reactor.jl` | `846dd29934d60b35ca2b550a67c8179ba398a38b9cb4a2ac08b6662c22680715` |
| `reactor_reference.py` | `a29a5e25fea97634d41cdce1afa0d9bff730e7ea850136b6afbb58ffb2f299fe` |
| `run_solver_regressions.jl` | `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609` |
