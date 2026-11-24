# Closed constant-pressure parity verification (2026-10-30)

Status: accepted. Formal input gates, the Cantera 50-sample reference, native target (255/255), complete 27-case native group (8430/8430, including five comparator selfchecks), and separate core guard (1/1) passed. Only the selected constant-pressure coverage row is added: **34 covered / 285 missing / 104 not_applicable**. The preceding wall phase was accepted at 26 cases/8175 assertions and coverage 33/286/104; see [its record](wall_batch_2026-10-30.md).

Executor: the agent, under the user's authorization to run routine Cantera and Julia verification. The configured WSL reference environment was reused.

## Exact upstream case

Only test/python/test_reactor.py::TestIdealGasConstPressureReactor::test_closed is ported. It inherits TestConstPressureReactor's helper/integrate body at the pinned Cantera commit 726522be4e2a13454d8415b7ef799d621f665cf3. Other class variants, heat-transfer, mass-inflow and surface cases are not covered by this result.

Both chambers start at 1200 K, 25 atm (2533125 Pa), CH4:0.5,H2O:0.2,CO:0.3 and initial volume 0.2 m3, with enabled energy and chemistry. The moving-wall chamber connects to a pure-H2 reservoir at 900 K/25 atm via A=0.1,K=1e3,U=0. The actual constant-pressure side has no heat or mass exchange; the source zero-K/zero-U wall contributes nothing. Native closed CP equations use specific Y/T; initial mass rho0*0.2 records the volume scale without adding a volume API. The unused helper self.gas CO/H2O mixture is not substituted for the actual pure-H2 reservoir.

At all 50 times 0.5,1.5,...,49.5 s, preserve moving-side==approx(CP-side): every Y uses rel=5e-4/abs=1e-6; T uses rel=5e-5/abs=1e-12; P uses rel=1e-6/abs=1e-12. Comparisons are scalar/elementwise, not vector norms. This case has no wall-profile CSV or xtol criterion. Both sides use dtmax=0.05 and the pinned rtol=1e-9/atol=1e-15. Native uses the existing moving-wall adapter and native_bdf's automatic CP selection unchanged.

## Scripted mechanism preservation and normalization

[Generator](../export_const_pressure_fixture.py) extracts the exact gas_def AST literal and resolves fixed data/gri30.yaml. Source GRI30 LF SHA256 is `06650b1e0ee0012f6903d5328b1bb218cb6007d07f8ebe375d18f24811039345`; gas_def SHA256 is `801614428053e316519d0ad57e4ae9a34fc4646a970c4a5acc825165cab9bee6`. Cantera write_yaml precision=17 exports a standalone original which remains untouched.

The original export is legal Cantera input with explicit skip-undeclared-third-bodies:true. Its 14 C2H6 efficiency entries come from the original GRI30 reaction input data, not an erroneous local exporter. Native does not implement that skip option. Only the normalized copy removes those 14 out-of-phase efficiency keys, explicitly selects reactions:all and uses skip-undeclared-third-bodies:false for strict loading. No reaction, rate parameter or species is dropped. All 18 species, 74 reaction order/equations, and 6 duplicate markings are preserved. Deletions are checked against their exact expected indices/values; unknown case-variant names or any additional removal fail.

Durable fixture files:

- [Original Cantera export](../fixtures/cantera-726522be/const_pressure_18/gri30-18.raw.yaml)
- [Normalized shared input](../fixtures/cantera-726522be/const_pressure_18/gri30-18.normalized.yaml)
- [Input/hash manifest](../fixtures/cantera-726522be/const_pressure_18/fixture.toml)
- [Complete conversion list and four-state numerical evidence](../fixtures/cantera-726522be/const_pressure_18/equivalence.json)

The script refuses to overwrite an existing output directory. Manifest/removal records include reaction index/equation, deleted species/original value, source commit and raw/normalized hashes. The first generation attempt's raw files were preserved in local-results while its provenance layout was clarified; the final shared generation nests the common h2o2 environment gate separately from the new submechanism metadata. This was a metadata correction only.

