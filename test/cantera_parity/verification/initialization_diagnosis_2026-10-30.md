# Bounded initialization / energy diagnosis (2026-10-30)

Conclusion for this case: **numerical energy-conservation accuracy with temperature coordinates**, rather than evidence of a state mapping, thermodynamic-evaluator or preparation defect. This is not a proof of bug absence in every state/solver path. No production source, numerical policy, integration tolerance, equilibrium tolerance, time horizon, or assertion limit is changed. The case remains missing; accepted coverage remains35/284/104.

The [preceding feasibility record](initialization_feasibility_2026-10-30.md) retains the passing original C++ initialization gtest and the initial failed physical-state comparison. This work diagnoses that mismatch; it does not register a new parity scenario. The test intentionally initializes the reactor before network use, but its assertion compares the 1-s integrated state with independent UV equilibrium, so a failed comparison alone does not identify initialization as the cause.

## Mapping and available capability

| Source quantity | Unit | Native reconstruction in this probe |
|---|---|---|
| mass | kg | rho*V, V=1 m3 |
| volume | m3 | fixed physical volume1 |
| total internal energy | J | rho*V*u(T,Y), evaluated from the advanced state |
| species | dimensionless | Y, in the same10-species order |

Cantera Generic Reactor uses [mass,V,U,Y] (Reactor.cpp:62-75). This particular native probe uses IdealGasReactor [Y,T], not ReactorNetwork's [species masses,T]. The previous probe already maps the physical quantities; raw coordinate arrays are never compared directly. Total U is neither specific u nor an initial-value substitute.

Existing equilibrate(...;mode=:UV) is supported (Equilibrium.jl:355-378). The original initial conditions1100 K,10 atm,H2:1,O2:0.5,AR:8 use the unchanged shared h2o2.yaml/ohmech input. The recomputed native UV equilibrium exactly matches the earlier probe. Its default property_rtol=1e-10 remains unchanged.

## The two requested conversions

| Measurement | Value |
|---|---:|
| Mass | 3.937203574206472 kg |
| Initial total heat capacity | 1580.4305782997656 J/K |
| Equilibrium total heat capacity | 1710.8211658734333 J/K |
| Signed integrated minus equilibrium U | -0.0013302635634317994 J |
| Equivalent dT=dU/(m*cv), frozen composition | -7.775585139856823e-07 K |
| Actual integrated minus equilibrium T | -5.373426574806217e-07 K |
| Maximum absolute Y difference | 5.9884597281012475e-12 |
| Source U bound converted to frozen-composition dT | 5.845146295518652e-11 K |

The source bound is1e-7 **J** on U; there is no1e-7 K temperature component in the generic source state. Consequently an equivalent temperature error near1e-7 K does not place the U check near its acceptance boundary. The conversion dU=m*cv*dT holds at fixed composition; both actual endpoints also differ slightly in Y. Tiny Y differences can have material energy contributions because species formation/internal energies are large.

An exact path decomposition (equilibrium -> change mass -> change Y at equilibrium T -> change T at actual Y) gives:

- Temperature contribution: -0.0009192977414300257 J.
- Composition contribution: -0.00041096484274109863 J.
- Mass contribution: -2.190992196723204e-10 J.
- Sum: -0.001330262803270344 J; residual against directly evaluated dU: -7.601614554833547e-10 J.

| Species | Signed dY | Energy contribution at equilibrium T (J) |
|---|---:|---:|
| H2 | -4.5178726212e-13 | -4.8060220183e-05 |
| H | -5.9183028893e-14 | -5.6663796998e-05 |
| O | -3.7983288390e-13 | -2.5861739898e-05 |
| O2 | -2.4079935095e-12 | -1.8631735204e-05 |
| OH | -2.6879414493e-12 | -5.9041009046e-05 |
| H2O | 5.9884597281e-12 | -2.0263537153e-04 |
| HO2 | -3.0183771318e-15 | -3.9817729271e-08 |
| H2O2 | -3.4371294686e-16 | 9.9663975934e-12 |
| AR | -1.1657341759e-14 | -3.1162123486e-08 |
| N2 | 0.0000000000e+00 | 0.0000000000e+00 |

## Discriminating evidence

