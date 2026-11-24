# Combustor invasive callback acceptance (2026-10-30)

The [authorized mapping and plan](../zeroD_coverage.md#authorized-invasive-callback-mapping-and-plan-2026-10-30) is complete. Only TestCombustor.test_invasive_mdot_function is newly covered. Initialization and HO2 remain deferred. No production API, solver strategy, tolerance or original profile assertion is changed.

## Interface mapping: why the existing capability is sufficient

At pinned Cantera726522be4e2a13454d8415b7ef799d621f665cf3, test/python/test_reactor.py3383-3407 installs a Python callback which reads igniter.density, returns amplitude*exp(-(t-t0)^2*4*log(2)/fwhm^2), advances to100 times, and compares the temperature/all-species curve. The comment says querying the property changes shared ThermoPhase state. The pinned binding actually defaults clone=True (reactor.py:58-63), phase returns _phase (220-228), and density returns phase.density (245-247); this path does not restore a shared phase before reading. The separate default-constructor probe confirms reservoir/reactor independence after changing the original gas and byte-identical phase states before/after the density query. See [mapping.json](combustor_invasive_2026-10-30/mapping.json) for clean pinned environment, actual import paths, source hashes and measured density. The environment gate in mapping.json retains its default upstream_test label (disable_chemistry); that field does not describe a test executed by this mapping probe. The probe body and the three formal reference records identify the actual work. This is a version-specific conclusion, not a claim about older Cantera versions.

Native MassFlowController documents f(states,t) with read-only temperature/pressure/density/composition observations. network_rhs allocates independent workspaces; _update_network_states! prepares node data before _network_signal invokes the flow. The native callback reads states.igniter.density, not a captured density constant and not the combustor density. Its test-local counter/extrema make the observation measurable. It does not mutate network states, recursively invoke the RHS, alter flow values using the observed density, or introduce a new query API.

Cantera preserves the original m3.mass_flow_rate callback assignment before the first integration. Native immutable configuration installs the callback in its constructor before solving. This tests the observable callback-query/integration contract; source setter readback, mutation after initialization and historical shared-ThermoPhase side effects are not asserted and are not claimed covered. Graph tools were unavailable, so mapping used direct source inspection plus the recorded pinned runtime probe.

## Unchanged fixture, times and numerical gates

Use the [accepted combustor setup](combustor_step_2026-10-30.md):300 K,1 atm,1 m3 adiabatic reacting AR vessel, pure-H2 fuel, O2:AR=1:3 oxidizer, pure-H igniter, AR exhaust. Constant feeds0.2016 and15.184800000000003 kg/s; pulse amplitude0.1 kg/s,center0.1 s,FWHM0.05 s; outlet valve K=1. Invasive callback operation order follows its original Python expression; the existing Step/Advance Gaussian expressions remain unchanged.

Unchanged h2o2.yaml/ohmech10 species29 reactions SHA-256 `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`; original CombustorTest-integrateWithAdvance.csv100x12 SHA-256 `7e21a86c82ae905150edab14d7f7f88c046fd1d6c4dec4d4dfb10440f73cd7b6`. Cantera disables transport; native zeroD does not use it. Columns t,T,X use H2,H,O,O2,OH,H2O,HO2,H2O2,AR,N2 order.

Output times exactly match numpy.linspace(0,0.25,101)[1:]. Native uses existing solve_network/native_network_bdf dense saved output, with no0.0025-s timestep cap. Integration rtol1e-9,atol1e-15; original profile rtol1e-6,atol1e-12,default xtol1e-5. Original amplitude normalization, interpolation, endpoints and joint-failure condition are unchanged. No reference regeneration or tighter cross-solver trajectory criterion is added.

## Observed callback and target evidence

| Measurement | Cantera | Native |
|---|---:|---:|
| Reads during solve | 6862 | 7139 |
| Minimum density (kg/m3) | 0.04094696381900617 | 0.040946963819006164 |
| Maximum density (kg/m3) | 0.04094696381900617 | 0.040946963819006164 |
| Expected pure-H reservoir density | 0.04094696381900617 | 0.040946963819006164 |

Native snapshots these counters immediately after the solve and before output diagnostics evaluate the RHS again. Both sides require at least one actual read and all observed densities equal their respective initial boundary density. Read counts are not required to match solver statistics or each other. These two native observation guards supplement, rather than replace, the source curve assertion.

The new target passes8/8; compatibility Step4/4 and Advance6/6,shared comparator5/5. Both Cantera and native Step/Advance retain bit-identical trajectories and all previously recorded solver counters. Native invasive100x12 output is finite, exactly on the original times, and returns `ReturnCode.Success = 1` at0.25 s with T=2180.211323746608 K. The unchanged upstream Python compareProfiles independently passes this output and all five comparator positive/negative fixtures.

Native solver counters: {"Number of Jacobians created": "37", "Number of W matrix evaluations": "162", "Number of accepted steps": "1743", "Number of fixed-point solver convergence failures": "0", "Number of fixed-point solver iterations": "0", "Number of function 1 evaluations": "6288", "Number of function 2 evaluations": "0", "Number of linear solves": "6285", "Number of nonlinear solver convergence failures": "0", "Number of nonlinear solver iterations": "5987", "Number of rejected steps": "55", "Number of rootfind condition calls": "0"}. Reference counters/full rows are in cantera_invasive.json. Missing information is not filled with zero. No equivalence of internal failure control or solver step counts is claimed.

## Full acceptance and scope

The new case was explicit-only until target gates passed, then registered in `all`. Complete31-scenario acceptance passes **8494/8494**, including five comparator selfchecks; separate core guard1/1. Full Pkg.test() is not claimed. Target three-mode process264.4463888 s; full process1038.387764 s, including loading/compilation, not a controlled performance comparison.

New target/full CSVs are byte-identical, SHA-256 `d1505aa5a84b82d0ff9a9ae3f5c05eb24bb9a12b832be82d7d2b54dbf213bfef`. All six existing saved trajectories remain byte-identical to the accepted30-case baseline. Only this row changes37/282/104 -> **38/281/104**, total423. Old related mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced by reactor_combustor.jl :: Cantera parity: TestCombustor.test_invasive_mdot_function. Initialization and HO2 remain missing/deferred. This covers the fixed version's complete observable test behavior, not the older shared-state mutation described by its comment.

## Reproduction and raw proof

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl combustor_step combustor_advance combustor_invasive
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-venv-python> test/cantera_parity/reactor_reference.py --case combustor_invasive --source-dir <pinned-source> --output <new-reference.json>
```

Use JULIA_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1 and fresh CANTERA_PARITY_RESULTS/output paths. [Raw evidence](combustor_invasive_2026-10-30/): mapping.json,three Cantera records/logs/timings,native target/all31/core logs and timings,all CSVs,target/all31 audits,source checkpoints,baseline files,and executed mapping/audit/acceptance scripts. [artifact_sha256.json](combustor_invasive_2026-10-30/artifact_sha256.json) hashes preserved files. No prior evidence was overwritten.
