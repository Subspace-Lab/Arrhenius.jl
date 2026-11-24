> **Superseded full-coverage proof.** The original outputs and text below are retained as history. Its claim that the energy-disabled Jacobian uses the identical advanced physical state was invalid: the native descriptor froze T at 900 K. The fixture and state-preservation checks have now been corrected and coverage restored using the [new verification record](reacting_jacobian_corrected_2026-10-29.md), including 21/21 targeted assertions and the full 24-case acceptance. The old 10/10 result alone is not full coverage evidence.

# ZeroD reacting-state Jacobian verification (2026-10-29)

The agent ran the pinned Cantera reference and native TestIdealGasReactor.test_finite_difference_jacobian (source line 138). Both exited 0; native 10/10 assertions. No production API, finite-difference rule or solver policy was changed.

## Scenario and coordinate mapping

Initially 900 K, 1 atm, H2:0.4,O2:0.4,N2:0.2, adiabatic constant volume and enabled chemistry. Both solvers take accepted steps until H2 mole fraction is <=0.3, then evaluate the finite-difference Jacobian. Preserve these behaviors:

- The Jacobian has the native state dimension and a nonzero temperature row at the reacted state.
- Disabling energy makes the temperature row exactly zero.
- Reenabling energy and disabling chemistry makes the species/species block exactly zero.

Cantera stores [mass,volume,T,Y...] (13 states); native fixed-volume network coordinates are [species masses...,T] (11 states). Cantera's two constant mass/volume rows are eliminated in native coordinates: mass is derived from the species masses and volume is a fixed descriptor. The native regression checks conserved mass and unchanged 1 m3 volume at the advanced state, in addition to its 11x11 finite Jacobian, nonzero thermal row and exact zero structures. It does not invent missing component-name/index APIs or compare Jacobian entries in different coordinates. This is the explicit native counterpart of the upstream constant-state rows, not a claim of a 13x13 native state interface.

The existing finite-difference network Jacobian is used unchanged. New isothermal and chemistry-disabled descriptors reuse the identical advanced state for evaluating the toggled Jacobians; the reaction trajectory is not reset or rerun for these checks. The integration uses Cantera's default rtol=1e-9 / atol=1e-15. No comparison tolerance is chosen for the zero/nonzero structure assertions.

## Observed states

| Quantity | Cantera | Native |
|---|---:|---:|
| First accepted time with X_H2<=0.3 (s) | 0.1702412857797428 | 0.17024128499704988 |
| Accepted steps | 1048 | 901 |
| H2 mole fraction | 0.29938874128532134 | 0.2988160189910338 |
| Temperature (K) | 1388.2567562886095 | 1389.7357593115607 |
| Jacobian dimension | 13x13 | 11x11 |

The first accepted threshold-crossing states differ, as allowed by the upstream loop; they are not asserted identical across solvers. Each passes its original structural checks at its own crossing state. This is targeted optional regression verification, not the full Pkg.test() suite. Native Windows Julia 1.12.7 uses SciMLBase 2.155.2 and OrdinaryDiffEqBDF 1.26.0 with one Julia/OpenBLAS thread. The reference gate validates actual import paths, clean pinned commit and shared mechanism digest.

## Reproduction

Use the pinned WSL interpreter/source with `reactor_reference.py --case finite_difference_jacobian --output <fresh-path>`. Native:

```powershell
julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl finite_difference_jacobian
```

## Executed-source SHA256 (LF-normalized)

- `test/cantera_parity/reactor.jl`: `e0fb16fc8595a6661f6111a0e8014526b25957ef79bdf07b92ac865437af86ff`
- `test/cantera_parity/reactor_time_controls.jl`: `7f8aa4f39a7fd154de808afb9d8b1e08cbd955481057e8d5ff582df344a4ed06`
- `test/cantera_parity/reactor_reference.py`: `f970aab67924837dadc31887903d17cdc07facddbec078025ef2eec70cf61318`
- `test/cantera_parity/run_solver_regressions.jl`: `732a902693e68664730e2c7f8ad16f43d7831e6e5b7b2afb759bc8c7c264e878`

## Complete Cantera record

```json
{
  "checked_at_utc": "2026-10-29T12:22:12.347868+00:00",
  "upstream_test": "test/python/test_reactor.py::TestIdealGasReactor::test_finite_difference_jacobian",
  "cantera_version": "4.0.0a2",
  "cantera_git_commit": "726522be4",
  "source_dir": "/home/subspace/src/cantera-726522be",
  "source_commit": "726522be4e2a13454d8415b7ef799d621f665cf3",
  "source_tracked_clean": true,
  "cantera_module": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/__init__.py",
  "cantera_extension": "/home/subspace/.venvs/cantera-726522be/lib/python3.12/site-packages/cantera/_utils.cpython-312-x86_64-linux-gnu.so",
  "python_executable": "/home/subspace/.venvs/cantera-726522be/bin/python",
  "python_version": "3.12.3",
  "platform": "Linux-6.18.33.2-microsoft-standard-WSL2-x86_64-with-glibc2.39",
  "sundials_version": "7.5.0",
  "mechanism": "/mnt/c/Users/DELL/Documents/GitHub/Arrhenius.jl/test/cantera_parity/fixtures/cantera-726522be/h2o2.yaml",
  "mechanism_sha256_lf": "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4",
  "phase": "ohmech",
  "result": {
    "time": 0.1702412857797428,
    "accepted_steps": 1048,
    "temperature": 1388.2567562886095,
    "pressure": 152540.7405803075,
    "mole_fractions": [
      0.29938874128532134,
      0.03248664243185323,
      0.009058242578941523,
      0.35612694577272025,
      0.007284564469692382,
      0.09037596000933942,
      0.0003279508874529383,
      2.9208313399542197e-05,
      0.0,
      0.20492174425127938
    ],
    "n_vars": 13,
    "first_component_names": [
      "mass",
      "volume",
      "temperature"
    ],
    "jacobian_shape": [
      13,
      13
    ],
    "reference_assertions_passed": true
  },
  "status": "reference_passed_native_not_verified"
}
```

## Complete native output

```text
Julia version: 1.12.7
Active project: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\example\reactors\Project.toml
Arrhenius source: C:\Users\DELL\Documents\GitHub\Arrhenius.jl\src\Arrhenius.jl
┌ Info: Reacting-state finite-difference Jacobian
│   time = 0.17024128499704988
│   steps = 901
│   temperature = 1389.7357593115607
│   pressure = 152692.00402687897
│   x_h2 = 0.2988160189910338
│   jacobian_size = (11, 11)
└   mechanism_sha256_lf = "0efc6c52862741a29e0c29b65d979c7d8cb409db5282bca83b9c5437b3d8c8d4"
Test Summary:                                                       | Pass  Total   Time
Cantera parity: TestIdealGasReactor.test_finite_difference_jacobian |   10     10  37.9s
```
