# Verified 18-case zeroD group checkpoint (2026-10-29)

The agent ran the no-argument unified optional entry point after adding the restart, reservoir, moving-wall, equilibrium, shifted-time and nonlinear-flow ports. The process exited 0: **18 cases, 7824/7824 assertions**. The empty-network Layer A guard separately passed 1/1 (raw log below). This checkpoint precedes registration of the later time-control cases; it does not claim to execute them.

The retained pulse candidate is explicitly excluded from the verified group and remains a real failing test by name. Its failed species assertion is neither weakened nor counted as passing. The user subsequently chose to retain that failure and continue other zeroD ports.

## Cases

| Case | Assertions |
|---|---:|
| `disable_chemistry` | 5/5 |
| `disjoint` | 10/10 |
| `disable_energy` | 6/6 |
| `heat_transfer1` | 5/5 |
| `heat_transfer2` | 8/8 |
| `heat_flux_func` | 7/7 |
| `valve1` | 11/11 |
| `valve2` | 205/205 |
| `valve_timing` | 17/17 |
| `reinitialize` | 6/6 |
| `reservoir_sync` | 4/4 |
| `wall_velocity` | 7/7 |
| `equalize_pressure` | 8/8 |
| `set_initial_time` | 8/8 |
| `equilibrium_UV` | 6/6 |
| `equilibrium_HP` | 6/6 |
| `valve3` | 5487/5487 |
| `pressure_controller2` | 2018/2018 |

## Reference evidence and cross-checks

The pinned Cantera references, actual imported module paths, clean source/commit and fixture digest checks are retained with each port:

- [Initial disable-chemistry reference](disable_chemistry_2026-10-29.md)
- [Disjoint reference](disjoint_2026-10-29.md)
- [Disabled-energy batch](agent_batch_2026-10-29.md)
- [Thermal batch](thermal_batch_2026-10-29.md)
- [Valve batch](valve_batch_2026-10-29.md)
- [Restart/reservoir/moving-wall/core guards](restart_wall_batch_2026-10-29.md)
- [UV/HP equilibrium and initial time](equilibrium_batch_2026-10-29.md)
- [Accepted-step flows](flow_steps_batch_2026-10-29.md)
- [Explicit retained pulse failure](pulse_failure_2026-10-29.md)

This run logs full native UV/HP compositions. A direct elementwise check against the retained Cantera integration outputs also passes rel=1e-6 / abs=1e-12 for every species. Maximum absolute X differences:

- UV: 1.5271145459294644e-11
- HP: 2.9223845565695683e-13

The repeated nonlinear-valve/controller step counts and final states match their earlier native runs exactly as printed. Production source and numerical policies are unchanged. The existing initial-step fallback warning is retained for pressure equalization, which completes successfully. This checkpoint is not the full default Pkg.test() suite, and compilation timings are not a performance comparison.

## Command at this checkpoint

```powershell
$env:JULIA_NUM_THREADS='1'
$env:OPENBLAS_NUM_THREADS='1'
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
```

At this checkpoint `all` meant the 18 cases listed above. Later registrations enlarge it; pass the names explicitly to reproduce just this set. Windows Julia 1.12.7 and the pinned example environment were used. The core command is `julia --project=. test/cantera_parity/reactor_core.jl`.

## Executed native-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `3771e8b6656aa9e5c0bacda2c9defad99fd9b1e60083d733be76d931d5b63e9e`
- `test/cantera_parity/reactor_core.jl`: `b6e52de99528d9e521478de3f82cfd1d44765d3efb7441fcf1d2e602f3d36fad`
- `test/cantera_parity/reactor_equilibrium.jl`: `87bbfee9e43660d7d9258803718f2262ed0c42a7887cf73e3b931600ebcb2502`
- `test/cantera_parity/reactor_flow_steps.jl`: `b32ef4242deb7546d46ebd3eb45ee5128d11cf1c3e6dd972a4b98fe13837815d`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`

## Complete native integration output

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
Cantera parity: TestIdealGasReactor.test_disjoint |   10     10  29.3s
┌ Info: Disabled left energy equation: final state
│   time = 11.0
│   left_T = 500.0
│   right_T = 500.00000009908587
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_disable_energy |    6      6  30.5s
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
Cantera parity: TestIdealGasReactor.test_valve1 |   11     11  31.3s
┌ Info: Isothermal valve: analytic solution
│   time = 0.5
│   samples = 50
│   left_mass = 8.37930800517398
│   right_mass = 5.918738057412256
│   max_analytic_mass_error = 3.401334325303651e-9
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve2 |  205    205  26.1s
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
Cantera parity: TestIdealGasReactor.test_valve_timing |   17     17  19.9s
┌ Info: Reinitialized thermal network
│   first_left_T = 407.6579430379587
│   first_right_T = 700.7335828671396
│   second_left_T = 407.6579461928992
│   second_right_T = 700.7335764276709
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                         | Pass  Total  Time
Cantera parity: TestIdealGasReactor.test_reinitialize |    6      6  0.6s
┌ Info: Updated reservoir boundary
│   first_T = 872.0994121452943
│   second_T = 747.2737647120872
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_reservoir_sync |    4      4  20.2s
┌ Info: Prescribed wall motion
│   left_V = 2.200000000548469
│   right_V = 4.799999999451596
│   rate_at_one = 0.2
│   rate_at_two = 0.0
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                          | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_wall_velocity |    7      7  54.3s
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
Cantera parity: TestIdealGasReactor.test_equalize_pressure |    8      8  1m09.3s
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
Cantera parity: TestIdealGasReactor.test_set_initial_time |    8      8  33.7s
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
Cantera parity: TestIdealGasReactor.test_equilibrium_UV |    6      6  23.9s
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
Test Summary:                                           | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_equilibrium_HP |    6      6  11.6s
┌ Info: Nonlinear valve accepted steps
│   time = 1.0001860234290827
│   steps = 1097
│   left_P = 667215.6238131989
│   right_P = 439372.5716427661
│   mdot = 2.3866454081536324
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                   | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_valve3 | 5487   5487  29.5s
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
Cantera parity: TestIdealGasReactor.test_pressure_controller2 | 2018   2018  46.1s
```

## Complete native core output

```text
Test Summary:                                          | Pass  Total  Time
Cantera parity: TestReactor.test_invalid_empty_network |    1      1  0.3s
```
