# ZeroD nonlinear flow accepted-step verification (2026-10-29)

The agent executed these two references and native integrations under the user's authorization. All exited 0; native assertions: valve3 5487/5487, pressure_controller2 2018/2018, total 7505/7505. Only the TestIdealGasReactor effective rows are covered.

## Scenarios and stepping contract

- `test_valve3` (source line 768): two 1-m3, 300 K adiabatic vessels initially containing Ar:0.5,O2:0.5 at 10 atm and pure O2 at 1 atm. A unit-coefficient valve uses mdot(dp)=5e-3*sqrt(dp) for dp>0, else zero. Integrate at rtol=1e-12, atol=1e-20. At every accepted step until the first time >=1 s, check flow law, unchanged upstream mass fractions and conserved total Ar/O2 masses. Chemistry remains enabled.
- `test_pressure_controller2` (line 881): O2 vessel at 300 K and 1 atm with H2 inlet reservoir at 500 K, 2 atm and H2 outlet reservoir at 300 K, 1 atm. The primary mass-flow rate is exp(-100*(t-0.5)^2); controller pressure function is 1e-5*sqrt(abs(dp)), coefficient 1. At every accepted step through the first time >=1 s, check primary and controller flow laws. Integration uses the upstream defaults rtol=1e-9, atol=1e-15.

The test-only step helper uses the existing network problem, ODEFunction, domain check and QNDF configuration. It calls SciMLBase.init/step! rather than replacing the upstream per-step assertions with endpoint samples. Its unused 2 s problem horizon permits the first accepted step crossing 1 s without forcing a stop at 1 s. No solver step schedule, convergence rule, Jacobian, production adapter or public API was changed. Additional finite-state and progress guards prevent a failed/stalled solve from being reported as coverage. Comparisons use upstream pytest scalar/elementwise rel=1e-6, abs=1e-12, including the original comparison direction for valve3 upstream composition.

## Observed execution

| Case | Cantera accepted steps | Native accepted steps | Cantera last time | Native last time |
|---|---:|---:|---:|---:|
| valve3 | 827 | 1097 | 1.0007434839776321 | 1.0001860234290827 |
| pressure_controller2 | 901 | 672 | 1.0239047088546571 | 1.0006374603467523 |

Step counts and last times differ because the integrations stop after their own first accepted step crossing 1 s. Final states at those different times are not asserted equal across solvers. Each solver passes the complete upstream flow/conservation assertions at all its accepted steps. Counts are observations, not policy comparison or performance claims. Runtime: WSL Cantera 4.0.0a2 at 726522be4e2a13454d8415b7ef799d621f665cf3; native Windows Julia 1.12.7 with SciMLBase 2.155.2, OrdinaryDiffEqBDF 1.26.0 and one Julia/OpenBLAS thread. The reference gate checks actual import paths, embedded commit, clean source and the shared pinned mechanism. No full Pkg.test() claim is made.

## Reproduction

Run `reactor_reference.py --case valve3` and `--case pressure_controller2` with the pinned WSL interpreter/source and fresh output paths as documented in the README. Native:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl valve3 pressure_controller2
```

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `f4167bce7cf81209023291008a1d20cd341d616bac954cc6a17e297f9fa22333`
- `test/cantera_parity/reactor_flow_steps.jl`: `890450ee8ec4602933331af3c2e0806247a8d4acced7d51d8a9e5fd684139368`
- `test/cantera_parity/reactor_reference.py`: `e13fd3ad5801236ddf7f04fd26b3e125c7fb7161b4e9e121e9f5d11dc2eb2de5`
- `test/cantera_parity/run_solver_regressions.jl`: `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609`

## Cantera record: valve3

```json
{
  "checked_at_utc": "2026-10-29T12:04:26.574575+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_valve3",
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
    "time": 1.0007434839776321,
    "accepted_steps": 827,
    "initial_upstream_mass_fractions": [
      0.0,
      0.0,
      0.0,
      0.4447378662367265,
      0.0,
      0.0,
      0.0,
      0.0,
      0.5552621337632735,
      0.0
    ],
    "conserved_species": [
      "AR",
      "O2"
    ],
    "initial_species_masses": [
      8.114242086157226,
      7.798934215955711
    ],
    "final_species_masses": [
      8.114242086298264,
      7.798934215814959
    ],
    "final": {
      "left": {
        "mass": 11.05342587289617,
        "temperature": 261.12325751686757,
        "pressure": 667095.3490358335,
        "mass_fractions": [
          -5.4242571118305885e-45,
          1.0671748426451771e-35,
          -2.8921850708101076e-34,
          0.4447378662367265,
          -2.118766223082547e-34,
          -1.3757791102967204e-44,
          -1.0148436472189976e-22,
          2.0578876350024886e-38,
          0.5552621337632735,
          0.0
        ]
      },
      "right": {
        "mass": 4.859750429216789,
        "temperature": 378.6977233734137,
        "pressure": 439492.1854305565,
        "mass_fractions": [
          -2.783676582998861e-30,
          -3.8654051485383304e-23,
          -1.272140233210452e-21,
          0.5932521063559907,
          -1.352290192284217e-21,
          -4.011740916203046e-30,
          4.289494314362878e-21,
          -2.6382459197735826e-31,
          0.40674789364406344,
          0.0
        ]
      },
      "mass_flow_rate": 2.385388666471761
    },
    "valve_coeff": 1.0,
    "rtol": 1e-12,
    "atol": 1e-20,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera record: pressure_controller2

```json
{
  "checked_at_utc": "2026-10-29T12:04:27.324590+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_pressure_controller2",
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
    "time": 1.0239047088546571,
    "accepted_steps": 901,
    "temperature": 556.2158332473022,
    "pressure": 542529.1755290313,
    "mass": 1.2959840195142003,
    "primary_flow": 1.2013029025545993e-12,
    "controller_flow": 0.006642320194695677,
    "pressure_coeff": 1.0,
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
┌ Info: Nonlinear valve accepted steps
│   time = 1.0001860234290827
│   steps = 1097
│   left_P = 667215.6238131989
│   right_P = 439372.5716427661
│   mdot = 2.3866454081536324
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve3 | 5487   5487  53.3s
┌ Info: Custom pressure controller accepted steps
│   time = 1.0006374603467523
│   steps = 672
│   temperature = 556.2412690145393
│   pressure = 542618.6691017642
│   mass = 1.2961385835559003
│   primary_flow = 1.3029740113341781e-11
│   controller_flow = 0.006642993834355817
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                                 | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_pressure_controller2 | 2018   2018  44.5s
```
