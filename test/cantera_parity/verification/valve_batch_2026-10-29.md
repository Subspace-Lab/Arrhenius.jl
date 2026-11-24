# ZeroD valve batch verification (2026-10-29)

The user authorized continued fast zeroD ports supported by existing native
capabilities, with discussion required for new production APIs, numerical
policy changes or substantial errors. The agent executed three pinned Cantera
references and the full nine-case Julia regression batch. All exited 0.

## Complete upstream scenarios

Source: Cantera 4.0.0a2 at
`726522be4e2a13454d8415b7ef799d621f665cf3`, `test/python/test_reactor.py`.
Only the effective `TestIdealGasReactor` variants below are newly covered.

- `test_valve1` (line 698): two 1-m3 vessels, 300 K, 10/1 atm, initially
  pure Ar/O2. Both energy equations and chemistry enabled. K=2e-5, integrate
  to 0.1 s with rtol=1e-12, atol=1e-15. Preserve outlet/inlet equality,
  coefficient and energy flags, initial/final pressure-flow laws, total mass,
  species mass (comparison atol=1e-10), and upstream composition assertions.
- `test_valve2` (line 733): both vessels pure O2 with disabled energy and
  chemistry enabled, otherwise the same geometry and pressures. Preserve
  coefficient/flags and all three assertions at each of 50 uniformly spaced
  times from 1e-5 to 0.5 s: analytic receiver mass, total mass conservation,
  and unchanged upstream Y. The analytic A and B expressions are copied from
  upstream. Integration rtol=1e-11, atol=1e-15. Native saveat uses the same
  sample-time grid; all 50 points are checked.
- `test_valve_timing` (line 801): Ar/O2, enabled energy/chemistry, same K,
  and time function t>0.01. Preserve activity, pressure-function value and
  flow assertions at 0, 0.01, 0.010000001 and 0.02 s. Integrate at rtol=1e-12,
  atol=1e-15 without introducing a forced timestep stop at the discontinuity.

Source assignments of K and energy flags happen before initialization.
Native constructors supply the same configuration. For the valve1 topology
assertion, existing network flow/endpoint fields provide outgoing-left and
incoming-right views. Both refer to the same edge; no attachment-list API or
live mutation capability is added or claimed. Disabled energy maps to the
existing isothermal vessel setting. Production source and defaults are not
changed. Comparison tolerances and their direction follow upstream; the test
helper only gains the explicit atol override needed by valve1's species-mass
assertion. The first six regressions still pass with their original results.

## Observed native results

| Case | Assertions | Result |
|---|---:|---|
| `disable_chemistry` | 5/5 | pass |
| `disjoint` | 10/10 | pass |
| `disable_energy` | 6/6 | pass |
| `heat_transfer1` | 5/5 | pass |
| `heat_transfer2` | 8/8 | pass |
| `heat_flux_func` | 7/7 | pass |
| `valve1` | 11/11 | pass |
| `valve2` | 205/205 | pass |
| `valve_timing` | 17/17 | pass |
| Total | 274/274 | pass |

| Selected value | Cantera | Native |
|---|---:|---:|
| valve1 final receiving mass (kg) | 2.8147544179393753 | 2.81475441790647 |
| valve1 final flow (kg/s) | 12.441900799304486 | 12.441900798820281 |
| valve2 final receiving mass (kg) | 5.918738056009255 | 5.918738057412256 |
| valve2 maximum analytic mass error (kg) | 1.3335625936861106e-9 | 3.401334325303651e-9 |
| valve_timing flow at 0.02 s (kg/s) | 17.55311379171346 | 17.55311379173182 |

The Cantera records retain all 50 valve2 mass samples and all four timing
samples. The native log retains the assertion counts, maximum analytic error,
final state values, and all timing samples. Both codes pass the complete
upstream assertions. No bitwise or solver-count equivalence is claimed.

The reference environment gate checks clean source HEAD, embedded commit,
actual imported module/extension paths, and the shared LF-normalized h2o2
fixture digest for each run. Cantera runs in WSL/Python 3.12.3 with SUNDIALS
7.5.0. Native Julia runs on Windows 1.12.7, SciMLBase 2.155.2 and
OrdinaryDiffEqBDF 1.26.0, using one Julia/OpenBLAS thread. Times in the native
log include compilation and are not performance comparisons. This is the
optional nine-case suite, not a full Pkg.test() result. No numerical failure
required escalation.

