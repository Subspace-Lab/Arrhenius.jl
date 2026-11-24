# Combustor Advance acceptance (2026-10-30)

The [authorized Advance plan](../zeroD_coverage.md#authorized-next-stage-combustor-advance-2026-10-30) is complete. Only TestCombustor.test_integrateWithAdvance is newly covered. Initialization and HO2 remain deferred. Production APIs, numerical strategy and existing assertion thresholds are unchanged.

## Source and physical mapping

Pinned Cantera726522be4e2a13454d8415b7ef799d621f665cf3, test/python/test_reactor.py3366-3381. The physical fixture is exactly the [accepted Step setup](combustor_step_2026-10-30.md):300 K,1 atm,1 m3 adiabatic reacting AR vessel; H2 fuel, O2:AR=1:3 oxidizer, H igniter, AR exhaust. The two constant flows are0.2016 and15.184800000000003 kg/s; the igniter pulse has amplitude0.1 kg/s,center0.1 s,FWHM0.05 s. The outlet valve has K=1. Cantera transport is explicitly none; native zeroD does not use transport.

The unchanged ohmech input has10 species/29 reactions and SHA-256 `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`. The original100x12 CSV is unchanged, SHA-256 `7e21a86c82ae905150edab14d7f7f88c046fd1d6c4dec4d4dfb10440f73cd7b6`. Columns are t,T,X in H2,H,O,O2,OH,H2O,HO2,H2O2,AR,N2 order. No reference-regeneration path is used.

Cantera calls advance(t) for numpy.linspace(0,0.25,101)[1:]. Native uses the existing solve_network/native_network_bdf QNDF adapter with saveat. Its Float64 times i*(0.25/100),i=1..100 were checked elementwise exactly against NumPy. There is no initial output row and the final time is0.25 s. Output spacing0.0025 s is not an internal maximum step; no dtmax, additional tstops, maxiters or pulse change is introduced. The native path uses dense saved output rather than reproducing CVODES internal steps.

Integration rtol1e-9/atol1e-15 are unchanged. Advance profile limits rtol1e-6/atol1e-12 come from the original test; default xtol1e-5 and normalization/interpolation/endpoints/joint-failure rule come from the unchanged compareProfiles. Step retains its separate rtol1e-3/atol1e-9 limits. No equality of trajectories beyond these original profile bounds, or equivalence of internal failure control, is claimed.

## Test-local sharing and independent verification

The existing fixture/row conversion/comparator are shared by two selected branches, with a fresh model for each. Before changing this organization, baseline Julia/Python test files were saved in this evidence directory. The shared-code change is not mixed with a numerical-policy change. Both Cantera and native Step trajectories and every recorded solver counter remain identical to the previously accepted Step evidence. Native Step CSV bytes are identical. Step remains4/4; Advance6/6 adds successful retcode, exact output grid and endpoint checks to finite/ordered/profile checks. Shared comparator selfchecks5/5 run only once.

The native Advance CSV independently passes the unchanged upstream Python comparator, including the five shared positive/negative fixtures. It has100 rows and12 columns, finite values, exact NumPy times and final T=2180.211323746608 K. Retcode: `ReturnCode.Success = 1`. Native solver counters: {"Number of Jacobians created": "37", "Number of W matrix evaluations": "162", "Number of accepted steps": "1743", "Number of fixed-point solver convergence failures": "0", "Number of fixed-point solver iterations": "0", "Number of function 1 evaluations": "6288", "Number of function 2 evaluations": "0", "Number of linear solves": "6285", "Number of nonlinear solver convergence failures": "0", "Number of nonlinear solver iterations": "5987", "Number of rejected steps": "55", "Number of rootfind condition calls": "0"}. Cantera actual internal accepted steps=3827; output rows=100. Raw counters and all rows remain in cantera_advance.json; unavailable information is not invented as zero.

Target Step+Advance process took103.4786716 s. Complete30-case process took621.4018282 s. These times include loading/compilation and are not controlled solver performance comparisons; per-solve timings are also logged.

## Acceptance and coverage

The candidate was explicit-only until both references, native target, unchanged-Step controls and independent comparison passed. It was then included in `all`. Complete30 integration scenarios passed **8486/8486**, including five comparator selfchecks; separate core guard1/1. Full Pkg.test() is not claimed. Both target/full Advance CSVs are byte-identical (SHA-256 `d1505aa5a84b82d0ff9a9ae3f5c05eb24bb9a12b832be82d7d2b54dbf213bfef`). The five existing saved trajectories (both walls,closed CP,C++ simple,combustor Step) remain byte-identical to the accepted29-case run.

Only this coverage row changes36/283/104 -> **37/282/104**, total423. Old related mapping `test/reactor_networks_native.jl:5 :: native reactor network balances and devices` is replaced by reactor_combustor.jl :: Cantera parity: TestCombustor.test_integrateWithAdvance. The invasive-callback case remains missing. The initialization and HO2 rows are unchanged and remain deferred.

## Reproduce and inspect

```text
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl combustor_step combustor_advance
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl all
julia --project=. test/cantera_parity/reactor_core.jl
<pinned-venv-python> test/cantera_parity/reactor_reference.py --case combustor_advance --source-dir <pinned-source> --output <new-reference.json>
```

Use JULIA_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1 and a new CANTERA_PARITY_RESULTS directory for CSV output. Never overwrite old evidence. [Raw evidence](combustor_advance_2026-10-30/): both Cantera records/logs/timings, native target/all30/core logs and timings, target/all30 CSVs, target_audit.json,all30_audit.json,source checkpoints including the new manifest,baseline sources and executed audit/acceptance scripts. [Artifact hashes](combustor_advance_2026-10-30/artifact_sha256.json) preserve the archived bytes. No historical evidence is rewritten.
