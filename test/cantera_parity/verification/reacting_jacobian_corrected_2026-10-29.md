# Corrected reacting-state Jacobian verification (2026-10-29)

Status: corrected Cantera reference and targeted native test passed (21/21); the full 24-case native group passed 8164/8164, and the core guard passed 1/1. All processes exited 0. Corrected coverage is restored after full acceptance: 31 covered / 288 missing / 104 not_applicable. The user authorized this independent correction stage; wall regression ports are not included.

## What was wrong and what changed

The historical [Jacobian record](reacting_jacobian_2026-10-29.md) retained a native 10/10 result but incorrectly claimed identical advanced physical states after disabling energy. The test reconstructed an isothermal vessel at the original 900 K while reusing the advanced species-mass/T vector. Native isothermal diagnostics intentionally use the descriptor's initial temperature, so the energy-off Jacobian was evaluated at 900 K rather than about 1389.7358 K. Its zero-temperature-row assertion alone could not expose this error. This was a fixture/proof defect, not evidence of a production solver failure.

The test-only vessel helper now accepts temperature, and the energy-off descriptor receives the advanced temperature. A copied advanced state vector and diagnostics with independent copied mass fractions provide the checkpoint. Both energy-off and chemistry-off configurations check T, P, Y, mass and volume against that checkpoint before the original zero-row/block assertions. A final exact vector check verifies that the accepted integrator state was not changed by the Jacobian work. These guards would reject the former 900 K setup.

The Cantera reference now captures independent physical snapshots before toggles and after evaluating each toggled Jacobian, and checks the same scalar/elementwise state consistency. Complete snapshots are retained below. Production code, ODE adapters, tolerances, finite-difference rules and other numerical policies are unchanged.

## Scenario and acceptance criteria

Upstream: `test/python/test_reactor.py::TestIdealGasReactor::test_finite_difference_jacobian`, definition line 138 at Cantera commit `726522be4e2a13454d8415b7ef799d621f665cf3`.

Initial state: 900 K, 1 atm, H2:0.4,O2:0.4,N2:0.2, 1 m3, enabled chemistry and adiabatic constant volume. Step until the first X_H2<=0.3. Keep the original finite Jacobian dimension, nonzero thermal row, energy-off zero thermal row and chemistry-off zero species/species block assertions. Native coordinates are 10 species masses plus T, while Cantera stores mass, volume, T and 10 mass fractions. Native total mass is derived and volume is a fixed descriptor, checked at the advanced state; matrix entries in different coordinates are not compared.

Integration rtol=1e-9 and atol=1e-15 are the pinned Cantera defaults, unchanged from provenance. The extra state-preservation checks reuse the existing pytest scalar/elementwise rule rel=1e-6 / abs=1e-12. Structural zero/nonzero assertions retain exact comparisons. State consistency is checked within each solver's own threshold-crossing checkpoint. Native and Cantera may cross the H2 threshold at different accepted steps; their checkpoint temperatures/compositions are not required to be identical.

| Checkpoint quantity | Cantera | Native |
|---|---:|---:|
| Time (s) | 0.1702412857797428 | 0.17024128499704988 |
| Accepted steps | 1048 | 901 |
| Advanced / energy-off / chemistry-off T (K) | 1388.2567562886095 | 1389.7357593115607 |
| Advanced / energy-off / chemistry-off P (Pa) | 152540.7405803075 | 152692.00402687897 |
| Advanced / energy-off / chemistry-off mass (kg) | 0.26009446422652055 | 0.26009446422651944 |
| All three volumes (m3) | 1.0 | 1.0 |

All three Y vectors within each solver are retained in the JSON/log and satisfy the new unchanged-state checks. Native threshold-crossing time, step count, temperature, pressure and H2 fraction match the prior native run as printed. No performance or bitwise cross-solver equivalence is claimed.

## Scope and runtime

The registered optional group has 24 integration scenarios. `all` and the known failed mass_flow_controller candidate are not additional passing scenarios. The latter remains explicit-only, missing/agent_failed, with its original HO2 species-mass assertion and [failure evidence](pulse_failure_2026-10-29.md) unchanged. No wall cases, new mechanisms or production APIs are added in this correction.

