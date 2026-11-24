# ZeroD combustion equilibrium and initial-time verification (2026-10-29)

The agent ran three pinned Cantera references and the corresponding native regressions under the user's authorization. All runs exited 0; native total 20/20 assertions. No production API or numerical policy was changed.

## Complete scenarios

- `TestIdealGasReactor.test_equilibrium_UV` (source line 506): adiabatic constant-volume H2:1,O2:0.5,AR:8 initially at 1100 K and 10 atm, integrated to 1 s. Compare T, density, pressure and every mole fraction against an independently equilibrated initial state at fixed UV.
- `TestReactor.test_equilibrium_HP` (line 527): the same initial state and time, using the source's explicitly constructed IdealGasConstPressureReactor. Compare T, density and every mole fraction against HP equilibrium, and pressure against the initial 10 atm. This body never reads `self` or constructs the current class's reactor. Its four effective inherited rows (TestReactor, TestMoleReactor, TestIdealGasReactor, TestIdealGasMoleReactor) execute the identical HP scenario and share one native/reference pair. No mole-coordinate solver support is inferred.
- `TestIdealGasReactor.test_set_initial_time` (line 938): two fresh Ar/O2 valve networks at 300 K, pressures 10/1 atm, unit coefficient and pressure function 5e-3*sqrt(dp) for dp>0, else zero. Integrate 0..0.5 s and 0.2..0.7 s using rtol=1e-12, atol=1e-15. Check both final times, pressure-function values and matching final vessel pressures. Native tspan start represents the caller-owned integrator's initial time. This test does not reset a previously advanced network.

Both equilibrium cases use rtol=1e-9 and atol=1e-15. The existing `native_bdf` adapter selects its ordinary constant-volume path or its supported structured constant-pressure path automatically. The test does not override that selection. Native `equilibrate` uses its existing defaults. All result comparisons retain upstream rel=1e-6 / abs=1e-12, including elementwise trace-species comparisons, rather than a vector norm. Full native compositions were checked but the logger summarized their values in this run; the raw output is retained as emitted.

## Observed values

| Quantity | Cantera | Native |
|---|---:|---:|
| UV final T (K) | 2671.775056112225 | 2671.7750554913887 |
| UV final P (Pa) | 2342366.277707329 | 2342366.2771420726 |
| UV final density (kg/m3) | 3.937203574206472 | 3.937203574206472 |
| HP final T (K) | 2230.322633348735 | 2230.322633321439 |
| HP final P (Pa) | 1013250.0000000001 | 1013250.0 |
| HP final density (kg/m3) | 2.0473174645509657 | 2.047317464576349 |
| Shifted-time final left P (Pa) | 805367.3496394965 | 805367.3496512682 |
| Shifted-time final right P (Pa) | 290861.8474481917 | 290861.8474506087 |

Both references and native runs pass the original assertions. This is targeted optional regression evidence, not a full Pkg.test() run or a claim of identical solver counts. The common fixture is the pinned 10-species ohmech phase. Every reference passes the clean checkout/import version/module-path/fixture-digest gate. Native runtime is Windows Julia 1.12.7, SciMLBase 2.155.2, OrdinaryDiffEqBDF 1.26.0, one Julia/OpenBLAS thread.

## Reproduction

