# ZeroD mass-flow pulse: retained failure (2026-10-29)

Status: Cantera reference passed; native candidate failed twice at the unchanged upstream species-mass assertion (15 pass / 1 fail / 16 total, exit 1). This row remains **missing**, with `agent_failed` verification, not covered. The candidate is retained under its explicit `mass_flow_controller` selector and excluded from the verified `all` group. No tolerance, chemistry setting, production API or numerical strategy was changed to accept it.

## Complete input and mapping

Upstream `TestIdealGasReactor.test_mass_flow_controller`, source line 621 at Cantera commit 726522be4e2a13454d8415b7ef799d621f665cf3. A 1-m3 pure-O2 vessel starts at 300 K, 1 atm, with enabled energy and chemistry. A pure-H2 reservoir at 300 K, 10 atm supplies mdot(t)=0.2-0.4*abs(t-0.7) for 0.2<=t<1.2, else zero, a triangular pulse of area 0.1 kg. Integrate with rtol=1e-11, atol=1e-15 and maximum step 0.05 s. Check flows at 0.1/0.3/1/1.2 s against 0/0.04/0.08/0 kg/s, then total and species mass at 2.5 s. The species comparison preserves upstream direction and rel=1e-6, abs=1e-12.

Native type checking and existing endpoint views map the upstream type/attachment checks. Native mdot is the complete callback rate with implicit unit coefficient, verified by its peak rate of 0.2 kg/s; no coefficient getter is added. Saveat reproduces the advance sample times and dtmax=0.05 is the upstream test input. No forced stop is added at pulse corners. These mappings are documented despite the failed final species check; no full coverage claim is made.

## Observed failure

- Both native runs reached 2.5 s and injected 0.10000000000557852 kg.
- Final native T=365.3610593944599 K, P=274084.2727407221 Pa, mass=1.3998223693315304 kg. Cantera T=365.36105951310765 K, P=274084.2727743681 Pa, mass=1.399822369315503 kg.
- The diagnostic-only repeat identifies **HO2 mass 4.583077935302556e-12 kg**, expected 0 and allowed absolute error 1e-12 kg. The difference is about 4.58 times that limit. Other species pass the same comparison.
- Cantera's HO2 final mass is approximately 1.83e-18 kg and satisfies the original absolute threshold.

Cause is not established. This observation alone does not justify changing trace-species handling, Jacobians, solver choice or tolerances. Those would require discussion and, for numerical policies, the repository's separate prediction/baseline/candidate workflow. The user explicitly chose to retain the failure and continue migrating other zeroD tests; numerical diagnosis/fixes are deferred. The verified tests are unaffected; the failing candidate remains reproducible explicitly.

Runtime: WSL Cantera 4.0.0a2 with the clean pinned checkout/import/digest gate; Windows Julia 1.12.7, SciMLBase 2.155.2 and OrdinaryDiffEqBDF 1.26.0, one Julia/OpenBLAS thread. This is a targeted failure record, not a passing package-test result.

