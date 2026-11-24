# Constant-pressure single-reaction hydrogen Jacobian

## Plan

Baseline: 47/272/104, 40 optional scenarios, ForgeKinetic PR #73.
Port only pinned `TestReactorJacobians.test_const_pressure_hydrogen_single`
at `726522be4e2a13454d8415b7ef799d621f665cf3`, preserving the entire 11x11
comparison at rel=1e-3 / abs=1e-4. Shared h2o2.yaml/ohmech, 1000 K, 1 atm,
H2:H:H2O=1:2:2, initial volume2 m3, adiabatic, only zero-based reaction14 enabled.
Cantera uses its original default transport; native zeroD invokes no transport.

Existing public `IdealGasReactor`, `reactor_problem`, `reactor_rhs`, and
`reactor_jacobian!` provide the needed closed constant-pressure Y/T equations.
Construct a caller-owned QNDF integrator from the public problem, using existing
rtol1e-9/atol1e-15, then call `step!` once. This tests the public dense FD
Jacobian callback, not the separate automatic structured solver/analytic adapter.
No production API, global solver default or numerical policy is modified.

Native state u=[Y,T]; physical upstream coordinates q=[T,n]. With M=W*n and
Y=W.*n/M, define A=dY/dn=(diag(W)-Y*W')/M. The physical RHS is
g=[f_T, M*diag(1/W)*f_Y]. Map the production Jacobian J=df/du as:

- d(g_T)/dT = J_TT; d(g_T)/dn = J_TY*A.
- d(g_n)/dT = M*diag(1/W)*J_YT.
- d(g_n)/dn = diag(1/W)*(f_Y*W' + M*J_YY*A).

The outer product retains the extensive-mass direction despite the singular
normalization derivative A. Do not invert A or use fixed-mass diagonal scaling.
Preserve the raw accepted state; physical-coordinate evaluation normalizes Y
from n locally and never projects or overwrites the integrator state. Record both.
Initial volume sets the mass scale through density; each perturbation recomputes
its mass and implied volume at the same pressure. No volume API is added.

Use the exact Reactor forward difference rule, h=max(abs(q_j),1000*atol)*sqrt(eps),
and save all 11 physical probes, mapped states, RHS values and full matrices.
Run original/shared-input Cantera, Julia target, the existing CV reference as a
helper-regression check, then all41 scenarios (37 one-step/time integrations +4
static checks), comparator and lightweight/runner guards. Verify prior16 numerical
records and144 logged solver-counter records stay identical. Independently audit
all121 entries and reject dropped T-T entries, normalization/mass-term omissions,
fabricated probes and out-of-limit matrices. Finally reproduce the new target
from a clean patch checkout and publish a small ForgeKinetic PR dependent on #73.

Only full acceptance changes this one row to48/271/104. Initialization #59,
HO2 #60 and isothermal connector mapping #72 remain suspended. A failure does
not authorize adjusting tolerances, adding APIs or changing numerical policy.

## Execution

Accepted under user authorization. The original Cantera method and shared-input
reference pass; Julia target **126/126**, comprising all121 matrix entries plus
five execution/state guards. Complete41 scenarios **9032/9032**, including the
five comparator checks (42 testsets). Core1/1, layout8/8 and runner11/11 pass.
[Portable logs, matrices, hashes and timings](https://github.com/Subspace-Lab/forgekinetic/tree/codex/zerodim-13-cp-hydrogen/tools/zerodim-parity/batches/13-cp-hydrogen/evidence) accompany the ForgeKinetic
incremental patch; no unrun row is reclassified.

| Measurement | Native | Cantera |
|---|---:|---:|
| Accepted steps | 1 | 1 |
| Time after one step (s) | 1.9955625498157085e-10 | 0.00014552922594605376 |
| Maximum element error / original bound | 0.000509541657 | 0.000200893896 |
| Process time, including startup/compilation (s) | 42.289 | 11.590 |

Full suite process time: **693.201 s**. These are execution
measurements, not controlled performance comparisons. Native retcode is
`Success`; Cantera exposes no retcode here. Full available counters
are retained. Numerical rtol/atol are equal, but apply to Y/T versus T/n states;
error weights and step selection are not claimed equivalent. Initial mass is
0.19528776958536009 kg. Accepted-state sum(Y) is
1; the observed inverse-mapping
state difference is 0.

Environment: Julia1.12.7, SciMLBase2.155.2, OrdinaryDiffEqBDF1.26.0, one Julia /
OpenBLAS thread; pinned Cantera4.0.0a2 / Python3.12.3. Historical dependency lock
and existing caches reused. Cantera transport is `mixture-averaged`.
No full Pkg.test(), fresh-machine installation or structured-analytic-Jacobian
coverage is claimed.

All16 prior saved numerical records (11 trajectories,4 connector matrices and
the CV hydrogen record) remain byte-identical. All144 previously logged solver
counter records match in order. The new record is identical in individual and
whole-suite runs. The existing CV reference result, including complete matrices,
FD steps, state and solver statistics, is unchanged by the shared helper branch.

## Adversarial review and corrections

The independent audit rebuilds each normalized state, mass, volume and mapped RHS
from all11 real perturbations; checks the full chain rule from saved native J/f
using scalar sums; and applies pytest.approx to every one of the121 original
elements. It rejects seven corruptions: T-T over-limit, species over-limit,
missing T-T data, omitted output-mass term, naive fixed-mass scaling, fabricated
probe and changed FD step. The actual pre-fix overwritten checkpoint is also
rejected with the expected audit exit1. Over-limit cases are separately checked against the
original rel/abs predicate, not just against mapping consistency.

The largest output-mass-term contribution here is only
1.4885037e-13 1/s. Omitting it
**still passes the upstream numerical predicate at this particular state**;
the separate algebraic reconstruction detects the omission. Its rel1e-12 /
abs1e-20 roundoff check compares two evaluations of the same mapping formula;
it neither replaces nor loosens the upstream rel1e-3 / abs1e-4 criterion.
This sparse, nearly stationary state does not establish broad finite-state
chemistry or cross-solver trajectory accuracy.

Two initial test-only problems were corrected before acceptance: the new file
needed an explicit LinearAlgebra import when run alone; then independent audit
found Julia closure capture overwrote the saved mapped-state checkpoint during
probing. Explicit local probe buffers fixed that. The retained diagnosis shows
all integration states, mapped Jacobians, FD matrices, step sizes and counters
were unchanged by the scope correction; the mapped-state evidence is now correct.
Initial failed logs remain archived locally; successful replacement runs are
identified in the delivery. No production defect or numerical-policy fix is claimed.

Only this coverage row changes to covered/layerB: **48/271/104**,423 rows.
The previous related mapping `test/reactors_native.jl:20 :: closed native ideal-gas
reactors` is retained in the delivery receipt. #59, #60 and #72 remain suspended.

## Reproduce

Apply the ForgeKinetic patch series and use its pinned example environment:

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases hydrogen_const_pressure -TimeoutSeconds 300 -OutputDirectory <fresh-directory>
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 3600 -OutputDirectory <another-fresh-directory>
```

Inside pinned WSL Python, from the patched Arrhenius root:

```sh
python test/cantera_parity/reactor_reference.py --case hydrogen_const_pressure --source-dir "$CANTERA_SOURCE" --output "$NEW_REFERENCE_JSON"
python test/cantera_parity/hydrogen_const_pressure_audit.py "$NATIVE_RESULT_TOML" "$NEW_REFERENCE_JSON"
```

Process deadlines are wall-clock guards, not solver bounds.