Use `reactor_reference.py --case equilibrium_UV` (or equilibrium_HP/set_initial_time), the pinned WSL interpreter and source directory documented in the README, and a fresh `--output` path. From the repository root:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl equilibrium_UV equilibrium_HP set_initial_time
```

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `e516b9b48ba67e74c4ce60e8bf3c6f66f82f071dfb871360b4af49baa1a40621`
- `test/cantera_parity/reactor_equilibrium.jl`: `503cdf0678f0b3362e031f30b27ec5cd24e48fb8a6b1726e9ada57e313ea0b38`
- `test/cantera_parity/reactor_reference.py`: `20a398b2c79bad7b23189c2913687153fe74d4f2ae3d76ea1fe508bef9226f8c`
- `test/cantera_parity/run_solver_regressions.jl`: `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609`

## Cantera record: set_initial_time

```json
{
  "checked_at_utc": "2026-10-29T11:58:07.278265+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_set_initial_time",
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
    "runs": [
      {
        "initial_time": 0.0,
        "time": 0.5,
        "left_pressure": 805367.3496394919,
        "right_pressure": 290861.8474481946,
        "pressure_function": 3.586451945137761
      },
      {
        "initial_time": 0.2,
        "time": 0.7,
        "left_pressure": 805367.3496394965,
        "right_pressure": 290861.8474481917,
        "pressure_function": 3.5864519451377874
      }
    ],
    "rtol": 1e-12,
    "atol": 1e-15,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: equilibrium_UV

```json
{
  "checked_at_utc": "2026-10-29T11:58:05.641518+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_equilibrium_UV",
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
    "mode": "UV",
    "species_names": [
      "H2",
      "H",
      "O",
      "O2",
      "OH",
      "H2O",
      "HO2",
      "H2O2",
      "AR",
      "N2"
    ],
    "temperature": 2671.775056112225,
    "pressure": 2342366.277707329,
    "density": 3.937203574206472,
    "mole_fractions": [
      0.005955200762004956,
      0.0008194980240754973,
      0.00030849783649933077,
      0.002150633216140749,
      0.0035052447288699013,
      0.10247894514417069,
      1.5560283197566257e-06,
      2.2909836613750493e-07,
      0.8847801951615529,
      0.0
    ],
    "equilibrium_temperature": 2671.7750560287313,
    "equilibrium_pressure": 2342366.277631349,
    "equilibrium_density": 3.937203574206481,
    "equilibrium_mole_fractions": [
      0.00595520076071945,
      0.0008194980237363526,
      0.0003084978363616043,
      0.0021506332157017866,
      0.0035052447279553234,
      0.1024789451462347,
      1.5560283192253602e-06,
      2.290983660789212e-07,
      0.8847801951626054,
      0.0
    ],
    "rtol": 1e-09,
    "atol": 1e-15,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: equilibrium_HP

```json
{
  "checked_at_utc": "2026-10-29T11:58:06.401495+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_equilibrium_HP",
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
    "mode": "HP",
    "species_names": [
      "H2",
      "H",
      "O",
      "O2",
      "OH",
      "H2O",
      "HO2",
      "H2O2",
      "AR",
      "N2"
    ],
    "temperature": 2230.322633348735,
    "pressure": 1013250.0000000001,
    "density": 2.0473174645509657,
    "mole_fractions": [
      0.001784457950294567,
      8.918177678368438e-05,
      2.7391612300501042e-05,
      0.0007026392236318139,
      0.0007921830803944202,
      0.10875576377788826,
      1.6892070497490135e-07,
      3.3857879369679796e-08,
      0.8878481798001224,
      0.0
    ],
    "equilibrium_temperature": 2230.3226333482426,
    "equilibrium_pressure": 1013250.0000000201,
    "equilibrium_density": 2.0473174645514534,
    "equilibrium_mole_fractions": [
      0.00178445795029003,
      8.918177678296865e-05,
      2.739161230018061e-05,
      0.0007026392236248747,
      0.0007921830803895457,
      0.10875576377790849,
      1.689207049727475e-07,
      3.385787936938246e-08,
      0.8878481798001197,
      0.0
    ],
    "rtol": 1e-09,
    "atol": 1e-15,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Complete native log

```text
Julia version: 1.12.7
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
┌ Info: Shifted initial time
│   initial_time = 0.0
│   time = 0.5
│   left_P = 805367.3496415046
│   right_P = 290861.8474737569
│   pressure_function = 3.5864519450556833
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
┌ Info: Shifted initial time
│   initial_time = 0.2
│   time = 0.7
│   left_P = 805367.3496512682
│   right_P = 290861.8474506087
│   pressure_function = 3.586451945170392
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                             | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_set_initial_time |    8      8  53.8s
┌ Info: Reactive equilibrium
│   mode = :UV
│   time = 1.0
│   temperature = 2671.7750554913887
│   pressure = 2.3423662771420726e6
│   density = 3.937203574206472
│   mole_fractions = 10-element Vector{Float64}: …
│   equilibrium_T = 2671.7750560287313
│   equilibrium_P = 2.3423662776313433e6
│   equilibrium_rho = 3.937203574206473
│   equilibrium_X = 10-element Vector{Float64}: …
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_equilibrium_UV |    6      6  23.8s
┌ Info: Reactive equilibrium
│   mode = :HP
│   time = 1.0
│   temperature = 2230.322633321439
│   pressure = 1.01325e6
│   density = 2.047317464576349
│   mole_fractions = 10-element Vector{Float64}: …
│   equilibrium_T = 2230.3226333482557
│   equilibrium_P = 1.01325e6
│   equilibrium_rho = 2.047317464551403
│   equilibrium_X = 10-element Vector{Float64}: …
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_equilibrium_HP |    6      6  11.4s
```
