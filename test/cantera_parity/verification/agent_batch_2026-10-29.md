# Authorized agent-run zeroD verification (2026-10-29)

The user authorized routine execution after completing the environment setup,
reserving important numerical decisions and major failures for discussion.
The agent checked the installed reference provenance, added the next simple
zeroD case, and executed the Cantera reference plus the complete native batch.
These results are directly observed runs, not user-output transcriptions.

## Changes and scope

New upstream ID:
`test/python/test_reactor.py::TestIdealGasReactor::test_disable_energy`.
Inherited definition: `TestReactor.test_disable_energy`, source line 574 at
Cantera commit `726522be4e2a13454d8415b7ef799d621f665cf3`.
Native testset: `Cantera parity: TestIdealGasReactor.test_disable_energy`
in `test/cantera_parity/reactor.jl`, Layer B (`example/reactors`).

Pure O2 fills two 1-m3 constant-volume vessels, initially at one atmosphere.
Left starts at 500 K with its energy equation disabled; right starts at 300 K
with its energy equation enabled. Chemistry stays enabled in both. A wall
with area 1 m2 and U=2500 W/(m2 K) transfers heat; both final temperatures must
be 500 K after 11 s within the upstream tolerance of 0.0005 K.

The Julia port selects `energy=:isothermal` on the left and `:adiabatic` on
the right and reuses the existing `HeatTransferWall`/network/QNDF interface.
No production source, solver policy, or tolerance was changed. The two older
cases were rerun together with the new case; their earlier reference and
user-run records were preserved without overwriting them.

## Observed results

| Case | Native assertions | Result |
|---|---:|---|
| `disable_chemistry` | 5/5 | pass |
| `disjoint` | 10/10 | pass |
| `disable_energy` | 6/6 | pass |
| Total | 21/21 | pass |

| New-case final temperature | Cantera (K) | Native (K) |
|---|---:|---:|
| Left | 500.0 | 500.0 |
| Right | 500.0000001175654 | 500.00000009908587 |

The new-case right temperatures differ by about 1.85e-8 K; both pass the
unchanged upstream assertion. This is a three-case correctness result, not a
full `Pkg.test()` result, a performance measurement, or a claim about all
Cantera reactor variants. Reported test times include compilation and must
not be interpreted as a controlled cross-platform speed comparison.

Cantera ran in WSL Ubuntu 24.04 using Python 3.12.3, Cantera 4.0.0a2 and
SUNDIALS 7.5.0. Its embedded commit prefix, clean source HEAD, actual module
paths and the shared LF-normalized input digest were checked before solving.
Native Julia was 1.12.7 on Windows; the raw log identifies the executable
bindir, active local project and Arrhenius checkout. The native test enforces
SciMLBase 2.155.2 / OrdinaryDiffEqBDF 1.26.0. Julia and OpenBLAS used one thread.
The nominal integration tolerances are 1e-9/1e-15. CVODE and QNDF need not have
the same step counts or error norms; no identical-count claim is made.

## Commands

Environment gate, from Windows PowerShell:

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --source-dir /home/subspace/src/cantera-726522be --check-environment
```

Reference (use a fresh output path when repeating):

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case disable_energy --source-dir /home/subspace/src/cantera-726522be --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/reactor-disable-energy.cantera.agent.json
```

Native run (with stdout/stderr retained in `local-results/reactor-batch-20261029.agent-native.log`):

```powershell
$env:JULIA_NUM_THREADS = '1'
$env:OPENBLAS_NUM_THREADS = '1'
julia --project=example/reactors -e 'using Arrhenius, LinearAlgebra; BLAS.set_num_threads(1); println("Julia version: ", VERSION); println("Julia bindir: ", Sys.BINDIR); println("Active project: ", Base.active_project()); println("Arrhenius source: ", pathof(Arrhenius)); include("test/cantera_parity/run_solver_regressions.jl")'
```

Both reference and native commands exited 0. The original reference record's
`reference_passed_native_not_verified` status is preserved below because it
was written before the native run; this combined record completes acceptance.

## New Cantera reference (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T10:52:49.151006+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_disable_energy",
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
    "time": 11.0,
    "initial": {
      "left_temperature": 500.0,
      "right_temperature": 300.0
    },
    "actual": {
      "left_temperature": 500.0,
      "right_temperature": 500.0000001175654
    },
    "expected": {
      "left_temperature": 500.0,
      "right_temperature": 500.0
    },
    "initial_pressure_each": 101325.0,
    "initial_mole_amounts": {
      "O2": 1.0
    },
    "volume_each": 1.0,
    "constraint": "constant_volume",
    "energy_enabled": {
      "left": false,
      "right": true
    },
    "chemistry_enabled": {
      "left": true,
      "right": true
    },
    "wall_area": 1.0,
    "wall_heat_transfer_coeff": 2500.0,
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
Cantera parity: TestIdealGasReactor.test_disable_chemistry |    5      5  23.9s
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
Cantera parity: TestIdealGasReactor.test_disjoint |   10     10  18.6s
┌ Info: Disabled left energy equation: final state
│   time = 11.0
│   left_T = 500.0
│   right_T = 500.00000009908587
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_energy |    6      6  18.6s
```

## Source fingerprints

SHA-256 with CRLF normalized to LF, for the source executed in this batch:

| File | SHA-256 (LF) |
|---|---|
| `reactor.jl` | `b61827e0eb7b6c38b42af5eac8ebbdbaece35080d09a74b655f78db315e2f249` |
| `reactor_reference.py` | `2212ea4074db483396f083062e3e2314129390d83caf3cae159ac74c4f49f066` |
| `run_solver_regressions.jl` | `d294617a495b4252d7201c995f86d2f08feaee5cd06f9221e9ea398b54bbb720` |
