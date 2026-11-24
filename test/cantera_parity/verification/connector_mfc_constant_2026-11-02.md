# Constant-flow MFC Jacobian acceptance (2026-11-02)

The [plan](../zeroD_coverage.md#remaining-connector-review-and-constant-mfc-plan-2026-11-02) is complete. Only TestConnectorJacobians.test_mfc_const_flow_cross_reactor_species becomes covered: **45/274/104 ->46/273/104**. Initialization and HO2 remain suspended. Production API, numerical strategy, solver tolerances and original assertions are unchanged.

## Source and inputs

Pinned Cantera commit726522be4e2a13454d8415b7ef799d621f665cf3,
test/python/test_reactor.py:1893-1917; helper1887-1891. The original source method
is executed without rewriting its body, followed by the shared-input reference.
Environment checks verify a clean source checkout, matching imported build,
Cantera4.0.0a2, Python3.12.3 and SUNDIALS7.5. Exact environment details are in raw JSON.
Both sides use unchanged h2o2.yaml, ohmech,10 species/29 reactions, LF SHA-256
`0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`.
No normalization/export is needed. Species order, molecular weights and initial
physical states are checked. Julia runtime and fixed dependencies are hashed.

Left:1000 K,2 atm,X1=H2:2,H:0.01,O:0.005,O2:1,OH:0.01,H2O:0.05,HO2:0.001,H2O2:0.001,AR:8,N2:0.1.
Right:900 K,1 atm,X2=H2:1,H:0.005,O:0.002,O2:0.5,OH:0.005,H2O:0.1,HO2:0.001,H2O2:0.001,AR:8,N2:0.1.
Both volumes1 m3, energy off, MFC left->right0.02 kg/s, no walls. Every reaction
multiplier is zero exactly as the upstream helper specifies; chemistry sources
and their derivatives are inactive. Source-default mixture-averaged transport is
recorded; native zeroD does not invoke transport.

## Coordinates and assertions

Existing MovingWallNetwork(base;walls=()) supplies both volume coordinates without
a physical wall. Native27 entries: left10 masses,T;right10 masses,T;V_left,V_right;
three passive ledgers. Guards check full node/order/species/mass/T/volume layout
before indexing. Cantera24 physical coordinates are [T,V,10 mole amounts] per
vessel. Native one-based order is [11,23,1:10,22,24,12:21]; scales are
[1,1,MW...,1,1,MW...]. Each mapped entry is J_native[i,j]*scale[j]/scale[i].
Ledgers are excluded from the asserted physical blocks.

The separate RHS oracle perturbs all24 physical coordinates on both vessels.
Source ReactorNet.cpp:481-508 and MoleReactor.cpp:64-75 prescribe defaults
rtol1e-9,atol1e-15: T/V step=atol+abs(value)*rtol, species step in kmol=
atol*sum(n_this_vessel)+abs(n_j)*rtol. Apply MW*step to masses; divide central RHS
differences by2*step and output species rows by MW. Complete plus/minus states,
RHS, observed volumes and pressures are retained. Both V probes demonstrably
change the physical volumes and pressures; no zero column is padded.

All three upstream assertions are retained: forward downstream10 species rows
over all12 upstream T/V/species columns match independent FD at rel5e-3/abs1e-10;
the full reverse12x12 production block is zero at abs1e-15; the full reverse FD
block is zero at abs1e-10. Relative bounds use the expected FD value. Added guards
check unchanged input, finite values and both volume probes, yielding6 assertions.
Native production Jacobian remains its existing numerical implementation;
Cantera's production Jacobian is analytical. No algorithm-equivalence claim.

Native isothermal models freeze temperature when evaluating pressure. The selected
constant-flow cross blocks are T-independent, so this does not discard a nonzero
asserted pressure coupling here. Full self-block equality and pressure-dependent
valve/wall T-column semantics remain outside this port. Those candidates require
separate interface review; no API or strategy change is silently introduced.

## Measured results

| Side | Max forward absolute error | Max error/original bound | Max reverse production | Max reverse FD |
|---|---:|---:|---:|---:|
| native | 1.4482535690002463e-05 | 0.91763511583280788 | 0 | 0 |
| cantera | 1.2604905589408411e-05 | 0.76438169029425274 | 0 | 0 |

Original/shared-input Cantera pass; native target6/6 and prior connectors27/27
pass. Full **35 integration +4 static Jacobian scenarios** pass **8781/8781**,
including comparator5/5. Separate core1/1 and layout8/8 pass. Full Pkg.test() is
not claimed. All11 prior trajectories are byte-identical; recorded solver counters
and all3 prior connector structured results are unchanged from all38. New target
and full native data are identical. 112 protected paths
match baseline, covering production, adapters, fixed dependencies and inputs.

Process elapsed times: Cantera 5.7476105 s;
four-connector target 66.5401248 s;
complete group 1155.1075832 s. These include startup and
compilation and are not controlled performance comparisons. Runner deadlines are
300 s and3600 s respectively; exits are0. Testset durations are in case_timings.csv.
Static Jacobian evaluations have no integration retcode, reached time or solver
statistics; these are not applicable rather than reported as zero. The full suite
has one process deadline, not separate deadlines for each testset.

The tightest native entry is downstream N2 versus upstream H: error
3.2942601227773077e-08, original allowed error3.589945574159477e-08 (91.76%).
This passes with limited margin; it is not evidence of cross-platform robustness.
Both sides have100 nonzero forward species entries. A separately retained
closed-form constant-MFC derivative diagnostic supports the physical mapping;
it is not substituted for the original predicates. An initial audit parsing
failure retained whitespace in source composition keys; stripping those keys
fixed only the audit. The failed tool outcome is transcribed in audit_repair.txt.

## Adversarial review

An independent Python reconstruction checks all mappings, source FD steps and24
saved probes before re-evaluating the three original predicates. Six intentionally
corrupted variants are rejected: omitted volume column; unperturbed right volume;
missing reverse rows; forward entry beyond its threshold; nonzero reverse
temperature row in the production matrix; nonzero reverse volume row in FD.
This specifically catches implementations that only check reverse species rows.
No blocking issue remains in the implemented contract. It does not exercise active
chemistry, prove unasserted self-block equivalence, or resolve the suspended cases.

Only one of423 coverage rows changes, to layer B with the exact new testset.
Old provisional native mapping: `test/reactor_networks_native.jl:5 :: native reactor network balances and devices`. Totals: **46 covered /273 missing
/104 not_applicable**. Issue5 remains open.

## Reproduction and evidence

```powershell
& ./test/cantera_parity/run_solver_regressions.ps1 -Cases connector_mfc_constant -TimeoutSeconds 300 -OutputDirectory <fresh-directory>
& ./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 3600 -OutputDirectory <fresh-directory>
```

Pinned Python reference: `reactor_reference.py --case connector_mfc_constant
--source-dir <clean-pinned-source> --output <fresh-json>`.
[Raw evidence](connector_mfc_constant_2026-11-02/) retains logs, full matrices,
probes, timings, environment/source/input hashes, executed scripts, baseline CSV,
independent audits and final artifact hashes.