## Reproduction

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl mass_flow_controller
```

The reference command uses `--case mass_flow_controller` with the pinned WSL Python/source and a fresh output filename as documented in the README.

## Initial run executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `ff402bf768db9dd1921451275706687f032573aec6bd3b71c7661e09d9836f5f`
- `test/cantera_parity/reactor_flow_steps.jl`: `fbbfc86032f93baa0f7dc2b464ba14f1d4e367cc5bd46abafd6db6b66e9fd524`
- `test/cantera_parity/reactor_reference.py`: `aa81697ff0081484b30e2869be7dd558509814cf67f0e68dafb6c8d14512da3e`
- `test/cantera_parity/run_solver_regressions.jl`: `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609`

## Diagnostic-only repeat executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `ff402bf768db9dd1921451275706687f032573aec6bd3b71c7661e09d9836f5f`
- `test/cantera_parity/reactor_flow_steps.jl`: `b32ef4242deb7546d46ebd3eb45ee5128d11cf1c3e6dd972a4b98fe13837815d`
- `test/cantera_parity/reactor_reference.py`: `aa81697ff0081484b30e2869be7dd558509814cf67f0e68dafb6c8d14512da3e`
- `test/cantera_parity/run_solver_regressions.jl`: `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609`

## Passing Cantera reference

```json
{
  "checked_at_utc": "2026-10-29T12:06:03.683713+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_mass_flow_controller",
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
    "time": 2.5,
    "samples": [
      {
        "time": 0.1,
        "mass_flow_rate": 0.0
      },
      {
        "time": 0.3,
        "mass_flow_rate": 0.04000000000000001
      },
      {
        "time": 1.0,
        "mass_flow_rate": 0.07999999999999999
      },
      {
        "time": 1.2,
        "mass_flow_rate": 0.0
      }
    ],
    "initial_mass": 1.2998223693259519,
    "initial_mass_fractions": [
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ],
    "inlet_mass_fractions": [
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0
    ],
    "final_mass": 1.399822369315503,
    "final_mass_fractions": [
      0.07143763534448355,
      2.091709266973461e-33,
      1.5239020148675182e-35,
      0.9285623646537527,
      1.3202429597813288e-37,
      -1.4440422801150324e-19,
      1.3044355213148693e-18,
      3.647424834240184e-20,
      0.0,
      0.0
    ],
    "temperature": 365.36105951310765,
    "pressure": 274084.2727743681,
    "rtol": 1e-11,
    "atol": 1e-15,
    "max_time_step": 0.05,
    "mass_flow_coeff": 1.0,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Initial native failure

```text
Julia version: 1.12.7
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
Cantera parity: TestIdealGasReactor.test_mass_flow_controller: Test Failed at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:50
  Expression: all((thermal_approx(a, b, provenance) for (a, b) = zip(expected_species, final.mass .* final.mass_fractions)))

Stacktrace:
 [1] top-level scope
   @ C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:14
 [2] macro expansion
   @ C:\Users\DELL\.julia\juliaup\julia-1.12.7+0.x64.w64.mingw32\share\julia\stdlib\v1.12\Test\src\Test.jl:1777 [inlined]
 [3] macro expansion
   @ C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:50 [inlined]
 [4] macro expansion
   @ C:\Users\DELL\.julia\juliaup\julia-1.12.7+0.x64.w64.mingw32\share\julia\stdlib\v1.12\Test\src\Test.jl:680 [inlined]
┌ Info: Triangular mass-flow pulse
│   time = 2.5
│   initial_mass = 1.2998223693259519
│   final_mass = 1.3998223693315304
│   injected_mass = 0.10000000000557852
│   temperature = 365.3610593944599
│   pressure = 274084.2727407221
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                                 | Pass  Fail  Total   Time
Cantera parity: TestIdealGasReactor.test_mass_flow_controller |   15     1     16  58.4s
RNG of the outermost testset: Random.Xoshiro(0x15d0c049536eea74, 0x2d79bfb8c64af7b2, 0xfbff5e0da8e8d439, 0xb14b73cd4ac92c9c, 0x634b0054fe5c2eeb)
ERROR: LoadError: Some tests did not pass: 15 passed, 1 failed, 0 errored, 0 broken.
in expression starting at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:12
in expression starting at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor.jl:1
in expression starting at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\run_solver_regressions.jl:11
```

## Diagnostic-only native repeat

```text
Julia version: 1.12.7
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
┌ Info: Pulse species mass mismatch
│   species = "HO2"
│   expected_mass = 0.0
│   actual_mass = 4.583077935302556e-12
│   absolute_error = 4.583077935302556e-12
└   allowed_error = 1.0e-12
Cantera parity: TestIdealGasReactor.test_mass_flow_controller: Test Failed at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:56
  Expression: all((thermal_approx(a, b, provenance) for (a, b) = zip(expected_species, final.mass .* final.mass_fractions)))

Stacktrace:
 [1] top-level scope
   @ C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:14
 [2] macro expansion
   @ C:\Users\DELL\.julia\juliaup\julia-1.12.7+0.x64.w64.mingw32\share\julia\stdlib\v1.12\Test\src\Test.jl:1777 [inlined]
 [3] macro expansion
   @ C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:56 [inlined]
 [4] macro expansion
   @ C:\Users\DELL\.julia\juliaup\julia-1.12.7+0.x64.w64.mingw32\share\julia\stdlib\v1.12\Test\src\Test.jl:680 [inlined]
┌ Info: Triangular mass-flow pulse
│   time = 2.5
│   initial_mass = 1.2998223693259519
│   final_mass = 1.3998223693315304
│   injected_mass = 0.10000000000557852
│   temperature = 365.3610593944599
│   pressure = 274084.2727407221
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                                 | Pass  Fail  Total   Time
Cantera parity: TestIdealGasReactor.test_mass_flow_controller |   15     1     16  58.5s
RNG of the outermost testset: Random.Xoshiro(0xe07ceb89ca938388, 0x4e7186bd6fd989c4, 0x5b106b627243e4ec, 0x05ee0ebd51c56f4a, 0xbca5ffdb91d9a476)
ERROR: LoadError: Some tests did not pass: 15 passed, 1 failed, 0 errored, 0 broken.
in expression starting at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor_flow_steps.jl:12
in expression starting at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\reactor.jl:1
in expression starting at C:\Users\DELL\Documents\GitHub\Arrhenius.jl\test\cantera_parity\run_solver_regressions.jl:11
```
