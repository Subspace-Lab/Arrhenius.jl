# ZeroD time controls and solver guards (2026-10-29)

After the user chose to retain the pulse failure and continue other ports, the agent ran five additional pinned Cantera references and native regressions. All exited 0: 319/319 native assertions. Only the selected TestIdealGasReactor rows are marked covered. No production API or numerical policy was changed.

## Upstream correspondence

- `test_timestepping` (line 177): two disconnected pure-O2 vessels at 300 K / 1 atm, initial time 0.3 s, max timestep 0.07 s. Check stored options and initial time; at every accepted step through the first time >=10 s check increment <=1.0001*0.07 and consistency of the saved time/current integrator time. Native saves accepted steps for this comparison.
- `test_maxsteps` (line 197): the same idle pair, t0=0, max step 1e-7 s, max step/iteration count 10, attempted advance to 1e-4 s. Cantera raises its maximum-timesteps error; the native caller-owned solver returns MaxIters. Check this expected failure, last reachable time <=10*1e-7, and stored limit 10. The expected max-iteration warning is retained. The mapping is this idle guard scenario; it does not equate CVODE accepted-step limits with SciML iteration limits for problems with rejected steps.
- `test_tolerances` (line 259): a 1100 K / 10 atm adiabatic constant-volume vessel with H2:1,O2:0.5,AR:8. Count accepted steps until the first time >=1 s for (rtol,atol)=(1e-10,1e-20), (1e-8,1e-20), and (1e-10,1e-5), retaining stored-tolerance checks. Assert baseline has more steps than either relaxed run, independently within each solver. These are source test inputs, not changes to default tolerances.
- `test_derivative` (line 121): one O2 vessel at 300 K / 1 atm, advance to 1 s, retain the solver derivative, take one accepted step, and compare every native state derivative with its finite state/time increment using pytest rel=1e-6 / abs=1e-12. Native coordinates are species masses and T; Cantera additionally stores constant total mass and volume coordinates. Native mass is derived and fixed volume is a descriptor. This tests the integrated solver derivative, not just an RHS self-check. A target-time stop at 1 s supplies the state at the requested advance time via the existing SciML stepping API; no production step policy changes.
- `test_advance_reverse` (line 472): after advancing the idle vessel to 0.1 s, an attempt to advance to 0.09 s is rejected by the existing SciML step interface with "Cannot step backward". Check the exception and preserved time. This exercises an already-advanced integrator, not just construction of a reversed tspan.

The test-only initializer uses the same ODEFunction, QNDF and domain check as the existing network adapter. Its unused 100 s horizon permits accepted-step loops to cross their target normally; only maxsteps has the attempted 1e-4 s horizon. No forced stop is introduced into the timestepping or tolerance loops. Default rtol=1e-9 / atol=1e-15 is used unless the upstream test specifies otherwise.

## Observed counts and times

| Quantity | Cantera | Native |
|---|---:|---:|
| Timestepping accepted steps | 140 | 142 |
| Timestepping final time (s) | 10.030036649318141 | 10.041100000000021 |
| Largest observed step (s) | 0.07000000000000028 | 0.07000000000000028 |
| Maxsteps last reachable time (s) | 9.034322590648825e-7 | 1e-6 |
| Baseline tolerance steps | 2531 | 2201 |
| Relaxed rtol steps | 1563 | 1111 |
| Relaxed atol steps | 601 | 402 |

Different accepted-step counts/times are recorded, not asserted equal. All original inequalities pass separately. This is targeted optional verification, not a full Pkg.test() run or a speed comparison. Windows Julia 1.12.7 uses the pinned SciMLBase 2.155.2 / OrdinaryDiffEqBDF 1.26.0 environment and one Julia/OpenBLAS thread. Every reference checks actual Cantera import paths, embedded version, clean pinned commit and shared fixture digest.

## Reproduction

Use the pinned WSL interpreter/source and `reactor_reference.py --case <name> --output <fresh-path>` for each listed case. Native:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl timestepping maxsteps tolerances derivative advance_reverse
```

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `3a7d9b8fef960d52ef5bfce62d9a5aeda0d8630f4ddee1170aeeda03ce8bdae3`
- `test/cantera_parity/reactor_time_controls.jl`: `d4674b04becffb1c5ed80b2f0c42f8ea0792c55a525fff3f6a5dc70fba5fa4a3`
- `test/cantera_parity/reactor_reference.py`: `90f139c59b67403a5d74635e3c244cf34048108348c304d40a1626249869d5ca`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`

