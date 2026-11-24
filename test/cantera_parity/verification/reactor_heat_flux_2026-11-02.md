# Prescribed wall heat flux with the generic Cantera Reactor

Frozen upstream node: [TestReactor.test_heat_flux_func, L595–619](https://github.com/Cantera/cantera/blob/726522be4e2a13454d8415b7ef799d621f665cf3/test/python/test_reactor.py#L595-L619).
The fixture calls `self.reactorClass`, which is `ct.Reactor` for this node.
A distinct pytest node uses `ct.IdealGasReactor`. We ran both original nodes,
then captured both sets of states through the shared-input reference runner.
The new reference selection records and checks the generic runtime class.

## Scope and plan

This case measures the heat leaving one vessel and entering the other. All
five upstream assertions concern observable physical quantities. The tested
phase is ideal-gas ohmech, even for the generic Reactor. For this closed,
fixed-volume phase, total internal energy is recovered from the masses and
temperature as the sum of species mass times specific internal energy.
Cantera's generic energy coordinate and the native temperature coordinate
therefore yield the same observable U for a given physical state.

Verify the generic reference independently, reuse the existing Julia
`heat_flux_func` integration, and archive the actual energy and volume pairs.
Its existing testset retains the historical IdealGasReactor label. Counting
one native scenario for both references preserves the distinction between the
number of upstream behaviors verified and the number of integrations run.
No other inherited row or nonideal EOS is certified by this result.

## Reproduction

From the clean pinned Cantera checkout, using its 4.0.0a2 Python environment:

```sh
python -m pytest -q test/python/test_reactor.py::TestReactor::test_heat_flux_func test/python/test_reactor.py::TestIdealGasReactor::test_heat_flux_func
```

From the replayed Arrhenius checkout (use a new output path for each command):

```sh
python test/cantera_parity/reactor_reference.py --case reactor_heat_flux_func --source-dir /path/to/pinned/cantera --output generic.json
python test/cantera_parity/reactor_reference.py --case heat_flux_func --source-dir /path/to/pinned/cantera --output ideal.json
```

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases heat_flux_func -TimeoutSeconds 240 -OutputDirectory heat-target
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory heat-all
```

Mechanism: h2o2.yaml (LF SHA-256
`0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`).
Both vessels contain pure O₂ at 1 atm, initially 500 K and 300 K. Volumes
are 0.5 and 1 m³. Chemistry and energy are enabled. Cantera disables gas
transport. The zero-D native path does not call it. ReactorNet and QNDF
integration tolerances are 1e-9 relative and 1e-15 absolute.

The wall area is 0.3 m². Applied heat flux is 90000(1−t²) W/m² through t=1 s,
then zero. At 1.1 s, the original test checks exact zero flux, both volumes
and both total internal energies. The integrated heat transfer is 18000 J.
For volume and energy comparisons the allowance is
`max(1e-12, 1e-6 * abs(observed_final_value))`, with the computed final
quantity on the expected side of pytest.approx as in upstream.

| At 1.1 s | Left U (J) | Right U (J) | Left/right V (m³) | Heat flux (W/m²) |
|---|---:|---:|---|---:|
| Cantera Reactor | 5507.417867 | −81116.839303 | 0.5 / 1 | 0 |
| Cantera IdealGasReactor | 5507.414436 | −81116.839137 | 0.5 / 1 | 0 |
| Julia | 5507.414881 | −81116.840541 | 0.5 / 1 | 0 |

Initial energies are 23507.416916 J and −99116.838352 J. For Julia the
absolute discrepancies from the two signed analytical energy balances are
0.002035 J and 0.002189 J. Allowed errors at the native final values are
0.005507 J and 0.081117 J. The test compares each side to the analytical
balance; the table also permits comparison of the actual integrations.

## Acceptance and adversarial review

Pinned Cantera pytest 2/2. Julia single case and independent clean replay
7/7 each. Full optional suite: 44 scenarios plus comparator, 10443/10443
assertions across 45 testsets in 719.90 s. Separate checks:
core 1/1, layout 8/8 and runner 11/11. All 20 previous numerical records
were byte-identical and all 192 historical solver counter entries matched.
New TOML SHA-256 from target, clean replay and full suite:
`19fa84ebf9d1005800d7cf8004313485641f0d515c5a61795f11063f91a8c3e1`.

An actual half-strength pulse in an isolated source copy failed both signed
energy assertions only (5 passed, 2 failed). Nine independent evidence
corruptions were rejected: wrong pytest identity, wrong runtime class with
correct node identity, nonzero final flux, wrong target time, each final
volume altered separately, reversed left energy change, omitted right energy
change and nonfinite energy. Exactly one inventory row becomes covered.
