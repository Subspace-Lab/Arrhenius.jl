# Independent small maintenance acceptance (2026-10-30)

Only three changes: zerodim.simple reads integration tolerances from its GRI30 manifest; README states the current CI boundary; the constant-pressure exporter checks that disabling only the raw third-body skip flag raises the expected C2H6 ThirdBody::checkSpecies error. No assertion, tolerance value, solver policy or production code changes. Broad helper refactoring is deferred.

The Julia target passes46/46 with Success. All21 saved rows are byte-identical to the accepted zerodim.simple baseline and every printed solver counter is identical. The new exporter passes the existing structural/four-state equivalence checks and the negative loading check. A valid normalized input is deliberately passed to the negative checker and correctly rejected as an invalid negative-test fixture. The original shared fixture hashes remain unchanged.

This maintenance is validated independently before adding the combustor case. The unchanged full28 suite is not rerun here; the following stage must run the full group after its own target passes. No new coverage is claimed:35/284/104. Initialization and HO2 remain deferred.

Raw evidence: [audit](maintenance_2026-10-30/audit.json), [native log](maintenance_2026-10-30/native_target.log), [native samples](maintenance_2026-10-30/native/zerodim_simple.native.csv), [export equivalence and exact expected error](maintenance_2026-10-30/export_equivalence.json). The audit records source hashes and actual elapsed time including process startup/loading/compilation. Old evidence is retained unchanged.
