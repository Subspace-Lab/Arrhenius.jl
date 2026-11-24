# Original C++ zerodim.simple verification (2026-10-30)

Status: accepted. The unchanged original C++ reference passes 1/1, native target 46/46, full 28-case optional suite 8476/8476 (including five comparator selfchecks), and separate core guard 1/1. Only zerodim.simple is newly covered: **35 covered / 284 missing / 104 not_applicable**.

Executor: the agent, under the user's authorization for routine build/reference/native verification. No production API or solver policy is changed.

## Frozen input and original reference

The exact case is test/zeroD/test_zeroD.cpp::zerodim.simple at commit 726522be4e2a13454d8415b7ef799d621f665cf3, source line 13. Its LF source SHA256 is 18cec1895658b480216c66cb6d52688bb76ab5f1a44f097b1b06af0f9da66233. The [shared original GRI30](../fixtures/cantera-726522be/gri30.yaml) is byte-identical to data/gri30.yaml in that checkout. Its [manifest](../fixtures/cantera-726522be/gri30_provenance.toml) retains Git blob 9a62004ec17bbec8ac11e97785932d426dd58610 and SHA256 06650b1e0ee0012f6903d5328b1bb218cb6007d07f8ebe375d18f24811039345. Phase gri30 has 53 species/325 reactions; both readers check the exact species order. No export, normalization or repository-mechanism substitution occurs.

The fixture's local .gitattributes pins gri30.yaml to LF so core.autocrlf=true cannot change the original bytes on a future Windows checkout.

The original C++ setup explicitly disables transport with newSolution(..., "none"). It uses 1050 K, 5 atm (506625 Pa), CH4:1,O2:2,N2:7.52, default volume 1 m3, enabled chemistry/energy and a closed constant-volume IdealGasReactor named simple. Its source-default nominal rtol=1e-9/atol=1e-15 are retained. The reference JSON's input section records source settings/defaults and Python phase metadata; these are not extra state/tolerance observations from the unchanged C++ program.

The environment gate verifies clean fixed HEAD, embedded Python commit, Cantera 4.0.0a2, actual import/interpreter paths, SUNDIALS 7.5, SCons 4.11.1, compiler and existing GoogleTest/Cantera libraries. The virtual-environment interpreter drives SCons; default PATH lookup is not used. The formal build-zeroD command exited 0 and generated build/test/zeroD/zeroD. No installation was needed. The runner sets CANTERA_DATA to the shared fixture folder, uses a fresh working directory, and checks ldd resolves the source-tree libcantera_shared.so.4.0.0. Binary/library SHA256 values are retained in the raw JSON.

The unmodified original binary executed with --gtest_filter=zerodim.simple. XML proves exactly one executed, completed, passing case, not zero matches. Original reactor->initialize() and network.initialize() calls remain in that C++ test. Python orchestrates input gates and the real binary; it does not replace the reference integration. The program does not print final time, full states or solver statistics; those fields remain null/unavailable, never invented as zero.

A separate synthetic runner check simulated exit code 0 with an XML report containing zero tests. The runner correctly rejected it as invalid_reference_test_selection. This [negative-check record](zerodim_simple_2026-10-30/zero_match_guard.json) has SHA256 `41ff4d9a7fa00be7a746559ccce323a1a010316e375dd6113c3d0e55bfa2e2b6`; it is not another upstream reference run or integration scenario.

## Native correspondence and assertion boundary

[Native case](../reactor_cpp.jl) uses existing WellStirredReactor, a single-node ReactorNetwork and native_network_bdf QNDF. The node identifier :simple maps the source name; this does not add a general name/initialize API. The Julia zero-dimensional RHS does not call transport. Nominal integration tolerances match the pinned defaults; no dtmax, tolerance floor, new error rule or changed negative-species policy is introduced.