Windows native runtime: Julia 1.12.7, SciMLBase 2.155.2, OrdinaryDiffEqBDF 1.26.0, one Julia/OpenBLAS thread, existing example/reactors environment. The reference gate validates clean source HEAD, embedded Cantera version/commit, actual module/extension paths, phase and LF-normalized shared fixture digest. This record does not claim a full default Pkg.test() run.

## Reproduction

Use fresh output/log names when repeating to preserve evidence:

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/reactor_reference.py --case finite_difference_jacobian --source-dir /home/subspace/src/cantera-726522be --output /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/finite_difference_jacobian.cantera.state-corrected.rerun.json
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl finite_difference_jacobian
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
julia --project=. test/cantera_parity/reactor_core.jl
```

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `e0fb16fc8595a6661f6111a0e8014526b25957ef79bdf07b92ac865437af86ff`
- `test/cantera_parity/reactor_time_controls.jl`: `7093f12319050e4f344ef172dc2e7e023ec84f089ecff9c88b1f6fc7997b9f5f`
- `test/cantera_parity/reactor_equilibrium.jl`: `87bbfee9e43660d7d9258803718f2262ed0c42a7887cf73e3b931600ebcb2502`
- `test/cantera_parity/reactor_flow_steps.jl`: `b32ef4242deb7546d46ebd3eb45ee5128d11cf1c3e6dd972a4b98fe13837815d`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`
- `test/cantera_parity/reactor_core.jl`: `b6e52de99528d9e521478de3f82cfd1d44765d3efb7441fcf1d2e602f3d36fad`
- `test/cantera_parity/reactor_reference.py`: `f18506d200a0edd99dd7eafe344405351dd8613c93c1ba540872af142a294a40`
- `example/reactors/network_solver.jl`: `b1026ef675e725cd8adbbe82d6eebc1ce31e42e1d594a8eec2c2db06cb43fa73`
- `example/reactors/ode_solver.jl`: `3aa38aff6e50e06b92f3a52cd1ffcca22c1ce6047143056e27b644f07c105ed2`

## Historical artifact SHA256 (original raw bytes)

- `test/cantera_parity/verification/reacting_jacobian_2026-10-29.md`: `a16c4a7d538bece9a51884e9008daea272556fca619b80f975b614d7fcb47b5a`
- `test/cantera_parity/local-results/reactor-jacobian-20261029.agent-native.log`: `d0b4019e167aa6c709e9d2fa3b62d7d0c3513be09dfd1d94aa9261423463dbdb`
- `test/cantera_parity/local-results/finite_difference_jacobian.cantera.agent.json`: `0ad7b94d8df37f7673c8d5c035d328e0e588337ef3dedec151b49a55c743e578`

The old verification Markdown now has an invalidation notice prepended; its original body and the two raw artifacts remain byte-for-byte unchanged. The Markdown hash above is its original pre-notice digest.

## Complete corrected Cantera reference