## Reproduction

From Windows PowerShell at the repository root, use a fresh output filename
when repeating the reference (replace valve1 with valve2 or valve_timing):

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case valve1 --source-dir /home/subspace/src/cantera-726522be --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/valve1.cantera.agent.json
```

Full native batch (the actual command also prints runtime paths, retained in
the verbatim log):

```powershell
$env:JULIA_NUM_THREADS = '1'
$env:OPENBLAS_NUM_THREADS = '1'
julia --project=example/reactors -e 'using Arrhenius, LinearAlgebra; BLAS.set_num_threads(1); println("Julia version: ", VERSION); println("Julia bindir: ", Sys.BINDIR); println("Active project: ", Base.active_project()); println("Arrhenius source: ", pathof(Arrhenius)); include("test/cantera_parity/run_solver_regressions.jl")'
```

A single native case can be run with:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl valve2
```

Raw stdout/stderr were retained in
`local-results/reactor-valve-batch-20261029.agent-native.log`. Original
reference records retain `reference_passed_native_not_verified` because they
were written before the native batch; this combined record completes their
acceptance. Historical six-case and earlier user-run records stay unchanged.

## Cantera valve1 record (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T11:32:49.619514+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_valve1",
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
    "initial": {
      "left": {
        "mass": 16.22848417231445,
        "temperature": 300.0,
        "pressure": 1013250.0,
        "mass_fractions": [
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0
        ]
      },
      "right": {
        "mass": 1.2998223693259519,
        "temperature": 300.0,
        "pressure": 101325.00000000001,
        "mass_fractions": [
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
        ]
      },
      "mass_flow_rate": 18.238500000000002
    },
    "actual": {
      "left": {
        "mass": 14.71355212370101,
        "temperature": 281.0267355617817,
        "pressure": 860562.8068360131,
        "mass_fractions": [
          -1.0890078511926612e-25,
          -1.9829361418428636e-27,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0
        ]
      },
      "right": {
        "mass": 2.8147544179393753,
        "temperature": 365.1654905116732,
        "pressure": 238467.76687078888,
        "mass_fractions": [
          -1.0336524155598146e-26,
          2.6111551292550254e-31,
          -2.4062790422118065e-33,
          0.46178890816868884,
          -2.5578840971521188e-33,
          -4.423799407769951e-45,
          1.860970214339638e-25,
          -1.5572601656777771e-40,
          0.5382110918313117,
          0.0
        ]
      },
      "mass_flow_rate": 12.441900799304486
    },
    "valve_coeff": 2e-05,
    "rtol": 1e-12,
    "atol": 1e-15,
    "energy_enabled": true,
    "chemistry_enabled": true,
    "assertion_rtol": 1e-06,
    "assertion_atol": 1e-12,
    "species_mass_assertion_atol": 1e-10,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera valve2 record (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T11:32:53.636231+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_valve2",
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
    "time": 0.5,
    "samples": [
      {
        "time": 1e-05,
        "left_mass": 12.998041311168079,
        "right_mass": 1.3000047514173942,
        "analytic_right_mass": 1.3000047514824908
      },
      {
        "time": 0.010213877551020408,
        "left_mass": 12.814873067364157,
        "right_mass": 1.483172995221308,
        "analytic_right_mass": 1.4831729949684584
      },
      {
        "time": 0.020417755102040816,
        "left_mass": 12.63744093273098,
        "right_mass": 1.660605129854487,
        "analytic_right_mass": 1.6606051296209925
      },
      {
        "time": 0.030621632653061222,
        "left_mass": 12.465565274433553,
        "right_mass": 1.8324807881519163,
        "analytic_right_mass": 1.8324807878038847
      },
      {
        "time": 0.040825510204081636,
        "left_mass": 12.299072085676936,
        "right_mass": 1.9989739769085322,
        "analytic_right_mass": 1.9989739765019356
      },
      {
        "time": 0.051029387755102046,
        "left_mass": 12.137792808634087,
        "right_mass": 2.1602532539513795,
        "analytic_right_mass": 2.1602532534856964
      },
      {
        "time": 0.06123326530612245,
        "left_mass": 11.981564164048724,
        "right_mass": 2.31648189853674,
        "analytic_right_mass": 2.316481897959422
      },
      {
        "time": 0.07143714285714285,
        "left_mass": 11.830227986192186,
        "right_mass": 2.467818076393279,
        "analytic_right_mass": 2.467818075865001
      },
      {
        "time": 0.08164102040816326,
        "left_mass": 11.68363106207206,
        "right_mass": 2.614415000513406,
        "analytic_right_mass": 2.614415000009222
      },
      {
        "time": 0.09184489795918367,
        "left_mass": 11.54162497703667,
        "right_mass": 2.756421085548795,
        "analytic_right_mass": 2.756421085176477
      },
      {
        "time": 0.10204877551020408,
        "left_mass": 11.404065964011528,
        "right_mass": 2.893980098573942,
        "analytic_right_mass": 2.893980098383948
      },
      {
        "time": 0.11225265306122449,
        "left_mass": 11.270814758026816,
        "right_mass": 3.027231304558654,
        "analytic_right_mass": 3.027231304431395
      },
      {
        "time": 0.12245653061224489,
        "left_mass": 11.141736455644102,
        "right_mass": 3.156309606941369,
        "analytic_right_mass": 3.1563096068928944
      },
      {
        "time": 0.13266040816326533,
        "left_mass": 11.016700377933635,
        "right_mass": 3.2813456846518365,
        "analytic_right_mass": 3.2813456846932683
      },
      {
        "time": 0.14286428571428572,
        "left_mass": 10.895579938300312,
        "right_mass": 3.40246612428516,
        "analytic_right_mass": 3.4024661244074816
      },
      {
        "time": 0.15306816326530615,
        "left_mass": 10.77825251435394,
        "right_mass": 3.5197935482315343,
        "analytic_right_mass": 3.5197935484169443
      },
      {
        "time": 0.16327204081632654,
        "left_mass": 10.664599323793142,
        "right_mass": 3.633446738792331,
        "analytic_right_mass": 3.633446739052452
      },
      {
        "time": 0.17347591836734694,
        "left_mass": 10.554505304055926,
        "right_mass": 3.743540758529546,
        "analytic_right_mass": 3.743540758849472
      },
      {
        "time": 0.18367979591836736,
        "left_mass": 10.447858995928206,
        "right_mass": 3.850187066657266,
        "analytic_right_mass": 3.850187067037497
      },
      {
        "time": 0.19388367346938776,
        "left_mass": 10.344552430637842,
        "right_mass": 3.95349363194763,
        "analytic_right_mass": 3.9534936323814116
      },
      {
        "time": 0.20408755102040818,
        "left_mass": 10.244481020549305,
        "right_mass": 4.053565042036167,
        "analytic_right_mass": 4.053565042489117
      },
      {
        "time": 0.21429142857142858,
        "left_mass": 10.147543453327833,
        "right_mass": 4.150502609257641,
        "analytic_right_mass": 4.150502609696064
      },
      {
        "time": 0.224495306122449,
        "left_mass": 10.05364158937631,
        "right_mass": 4.244404473209158,
        "analytic_right_mass": 4.244404473633901
      },
      {
        "time": 0.2346991836734694,
        "left_mass": 9.962680362715878,
        "right_mass": 4.335365699869591,
        "analytic_right_mass": 4.335365700587079
      },
      {
        "time": 0.2449030612244898,
        "left_mass": 9.874567684086315,
        "right_mass": 4.423478378499154,
        "analytic_right_mass": 4.423478379737997
      },
      {
        "time": 0.2551069387755102,
        "left_mass": 9.789214346908148,
        "right_mass": 4.508831715677324,
        "analytic_right_mass": 4.50883171639812
      },
      {
        "time": 0.26531081632653064,
        "left_mass": 9.7065339408025,
        "right_mass": 4.591512121782973,
        "analytic_right_mass": 4.591512122319478
      },
      {
        "time": 0.275514693877551,
        "left_mass": 9.626442759744998,
        "right_mass": 4.6716033028404755,
        "analytic_right_mass": 4.671603303177957
      },
      {
        "time": 0.28571857142857143,
        "left_mass": 9.548859719426789,
        "right_mass": 4.749186343158686,
        "analytic_right_mass": 4.749186343316957
      },
      {
        "time": 0.29592244897959186,
        "left_mass": 9.473706274821401,
        "right_mass": 4.824339787764074,
        "analytic_right_mass": 4.824339787837217
      },
      {
        "time": 0.3061263265306123,
        "left_mass": 9.400906340502624,
        "right_mass": 4.8971397220828505,
        "analytic_right_mass": 4.897139722115901
      },
      {
        "time": 0.31633020408163265,
        "left_mass": 9.330386213751382,
        "right_mass": 4.967659848834093,
        "analytic_right_mass": 4.967659848835469
      },
      {
        "time": 0.3265340816326531,
        "left_mass": 9.26207449997961,
        "right_mass": 5.035971562605863,
        "analytic_right_mass": 5.035971562600299
      },
      {
        "time": 0.3367379591836735,
        "left_mass": 9.195902040359739,
        "right_mass": 5.102144022225739,
        "analytic_right_mass": 5.102144022216615
      },
      {
        "time": 0.34694183673469386,
        "left_mass": 9.131801841794772,
        "right_mass": 5.166244220790707,
        "analytic_right_mass": 5.166244220708888
      },
      {
        "time": 0.3571457142857143,
        "left_mass": 9.06970900918872,
        "right_mass": 5.228337053396757,
        "analytic_right_mass": 5.228337053143603
      },
      {
        "time": 0.3673495918367347,
        "left_mass": 9.00956067986696,
        "right_mass": 5.288485382718518,
        "analytic_right_mass": 5.288485382329046
      },
      {
        "time": 0.37755346938775514,
        "left_mass": 8.951295959607181,
        "right_mass": 5.346750102978293,
        "analytic_right_mass": 5.346750102457643
      },
      {
        "time": 0.3877573469387755,
        "left_mass": 8.894855861187738,
        "right_mass": 5.403190201397734,
        "analytic_right_mass": 5.403190200755257
      },
      {
        "time": 0.39796122448979593,
        "left_mass": 8.84018324462937,
        "right_mass": 5.457862817956102,
        "analytic_right_mass": 5.457862817199886
      },
      {
        "time": 0.40816510204081635,
        "left_mass": 8.78722275941844,
        "right_mass": 5.510823303167031,
        "analytic_right_mass": 5.510823302370191
      },
      {
        "time": 0.4183689795918367,
        "left_mass": 8.735920788282144,
        "right_mass": 5.56212527430333,
        "analytic_right_mass": 5.562125273482456
      },
      {
        "time": 0.42857285714285714,
        "left_mass": 8.68622539291473,
        "right_mass": 5.611820669670745,
        "analytic_right_mass": 5.6118206686726655
      },
      {
        "time": 0.43877673469387757,
        "left_mass": 8.638086261864458,
        "right_mass": 5.659959800721017,
        "analytic_right_mass": 5.659959799578704
      },
      {
        "time": 0.448980612244898,
        "left_mass": 8.591454659023384,
        "right_mass": 5.70659140356209,
        "analytic_right_mass": 5.706591402275874
      },
      {
        "time": 0.45918448979591836,
        "left_mass": 8.546283374634589,
        "right_mass": 5.751762687950882,
        "analytic_right_mass": 5.75176268661732
      },
      {
        "time": 0.4693883673469388,
        "left_mass": 8.502526677231087,
        "right_mass": 5.795519385354385,
        "analytic_right_mass": 5.795519384029299
      },
      {
        "time": 0.4795922448979592,
        "left_mass": 8.460140267459662,
        "right_mass": 5.8379057951258115,
        "analytic_right_mass": 5.8379057938097
      },
      {
        "time": 0.4897961224489796,
        "left_mass": 8.41908123330213,
        "right_mass": 5.878964829283345,
        "analytic_right_mass": 5.878964827976667
      },
      {
        "time": 0.5,
        "left_mass": 8.379308006576222,
        "right_mass": 5.918738056009255,
        "analytic_right_mass": 5.918738054712743
      }
    ],
    "initial_left_mass": 12.998223693259517,
    "initial_right_mass": 1.2998223693259519,
    "initial_left_mass_fractions": [
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
    "A": 22.291500000000003,
    "B": 3.118118364205228,
    "max_analytic_mass_error": 1.3335625936861106e-09,
    "valve_coeff": 2e-05,
    "rtol": 1e-11,
    "atol": 1e-15,
    "energy_enabled": false,
    "chemistry_enabled": true,
    "assertion_rtol": 1e-06,
    "assertion_atol": 1e-12,
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Cantera valve_timing record (verbatim)

```json
{
  "checked_at_utc": "2026-10-29T11:32:58.160422+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_valve_timing",
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
    "time": 0.02,
    "samples": [
      {
        "time": 0.0,
        "activity": 0.0,
        "pressure_difference": 911925.0,
        "mass_flow_rate": 0.0
      },
      {
        "time": 0.01,
        "activity": 0.0,
        "pressure_difference": 911924.9999999992,
        "mass_flow_rate": 0.0
      },
      {
        "time": 0.010000001,
        "activity": 1.0,
        "pressure_difference": 911924.9965140508,
        "mass_flow_rate": 18.238499930281016
      },
      {
        "time": 0.02,
        "activity": 1.0,
        "pressure_difference": 877655.6895856729,
        "mass_flow_rate": 17.55311379171346
      }
    ],
    "valve_coeff": 2e-05,
    "rtol": 1e-12,
    "atol": 1e-15,
    "energy_enabled": true,
    "chemistry_enabled": true,
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
Cantera parity: TestIdealGasReactor.test_disable_chemistry |    5      5  40.0s
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
Cantera parity: TestIdealGasReactor.test_disjoint |   10     10  30.0s
┌ Info: Disabled left energy equation: final state
│   time = 11.0
│   left_T = 500.0
│   right_T = 500.00000009908587
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_energy |    6      6  30.7s
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
Cantera parity: TestIdealGasReactor.test_heat_transfer2 |    8      8  0.2s
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
Cantera parity: TestIdealGasReactor.test_heat_flux_func |    7      7  30.9s
┌ Info: Adiabatic valve: final state
│   time = 0.1
│   left_mass = 14.713552123734098
│   right_mass = 2.81475441790647
│   left_P = 860562.8068392661
│   right_P = 238467.76689825207
│   mdot = 12.441900798820281
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve1 |   11     11  31.6s
┌ Info: Isothermal valve: analytic solution
│   time = 0.5
│   samples = 50
│   left_mass = 8.37930800517398
│   right_mass = 5.918738057412256
│   max_analytic_mass_error = 3.401334325303651e-9
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve2 |  205    205  31.2s
┌ Info: Timed valve: sample
│   time = 0.0
│   activity = false
│   pressure_difference = 911925.0
└   mdot = 0.0
┌ Info: Timed valve: sample
│   time = 0.01
│   activity = false
│   pressure_difference = 911925.0000000002
└   mdot = 0.0
┌ Info: Timed valve: sample
│   time = 0.010000001
│   activity = true
│   pressure_difference = 911924.9965140434
└   mdot = 18.23849993028087
┌ Info: Timed valve: sample
│   time = 0.02
│   activity = true
│   pressure_difference = 877655.689586591
└   mdot = 17.55311379173182
┌ Info: Timed valve: input provenance
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                         | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve_timing |   17     17  31.2s
```

## Executed source fingerprints

SHA-256 with CRLF normalized to LF:

| File | SHA-256 (LF) |
|---|---|
| `reactor.jl` | `23b8e99dbc40c19c0414e6c9f876d38b33b07784c769d140db4797e8df2e4e12` |
| `reactor_reference.py` | `2b24739867b421bac4379fc6c34e73a04d441b72272cd7f1edfd53f8d26e4037` |
| `run_solver_regressions.jl` | `51ca3100186a531abe79cb6b5fd3e05c34afffad6f31c29add393e8c456fa609` |
