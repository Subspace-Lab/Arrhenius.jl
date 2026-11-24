# ZeroD restart, reservoir and moving-wall verification (2026-10-29)

The agent executed these runs under the user's authorization to continue existing-capability zeroD ports. All five pinned Cantera references and the native runs exited 0. No production API, solver default, tolerance, or numerical policy was changed.

## Scenarios and assertion correspondence

- `TestIdealGasReactor.test_reinitialize` (source line 973): pure O2 at 300/1000 K, 1 atm, two 1-m3 vessels, U=200 W/(m2 K), A=1. Integrate to 1 s, reset both temperatures at unchanged density, then integrate 1..2 s; check reset temperatures and repetition of the first temperature trajectory. Native explicit checkpoint restart supplies `initial_state`; it is the counterpart of upstream phase update/syncState without a live phase-mutation API. 6/6 native assertions.
- `TestIdealGasReactor.test_reservoir_sync` (line 1005): O2 vessel initially 800 K, reservoir 900 K, U=500. After 1 s check 872.099 K (rel=1e-3), update the reservoir to 700 K, continue to 2 s and check 747.27 K (rel=1e-3). The native reservoir descriptor is reconstructed and the vessel checkpoint is preserved when restarting. 4/4 assertions. This does not claim support for mutating an existing reservoir object.
- `TestIdealGasReactor.test_wall_velocity` (line 551): two O2 vessels at 300 K, 1 atm, volumes 2 and 5 m3, A=0.2; triangular tabulated velocity at t=[0,1,2] with v=[0,1,0]. Check velocity and volume rate at 1 s, zero final rate, and final volumes 2.2/4.8 m3 with upstream rel=1e-7. No forced stop at the kink or change of step schedule. 7/7 assertions.
- `TestIdealGasReactor.test_equalize_pressure` (line 243): 300 K pure O2 at 101325/300000 Pa, two 1-m3 vessels, A=1, K=0.1. Check the same attached wall on both vessels; at 1 s pressures agree and temperatures differ. 8/8 assertions.
- `TestReactor.test_invalid_empty_network` (line 1037): reject construction of an empty reactor network. This exact source body contains no `self` access or reactor-class construction. The four effective rows inherited by TestReactor, TestMoleReactor, TestIdealGasReactor and TestIdealGasMoleReactor therefore share one reference and one native guard test. Native ArgumentError corresponds to CanteraError containing "No reactors in network". 1/1 Layer A assertion, now included in default `test/runtests.jl`.

The four integration cases use rtol=1e-9 and atol=1e-15. Unless explicitly given above, comparisons use pytest's elementwise/scalar rel=1e-6 and abs=1e-12. Layer B new-case total: 25/25; Layer A: 1/1. Only the four selected IdealGasReactor physics variants are marked covered; inherited variants are not inferred from them. Four empty-network rows are explicitly shared for the class-independent reason above.

## Observed values

| Quantity | Cantera | Native |
|---|---:|---:|
| Restart first left T (K) | 407.6579442508551 | 407.6579430379587 |
| Restart second left T (K) | 407.6579442508553 | 407.6579461928992 |
| Heated vessel T (K) | 872.0994170502887 | 872.0994121452943 |
| Cooled vessel T (K) | 747.2737643266164 | 747.2737647120872 |
| Prescribed wall final left V (m3) | 2.1999999914087036 | 2.200000000548469 |
| Pressure equilibrium left P (Pa) | 193110.7074200597 | 193110.7014002654 |

The existing QNDF adapter emitted its initial-timestep-near-epsilon fallback warning in the pressure equalization run and completed successfully. Its fallback remains unchanged. No solver-count or performance equivalence is claimed; timings include compilation. This is targeted Layer A/B verification, not a full Pkg.test() run.

## Reproduction

