# Combustor accepted-step parity acceptance (2026-10-30)

The authorized stage follows [independent maintenance acceptance](maintenance_2026-10-30.md) and the [candidate mapping / execution plan](../zeroD_coverage.md#next-candidate-mapping-review-2026-10-30-not-execution-evidence). All required gates passed. Only `TestCombustor.test_integrateWithStep` is added; initialization and the HO2 pulse remain deferred. Production APIs, solver policy and numerical tolerances are unchanged.

## Original contract and exact inputs

Pinned commit: `726522be4e2a13454d8415b7ef799d621f665cf3`. Test source lines3289-3364, numerical comparison at3362-3363. Use original `data/h2o2.yaml`, ohmech,10 species/29 reactions. Its SHA-256 is `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`. Species order: H2,H,O,O2,OH,H2O,HO2,H2O2,AR,N2. Transport is explicitly none on Cantera; native zeroD does not call transport.

`test/data/CombustorTest-integrateWithAdvance.csv` is unchanged, SHA-256 `7e21a86c82ae905150edab14d7f7f88c046fd1d6c4dec4d4dfb10440f73cd7b6`. Its100x12 matrix is t,T,X[10]. The same CSV is the upstream Step reference; it is not regenerated from this run. Git attributes preserve its LF line endings.

All initial temperatures300 K and pressures1 atm. Vessel: pure AR,1 m3,fixed volume,adiabatic,chemistry enabled. Exhaust: pure AR. Fuel: pure H2 (source methane comment is stale). Oxidizer: O2:AR=1:3. Igniter: pure H. Flows:0.1*MW(H2)=0.2016 kg/s;4*0.1*MW(oxidizer)=15.184800000000003 kg/s; Gaussian0.1*exp(-4*log(2)*(t-0.1)^2/0.05^2) kg/s. Width0.05 s is FWHM, verified against Gaussian1. Outlet valve K=1 kg/(s Pa).

Native uses existing WellStirredReactor, Reservoir, MassFlowController, Valve and ReactorNetwork. The QNDF problem/function/domain/Jacobian configuration matches the existing network adapter. Integration rtol1e-9,atol1e-15 are unchanged Cantera defaults. No dtmax, forced stop at0.25, pulse truncation or maxiters substitution is introduced. Nominal horizon0.5 s only permits the first step crossing0.25; the loop stops immediately at that crossing. Sampling uses a separate diagnostic RHS, so observations do not overwrite the integrator workspace. Mole fractions are reconstructed from mass fractions/MW and normalized without clipping.

The source records post-step states, with no initial row. Each side's own accepted times are retained. The original comparison normalizes amplitudes, linearly interpolates and clamps endpoints, and fails a point only when absolute, relative and time-shift errors all exceed their limits. Step rtol1e-3,atol1e-9; xtol1e-5 is the unchanged upstream default. No additional pointwise trajectory tolerance is asserted.

## Observed target results

| Quantity | Cantera | Julia |
|---|---:|---:|
| Accepted steps / rows | 3949 | 1743 |
| Previous time (s) | 0.24916471027747272 | 0.24883304266942916 |
| First crossing time (s) | 0.2504113317546181 | 0.25024621849644935 |
| Final temperature (K) | 2180.2064724434254 | 2180.208400623913 |
| Whole target process (s) | 1.6006019 | 77.8301932 |

Both processes exited0; both curves pass the original CSV criterion. Native testset4/4 plus shared comparator selfchecks5/5. Saved native rows also independently pass the unchanged pinned Python compareProfiles; the same five positive/negative comparator fixtures pass upstream. Native logged retcode is `ReturnCode.Success = 1`. This is observed status for manual stepping, not a claim of integration through the nominal0.5-s endpoint. Step-count equality and equivalent internal error/failure control are not claimed.

Native solver counters: {"Number of Jacobians created": "37", "Number of W matrix evaluations": "161", "Number of accepted steps": "1743", "Number of fixed-point solver convergence failures": "0", "Number of fixed-point solver iterations": "0", "Number of function 1 evaluations": "6288", "Number of function 2 evaluations": "0", "Number of linear solves": "6285", "Number of nonlinear solver convergence failures": "0", "Number of nonlinear solver iterations": "5987", "Number of rejected steps": "55", "Number of rootfind condition calls": "0"}.
Cantera counters are preserved in cantera_reference.json; missing fields are not filled with zero. Recorded counts have solver-specific meanings. Target process duration includes startup/loading/compilation; the stepping duration in the native log also includes work compiled lazily in the loop and diagnostics. These are not controlled performance comparisons.

## Full acceptance and coverage

The new candidate was excluded from `all` until target and independent comparison passed. Then the complete29-scenario suite passed **8480/8480**, including five comparator selfchecks, in 838.7784226 s. The separate default-environment core guard passed1/1. Full Pkg.test() was not run and is not claimed. CI does not currently invoke this optional integration group.

Target/full combustor CSVs are byte-identical, SHA-256 `6b472d019cc70e6eca97929d267817b5846a18550509562be7692eb051aca53c`. Existing wall_step,wall_advance,const_pressure_closed,zerodim_simple full-group CSVs remain byte-identical to the previous accepted28-case run. Source checkpoints match the executions; the only target-to-full dispatch change enables the accepted candidate in `all`.

Only the selected coverage row changes:35/284/104 -> **36/283/104**, total423. Old related mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced by `reactor_combustor.jl :: Cantera parity: TestCombustor.test_integrateWithStep`. The Advance and invasive-callback variants stay missing; passing Step does not cover them.

## Reproduction and evidence

From the repository root, prepare the existing pinned environments and use fresh output paths:

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl combustor_step
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<venv-python> test/cantera_parity/reactor_reference.py --case combustor_step --source-dir <pinned-cantera-source> --output <new-reference.json>
```

Set JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1. CANTERA_PARITY_RESULTS selects a new native CSV directory. Native and reference writers refuse to overwrite old evidence. This acceptance keeps original logs, paths and hashes; no retrospective redaction was applied.

Raw files in [combustor_step_2026-10-30](combustor_step_2026-10-30/): cantera_reference.json, cantera_timing.json, native_target.log/timing, target/combustor_step.native.csv, target_audit.json, native_all29.log/timing, all29/*.csv, all29_audit.json, native_core.log/timing, target_source_sha256.json, full_source_sha256.json and upstream_source_sha256.json. [artifact_sha256.json](combustor_step_2026-10-30/artifact_sha256.json) hashes all archived files existing at acceptance. The scripts and proof records are preserved; old stage records are not overwritten.
