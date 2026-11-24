# Nonideal constant-volume ignition on the native mass-fraction/temperature formulation

The local selector is `rk_cv_ignition`. The grouped inventory row for
`TestNonIdealConstVolumeEnergy.test_const_volume_ignition_internal_energy`
remains **missing**. The native Redlich–Kwong reactor provides one formulation,
with state [Y, T]. Cantera exercises four reactor classes in the same test.
The physical energy and ignition predicates have been ported for the available
formulation. Native coverage of the other formulations is still open.

## Inputs and checks

Use the frozen h2o2.yaml with SHA-256 (LF)
`0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4`.
Cantera selects ohmech-RK. Julia reads the same species and gas reactions from
ohmech for its kinetic data and selects **ohmech-RK** for EOS and reaction
activities. The reference cross-check confirmed the species and equation order
in both phases. The integration starts at 1050 K, 20 atm, equivalence ratio 1
(H₂:O₂:N₂ = 2:1:3.76), in a closed adiabatic 1 m³ vessel.

After every accepted step until the first t ≥ 0.1 s, compare
`abs(m*u - U0) <= max(1e-12, 1e-8 * abs(U0))` in J. The final temperature must
exceed the initial temperature by strictly more than 500 K. Use the reactor's
initial density and specified volume for the constant mass; evaluate specific
internal energy from each actual state. Each solver chooses its own steps.
The native adapter uses the production reactor callbacks and QNDF with the
pinned ReactorNet defaults (rtol 1e-9, atol 1e-15). Integration stops after
the first crossing, without forcing a time stop. The upper endpoint 1 s just
gives the stepper room to cross 0.1 s.

The additional native initialization gate compares total energy to the common
Cantera initial state. The threshold for this setup check is the established
default approx rule. The physical drift test uses the tighter original bound.

## Reproduce

In the fixed Cantera checkout with its verified 4.0.0a2 Python environment:

```sh
python -m pytest -q 'test/python/test_reactor.py::TestNonIdealConstVolumeEnergy::test_const_volume_ignition_internal_energy'
```

In the Arrhenius checkout with the locked reactor example environment:

```powershell
./test/cantera_parity/run_solver_regressions.ps1 -Cases rk_cv_ignition -TimeoutSeconds 240 -OutputDirectory rk-target
./test/cantera_parity/run_solver_regressions.ps1 -Cases all -TimeoutSeconds 2400 -OutputDirectory rk-all
```

The runner saves each accepted time, temperature and total internal energy in
rk_cv_ignition.native.csv, including the initial state. Output folders must be new.

## Observations

All runs start at U0 = 3304270.86613277 J, with an allowed drift of 0.03304271 J.
The Cantera columns below come from repeating each class with the verified shared
fixture and inspecting every accepted step. Its original pytest node passed 4/4.

| Formulation | Accepted steps | Final time (s) | Final T (K) | Maximum absolute energy drift (J) |
|---|---:|---:|---:|---:|
| Cantera Reactor | 1892 | 0.11423632 | 3182.453764 | 1.374e-7 |
| Cantera IdealGasReactor | 1954 | 0.24059797 | 3182.453764 | 0.00454940 |
| Cantera MoleReactor | 1927 | 0.66919271 | 3182.453764 | 1.327e-7 |
| Cantera IdealGasMoleReactor | 1935 | 0.10811059 | 3182.453764 | 0.00433698 |
| Julia RedlichKwongReactor | 1304 | 0.10074567 | 3182.453763 | 0.00408584 |

Native single case: 1309/1309, 65 rejected steps, 25.33 s including startup.
Clean replay from the preceding accepted source with the test patch and locked
environment: 1309/1309. Injecting a 2-bound energy drift in one intermediate
sample failed the energy predicate only. Disabling all reactions on an independent
copy failed the temperature-rise predicate only, even though energy was conserved.

The optional full run passed 10443/10443 assertions in 45 testsets (702.77 s including startup). It includes 44 scenarios and the comparator self-check. Core 1/1, layout 8/8 and runner 11/11 were checked separately. All 19 historical result files and 180 prior solver counter entries matched the preceding accepted run. The target, clean replay and full run produced the identical trajectory (SHA-256 `66b6a230834cd038f5e156f4a8e01a4d676f35ade460aee754aa103614e68769`).