The source checks T >= 1050 K **before** each advance, then targets reported network.time()+0.005 until t>=0.1. Native sequential Float64 addition produces 21 saved times (including the initial state), ending at 0.10000000000000002. Exactly the first 20 temperatures are checked without an assertion tolerance; the final sample has no additional temperature-floor assertion. CVODES may overshoot internally, but CVodeGetDky interpolates back to the target and currentTime reports that target (src/numerics/CVodesIntegrator.cpp:522-527; ReactorNet.cpp:351-356). There is no output-time drift from internal overshoot. The 5 ms sample interval is not an internal-step bound.

All 21 state vectors are finite and every requested time is retained. Native returned Success, final T=2894.9212398643467 K, final P=1438184.2665081366 Pa and minimum checked T=1050.0 K. Accepted steps=12282, rejected steps=3667, RHS evaluations=39348, Jacobians=410, nonlinear convergence failures=619. These are native observations; the original C++ gtest exposes no comparable counters.

This smoke regression verifies completion, the original temperature floor, finite native states and arrival at the requested times. It does **not** validate trajectory accuracy against Cantera, require monotonic heating, or claim equivalent solver failure control. All 21 native rows retain columns t,T,P,Y[53] for inspection.

## Actual timings

| Measurement | Seconds | Included work |
|---|---:|---|
| Formal build | 15.7222235 | WSL startup, SCons configuration, C++ compilation/linking |
| Original C++ subprocess | 0.15434356299374485 | Program start and filtered gtest |
| Gtest XML testcase | 0.135 | Gtest's reported testcase time |
| Native target process | 33.9905103 | Startup, package loading, compilation and test |
| Native timed solve | 11.5555591 | Timed solve call, including compilation on that path |

Full 28-case process elapsed: 513.4535217 s, including startup/loading/compilation and comparator selfchecks. Its zerodim.simple testset reports 11.4s; the timed solve call reports 10.5776891 s, including any compilation on that path. These cross-platform observations are a suite-budget checkpoint, not a controlled performance comparison or a performance acceptance threshold.

## Coverage and executed-source epochs

Prior native_test mapping: `test/reactors_native.jl:20 :: closed native ideal-gas reactors`. That related native RHS/property suite did not establish this full source scenario. The old complete CSV row is preserved in environment.json. After full acceptance, only this row's mapping is replaced with reactor_cpp.jl :: Cantera parity: zerodim.simple, retaining layer B and linking this record. The inventory is now 35/284/104. The known HO2 pulse remains missing/agent_failed and explicit-only.

Target/reference execution used target_source_sha256.json. After both targeted tests passed, only reactor.jl's temporary exclusion of zerodim_simple from all was removed; full_group_source_sha256.json records that second epoch. Other executable sources are identical. The example environment, production modules and solver adapters are preserved. The existing disable_chemistry reference also passed after adding the C++ dispatch. Full Pkg.test() is not claimed.

## Raw target evidence

