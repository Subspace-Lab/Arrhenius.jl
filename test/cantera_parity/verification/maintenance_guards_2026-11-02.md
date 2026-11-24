# Independent connector/runner maintenance (2026-11-02)

## Plan and acceptance boundary

Keep coverage44/275/104 and all37 accepted scenarios. No production API, solver policy, physics assertion, tolerance, default-test registration or handling of suspended initialization/HO2 cases changes. Do not combine broad Python/helper refactoring with this maintenance.

1. Add a test-local layout guard to both connector Jacobian fixtures, before indexing. Validate named-node order, offsets, length, species order, mass coordinates and temperature positions. Exercise positive and negative cases, including same-length coordinate changes. Re-run both original connector tests and require their saved numerical data identical to the accepted baseline.
2. Explain why WSR24 needs no normalization in its manifest and exporter output. Change comments only in the shared manifest. Re-run the exporter in a fresh folder, including strict reload and four-state equivalence; retain existing mechanism/equivalence files unchanged.
3. Add an optional Windows/PowerShell7 external-process wrapper with an explicitly supplied wall-clock deadline. Preserve the original Julia entry and single-process all ordering. Capture stdout/stderr, actual process outcome, total elapsed time and Test-summary per-case elapsed times. Reject reused output directories. Exercise success, nonzero exit, missing executable, timeout, descendant termination, partial logs and invalid inputs. A process timeout is not a solver step/iteration policy. Single-case invocations give a per-case deadline; a grouped/all invocation has one shared deadline, not separate limits per testset.
4. Validate the wrapper on real connector targets. Publish the previous accepted all37 per-case times as a labeled historical baseline, separately from new targeted timings; do not invent a fresh complete-suite run. This scoped maintenance requires affected targets and guard/control-path tests, not a repeat of unchanged integration physics.
5. Perform an adversarial review of the final code and evidence. After maintenance acceptance, read the pinned species-subset MFC source and map all asserted blocks. Candidate review is not coverage and is not permission to add an API or change numerical strategy.

## Acceptance

Both connector targets pass their unchanged6+5 assertions. Their complete saved
states, production Jacobians, independent FD data and metadata are identical to
the accepted all37 baseline. Layout guards pass8/8, including wrong node/species
order, wrong offsets, extra coordinates and same-length mass/T swaps. Guards
throw before index use; they are test-local initial-fixture contracts, not a new
production state-layout API.

The final process runner passes11 control-path checks, plus2 real entry checks:
an actual Julia timeout returns wrapper124 (the killed child's actual code is
separately retained), and an unknown selector returns1. The timeout entry also
restores the caller's environment. Final real connector execution from a changed
PowerShell directory succeeds in43.9682073 s with its explicit300 s deadline.
The earlier targeted runs and intermediate runner checks remain archived.

WSR export passes strict loading and all four input-equivalence states. The new
raw export differs from the shared raw file only in its generated date field;
shared mechanism/equivalence files retain their hashes. Removing the five added
manifest comment lines recovers its original hash exactly. Exporter-generated
manifests carry the same explanation, preventing later regeneration from losing
it. Production source, adapter, environment and other fixture checks cover108
protected paths/semantic checks.

The timing CSV contains37 historical scenarios plus comparator5/5, totaling8759
assertions, from the previous accepted full run. It is explicitly historical;
this maintenance ran affected targets and negative/control checks, not a new
complete integration suite. No coverage row changes:44/275/104. Initialization
and HO2 remain suspended.

## Final adversarial review

| Attack / concern | Result |
|---|---|
| Same-length layout reorder silently selects wrong columns | Node/offset/species and explicit mass/T checks reject it; negative tests pass. |
| A hung child leaves descendants running | A real sleeping process tree is terminated; partial stdout survives; timeout has distinct status. |
| A failed or missing executable is reported as a pass | Exit7 and missing-executable tests are distinguished from success. Unknown Julia selector also fails through the real entry. |
| Failed Test summary is parsed as a successful timing row | Multi-count failure row is rejected. Timings do not certify full test census; raw failure output and process status are retained. |
| Old evidence overwritten | Existing output directory is rejected before launch. |
| Space-containing paths / changed PowerShell location | Quoted-argument test and real changed-location target pass. Review found and fixed dependence on the process working directory for relative output paths. |
| Process startup extends the requested waiting budget | Review found and fixed waiting for the full budget after launch: remaining wait now subtracts startup elapsed time. Cleanup latency may still extend observed wall time. |
| Cancellation leaks the running child | Finally-block cleanup was added. Forced termination of the wrapper/OS failure is not claimed to be covered, nor was interactive Ctrl-C exhaustively tested. |
| Maintenance changes numerical policy or claims new coverage | Protected-source/fixture checks pass; CSV is unchanged; all37 timing report remains labeled historical. |

No unresolved blocking issue was found within this maintenance scope. The runner
is Windows/PowerShell7-only, requires an explicit deadline, and applies one deadline
per invocation. It does not implement independent per-testset limits inside all;
use separate one-case invocations for that requirement. These limits are stated
in README rather than hidden behind a broader claim.

[Final independent audit](maintenance_guards_2026-11-02/final_audit.json),
[raw evidence](maintenance_guards_2026-11-02/), and
[subsequent candidate review](species_subset_mfc_review_2026-11-02.md).
Executed-source and archive SHA-256 indexes are retained in the raw evidence
folder; prior accepted logs and raw results remain unchanged.