## Formal input equivalence gates

Three independently loaded phases (original helper, raw export reload, normalized strict reload) are compared at 1200 K/25 atm with the initial mixture, 900 K/25 atm pure H2, 2000 K/25 atm equal fractions of all 18 species, and 3000 K/1 atm the same equal mixture. Each receives the same literal input independently; no returned TPX state is copied between phases.

Each state retains all 74 forward and reverse constants, 74 net reaction progress rates, 18 net production rates, 18 partial molar enthalpies, and 22 effective third-body concentrations, plus actual T/P/X. Formal comparison uses abs(a-b)<=max(1e-12,1e-6*abs(b)), sourced from [test_composite.py:1217-1219](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_composite.py#L1217) (Cantera YAML roundtrip). The earlier feasibility threshold 1e-13 and observed zero third-body differences were not promoted into new formal thresholds. Raw-to-normalized observed differences are zero for the measured fields at all four states; source-to-raw maximum observed forward-rate relative difference is 3.5049276316264844e-15. The existing native CreateSolution gate succeeds at 18 species/74 reactions, with exact species order retained in the input log. No production reader is changed.

## Failure-control distinction

The Cantera CP network explicitly sets max_err_test_fails=10. CVodesIntegrator.cpp:238-243 stores/forwards it when initialized; lines 474-475 apply it during option setup. The underlying [CVodeSetMaxErrTestFails](https://sundials.readthedocs.io/en/v7.5.0/cvodes/Usage/SIM.html#c.CVodeSetMaxErrTestFails) limits error-test failures while attempting one internal step. Native QNDF has no equivalent public setting; existing behavior is retained and maxiters is not substituted. Original physical assertions are all retained; no equivalence of internal failure protection is claimed.

The complete binding call chain is `ReactorNet.max_err_test_fails` setter
(`interfaces/cython/cantera/reactor.py:2005-2007`) -> Cython declaration
(`reactor.pxd:193`) -> `ReactorNet::setMaxErrTestFails`
(`src/zeroD/ReactorNet.cpp:185-188`) -> `CVodesIntegrator::setMaxErrTestFails`
(`src/numerics/CVodesIntegrator.cpp:238-243`) -> immediate
`CVodeSetMaxErrTestFails` when initialized, or the stored option applied at
lines 474-475 during initialization. The public header describes the single-step
meaning at `include/cantera/zeroD/ReactorNet.h:75-77`. The exact pinned
[source excerpts](const_pressure_closed_2026-10-30/failure_control_source.log)
have SHA256 `a986ad53c67081bdd2c82e02c5d36d12cfcefabd86bf26e1e97f97854741527e`.

Input validation failures stop before integration. Cantera solver failures retain exception, last reported network times and available statistics in a failed reference record; completed-trajectory mismatches are a separate category. Native adapters require successful retcodes, log successful last time/counters, and throw on failures; where their failed partial solution is not exposed, the test explicitly reports unavailable fields rather than inventing zeros. The cumulative err_test_fails count alone is not evidence that a per-step cap was reached. No unsupported skip-loader API is added; such support is a future separate capability topic, not part of this stage.

## Observed target solves

| Quantity | Cantera | Native |
|---|---:|---:|
| Final time, both sides (s) |49.5|49.5|
| Moving-wall final T (K) |1255.884126890404|1255.8841165731105|
| CP final T (K) |1255.8841184604382|1255.8841185166548|
| Moving-wall final P (Pa) |2533124.999999999|2533125.000000001|
| CP final P (Pa) |2533125.000000001|2533125.0|
| Initial mass (kg) |1.0169460787266196|1.0169460787266196|
| Steps (Cantera `steps`; native accepted): moving / CP |1837 / 1722|62308 / 1371|
| Cantera cumulative `err_test_fails`: moving / CP |63 / 51|not the native rejected-step counter|
| Native rejected steps: moving / CP |not the Cantera error-test counter|27154 / 3|
| Nonlinear convergence failures: moving / CP |5 / 0|10033 / 0|

Both native branches return Success and retain their actual counters. Counter meanings, coordinates, solver implementations and sampling differ; these values are not a controlled performance comparison. The high-K moving branch has many rejected steps/convergence failures, which are retained observations rather than failed tests. Full reference statistics are in its raw JSON. Independent rechecking of all native CSV samples against the original scalar bounds also passes; maximum error/bound ratios:

- Y: 0.00046323934089261877
- T: 0.0001821950543774097
- P: 4.742782615362318e-06

## Reproduction and runtime

```powershell
wsl -d Ubuntu-24.04 -u subspace -- /home/subspace/.venvs/cantera-726522be/bin/python /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/export_const_pressure_fixture.py --source-dir /home/subspace/src/cantera-726522be --output-dir /mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/local-results/const-pressure-regenerate-unique
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl const_pressure_closed
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
julia --project=. test/cantera_parity/reactor_core.jl
```

Run reactor_reference.py with --case const_pressure_closed, the same pinned WSL source/interpreter and a fresh --output. CANTERA_PARITY_RESULTS selects a fresh optional native CSV directory. The record retains all 50 rows with columns t,moving_T,moving_P,moving_Y[18],constant_T,constant_P,constant_Y[18]. Windows Julia 1.12.7 uses the existing SciMLBase 2.155.2/OrdinaryDiffEqBDF 1.26.0 environment with one Julia/OpenBLAS thread. Reference gates check actual import paths, clean fixed HEAD, runtime and input hashes. Full Pkg.test() and numerical-strategy changes are not part of this evidence.

## Executed-source SHA256 (LF-normalized)


### Export/input equivalence

- `test/cantera_parity/export_const_pressure_fixture.py`: `a1e418d3e5e349f5bc15140f95f8495ab1bb36f7aee1347b32ae022c38aab923`
- `test/cantera_parity/reactor_reference.py`: `e415c7d6efc527bf6837089267efad6e4ddd15b4422c22da9472cbca9b77ee44`

### Target test (staged explicit selector)

- `test/cantera_parity/reactor.jl`: `af748464defe20bbf4879fd3e6e0821d7ec2e790426f3d0ad0211892b55da129`
- `test/cantera_parity/reactor_const_pressure.jl`: `77130c7e82e2260cc2b823d50796c4381121adcb21bd069d37d6dbdcc2a3cef5`
- `test/cantera_parity/reactor_const_pressure_reference.py`: `bc826d38a376acc12290661ac1466189cf8636d92a55e5cfa2d0613393489506`
- `test/cantera_parity/reactor_reference.py`: `43d51d3626e6a6bf001c8d96160afdc7fa0fc20fdada9661a819493e535785d1`
- `test/cantera_parity/export_const_pressure_fixture.py`: `a1e418d3e5e349f5bc15140f95f8495ab1bb36f7aee1347b32ae022c38aab923`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`

### Full-group test (accepted target added to all)

- `test/cantera_parity/reactor.jl`: `0be35cfc58153172bb9537faa69cb157d3f17afaf30f6fce51f2ca6ab20ebda5`
- `test/cantera_parity/reactor_const_pressure.jl`: `77130c7e82e2260cc2b823d50796c4381121adcb21bd069d37d6dbdcc2a3cef5`
- `test/cantera_parity/reactor_const_pressure_reference.py`: `bc826d38a376acc12290661ac1466189cf8636d92a55e5cfa2d0613393489506`
- `test/cantera_parity/reactor_wall.jl`: `8be5f965f1f9851fa2ad25b384d6ee8874356d3ee1e023b82a76ccc2bd267c48`
- `test/cantera_parity/reactor_wall_reference.py`: `63ed30f5444a22818182a096f8b3527c4437cf45bc4e52fd2fbb5b7fa43fc975`
- `test/cantera_parity/reactor_reference.py`: `43d51d3626e6a6bf001c8d96160afdc7fa0fc20fdada9661a819493e535785d1`
- `test/cantera_parity/export_const_pressure_fixture.py`: `a1e418d3e5e349f5bc15140f95f8495ab1bb36f7aee1347b32ae022c38aab923`
- `test/cantera_parity/reactor_time_controls.jl`: `7093f12319050e4f344ef172dc2e7e023ec84f089ecff9c88b1f6fc7997b9f5f`
- `test/cantera_parity/reactor_equilibrium.jl`: `87bbfee9e43660d7d9258803718f2262ed0c42a7887cf73e3b931600ebcb2502`
- `test/cantera_parity/reactor_flow_steps.jl`: `b32ef4242deb7546d46ebd3eb45ee5128d11cf1c3e6dd972a4b98fe13837815d`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`
- `test/cantera_parity/reactor_core.jl`: `b6e52de99528d9e521478de3f82cfd1d44765d3efb7441fcf1d2e602f3d36fad`

## Raw target evidence

- [cantera_reference.json](const_pressure_closed_2026-10-30/cantera_reference.json): SHA256 `15b099dba39dc30b8476b8f91ccf0a3c41a5d48d7e612d255afa83d86005e0d1`
- [export.log](const_pressure_closed_2026-10-30/export.log): SHA256 `80ebeefdf4011f32fe437343b479e7a2d3989834795297d8b25063d1c07875c7`
- [native_core.log](const_pressure_closed_2026-10-30/native_core.log): SHA256 `55e2643f8ff7ff166fc72759096da393e85faf7bfdacc2a42432c95871c79126`
- [native_data_audit.json](const_pressure_closed_2026-10-30/native_data_audit.json): SHA256 `0609c8b0177d7cc34742a5a2d0ac0c6dd16c6f1416696944c7900d94eb054461`
- [native_input.log](const_pressure_closed_2026-10-30/native_input.log): SHA256 `3c167845d29ea27593933977139c9f2134f51cca4e7b677e485149712f84e87c`
- [native_samples.csv](const_pressure_closed_2026-10-30/native_samples.csv): SHA256 `ce699ff5c01fb0ed5b625fde60db4a657132bf080df797c7f4fb8d6379b6e0ee`
- [native_target.log](const_pressure_closed_2026-10-30/native_target.log): SHA256 `7942e292acd4dd764bca95c18397d388a8e00bfc05727d332e65908d80786cfc`

## Complete 27-case acceptance

The no-argument optional entry point exited 0. All 27 distinct integration scenarios passed (8425/8425 assertions), together with five comparator selfchecks: **8430/8430**. The separate core guard passed 1/1. The explicit-only HO2 pulse candidate was not selected and remains missing with its previous failure evidence. No full default Pkg.test() run is claimed.

The full-run constant-pressure CSV independently passes all 50 original scalar Y/T/P bounds. It is byte-identical to the target CSV. Executed source hashes still match the full-group checkpoint above. The final group includes the already accepted wall regressions; all full-run CSVs are retained.

- [native_all27.log](const_pressure_closed_2026-10-30/native_all27.log): SHA256 `480522da8079c44b7b2a9b2e54c40d6dc4c738d98e0969d6315c02bba9ef0206`
- [full27_const_pressure_closed.native.csv](const_pressure_closed_2026-10-30/full27_const_pressure_closed.native.csv): SHA256 `ce699ff5c01fb0ed5b625fde60db4a657132bf080df797c7f4fb8d6379b6e0ee`
- [full27_wall_advance.native.csv](const_pressure_closed_2026-10-30/full27_wall_advance.native.csv): SHA256 `a8da1e9ef62044be9c7d6de38fc0ef014fac8adddf5879388183af7bd4ed208c`
- [full27_wall_step.native.csv](const_pressure_closed_2026-10-30/full27_wall_step.native.csv): SHA256 `81781ec79506090a8010b36e4654162c67bf604203d44f0c52291bf371e0e297`
- [Full-group audit](const_pressure_closed_2026-10-30/full27_audit.json): SHA256 `096dd90af34329f88a468714f55a17346877f1894ffb30d57e7dc676c260184c`
