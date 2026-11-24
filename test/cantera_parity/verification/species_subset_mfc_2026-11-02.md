# Species-subset MFC acceptance (2026-11-02)

The [authorized plan](../zeroD_coverage.md#authorized-species-subset-mfc-execution-plan-2026-11-02) is complete. Only TestConnectorJacobians.test_species_subset_mfc_cross_reactor changes to covered: **44/275/104 ->45/274/104**. Initialization and HO2 remain suspended. Production API, numerical strategy, original assertions and thresholds are unchanged.

## Pinned source and formal input gates

Source commit `726522be4e2a13454d8415b7ef799d621f665cf3`, test_reactor.py:2084-2133. The original source method was executed unmodified, in addition to a reference using the same normalized input as Julia. Reference environment checks verify clean source, matching imported build, Cantera4.0.0a2,Python3.12.3,SUNDIALS7.5; exact paths are in raw JSON. Native runtime and fixed example/reactors dependency hashes are archived. The equivalence record's nested environment retains the common h2o2 environment gate's provenance label; the fixture manifest and formal reference identify this subset test explicitly.

The upstream phase has H2,O2,AR in that order and zero reactions. Its self-contained precision17 export is legal Cantera input with `reactions: none`; the existing Julia reader requires a supported representation. The scripted conversion changes only `phases[0].reactions` to `[]`. The raw export remains intact. Parsed-data equality rejects any other change, including species order or thermo parameters. Both strict reloads preserve zero reactions and species thermodynamic definitions. No production-reader change is included.

| Input digest (LF SHA-256) | Value |
|---|---|
| Source h2o2.yaml | `0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4` |
| Original phase definition | `36c2f00ff55266e55ad171c074e58cc9a9f75da4103bcca976c9f7a8630e9a5d` |
| Raw export | `689521645965946d4f8b981f21ac13dc6d979223b76504287591e1804c0cf9d5` |
| Normalized export | `b7a59f95e59c02ec9f0f7860328cafecf6a764933d9f83c96ff93f12f8ed9193` |

Formal source/raw/normalized comparisons use four states:1000 K/2 atm/X=2:1:8;
900 K/1 atm/X=1:0.5:8;300 K/1 atm/equimolar;2500 K/2 atm/equimolar.
Retained values include T,P,X,Y,density,MW,partial molar h,u,cp,s and net production
rates. Forward/reverse rate arrays are empty because this phase has zero reactions;
their recorded entry counts are0, not evidence of nontrivial rate agreement.
All nonempty arrays use the pinned write/reload rule
`abs(a-b)<=max(1e-12,1e-6*abs(b))`. Actual maximum absolute input difference is
0; full snapshots and per-field relative/absolute metrics are
in the fixture equivalence record. Native loading, order and count checks pass.
The preceding candidate preflight is not reused as formal acceptance.

## Physical setup and complete coordinate mapping

Upstream1000 K,2 atm,H2:O2:AR=2:1:8; downstream900 K,1 atm,H2:O2:AR=1:0.5:8
in full10-species h2o2/ohmech. Both volumes1 m3, energy off; upstream has no
reactions and downstream multipliers are all zero. MFC upstream->downstream
0.02 kg/s, no walls. Source-default transport settings are retained in reference
JSON; native zeroD does not call transport.

Existing `MovingWallNetwork(base; walls=())` supplies real volume coordinates
without introducing a physical wall. Native state20 entries comprise3 upstream
masses,T_up;10 downstream masses,T_down;V_up,V_down;3 passive ledgers. Explicit
guards check node order, offsets, species map, volumes, ledger positions and all
initial mass/T/V values before indexing. Cantera uses17 physical entries.

All10 downstream species rows are mapped over **five** upstream columns
`[T_up,V_up,n_H2,n_O2,n_AR]`, native indices `[4,16,1,2,3]` (one-based).
Divide output species rows by downstream MW; multiply species input columns by
upstream MW. T/V input scales are1. No volume column is synthesized; ledger states
are additional bookkeeping and excluded from the asserted physical block.

Production native moving_wall_jacobian! remains its existing numerical algorithm.
The separate RHS oracle follows ReactorNet.cpp:481-508 and MoleReactor.cpp:64-75:
T/V step=atol+abs(value)*rtol; species step=atol*sum(n_up)+abs(n_j)*rtol,
with defaults rtol1e-9/atol1e-15. Apply MW*h to mass coordinates and divide the
RHS difference by2h. Saved full perturbed input vectors, RHS outputs and observed
upstream volumes/pressures prove that V changed and propagated through the RHS.
The resulting zero V derivative reflects constant prescribed flow and fixed
composition amounts, not a padded zero column.

All13 original assertions are retained:3 shared rows each have a nonzero entry;
7 downstream-only rows are zero across5 columns at abs1e-15;3 shared full rows
match independent FD at rel1e-4/abs1e-10. Native adds unchanged-state, finite-data
and actual-volume-propagation guards, for16 assertions. This tests the original
cross-reactor derivative contract, not active chemistry or algorithm equivalence.

## Results and complete regression

| Side | Max shared absolute error | Max error / original allowed limit | Max absolute V-column value |
|---|---:|---:|---:|
| native | 1.2266555767664888e-08 | 0.049466836308973756 | 0 |
| cantera | 6.5552065737356502e-09 | 0.036814248658674741 | 0 |

Both downstream-only blocks are zero. The ratio is computed per element using
its own original bound; no absolute-only or relaxed criterion is substituted.
Cantera original/shared-input references pass; native target16/16 and both
previous connector targets6/6 and5/5 pass. Complete **35 integration +3 static
Jacobian scenarios** pass **8775/8775**, including comparator5/5. Separate core
guard1/1 and layout checks8/8 pass. Full Pkg.test() is not claimed.

All11 prior saved trajectories are byte-identical; every recorded solver counter
matches the accepted all37 baseline. Both prior connector structured results are
identical, and new target/full native data are identical. Protected production,
adapter, environment and previously shared input checks cover
108 paths; accepted WSR comment-only maintenance
is checked against its own baseline. No numerical-policy change is hidden in this port.

Process times: Cantera reference 10.1142434 s; combined native
target 58.9142404 s; full group 1143.8177169 s.
The bounded runner used300 s for target and3600 s for full; all completed with
exit0. Times include startup/compilation, not controlled performance comparisons.
Input-export elapsed time was not separately captured. Static derivative tests
have no integration retcode/time-step statistics; these are not reported as zero.
Full-run [per-case timings](species_subset_mfc_2026-11-02/all38/case_timings.csv)
separate testset timing from total process wall time.

Logs became visible in a batch late in the full run. A separate bounded
disable_chemistry diagnostic passed5/5 in45.1651024 s while the original full
process continued unchanged. It is archived separately and excluded from8775.
The full process then completed normally; no failure or numerical repair is
inferred from delayed log visibility.

## Final adversarial review

Five deliberate corruptions are rejected by the independent audit: an additional
input species-order change, a recorded V probe left at the unperturbed value, a
missing V column, a downstream-only entry above its zero bound, and a shared-row
entry above its FD bound. The audit reconstructs production-block scaling and
FD values from saved matrices and complete perturbations, and rechecks all13
source assertions. Source inspection confirms the selected volume column comes
from the production20x20 Jacobian and that independent RHS calls include V.
A zero-column result by itself would not establish this, so probe-state and
volume/pressure propagation evidence is required. Exact layout guards prevent
unequal-species indexing from silently selecting the wrong rows.

No unresolved blocking issue was found within this port's scope. Limitations:
only asserted cross blocks are covered; chemistry is intentionally inactive as
upstream specifies; algorithms are not claimed equivalent. Full integration
regressions use the unchanged single-process order and one process-level deadline,
not independent per-testset deadlines. Initialization and HO2 remain suspended.

Only one coverage row changes, from its provisional layer to actual optional
layer B. The old related mapping was `test/reactor_networks_native.jl:5 :: native reactor network balances and devices`; it is replaced by the exact
new testset. Totals: **45 covered /274 missing /104 not_applicable**,423 rows.
This does not close issue5. Input normalization is test-fixture adaptation, not
a claim that the production reader now supports reactions:none.

## Reproduction and evidence

```powershell
& ./test/cantera_parity/run_solver_regressions.ps1 -Cases connector_species_subset -TimeoutSeconds 300 -OutputDirectory <fresh-directory>
& ./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 3600 -OutputDirectory <fresh-directory>
```

Python reference selector: `reactor_reference.py --case connector_species_subset
--source-dir <clean-pinned-source> --output <fresh-json>` using the pinned Python.
Exporter: `export_subset_fixture.py --source-dir <clean-pinned-source>
--output-dir <fresh-fixture-directory>`. Both solvers share the registered normalized
fixture; do not overwrite it during reproduction.

[Raw evidence](species_subset_mfc_2026-11-02/) retains original logs, complete data,
timings, source checkpoints, executed scripts, coverage-before CSV and independent
audits. Artifact and final-source SHA-256 indexes accompany that archive.