## Cantera record: timestepping

```json
{
  "checked_at_utc": "2026-10-29T12:17:34.895864+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_timestepping",
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
    "initial_time": 0.3,
    "time": 10.030036649318141,
    "accepted_steps": 140,
    "maximum_observed_step": 0.07000000000000028,
    "max_time_step": 0.07,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: maxsteps

```json
{
  "checked_at_utc": "2026-10-29T12:17:35.541041+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_maxsteps",
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
    "time": 9.034322590648825e-07,
    "max_steps": 10,
    "max_time_step": 1e-07,
    "exception": "\n*******************************************************************************\nCanteraError thrown by CVodesIntegrator::integrate:\nMaximum number of timesteps (10) taken without reaching output time (0.0001).\nCurrent integrator time: 9.034322590648825e-07\n*******************************************************************************\n",
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: tolerances

```json
{
  "checked_at_utc": "2026-10-29T12:17:36.271203+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_tolerances",
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
        "rtol": 1e-10,
        "atol": 1e-20,
        "accepted_steps": 2531,
        "time": 1.9224158240345603
      },
      {
        "rtol": 1e-08,
        "atol": 1e-20,
        "accepted_steps": 1563,
        "time": 2.7184675916799486
      },
      {
        "rtol": 1e-10,
        "atol": 1e-05,
        "accepted_steps": 601,
        "time": 3.8311460292095503
      }
    ],
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: derivative

```json
{
  "checked_at_utc": "2026-10-29T12:17:37.005043+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_derivative",
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
    "initial_time": 1.0,
    "time": 38.09810994278642,
    "derivative": [
      0.0,
      0.0,
      -3.4100868838177417e-71,
      0.0,
      0.0,
      1.4491991649629881e-75,
      -1.4491991649629881e-75,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ],
    "finite_difference": [
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.449199164962988e-75,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ],
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: advance_reverse

```json
{
  "checked_at_utc": "2026-10-29T12:17:37.865063+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_advance_reverse",
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
    "time": 0.1,
    "requested_time": 0.09,
    "exception": "\n*******************************************************************************\nCanteraError thrown by CVodesIntegrator::integrate:\nCannot integrate backwards in time.\nRequested time 0.09 < current time 0.1\n*******************************************************************************\n",
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
┌ Info: Maximum time-step bound
│   time = 10.041100000000021
│   steps = 142
│   maximum_step = 0.07000000000000028
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                         | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_timestepping |  288    288  51.4s
┌ Warning: Verbosity toggle: max_iters 
│  Interrupted. Larger maxiters is needed. If you are using an integrator for non-stiff ODEs or an automatic switching algorithm (the default), you may want to consider using a method for stiff equations. See the solver pages for more details (e.g. https://docs.sciml.ai/DiffEqDocs/stable/solvers/ode_solve/#Stiff-Problems).
└ @ SciMLBase C:\Users\DELL\.julia\packages\SciMLBase\S0d2P\src\integrator_interface.jl:679
┌ Info: Expected maximum-step failure
│   time = 1.0e-6
│   retcode = ReturnCode.MaxIters = 4
│   maxiters = 10
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                     | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_maxsteps |    3      3  4.1s
┌ Info: Tolerance accepted-step count
│   rtol = 1.0e-10
│   atol = 1.0e-20
│   time = 3.4505441290431755
│   steps = 2201
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
┌ Info: Tolerance accepted-step count
│   rtol = 1.0e-8
│   atol = 1.0e-20
│   time = 1.7767248357036127
│   steps = 1111
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
┌ Info: Tolerance accepted-step count
│   rtol = 1.0e-10
│   atol = 1.0e-5
│   time = 3.200609440104045
│   steps = 402
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                       | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_tolerances |   11     11  13.0s
┌ Info: Integrated state derivative
│   initial_time = 1.0
│   time = 9.889
│   derivative = "[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]"
│   finite_difference = "[-4.665351947498029e-54, -2.755024308695573e-35, 4.055234360263129e-43, -2.4979705807743427e-17, 1.501777308886026e-42, 7.743042175185458e-63, 6.608128929283056e-33, 1.7734973525686664e-54, 0.0, 0.0, 3.197402343391159e-14]"
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                       | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_derivative |   13     13  13.4s
┌ Info: Backward advance rejected
│   time = 0.1
│   requested_time = 0.09
│   error = "Cannot step backward."
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                            | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_advance_reverse |    4      4  0.1s
```
