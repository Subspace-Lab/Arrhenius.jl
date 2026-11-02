# Cross-residual tool

`xresid.py` compares native and Cantera residuals at two states and checks the state-transfer round trips. The native subprocess is `xresid_native.jl`; both are kept in this directory. `snapshots/xresid_adapter.py` imports the local `xresid.py`, so no separate checkout or path variable is needed. Python requires NumPy and Cantera 4; Julia resolves Arrhenius from the repository root. `XRESID_JULIA` can optionally select a Julia executable.

Run the compact h2o2 regression from the repository root:

```sh
python test/cantera_parity/xresid_h2o2.py --kinds free
python test/cantera_parity/xresid_h2o2.py
```

The first command is a single-kind smoke check; the second covers free, burner, fixed-temperature, and stagnation flames. For recorded states, run `xresid.py SPEC STATE_A.npz STATE_B.npz` or use the adapter with the same arguments.


## Optional zero-dimensional parity: disabled chemistry

The first delivered reactor port is
`TestIdealGasReactor.test_disable_chemistry`, inherited from `TestReactor` in
[Cantera test_reactor.py](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_reactor.py).
This section describes only this delivered case, not the broader development
coverage inventory or other reactor subclasses inheriting the same method.

Both sides use the original ten-species `h2o2.yaml`, phase `ohmech`, from Cantera
commit `726522be4e2a13454d8415b7ef799d621f665cf3`. Its LF-normalized SHA-256 is
`0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`.
The copied mechanism and its Cantera license are in
[`fixtures/cantera-726522be`](fixtures/cantera-726522be). Do not substitute the
repository's different same-named mechanism. This native zeroD fixture loads
directly from YAML; it does not require a generated transport sidecar.

The vessel is closed, constant-volume (1 m3), adiabatic, initially1000 K and
101325 Pa, with H2:O2=2:1 and chemistry disabled. Integrate to11 seconds of
physical time using the existing QNDF network adapter with rtol1e-9/atol1e-15,
matching the pinned Cantera ReactorNet defaults. The three original final-state
assertions check T=1000 K, X_H2=2/3 and X_O2=1/3 with
`abs(actual-expected) <= max(1e-12, 1e-6*abs(expected))` (pytest.approx defaults).
Two additional checks require arrival at11 s and finite state. The unchanged
network adapter rejects unsuccessful solver return codes. No solver policy or
core dependency is added; nominal equal tolerances do not imply equal error norms.

### Julia, from a clean checkout

Use Julia1.12 (validated with1.12.7). From the repository root:

```sh
julia --project=example/reactors -e 'using Pkg; Pkg.instantiate()'
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl disable_chemistry
```

No argument or `all` runs this one delivered scenario; unknown selectors fail.
Expect5/5 assertions. The existing example Project fixes direct solver versions,
including SciMLBase2.155.2 and OrdinaryDiffEqBDF1.26.0; the test checks these.
Instantiation creates an ignored local Manifest, so transitive dependencies are
resolved locally rather than shipped as a complete lockfile. Record that Manifest
when reproducing numerical results. Julia resolves Arrhenius from this checkout
through the example Project's relative source path; no sibling checkout is needed.

This optional integration is not included in `test/runtests.jl` or the default CI
suite. The normal package test command remains
`julia --project=. -e 'using Pkg; Pkg.test()'`; passing that command alone does not
run this integration. First-run elapsed time includes package compilation.

### Independent Cantera reference

Use Python 3.12 (validated with 3.12.3) and a Cantera 4.0.0a2 build from the exact commit above and its
clean source checkout. A stock3.2 installation is not equivalent. Build setup is
described by the [pinned upstream instructions](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/doc/sphinx/develop/compiling/configure-build.md).
These commands assume that reference environment is already installed; they do
not install or rebuild Cantera. In its activated Linux/WSL environment, with the
Arrhenius checkout as the current directory and CT_SOURCE pointing to the source:

```sh
python test/cantera_parity/reactor_reference.py --source-dir "$CT_SOURCE" --check-environment
python test/cantera_parity/reactor_reference.py --source-dir "$CT_SOURCE" --output test/cantera_parity/local-results/disable-chemistry.cantera.json
```

The first command verifies the source commit/clean tracked state, imported build
version/commit and paths, and agreement of the source and bundled input hashes;
it performs no integration. The second runs the reference and checks the same
physical contract. Reference transport is disabled; native zeroD does not call
transport. Output JSON is created only after assertions pass; an existing output
path is rejected. `reference_passed_native_not_verified` deliberately does not
claim that the independent Julia check has run. Keep both outputs when reporting
acceptance. Local results are ignored by Git.
