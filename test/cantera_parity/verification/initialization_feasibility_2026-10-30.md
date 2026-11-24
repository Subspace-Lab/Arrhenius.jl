# Initialization feasibility audit (2026-10-30)

Status: planning evidence only, not a registered parity test or accepted coverage. The preceding zerodim.simple stage is accepted at 28 scenarios/8476 assertions and coverage35/284/104. This audit changes none of those numbers. zerodim.test_individual_reactor_initialization remains missing; no initialize API, solver policy or tolerance is changed.

## Exact source and preliminary results

The pinned source is test/zeroD/test_zeroD.cpp:158-193 at commit726522be4e2a13454d8415b7ef799d621f665cf3. The unmodified existing C++ binary was filtered to zerodim.test_individual_reactor_initialization and passed exactly1/1. It retains the original reactor->initialize(), network.initialize() and 1-s advance, followed by comparison with independently initialized UV equilibrium.

Initial conditions are1100 K,10 atm,H2:1,O2:0.5,AR:8 with the shared original h2o2.yaml/ohmech phase and default1 m3 volume. The C++ Generic Reactor::getState layout is [mass,volume,total_internal_energy,Y...] (src/zeroD/Reactor.cpp:62-75). Every element uses the absolute EXPECT_NEAR bound1e-7, with no relative-tolerance term. T is not itself an element of this generic source state vector.

The existing native IdealGasReactor uses [Y,T] and has no corresponding stateful public initialize method. The planning probe prepares reactor_problem, confirms the initial state is unchanged, and solves that prepared problem with the unchanged existing native_bdf, rtol1e-9/atol1e-15. It reconstructs [mass,volume,U,Y] from the **actual advanced thermodynamic state**, using U=mass*internal_energy; it does not substitute the initial conserved U. Expected state comes from an independent native UV-equilibrium solve.

The native solve returns Success at1 s. Only U exceeds the original absolute bound:

| Component | Absolute difference | Source absolute bound |
|---|---:|---:|
| mass (kg) |8.881784197001252e-16|1e-7|
| volume (m3) |0.0|1e-7|
| total internal energy (J) |0.0013302635634317994|1e-7|
| maximum species Y |5.9884597281012475e-12|1e-7|

Advanced U=971244.3023660148 J; independent UV-equilibrium U=971244.3036962784 J. The U difference is about13302.6 times the source bound. Actual T=2671.7750554913887 K and equilibrium T=2671.7750560287313 K are diagnostics, not a separate source temperature assertion.

## Interpretation and next decision

This does not prove that preparation/initialization caused the U difference. The probe has not yet compared a fresh solve with an otherwise identical pre-prepared solve. Different state coordinates and derived-energy integration error are possible explanations, not established causes. The existing Python UV-equilibrium port uses different comparisons and cannot be promoted into coverage for this stricter C++ vector test.

Before a formal port, separately establish (1) the permitted correspondence of reactor_problem preparation with the source lifecycle and (2) the cause of the U discrepancy under the original bound. Do not hide it using initial U metadata, loosen the bound, reduce tolerances, or modify solver/coordinate policies without a separate discussed plan. The source [mass,V,U,Y] values are not all within tolerance in this native probe, so the row must not be marked covered.

The probe scripts below are exact retained copies for review, not registered tests. Their original execution paths were local-results/probe_initialization_state.jl and local-results/probe_initialization_cpp.py; their relative paths assume those original locations.

## Raw planning evidence

- [native_state_probe.toml](initialization_feasibility_2026-10-30/native_state_probe.toml): SHA256 `980e15cfc3a53fcec4707403ee458b690edad54ca27b8ca04ddef0e4884f9421`
- [cpp_probe_result.json](initialization_feasibility_2026-10-30/cpp_probe_result.json): SHA256 `1a88b8812432ed25fb9cceb8be83b8c75eb280b369abecb722a960569050a1ff`
- [gtest.log](initialization_feasibility_2026-10-30/gtest.log): SHA256 `e8c460090c9b260989a0afe034246b2fc5361834ad778243aa40bb1aa7b7d3c9`
- [gtest.xml](initialization_feasibility_2026-10-30/gtest.xml): SHA256 `03d318257b29767f4c5f55c5e68532f038f53fe145313896e7050d4cd23e6806`
- [executed_native_probe.jl.txt](initialization_feasibility_2026-10-30/executed_native_probe.jl.txt): SHA256 `b9824d1de0b91d95f7900a3aba284bf9d82673add1890671e946957f4b3594f7`
- [executed_cpp_probe.py.txt](initialization_feasibility_2026-10-30/executed_cpp_probe.py.txt): SHA256 `5b80c89723685a986e13277dcb6392602dd2b7c1da79a54a424505b663d0c11c`
