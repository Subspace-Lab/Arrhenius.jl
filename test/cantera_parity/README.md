# Cross-residual tool

`xresid.py` compares native and Cantera residuals at two states and checks the state-transfer round trips. The native subprocess is `xresid_native.jl`; both are kept in this directory. `snapshots/xresid_adapter.py` imports the local `xresid.py`, so no separate checkout or path variable is needed. Python requires NumPy and Cantera 4; Julia resolves Arrhenius from the repository root. `XRESID_JULIA` can optionally select a Julia executable.

Run the compact h2o2 regression from the repository root:

```sh
python test/cantera_parity/xresid_h2o2.py --kinds free
python test/cantera_parity/xresid_h2o2.py
```

The first command is a single-kind smoke check; the second covers free, burner, fixed-temperature, and stagnation flames. For recorded states, run `xresid.py SPEC STATE_A.npz STATE_B.npz` or use the adapter with the same arguments.

The H2/O2 regression rejects incomplete reports and non-finite values before
aggregating round-trip errors or applying its existing numeric limits. Its report
gate tests use only the Python standard library and can run without NumPy,
Cantera, or Julia:

```sh
python -m unittest discover -s test/cantera_parity -p 'test_xresid_gates.py' -v
```

These Python checks are separate from the Julia `Pkg.test()` entry point and
run in their own Linux CI job.

Before reporting aggregates, `xresid.py` checks every non-absent physical
residual maximum, relative residual, and shared-row agreement value for finite,
nonnegative values. It also checks explicit native scales before normalization
(zero is allowed). Invalid data causes exit 2 and, with `--json`, a refusal
report with a diagnostic field path rather than partial aggregates. Structural
`None` entries and the infinity sentinel for a missing equation-type scale
retain their existing meanings; normalization and gate thresholds are unchanged.
