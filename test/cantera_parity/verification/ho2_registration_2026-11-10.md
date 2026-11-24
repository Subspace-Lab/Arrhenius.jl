# HO2 registration and full zeroD regression — 2026-11-10

This stage registers an existing repaired case; it adds no physical scenario,
changes no numerical policy and relaxes no assertion. Native baseline is
`1b3cd11262515a19f9f2e6bdfaa640dd5c1c069a`; accepted public source tree is
`7febaf117a6086e7bb4952dafe7a6e9359cfff57`. Accepted #83 already fixed the gas-phase
signed-activity behavior. #85/#86 surface candidates are not applied.

## Original case and reference

Pinned Cantera `726522be4e2a13454d8415b7ef799d621f665cf3`,
`TestIdealGasReactor.test_mass_flow_controller`: 300 K, 1 atm pure O2 vessel,
1 m3; 300 K, 10 atm pure H2 reservoir; triangular pulse area 0.1 kg.
Energy and chemistry enabled. Integration rtol=1e-11, atol=1e-15, dtmax=0.05 s;
flow samples at 0.1/0.3/1.0/1.2 s, endpoint at 2.5 s. Total/species mass gates
retain upstream rel=1e-6, abs=1e-12 and the original argument direction.
No forced corner stops, output normalization, clipping or changed chemistry.

[Fresh prior ZD003 evidence](https://github.com/Subspace-Lab/forgekinetic/tree/codex/zerodim-17-energy-heat-batch/tools/orchestration/zd-003-signed-rates-baseline/correctness-replay)
ran the pinned original Cantera node (1/1), native selector (16/16), instrumented
repeat (16/16) and existing signed-state guard (8/8) on this same native baseline.
Native HO2=-1.6365540201796873e-23 kg; Cantera=1.8259780220662835e-18 kg.
All ten species satisfy the original gates. These endpoint numbers and pulse
334/72 accepted/rejected steps belong to that instrumented run, not new statistics
invented for the all-suite output. This stage reuses that reference evidence;
it does not claim a second Cantera execution.

The [original failure](pulse_failure_2026-10-29.md), HO2=4.583077935302556e-12 kg
against 1e-12 kg, is retained byte-for-byte: SHA-256 `1f8c6ba7490789f1476b168bdabcc8134c2cefb940eb3877e09693cbdc3003f8`.
Its missing/excluded wording is its historical status, not the current inventory.

## Newly executed regression

- Optional `all`: **45 scenarios, 46 testsets, 5971/5971 assertions** including
  five comparator self-checks and the pulse's 16 assertions.
- Every preceding 44-case name/order/assertion count matches the accepted archive.
- All 21 numerical result files are byte-identical; all 192 emitted old-case
  solver counter entries match. The pulse's official selector does not emit its
  solver statistics; see the separately identified ZD003 instrumented evidence.
- Core guard 1/1, layout guard 8/8, runner controls 11/11 pass separately.
- Julia 1.12.7, one Julia/BLAS/OMP thread; original locked reactor environment,
  Manifest SHA-256 `5847fff16eeda51c96bd8e1b588399ce6b101f92ef0ff640850a7f55b2a5b181`.
- Full process elapsed 779.474612 s, deadline 2400 s. Includes loading,
  compilation and briefly concurrent guard checks; not a performance comparison.
- Package-wide Pkg.test was not rerun for this registration-only increment.

[Portable batch24 evidence and replay](https://github.com/Subspace-Lab/forgekinetic/tree/codex/zerodim-17-energy-heat-batch/tools/zerodim-parity/batches/24-ho2-registration)
contains full logs, case timings, numeric outputs, audit and patch/tree receipts.

## Coverage and limitations

Only `TestIdealGasReactor.test_mass_flow_controller` is promoted: **54 covered,
265 missing, 104 not_applicable**, 423 unique rows. Other inherited reactor variants
are not inferred covered. Behavior: original pulse gates pass. Trajectory accuracy:
no new full-trajectory error gate or universal accuracy claim. Regression: the
optional complete suite and named guards pass, distinct from package/CI scope.
No-argument mode and `all` select the same registered cases; explicit pulse still
uses the identical test body. Initialization #59 stays open; #80 stays paused;
#85/#86 remain unmerged. This record does not establish lifecycle/API equivalence.

Reproduce from the verified replay tree with Julia 1.12.7 and the locked environment:

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory <fresh-directory>
```
