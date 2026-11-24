# User-run verification: disabled chemistry (2026-10-29)

Upstream ID: `test/python/test_reactor.py::TestIdealGasReactor::test_disable_chemistry`.
Inherited definition: `TestReactor.test_disable_chemistry`, fixed Cantera commit
`726522be4e2a13454d8415b7ef799d621f665cf3`.
Native testset: `Cantera parity: TestIdealGasReactor.test_disable_chemistry`,
`test/cantera_parity/reactor.jl`, Layer B (`example/reactors`).

The user executed the environment setup, reference integration, and Julia test,
then supplied the passing outputs in chat. The agent read the saved reference
JSON and transcribed the supplied Julia output; it did not rerun either solve.
This accepts only this effective upstream class/method, not every inherited
reactor variant or the full package suite.

Both runs use the same ten-species `h2o2.yaml`, ideal-gas phase `ohmech`,
1000 K, 101325 Pa, H2:O2 = 2:1, a 1-m3 closed constant-volume adiabatic vessel,
chemistry disabled, and final physical time 11 s. Integration uses nominal
rtol/atol 1e-9/1e-15; result assertions retain the upstream scalar tolerance
max(1e-12, 1e-6*abs(expected)). No solver defaults or production code changed.

| Quantity | Cantera reference | Julia native |
|---|---:|---:|
| Final physical time (s) | 11.0 | 11.0 |
| Temperature (K) | 1000.0 | 1000.0000000000025 |
| H2 mole fraction | 0.6666666666666667 | 0.6666666666666672 |
| O2 mole fraction | 0.3333333333333333 | 0.33333333333333276 |

The common LF-normalized mechanism SHA-256 is
`0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`.
The Cantera record proves version 4.0.0a2, the embedded commit prefix, clean
pinned source, actual Python/extension import paths, Python 3.12.3 and SUNDIALS
7.5.0. Julia's test checks SciMLBase 2.155.2 and OrdinaryDiffEqBDF 1.26.0 before
integration. The exact Julia executable/version and a complete dependency
manifest were not captured in this run evidence; no stronger environment
reproducibility claim is made.

The native summary reports 24.2 s, and the supplied output also includes
precompilation. This is not a warm timing measurement or speedup claim.
Solver counts and a full package-suite result were not collected.

## Preserved Cantera reference record

The content below was read from the user-generated local JSON. Its status
`reference_passed_native_not_verified` is intentionally preserved: that file
was created before the native run. The later native result below completes
acceptance; the original reference record is not rewritten.

```json
{
  "checked_at_utc": "2026-10-29T08:48:35.108927+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_disable_chemistry",
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
    "initial_temperature": 1000.0,
    "initial_pressure": 101325.0,
    "initial_mole_amounts": {
      "H2": 2.0,
      "O2": 1.0
    },
    "volume": 1.0,
    "energy": "adiabatic",
    "chemistry_enabled": false,
    "rtol": 1e-09,
    "atol": 1e-15,
    "assertion_rtol": 1e-06,
    "assertion_atol": 1e-12,
    "actual": {
      "temperature": 1000.0,
      "X_H2": 0.6666666666666667,
      "X_O2": 0.3333333333333333
    },
    "expected": {
      "temperature": 1000.0,
      "X_H2": 0.6666666666666666,
      "X_O2": 0.3333333333333333
    },
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Julia output supplied by the user

```text
Precompiling InverseFunctionsTestExt finished.
  1 dependency successfully precompiled in 3 seconds
Precompiling TestExt finished.
  1 dependency successfully precompiled in 1 seconds
┌ Info: Disabled chemistry: final state
│   time = 11.0
│   temperature = 1000.0000000000025
│   X_H2 = 0.6666666666666672
│   X_O2 = 0.33333333333333276
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                              | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_chemistry |    5      5  24.2s
```
