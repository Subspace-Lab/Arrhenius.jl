# Generic Reactor thermal equilibrium and heat-transfer scaling

These physical checks use the frozen Cantera commit `726522be4e2a13454d8415b7ef799d621f665cf3` and its original `data/h2o2.yaml`, phase `ohmech`. Both closed vessels contain pure oxygen at 1 atm, initially 300 and 1000 K. Energy and chemistry are enabled. Cantera disables transport. The constant-volume native network uses the same ideal gas and fixed heat-transfer wall. The shared Julia selectors retain their existing testset names. The new reference selectors construct the generic `ct.Reactor`. The previously verified `ct.IdealGasReactor` reference was also rerun. Internal state coordinates are outside these two tests' observable contract.

## Input and assertions

- [Heat transfer 1](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_reactor.py#L455) joins two 1 m³ vessels with area 1 m² and U = 500 W/(m² K). At 10 s the temperatures must agree with rel=5e-7, and the pressures must differ under default approx.
- [Heat transfer 2](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_reactor.py#L479) advances an independent pair to 1 s with each V = 1 m³, U = 200, A = 1. The scaled pair starts from the same T/P/X with each V = 0.25, U = 100, A = 0.5. Heat capacity and conductance both scale by 1/4. Check U A (T_left − T_right) against reported wall power before and after the scaled integration, then compare both final temperatures with the first pair.
- Integration uses rtol=1e-9 and atol=1e-15. Default approx uses max(1e-12, 1e-6 times the absolute expected value). The temperature equilibrium comparison uses 5e-7 in the same formula. The two volume assignments configure a fresh pair before initialization and map to native constructor inputs.

## Reproduction

From the pinned Cantera checkout, run both class variants:

```sh
python -m pytest -q test/python/test_reactor.py::TestReactor::test_heat_transfer1 test/python/test_reactor.py::TestReactor::test_heat_transfer2 test/python/test_reactor.py::TestIdealGasReactor::test_heat_transfer1 test/python/test_reactor.py::TestIdealGasReactor::test_heat_transfer2
```

From the replayed Arrhenius checkout:

```sh
for case in reactor_heat_transfer1 reactor_heat_transfer2 heat_transfer1 heat_transfer2; do
    python test/cantera_parity/reactor_reference.py --case "$case" --source-dir "$CANTERA_SOURCE" --output "$case.json" || exit 1
done
```

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases heat_transfer1,heat_transfer2 -TimeoutSeconds 300 -OutputDirectory thermal-target
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory thermal-all
```

## Results and review

| Julia observable | Left | Right |
|---|---:|---:|
| Equilibrium temperature at 10 s (K) | 478.617927723 | 478.617927565 |
| Pressure at 10 s (Pa) | 161653.205088 | 48495.961510 |
| First pair at 1 s (K) | 407.657943038 | 700.733582867 |
| Scaled pair at 1 s (K) | 407.657943038 | 700.733582866 |

Measured scaled wall powers are -35000.0 W and -14653.781991 W. Negative power denotes heat flowing from right to left. The generic Cantera case reports -14653.782426 W at the endpoint. Cross-solver values are diagnostic; the acceptance comparisons are the within-solver predicates above.

The four original Cantera nodes passed. Julia passed 5/5 and 8/8 respectively. A clean checkout at the previous public batch tree reproduced both targets plus the prior heat flux and RK ignition targets (1329/1329). Full optional regressions passed 10443/10443 in 45 testsets, 716.45 s including startup. All 21 prior numerical outputs and 192 counter records matched the previous full run. Core 1/1, layout 8/8 and runner 11/11 passed separately.

On an isolated checkout, setting U=0 in the equilibrium pair caused exactly the temperature equality and pressure inequality assertions to fail. Halving only the scaled wall area caused both final temperature comparisons to fail, while the two local power identities still passed. The original runtime files were restored before comparing their hashes.

Only the two generic Reactor inventory rows are newly covered in this step, bringing coverage to **53/266/104**. These are shared physical scenarios. The native optional suite remains 44 scenarios plus comparator checks. The nonideal ignition grouped row remains missing.