```json
{
  "checked_at_utc": "2026-10-29T14:47:12.904762+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_finite_difference_jacobian",
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
    "time": 0.1702412857797428,
    "accepted_steps": 1048,
    "temperature": 1388.2567562886095,
    "pressure": 152540.7405803075,
    "mole_fractions": [
      0.29938874128532134,
      0.03248664243185323,
      0.009058242578941523,
      0.35612694577272025,
      0.007284564469692382,
      0.09037596000933942,
      0.0003279508874529383,
      2.9208313399542197e-05,
      0.0,
      0.20492174425127938
    ],
    "n_vars": 13,
    "first_component_names": [
      "mass",
      "volume",
      "temperature"
    ],
    "jacobian_shape": [
      13,
      13
    ],
    "advanced_state": {
      "temperature": 1388.2567562886095,
      "pressure": 152540.7405803075,
      "mass": 0.26009446422652055,
      "volume": 1.0,
      "mass_fractions": [
        0.030667385536701515,
        0.001663857471682847,
        0.007363555188148829,
        0.5789998217271721,
        0.0062948018499477,
        0.08272522382231086,
        0.000549987053692951,
        5.0479488783783016e-05,
        0.0,
        0.29168488786156055
      ]
    },
    "energy_disabled_state": {
      "temperature": 1388.2567562886095,
      "pressure": 152540.7405803075,
      "mass": 0.26009446422652055,
      "volume": 1.0,
      "mass_fractions": [
        0.030667385536701515,
        0.001663857471682847,
        0.007363555188148829,
        0.5789998217271721,
        0.0062948018499477,
        0.08272522382231086,
        0.000549987053692951,
        5.0479488783783016e-05,
        0.0,
        0.29168488786156055
      ]
    },
    "chemistry_disabled_state": {
      "temperature": 1388.2567562886095,
      "pressure": 152540.7405803075,
      "mass": 0.26009446422652055,
      "volume": 1.0,
      "mass_fractions": [
        0.030667385536701515,
        0.001663857471682847,
        0.007363555188148829,
        0.5789998217271721,
        0.0062948018499477,
        0.08272522382231086,
        0.000549987053692951,
        5.0479488783783016e-05,
        0.0,
        0.29168488786156055
      ]
    },
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Complete targeted native log

```text
Julia version: 1.12.7
Julia bindir: C:\Users\DELL\.julia\juliaup\julia-1.12.7+0.x64.w64.mingw32\bin
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
┌ Info: Jacobian toggle preserves advanced state
│   mode = :energy_off
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   mass = 0.26009446422651944
│   volume = 1.0
└   mass_fractions = "[0.030606464984356943, 0.0016754222105754316, 0.007424690933579748, 0.5785207952208857, 0.0063516200879577605, 0.08313674919764454, 0.0005499602861561957, 4.9409217284535275e-5, 0.0, 0.2916848878615591]"
┌ Info: Jacobian toggle preserves advanced state
│   mode = :chemistry_off
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   mass = 0.26009446422651944
│   volume = 1.0
└   mass_fractions = "[0.030606464984356943, 0.0016754222105754316, 0.007424690933579748, 0.5785207952208857, 0.0063516200879577605, 0.08313674919764454, 0.0005499602861561957, 4.9409217284535275e-5, 0.0, 0.2916848878615591]"
┌ Info: Jacobian advanced-state checkpoint
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   mass = 0.26009446422651944
│   volume = 1.0
└   mass_fractions = "[0.030606464984356943, 0.0016754222105754316, 0.007424690933579748, 0.5785207952208857, 0.0063516200879577605, 0.08313674919764454, 0.0005499602861561957, 4.9409217284535275e-5, 0.0, 0.2916848878615591]"
┌ Info: Reacting-state finite-difference Jacobian
│   time = 0.17024128499704988
│   steps = 901
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   x_h2 = 0.2988160189910338
│   jacobian_size = (11, 11)
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                                       | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_finite_difference_jacobian |   21     21  22.8s
```

## Complete native core log

```text
Test Summary:                                          | Pass  Total  Time
Cantera parity: TestReactor.test_invalid_empty_network |    1      1  0.3s
```

## Full 24-case acceptance

| Case | Passed / total |
|---|---:|
| `disable_chemistry` | 5 / 5 |
| `disjoint` | 10 / 10 |
| `disable_energy` | 6 / 6 |
| `heat_transfer1` | 5 / 5 |
| `heat_transfer2` | 8 / 8 |
| `heat_flux_func` | 7 / 7 |
| `valve1` | 11 / 11 |
| `valve2` | 205 / 205 |
| `valve_timing` | 17 / 17 |
| `reinitialize` | 6 / 6 |
| `reservoir_sync` | 4 / 4 |
| `wall_velocity` | 7 / 7 |
| `equalize_pressure` | 8 / 8 |
| `set_initial_time` | 8 / 8 |
| `equilibrium_UV` | 6 / 6 |
| `equilibrium_HP` | 6 / 6 |
| `valve3` | 5487 / 5487 |
| `pressure_controller2` | 2018 / 2018 |
| `finite_difference_jacobian` | 21 / 21 |
| `timestepping` | 288 / 288 |
| `maxsteps` | 3 / 3 |
| `tolerances` | 11 / 11 |
| `derivative` | 13 / 13 |
| `advance_reverse` | 4 / 4 |
| Total | 8164 / 8164 |

The full default selector contains exactly the 24 integration scenarios above. The standalone core guard is separate. The original Jacobian test had 10 assertions; the corrected test has 21, adding ten physical-state checks (five per toggle) plus an exact checkpoint-vector preservation check. Other cases retain their observed counts. The existing initial-step fallback warning in pressure equalization and the expected MaxIters warning in the dedicated failure-guard test are retained; neither required a policy change.

Coverage history: the inventory initially listed 31 covered including the disputed proof; invalidation changed it to 30 covered / 289 missing / 104 not_applicable. After corrected targeted and full-group verification, the row is restored and totals return to 31 / 288 / 104. This is a correction of evidence, not a new upstream case. No wall tests were added. The known HO2 candidate remains missing/agent_failed and was not rerun in this stage.

## Complete full-group native log

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
Cantera parity: TestIdealGasReactor.test_disable_chemistry |    5      5  34.0s
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
Cantera parity: TestIdealGasReactor.test_disjoint |   10     10  27.8s
┌ Info: Disabled left energy equation: final state
│   time = 11.0
│   left_T = 500.0
│   right_T = 500.00000009908587
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_energy |    6      6  28.0s
┌ Info: Thermal equilibrium: final state
│   time = 10.0
│   left_T = 478.61792772303863
│   right_T = 478.61792756510783
│   left_P = 161653.2050879414
│   right_P = 48495.96151049812
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_heat_transfer1 |    5      5  1.0s
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
Cantera parity: TestIdealGasReactor.test_heat_flux_func |    7      7  29.1s
┌ Info: Adiabatic valve: final state
│   time = 0.1
│   left_mass = 14.713552123734098
│   right_mass = 2.81475441790647
│   left_P = 860562.8068392661
│   right_P = 238467.76689825207
│   mdot = 12.441900798820281
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve1 |   11     11  30.3s
┌ Info: Isothermal valve: analytic solution
│   time = 0.5
│   samples = 50
│   left_mass = 8.37930800517398
│   right_mass = 5.918738057412256
│   max_analytic_mass_error = 3.401334325303651e-9
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve2 |  205    205  29.6s
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
Cantera parity: TestIdealGasReactor.test_valve_timing |   17     17  29.2s
┌ Info: Reinitialized thermal network
│   first_left_T = 407.6579430379587
│   first_right_T = 700.7335828671396
│   second_left_T = 407.6579461928992
│   second_right_T = 700.7335764276709
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                         | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_reinitialize |    6      6  0.8s
┌ Info: Updated reservoir boundary
│   first_T = 872.0994121452943
│   second_T = 747.2737647120872
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_reservoir_sync |    4      4  31.0s
┌ Info: Prescribed wall motion
│   left_V = 2.200000000548469
│   right_V = 4.799999999451596
│   rate_at_one = 0.2
│   rate_at_two = 0.0
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                          | Pass  Total     Time
Cantera parity: TestIdealGasReactor.test_wall_velocity |    7      7  1m00.8s
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
Test Summary:                                              | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_equalize_pressure |    8      8  59.3s
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
Cantera parity: TestIdealGasReactor.test_set_initial_time |    8      8  24.7s
┌ Info: Reactive equilibrium
│   mode = :UV
│   time = 1.0
│   temperature = 2671.7750554913887
│   pressure = 2.3423662771420726e6
│   density = 3.937203574206472
│   mole_fractions = "[0.005955200752397925, 0.0008194980215503963, 0.0003084978354775205, 0.0021506332129084824, 0.003505244722081045, 0.10247894515944184, 1.5560283158227463e-6, 2.2909836570337743e-7, 0.8847801951694612, 0.0]"
│   equilibrium_T = 2671.7750560287313
│   equilibrium_P = 2.3423662776313433e6
│   equilibrium_rho = 3.937203574206473
│   equilibrium_X = "[0.005955200760719497, 0.000819498023736356, 0.0003084978363616022, 0.0021506332157017493, 0.0035052447279553, 0.10247894514623439, 1.5560283192253334e-6, 2.2909836607891563e-7, 0.8847801951626059, 0.0]"
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_equilibrium_UV |    6      6  13.7s
┌ Info: Reactive equilibrium
│   mode = :HP
│   time = 1.0
│   temperature = 2230.322633321439
│   pressure = 1.01325e6
│   density = 2.047317464576349
│   mole_fractions = "[0.0017844579500879364, 8.918177676456165e-5, 2.739161229413833e-5, 0.0007026392235499402, 0.0007921830802842842, 0.1087557637781805, 1.689207049443335e-7, 3.385787936512436e-8, 0.8878481798002544, 0.0]"
│   equilibrium_T = 2230.3226333482557
│   equilibrium_P = 1.01325e6
│   equilibrium_rho = 2.047317464551403
│   equilibrium_X = "[0.001784457950290097, 8.918177678297803e-5, 2.7391612300183438e-5, 0.0007026392236249037, 0.0007921830803895926, 0.10875576377790641, 1.689207049727587e-7, 3.385787936938325e-8, 0.8878481798001215, 0.0]"
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_equilibrium_HP |    6      6  6.5s
┌ Info: Nonlinear valve accepted steps
│   time = 1.0001860234290827
│   steps = 1097
│   left_P = 667215.6238131989
│   right_P = 439372.5716427661
│   mdot = 2.3866454081536324
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve3 | 5487   5487  16.9s
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
Cantera parity: TestIdealGasReactor.test_pressure_controller2 | 2018   2018  26.6s
┌ Info: Jacobian toggle preserves advanced state
│   mode = :energy_off
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   mass = 0.26009446422651944
│   volume = 1.0
└   mass_fractions = "[0.030606464984356943, 0.0016754222105754316, 0.007424690933579748, 0.5785207952208857, 0.0063516200879577605, 0.08313674919764454, 0.0005499602861561957, 4.9409217284535275e-5, 0.0, 0.2916848878615591]"
┌ Info: Jacobian toggle preserves advanced state
│   mode = :chemistry_off
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   mass = 0.26009446422651944
│   volume = 1.0
└   mass_fractions = "[0.030606464984356943, 0.0016754222105754316, 0.007424690933579748, 0.5785207952208857, 0.0063516200879577605, 0.08313674919764454, 0.0005499602861561957, 4.9409217284535275e-5, 0.0, 0.2916848878615591]"
┌ Info: Jacobian advanced-state checkpoint
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   mass = 0.26009446422651944
│   volume = 1.0
└   mass_fractions = "[0.030606464984356943, 0.0016754222105754316, 0.007424690933579748, 0.5785207952208857, 0.0063516200879577605, 0.08313674919764454, 0.0005499602861561957, 4.9409217284535275e-5, 0.0, 0.2916848878615591]"
┌ Info: Reacting-state finite-difference Jacobian
│   time = 0.17024128499704988
│   steps = 901
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   x_h2 = 0.2988160189910338
│   jacobian_size = (11, 11)
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                                       | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_finite_difference_jacobian |   21     21  1.6s
┌ Info: Maximum time-step bound
│   time = 10.041100000000021
│   steps = 142
│   maximum_step = 0.07000000000000028
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                         | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_timestepping |  288    288  2.3s
┌ Warning: Verbosity toggle: max_iters 
│  Interrupted. Larger maxiters is needed. If you are using an integrator for non-stiff ODEs or an automatic switching algorithm (the default), you may want to consider using a method for stiff equations. See the solver pages for more details (e.g. https://docs.sciml.ai/DiffEqDocs/stable/solvers/ode_solve/#Stiff-Problems).
└ @ SciMLBase C:\Users\DELL\.julia\packages\SciMLBase\S0d2P\src\integrator_interface.jl:679
┌ Info: Expected maximum-step failure
│   time = 1.0e-6
│   retcode = ReturnCode.MaxIters = 4
│   maxiters = 10
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                     | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_maxsteps |    3      3  1.4s
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
Test Summary:                                       | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_tolerances |   11     11  0.1s
┌ Info: Integrated state derivative
│   initial_time = 1.0
│   time = 9.889
│   derivative = "[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]"
│   finite_difference = "[-4.665351947498029e-54, -2.755024308695573e-35, 4.055234360263129e-43, -2.4979705807743427e-17, 1.501777308886026e-42, 7.743042175185458e-63, 6.608128929283056e-33, 1.7734973525686664e-54, 0.0, 0.0, 3.197402343391159e-14]"
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                       | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_derivative |   13     13  7.9s
┌ Info: Backward advance rejected
│   time = 0.1
│   requested_time = 0.09
│   error = "Cannot step backward."
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                            | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_advance_reverse |    4      4  0.1s
```