- [environment.json](zerodim_simple_2026-10-30/environment.json): SHA256 `3d0e47daa5125488c99c84b65bad9b3e93f46bf1081a9b4c3f19874ba9ccc829`
- [build.log](zerodim_simple_2026-10-30/build.log): SHA256 `64d343b1654aa64238b602e15c97ce1ec3428a76d0b2f3ed4c6ecf5d32d83500`
- [build_timing.json](zerodim_simple_2026-10-30/build_timing.json): SHA256 `df685fb31a1e018e493617a38997ba6f9f356e2a1b3621b01ad4a21116dff87c`
- [cantera_reference.json](zerodim_simple_2026-10-30/cantera_reference.json): SHA256 `16d0d631392f55614dd762977b0b77ca9102e4496c6e1bc3b78dffefcc740c81`
- [gtest.log](zerodim_simple_2026-10-30/gtest.log): SHA256 `b57f924f7955451768cfb16f0afaa23bd1385f0bf40af1cbb430b23a234c81e8`
- [gtest.xml](zerodim_simple_2026-10-30/gtest.xml): SHA256 `c8e58d148bf828879faf26b87ee8bb941f89ad73fc5e9564ef8000e69c787f67`
- [linked_libraries.log](zerodim_simple_2026-10-30/linked_libraries.log): SHA256 `22a0766e1c275f218b45b2a6713918159dca45fccb610ec2e124c3f84b2917fc`
- [native_target.log](zerodim_simple_2026-10-30/native_target.log): SHA256 `44e73e770bb491b1cff6ee7bb5fdff53081e2f372041d3e92456a8e341c886a6`
- [native_target_timing.json](zerodim_simple_2026-10-30/native_target_timing.json): SHA256 `3234af9fba3a57049092a1b7e7027858c9218aabd9768b762489c8e1dd461bda`
- [native_core.log](zerodim_simple_2026-10-30/native_core.log): SHA256 `3e3bcfb649120ea3a14ae6492e95e4cf9106cd537c72382386a3958a3d0acae9`
- [old_reference_compatibility.json](zerodim_simple_2026-10-30/old_reference_compatibility.json): SHA256 `54e24812e893b7aca1a4146053f0a7ca18d38b1f83e7c2097c49738216c913f9`
- [target_source_sha256.json](zerodim_simple_2026-10-30/target_source_sha256.json): SHA256 `5be966e724af22dbc2d26b7609851774fd5f9a5b481c2276ea31b780cf06dd7c`
- [full_group_source_sha256.json](zerodim_simple_2026-10-30/full_group_source_sha256.json): SHA256 `341353ea994c7ebf79d293b392b2df7b193c51798fe0192905a3cce4720a9f5d`
- [native_samples.csv](zerodim_simple_2026-10-30/native_samples.csv): SHA256 `73add51213fa9023e7f4af3aa937500c4dd1b1f07ba46ffa6df5ce0a6ce8c43f`
- [native_data_audit.json](zerodim_simple_2026-10-30/native_data_audit.json): SHA256 `c155c8c50512ddf0b16d312f04eb5b870a5def7d898a07515e11d29c9d300737`

## Complete 28-case acceptance

The no-argument optional entry point exited 0. Exactly the previous 27 integration scenarios plus zerodim.simple passed: 8471/8471 scenario assertions and five comparator selfchecks, totaling **8476/8476**. The separate core guard passed 1/1. The known HO2 pulse was not selected and remains missing/agent_failed. Full Pkg.test() was not run.

Independent inspection of the full-run CSV confirms all 21 sequential output times, finite values and 20 exact T>=1050 checks. The full-run CSV is byte-identical to the target CSV. Executed source hashes match the retained full-group checkpoint. No Cantera trajectory-accuracy assertion is added.

- [native_all28.log](zerodim_simple_2026-10-30/native_all28.log): SHA256 `d84c31684f3c4b2f6d94ffd906ec1d2231175b6350f5d37c3582cbf233046252`
- [native_all28_timing.json](zerodim_simple_2026-10-30/native_all28_timing.json): SHA256 `a9e7f17ee9143470b6aee13db70f60816ee6e7ad2e941aaef55e4a9d50f776d4`
- [full28_const_pressure_closed.native.csv](zerodim_simple_2026-10-30/full28_const_pressure_closed.native.csv): SHA256 `ce699ff5c01fb0ed5b625fde60db4a657132bf080df797c7f4fb8d6379b6e0ee`
- [full28_wall_advance.native.csv](zerodim_simple_2026-10-30/full28_wall_advance.native.csv): SHA256 `a8da1e9ef62044be9c7d6de38fc0ef014fac8adddf5879388183af7bd4ed208c`
- [full28_wall_step.native.csv](zerodim_simple_2026-10-30/full28_wall_step.native.csv): SHA256 `81781ec79506090a8010b36e4654162c67bf604203d44f0c52291bf371e0e297`
- [full28_zerodim_simple.native.csv](zerodim_simple_2026-10-30/full28_zerodim_simple.native.csv): SHA256 `73add51213fa9023e7f4af3aa937500c4dd1b1f07ba46ffa6df5ce0a6ce8c43f`
- [Full-group audit](zerodim_simple_2026-10-30/full_group_audit.json): SHA256 `d412ef3301b9ee391e66fed6965600265b412b6cc48f0e1df2717b6d8ce2397b`