1. **Same-state thermo:** Cantera and native U evaluated at identical T,rho and unnormalized Y differ by 3.4924596548080444e-10 J at the advanced state and -2.3283064365386963e-10 J at equilibrium. These differences cannot account for the observed1.33e-3 J mismatch. This comparison checks energy evaluation, not the equality of trajectories.
2. **Where the mismatch enters:** initial U=971244.3036962787 J. UV-equilibrium U minus initial U=-3.4924596548080444e-10 J; integrated U minus initial U=-0.001330263912677765 J. The discrepancy is almost entirely accumulated along the numerical integration, rather than the UV target or evaluating the same endpoint by different thermodynamic routines.
3. **Preparation control:** independent unprepared and pre-prepared/RHS-evaluated reactors give bit-identical saved states and identical solver counters. Both return Success; counts are1237 accepted,44 rejected,7 Jacobians. The prepared input state is unchanged. This checks the existing native preparation path; it does not create or verify a new stateful initialize API.
4. **Energy equation:** native local m*(cv*Tdot + sum(u_k*Ydot_k)) is0 W at the initial state and -4.336808689942018e-18 W at the final state. The algebraic energy balance is consistent at these checked states. In the upstream generic Reactor, U is itself integrated and its closed, fixed-volume, adiabatic RHS is zero (Reactor.cpp:168-198). Native integrates T instead; derived U is not independently error-controlled or projected back onto its initial value.

| Time (s) | T (K) | U minus initial U (J) | max abs(Y minus equilibrium Y) |
|---|---:|---:|---:|
| 0.0 | 1100.0000000000 | 0.0000000000e+00 | 4.9442653806e-02 |
| 0.0001 | 1100.0019630440 | 2.8521753848e-08 | 4.9442594634e-02 |
| 0.001 | 1156.5760509262 | -5.1503302529e-06 | 4.7779817580e-02 |
| 0.01 | 2671.7750556206 | -1.0103199165e-03 | 4.5480424982e-12 |
| 0.1 | 2671.7750556019 | -1.0566146811e-03 | 4.7565562600e-12 |
| 0.5 | 2671.7750554496 | -1.4338071924e-03 | 6.4551558543e-12 |
| 1.0 | 2671.7750554914 | -1.3302639127e-03 | 5.9884597281e-12 |

By0.01 s the composition is already within about5e-12 of the target, while the energy drift remains around1e-3 J. A closed adiabatic system must conserve U even before reaching chemical equilibrium, so simply needing more time to equilibrate does not explain this invariant error. No extended-time or tighter-tolerance solve was used.

## Disposition

Within the requested three-way split, classify this under the **numerical accuracy/representation boundary**, specifically energy-conservation drift of the temperature-coordinate integration. Do not call it a thermodynamic path bug solely because compositions agree. There is no demonstrated state-unit mismatch, thermo evaluator discrepancy of the required size, or dependence on native preparation in these checks.

Keep this upstream row missing and pending discussion of its strict absolute-U criterion versus the existing integration representation. Do not substitute initial U, relax the bound, tighten tolerances, or redesign state coordinates as part of this diagnosis. Return to screening other existing-capability ports; any new API or numerical-policy work requires its own plan. The observed small drift is not upgraded into formal parity acceptance.

## Raw evidence

- [native_diagnosis.toml](initialization_diagnosis_2026-10-30/native_diagnosis.toml): SHA256 `09dabbe87e8cb9826fc41192239df7c9967ba4d30df45ccba8a377f49e81c22b`
- [native_diagnosis.log](initialization_diagnosis_2026-10-30/native_diagnosis.log): SHA256 `23fffdc4addda08eb7b897e3e37b339a0453d3202af7383d136884e00f7b933b`
- [executed_native_diagnostic.jl.txt](initialization_diagnosis_2026-10-30/executed_native_diagnostic.jl.txt): SHA256 `a8cea5069d93d5291edbc5b7bf7d0ea8874d2c2067f51dc37d13130251ca8525`
- [same_state_cantera.json](initialization_diagnosis_2026-10-30/same_state_cantera.json): SHA256 `7ff1fc9b96075bf1fddf8da03e231fea449fd310f09f5e1fdd79a12d559f84c4`
- [source_sha256.json](initialization_diagnosis_2026-10-30/source_sha256.json): SHA256 `77009fe1ef97adff818f02cf027f6052421ad7e2a0da132a7bd6d8db23a3a915`

Coverage bookkeeping: the row stays missing; validation=agent_failed links this failed mapped-state diagnostic comparison. This does not claim a registered initialization parity test or a failed Julia process: the diagnostic process completed successfully and measured a state comparison outside the source bound. Existing native_test remains related evidence until a formal port is designed.

Source detail: ThermoPhase.h:1173-1176 returns zero intrinsicHeating for the ordinary ideal-gas phase. With no walls, flow or surfaces, the generic Reactor total-U RHS is zero in this case.

## Follow-up candidate screening

The bounded source screen checked pressure_controller1 (test_reactor.py:852-879), extra_variable (3628-3676), and heat_addition (3838-3857). Existing pressure-flow integration, inertial walls and heat-flux operators support their physical ingredients. However, complete coverage still requires resolving controller coefficient-alias writes, custom component name/index contracts, or direct heat-rate hook correspondence respectively. None is declared fully supported or newly covered by this screen. Continue with a separate candidate-mapping plan rather than implementing an unverified adapter or adding an API during this diagnosis.