From the repository root, repeat each reference with a fresh output filename and `--case reinitialize`, `reservoir_sync`, `wall_velocity`, `equalize_pressure`, or `invalid_empty_network`:

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case reinitialize --source-dir /home/subspace/src/cantera-726522be --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/reinitialize.cantera.fresh.json
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl reinitialize reservoir_sync wall_velocity equalize_pressure
julia --project=. test/cantera_parity/reactor_core.jl
```

Native runs used Windows Julia 1.12.7, SciMLBase 2.155.2, OrdinaryDiffEqBDF 1.26.0 and one Julia/OpenBLAS thread. Every reference retained below passed the clean source commit, embedded version, actual import-path and shared-mechanism digest gate. The common source commit is `726522be4e2a13454d8415b7ef799d621f665cf3`.

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `686bd56305473acbec43efab4ab13d07dc1085b5d6e658937746c3faf44eb51e`
- `test/cantera_parity/reactor_core.jl`: `b6e52de99528d9e521478de3f82cfd1d44765d3efb7441fcf1d2e602f3d36fad`
- `test/cantera_parity/reactor_reference.py`: `20a398b2c79bad7b23189c2913687153fe74d4f2ae3d76ea1fe508bef9226f8c`
- `test/cantera_parity/run_solver_regressions.jl`: `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609`

## Cantera record: reinitialize

```json
{
  "checked_at_utc": "2026-10-29T11:59:22.818325+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_reinitialize",
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
    "time": 2.0,
    "first_temperatures": [
      407.6579442508551,
      700.733584353149
    ],
    "second_temperatures": [
      407.6579442508553,
      700.7335843531498
    ],
    "reset_temperatures": [
      300.0,
      1000.0
    ],
    "rtol": 1e-09,
    "atol": 1e-15,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: reservoir_sync

```json
{
  "checked_at_utc": "2026-10-29T11:59:23.493224+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_reservoir_sync",
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
    "time": 2.0,
    "first_temperature": 872.0994170502887,
    "second_temperature": 747.2737643266164,
    "reservoir_temperatures": [
      900.0,
      700.0
    ],
    "rtol": 1e-09,
    "atol": 1e-15,
    "temperature_comparison_rtol": 0.001,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: wall_velocity

```json
{
  "checked_at_utc": "2026-10-29T11:59:24.165490+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_wall_velocity",
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
    "time": 2.0,
    "at_one": {
      "velocity": 1.0,
      "expansion_rate": 0.2
    },
    "left_volume": 2.1999999914087036,
    "right_volume": 4.800000008591295,
    "final_expansion_rate": 0.0,
    "rtol": 1e-09,
    "atol": 1e-15,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: equalize_pressure

```json
{
  "checked_at_utc": "2026-10-29T11:59:25.081871+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_equalize_pressure",
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
    "left_pressure": 193110.7074200597,
    "right_pressure": 193110.70742005974,
    "left_temperature": 359.64990816548294,
    "right_temperature": 264.7496583572278,
    "left_volume": 0.6290265211377599,
    "right_volume": 1.3709734788622419,
    "K": 0.1,
    "rtol": 1e-09,
    "atol": 1e-15,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: invalid_empty_network

```json
{
  "checked_at_utc": "2026-10-29T11:59:25.694617+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_invalid_empty_network",
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
    "exception": "CanteraError",
    "message": "\n*******************************************************************************\nCanteraError thrown by ReactorNet::ReactorNet:\nNo reactors in network!\n*******************************************************************************\n",
    "equivalent_upstream_ids": [
      "test/python/test_reactor.py::TestReactor::test_invalid_empty_network",
      "test/python/test_reactor.py::TestMoleReactor::test_invalid_empty_network",
      "test/python/test_reactor.py::TestIdealGasReactor::test_invalid_empty_network",
      "test/python/test_reactor.py::TestIdealGasMoleReactor::test_invalid_empty_network"
    ],
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Native complete integration log

```text
Julia version: 1.12.7
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
┌ Info: Reinitialized thermal network
│   first_left_T = 407.6579430379587
│   first_right_T = 700.7335828671396
│   second_left_T = 407.6579461928992
│   second_right_T = 700.7335764276709
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                         | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_reinitialize |    6      6  55.7s
┌ Info: Updated reservoir boundary
│   first_T = 872.0994121452943
│   second_T = 747.2737647120872
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_reservoir_sync |    4      4  32.4s
┌ Info: Prescribed wall motion
│   left_V = 2.200000000548469
│   right_V = 4.799999999451596
│   rate_at_one = 0.2
│   rate_at_two = 0.0
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                          | Pass  Total     Time
Cantera parity: TestIdealGasReactor.test_wall_velocity |    7      7  1m05.8s
┌ Warning: Verbosity toggle: dt_epsilon 
│  Initial timestep too small (near machine epsilon), using default: dt = 1.0e-6
└ @ OrdinaryDiffEqCore C:\Users\DELL\.julia\packages\OrdinaryDiffEqCore\rnOL4\src\initdt.jl:196
┌ Info: Pressure-driven wall equilibrium
│   left_P = 193110.7014002654
│   right_P = 193110.70140026542
│   left_T = 359.6498986111629
│   right_T = 264.74964954531583
│   left_V = 0.6290265240338347
│   right_V = 1.3709734759660064
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                              | Pass  Total     Time
Cantera parity: TestIdealGasReactor.test_equalize_pressure |    8      8  1m01.7s
```

## Native complete core log

```text
Test Summary:                                          | Pass  Total  Time
Cantera parity: TestReactor.test_invalid_empty_network |    1      1  0.3s
```
