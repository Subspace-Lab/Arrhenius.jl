"""User-run Cantera references and environment gate for zeroD ports.

--check-environment inspects provenance only; it never constructs or solves a
reactor. --output runs the reference and writes a record after assertions pass.
Neither mode changes the coverage table.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import platform
import re
import subprocess
import sys
import tomllib


FIXTURE = Path(__file__).resolve().parent / "fixtures" / "cantera-726522be"


def environment(source_dir):
    with (FIXTURE / "provenance.toml").open("rb") as stream:
        provenance = tomllib.load(stream)
    source_dir = source_dir.resolve(strict=True)

    def git(*args):
        return subprocess.check_output(
            ["git", "-C", str(source_dir), *args], text=True
        ).strip()

    commit = git("rev-parse", "HEAD")
    if commit != provenance["cantera_commit"]:
        raise RuntimeError(f"Source HEAD must be {provenance['cantera_commit']}; got {commit}")
    dirty = git("status", "--porcelain", "--untracked-files=no")
    if dirty:
        raise RuntimeError(f"Reference source has tracked modifications:\n{dirty}")

    import cantera as ct
    import cantera._utils as ct_utils

    built_commit = str(ct.__git_commit__).lower()
    if not re.fullmatch(r"[0-9a-f]{7,40}", built_commit) or not commit.startswith(built_commit):
        raise RuntimeError(f"Imported Cantera was built from {built_commit!r}, not {commit}")
    if ct.__version__ != provenance["cantera_version"]:
        raise RuntimeError(f"Expected Cantera {provenance['cantera_version']}; got {ct.__version__}")

    mechanism = FIXTURE / "h2o2.yaml"
    digest = hashlib.sha256(mechanism.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    if digest != provenance["mechanism_sha256_lf"]:
        raise RuntimeError("Pinned h2o2 fixture digest mismatch")
    source_mechanism = source_dir / provenance["mechanism_source"]
    source_digest = hashlib.sha256(source_mechanism.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    if source_digest != digest:
        raise RuntimeError("Source-tree and parity-fixture mechanisms differ")

    record = {
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "upstream_test": provenance["upstream_test"],
        "cantera_version": ct.__version__,
        "cantera_git_commit": built_commit,
        "source_dir": str(source_dir),
        "source_commit": commit,
        "source_tracked_clean": True,
        "cantera_module": str(Path(ct.__file__).resolve()),
        "cantera_extension": str(Path(ct_utils.__file__).resolve()),
        "python_executable": sys.executable,
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "sundials_version": ct.__sundials_version__,
        "mechanism": str(mechanism),
        "mechanism_sha256_lf": digest,
        "phase": provenance["phase"],
    }
    return ct, provenance, mechanism, record


def reference(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 1000.0, ct.one_atm, "H2:2.0,O2:1.0"
    reactor = ct.IdealGasReactor(gas, clone=True, energy="on", volume=1.0)
    reactor.chemistry_enabled = False
    network = ct.ReactorNet([reactor])
    # Read the reference's defaults; do not silently replace a mismatch.
    if (network.rtol, network.atol) != (
        provenance["integration_rtol"], provenance["integration_atol"]
    ):
        raise RuntimeError("Cantera integration defaults do not match the pinned reference")
    network.advance(11.0)
    actual = {
        "temperature": float(reactor.T),
        "X_H2": float(reactor.phase.X[reactor.phase.species_index("H2")]),
        "X_O2": float(reactor.phase.X[reactor.phase.species_index("O2")]),
    }
    expected = {"temperature": 1000.0, "X_H2": 2.0 / 3.0, "X_O2": 1.0 / 3.0}
    if network.time != 11.0:
        raise AssertionError(f"Reference did not reach 11 s: {network.time}")
    for name, value in actual.items():
        tolerance = max(provenance["assertion_atol"],
                        provenance["assertion_rtol"] * abs(expected[name]))
        if not math.isfinite(value) or abs(value - expected[name]) > tolerance:
            raise AssertionError(f"{name}: {value} != {expected[name]} (tolerance {tolerance})")
    return {
        "time": float(network.time),
        "initial_temperature": 1000.0,
        "initial_pressure": float(ct.one_atm),
        "initial_mole_amounts": {"H2": 2.0, "O2": 1.0},
        "volume": 1.0,
        "energy": "adiabatic",
        "chemistry_enabled": False,
        "rtol": network.rtol,
        "atol": network.atol,
        "assertion_rtol": provenance["assertion_rtol"],
        "assertion_atol": provenance["assertion_atol"],
        "actual": actual,
        "expected": expected,
        "reference_assertions_passed": True,
    }


def reference_disjoint(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 300.0, 101325.0, "O2:1.0"
    left = ct.IdealGasReactor(gas, clone=True, energy="on", volume=1.0)
    gas.TPX = 500.0, 300000.0, "O2:1.0"
    right = ct.IdealGasReactor(gas, clone=True, energy="on", volume=1.0)
    # Both clones retain independent states; chemistry stays enabled.
    left.chemistry_enabled = right.chemistry_enabled = True
    network = ct.ReactorNet([left, right])
    if (network.rtol, network.atol) != (
        provenance["integration_rtol"], provenance["integration_atol"]
    ):
        raise RuntimeError("Cantera integration defaults do not match the pinned reference")

    def snapshot():
        return {
            "left": {"temperature": float(left.T), "pressure": float(left.phase.P)},
            "right": {"temperature": float(right.T), "pressure": float(right.phase.P)},
        }

    expected = {
        "left": {"temperature": 300.0, "pressure": 101325.0},
        "right": {"temperature": 500.0, "pressure": 300000.0},
    }
    def check(stage, states):
        for node in expected:
            for name, nominal in expected[node].items():
                computed = states[node][name]
                # Upstream writes nominal == approx(computed): the relative
                # tolerance scales with the computed value in this test.
                tolerance = max(provenance["assertion_atol"],
                                provenance["assertion_rtol"] * abs(computed))
                if not math.isfinite(computed) or abs(nominal - computed) > tolerance:
                    raise AssertionError(
                        f"{stage} {node}.{name}: {computed} != {nominal} "
                        f"(tolerance {tolerance})"
                    )

    initial = snapshot()
    check("initial", initial)
    network.advance(1.0)
    actual = snapshot()
    if network.time != 1.0:
        raise AssertionError(f"Reference did not reach 1 s: {network.time}")
    check("final", actual)
    return {
        "time": float(network.time),
        "initial": initial,
        "actual": actual,
        "expected": expected,
        "initial_mole_amounts": {"O2": 1.0},
        "volume_each": 1.0,
        "energy": "adiabatic",
        "constraint": "constant_volume",
        "chemistry_enabled": True,
        "connections": [],
        "rtol": network.rtol,
        "atol": network.atol,
        "assertion_rtol": provenance["assertion_rtol"],
        "assertion_atol": provenance["assertion_atol"],
        "reference_assertions_passed": True,
    }


def reference_disable_energy(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 500.0, ct.one_atm, "O2:1.0"
    left = ct.IdealGasReactor(gas, clone=True, energy="off", volume=1.0)
    gas.TPX = 300.0, ct.one_atm, "O2:1.0"
    right = ct.IdealGasReactor(gas, clone=True, energy="on", volume=1.0)
    wall = ct.Wall(left, right, A=1.0, U=2500.0)
    network = ct.ReactorNet([left, right])
    if (network.rtol, network.atol) != (
        provenance["integration_rtol"], provenance["integration_atol"]
    ):
        raise RuntimeError("Cantera integration defaults do not match the pinned reference")
    initial = {"left_temperature": float(left.T), "right_temperature": float(right.T)}
    network.advance(11.0)
    actual = {"left_temperature": float(left.T), "right_temperature": float(right.T)}
    expected = {"left_temperature": 500.0, "right_temperature": 500.0}
    if network.time != 11.0:
        raise AssertionError(f"Reference did not reach 11 s: {network.time}")
    for name, value in actual.items():
        tolerance = max(provenance["assertion_atol"],
                        provenance["assertion_rtol"] * abs(expected[name]))
        if not math.isfinite(value) or abs(value - expected[name]) > tolerance:
            raise AssertionError(f"{name}: {value} != {expected[name]} (tolerance {tolerance})")
    return {
        "time": float(network.time),
        "initial": initial,
        "actual": actual,
        "expected": expected,
        "initial_pressure_each": float(ct.one_atm),
        "initial_mole_amounts": {"O2": 1.0},
        "volume_each": 1.0,
        "constraint": "constant_volume",
        "energy_enabled": {"left": bool(left.energy_enabled), "right": bool(right.energy_enabled)},
        "chemistry_enabled": {"left": bool(left.chemistry_enabled), "right": bool(right.chemistry_enabled)},
        "wall_area": float(wall.area),
        "wall_heat_transfer_coeff": float(wall.heat_transfer_coeff),
        "rtol": network.rtol,
        "atol": network.atol,
        "assertion_rtol": provenance["assertion_rtol"],
        "assertion_atol": provenance["assertion_atol"],
        "reference_assertions_passed": True,
    }


def thermal_pair(ct, provenance, mechanism, *, temperatures=(300.0, 1000.0),
                 volumes=(1.0, 1.0), area=1.0, U=0.0, reactor_type=None):
    reactor_type = ct.IdealGasReactor if reactor_type is None else reactor_type
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = temperatures[0], ct.one_atm, "O2:1.0"
    left = reactor_type(gas, clone=True, energy="on", volume=volumes[0])
    gas.TPX = temperatures[1], ct.one_atm, "O2:1.0"
    right = reactor_type(gas, clone=True, energy="on", volume=volumes[1])
    wall = ct.Wall(left, right, A=area, U=U)
    network = ct.ReactorNet([left, right])
    if (network.rtol, network.atol) != (
        provenance["integration_rtol"], provenance["integration_atol"]
    ):
        raise RuntimeError("Cantera integration defaults do not match the pinned reference")
    return left, right, wall, network


def check_close(name, actual, expected, provenance, *, rtol=None, atol=None):
    if rtol is None:
        rtol = provenance["assertion_rtol"]
    if atol is None:
        atol = provenance["assertion_atol"]
    tolerance = max(atol, rtol * abs(expected))
    if (not math.isfinite(actual) or not math.isfinite(expected)
            or abs(actual - expected) > tolerance):
        raise AssertionError(f"{name}: {actual} != {expected} (tolerance {tolerance})")


def reference_heat_transfer1(ct, provenance, mechanism, *, reactor_type=None):
    left, right, wall, network = thermal_pair(ct, provenance, mechanism, U=500.0, reactor_type=reactor_type)
    network.advance(10.0)
    check_close("time", network.time, 10.0, provenance)
    check_close("thermal equilibrium", left.T, right.T, provenance, rtol=5e-7)
    pressure_tolerance = max(provenance["assertion_atol"],
                             provenance["assertion_rtol"] * abs(right.phase.P))
    if (not math.isfinite(left.phase.P) or not math.isfinite(right.phase.P)
            or abs(left.phase.P - right.phase.P) <= pressure_tolerance):
        raise AssertionError("Vessels must retain different pressures at thermal equilibrium")
    return {
        "reactor_type": left.type,
        "time": float(network.time),
        "actual": {"left_temperature": float(left.T), "right_temperature": float(right.T),
                   "left_pressure": float(left.phase.P), "right_pressure": float(right.phase.P)},
        "initial_temperatures": [300.0, 1000.0],
        "initial_pressure_each": float(ct.one_atm),
        "initial_mole_amounts": {"O2": 1.0},
        "volume_each": 1.0,
        "energy": "adiabatic", "chemistry_enabled": True,
        "wall_area": float(wall.area), "wall_heat_transfer_coeff": float(wall.heat_transfer_coeff),
        "rtol": network.rtol, "atol": network.atol,
        "temperature_comparison_rtol": 5e-7,
        "assertion_rtol": provenance["assertion_rtol"],
        "assertion_atol": provenance["assertion_atol"],
        "reference_assertions_passed": True,
    }


def reference_heat_transfer2(ct, provenance, mechanism, *, reactor_type=None):
    left, right, _, network = thermal_pair(ct, provenance, mechanism, U=200.0, reactor_type=reactor_type)
    network.advance(1.0)
    first = {"left_temperature": float(left.T), "right_temperature": float(right.T)}
    left, right, wall, network = thermal_pair(ct, provenance, mechanism,
                                             volumes=(0.25, 0.25), U=100.0, area=0.5, reactor_type=reactor_type)
    initial_reported_power = wall.heat_rate
    initial_power = wall.heat_transfer_coeff * wall.area * (left.T - right.T)
    check_close("initial wall power", initial_power, wall.heat_rate, provenance)
    network.advance(1.0)
    final_power = wall.heat_transfer_coeff * wall.area * (left.T - right.T)
    check_close("final wall power", final_power, wall.heat_rate, provenance)
    scaled = {"left_temperature": float(left.T), "right_temperature": float(right.T)}
    for name, actual in first.items():
        check_close(name, actual, scaled[name], provenance)
    if network.time != 1.0:
        raise AssertionError(f"Reference did not reach 1 s: {network.time}")
    return {
        "reactor_type": left.type,
        "time": float(network.time), "first": first, "scaled": scaled,
        "initial_temperatures": [300.0, 1000.0],
        "initial_pressure_each": float(ct.one_atm),
        "initial_mole_amounts": {"O2": 1.0},
        "first_configuration": {"volume_each": 1.0, "U": 200.0, "area": 1.0},
        "scaled_configuration": {"volume_each": 0.25, "U": 100.0, "area": 0.5},
        "energy": "adiabatic", "chemistry_enabled": True,
        "initial_wall_power": float(initial_reported_power), "final_wall_power": float(wall.heat_rate),
        "rtol": network.rtol, "atol": network.atol,
        "assertion_rtol": provenance["assertion_rtol"],
        "assertion_atol": provenance["assertion_atol"],
        "reference_assertions_passed": True,
    }


def reference_heat_flux_func(ct, provenance, mechanism, *, reactor_type=None):
    left, right, wall, network = thermal_pair(ct, provenance, mechanism,
        temperatures=(500.0, 300.0), volumes=(0.5, 1.0), area=0.3, reactor_type=reactor_type)
    heat_flux = lambda t: 90000.0 * (1.0 - t**2) if t <= 1.0 else 0.0
    wall.heat_flux = heat_flux
    def snapshot():
        return {"left_U": float(left.volume * left.density * left.phase.u),
                "right_U": float(right.volume * right.density * right.phase.u),
                "left_volume": float(left.volume), "right_volume": float(right.volume)}
    if reactor_type is not None and (type(left) is not reactor_type or type(right) is not reactor_type):
        raise AssertionError("Unexpected Cantera reactor class")
    initial = snapshot()
    transferred_heat = 0.3 * 60000.0
    network.advance(1.1)
    actual = snapshot()
    if wall.heat_flux != heat_flux(1.1):
        raise AssertionError("Final wall heat flux differs from its prescribed time function")
    check_close("left volume", initial["left_volume"], actual["left_volume"], provenance)
    check_close("right volume", initial["right_volume"], actual["right_volume"], provenance)
    check_close("left total energy", initial["left_U"] - transferred_heat, actual["left_U"], provenance)
    check_close("right total energy", initial["right_U"] + transferred_heat, actual["right_U"], provenance)
    if network.time != 1.1:
        raise AssertionError(f"Reference did not reach 1.1 s: {network.time}")
    return {
        "time": float(network.time), "initial": initial, "actual": actual,
        "reactor_type": left.type, "transferred_heat": transferred_heat, "final_heat_flux": float(wall.heat_flux),
        "initial_temperatures": [500.0, 300.0], "initial_pressure_each": float(ct.one_atm),
        "initial_mole_amounts": {"O2": 1.0},
        "energy": "adiabatic", "chemistry_enabled": True, "wall_area": 0.3,
        "rtol": network.rtol, "atol": network.atol,
        "assertion_rtol": provenance["assertion_rtol"],
        "assertion_atol": provenance["assertion_atol"],
        "reference_assertions_passed": True,
    }


def valve_pair(ct, provenance, mechanism, *, composition="AR:1.0", energy="on"):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 300.0, 10 * ct.one_atm, composition
    left = ct.IdealGasReactor(gas, clone=True, energy=energy, volume=1.0)
    gas.TPX = 300.0, ct.one_atm, "O2:1.0"
    right = ct.IdealGasReactor(gas, clone=True, energy=energy, volume=1.0)
    valve = ct.Valve(left, right)
    valve.valve_coeff = 2e-5
    network = ct.ReactorNet([left, right])
    if (network.rtol, network.atol) != (
        provenance["integration_rtol"], provenance["integration_atol"]
    ):
        raise RuntimeError("Cantera integration defaults do not match the pinned reference")
    return left, right, valve, network


def valve_snapshot(left, right, valve):
    return {
        "left": {"mass": float(left.mass), "temperature": float(left.T),
                 "pressure": float(left.phase.P), "mass_fractions": list(left.Y)},
        "right": {"mass": float(right.mass), "temperature": float(right.T),
                  "pressure": float(right.phase.P), "mass_fractions": list(right.Y)},
        "mass_flow_rate": float(valve.mass_flow_rate),
    }


def reference_valve1(ct, provenance, mechanism):
    left, right, valve, network = valve_pair(ct, provenance, mechanism)
    if left.outlets != right.inlets or valve.valve_coeff != 2e-5:
        raise AssertionError("Valve topology or coefficient differs from upstream setup")
    if not left.energy_enabled or not right.energy_enabled:
        raise AssertionError("Both energy equations must be enabled")
    network.rtol = 1e-12
    network.initialize()
    check_close("initial valve flow", (left.phase.P - right.phase.P) * valve.valve_coeff,
                valve.mass_flow_rate, provenance)
    initial = valve_snapshot(left, right, valve)
    network.advance(0.1)
    actual = valve_snapshot(left, right, valve)
    check_close("final valve flow", (left.phase.P - right.phase.P) * valve.valve_coeff,
                valve.mass_flow_rate, provenance)
    check_close("total mass", initial["left"]["mass"] + initial["right"]["mass"],
                actual["left"]["mass"] + actual["right"]["mass"], provenance)
    for k in range(left.phase.n_species):
        initial_mass = (initial["left"]["mass"] * initial["left"]["mass_fractions"][k]
                        + initial["right"]["mass"] * initial["right"]["mass_fractions"][k])
        final_mass = (actual["left"]["mass"] * actual["left"]["mass_fractions"][k]
                      + actual["right"]["mass"] * actual["right"]["mass_fractions"][k])
        check_close(f"species mass {k}", initial_mass, final_mass, provenance, atol=1e-10)
        check_close(f"upstream Y[{k}]", initial["left"]["mass_fractions"][k],
                    actual["left"]["mass_fractions"][k], provenance)
    return {"time": float(network.time), "initial": initial, "actual": actual,
            "valve_coeff": float(valve.valve_coeff), "rtol": network.rtol, "atol": network.atol,
            "energy_enabled": True, "chemistry_enabled": True,
            "assertion_rtol": provenance["assertion_rtol"],
            "assertion_atol": provenance["assertion_atol"],
            "species_mass_assertion_atol": 1e-10, "reference_assertions_passed": True}


def reference_valve2(ct, provenance, mechanism):
    import numpy as np

    left, right, valve, network = valve_pair(ct, provenance, mechanism,
                                            composition="O2:1.0", energy="off")
    if valve.valve_coeff != 2e-5 or left.energy_enabled or right.energy_enabled:
        raise AssertionError("Valve coefficient or disabled energy settings differ")
    m1a, m2a = left.volume * left.density, right.volume * right.density
    A = valve.valve_coeff * left.phase.P * (1 + m2a / m1a)
    B = valve.valve_coeff * (left.phase.P / m1a + right.phase.P / m2a)
    initial_y = list(left.Y)
    network.rtol = 1e-11
    samples = []
    for t in np.linspace(1e-5, 0.5):
        network.advance(float(t))
        m1, m2 = left.volume * left.density, right.volume * right.density
        analytic_m2 = (m2a - A / B) * math.exp(-B * t) + A / B
        check_close("analytic receiver mass", m2, analytic_m2, provenance)
        check_close("total mass", m1a + m2a, m1 + m2, provenance)
        for k, expected in enumerate(initial_y):
            check_close(f"upstream Y[{k}]", float(left.Y[k]), expected, provenance)
        samples.append({"time": float(t), "left_mass": float(m1), "right_mass": float(m2),
                        "analytic_right_mass": float(analytic_m2)})
    return {"time": float(network.time), "samples": samples,
            "initial_left_mass": float(m1a), "initial_right_mass": float(m2a),
            "initial_left_mass_fractions": initial_y, "A": float(A), "B": float(B),
            "max_analytic_mass_error": max(abs(s["right_mass"] - s["analytic_right_mass"]) for s in samples),
            "valve_coeff": float(valve.valve_coeff), "rtol": network.rtol, "atol": network.atol,
            "energy_enabled": False, "chemistry_enabled": True,
            "assertion_rtol": provenance["assertion_rtol"],
            "assertion_atol": provenance["assertion_atol"], "reference_assertions_passed": True}


def reference_valve_timing(ct, provenance, mechanism):
    left, right, valve, network = valve_pair(ct, provenance, mechanism)
    valve.time_function = lambda t: t > 0.01
    network.rtol = 1e-12
    network.initialize()
    samples = []
    for t in (0.0, 0.01, 0.01 + 1e-9, 0.02):
        if t:
            network.advance(t)
        dp = left.phase.P - right.phase.P
        expected_activity = 0.0 if t <= 0.01 else 1.0
        if valve.time_function != expected_activity:
            raise AssertionError(f"Valve time function mismatch at {t}")
        check_close("pressure function", valve.pressure_function, dp, provenance)
        if t <= 0.01:
            if valve.mass_flow_rate != 0.0:
                raise AssertionError(f"Valve should be closed at {t}")
        else:
            check_close("open-valve flow", valve.mass_flow_rate, valve.valve_coeff * dp, provenance)
        samples.append({"time": float(t), "activity": float(valve.time_function),
                        "pressure_difference": float(dp), "mass_flow_rate": float(valve.mass_flow_rate)})
    return {"time": float(network.time), "samples": samples,
            "valve_coeff": float(valve.valve_coeff), "rtol": network.rtol, "atol": network.atol,
            "energy_enabled": True, "chemistry_enabled": True,
            "assertion_rtol": provenance["assertion_rtol"],
            "assertion_atol": provenance["assertion_atol"], "reference_assertions_passed": True}


def reference_reinitialize(ct, provenance, mechanism):
    left, right, wall, network = thermal_pair(ct, provenance, mechanism, U=200.0, reactor_type=reactor_type)
    network.advance(1.0)
    first = [float(left.T), float(right.T)]
    ct.suppress_deprecation_warnings()  # Same allow_deprecated fixture as upstream.
    try:
        left.phase.TD = 300.0, None
        left.syncState()
        right.phase.TD = 1000.0, None
        right.syncState()
    finally:
        ct.make_deprecation_warnings_fatal()
    check_close("reset left T", left.T, 300.0, provenance)
    check_close("reset right T", right.T, 1000.0, provenance)
    network.advance(2.0)
    actual = [float(left.T), float(right.T)]
    for i in range(2):
        check_close(f"reinitialized T[{i}]", first[i], actual[i], provenance)
    return {"time": float(network.time), "first_temperatures": first,
            "second_temperatures": actual, "reset_temperatures": [300.0, 1000.0],
            "rtol": network.rtol, "atol": network.atol, "reference_assertions_passed": True}


def reference_reservoir_sync(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 800.0, ct.one_atm, "O2:1.0"
    reactor = ct.IdealGasReactor(gas, clone=True)
    gas.TP = 900.0, ct.one_atm
    reservoir = ct.Reservoir(gas, clone=True)
    wall = ct.Wall(reactor, reservoir, U=500.0)
    network = ct.ReactorNet([reactor])
    network.advance(1.0)
    first_T = float(reactor.T)
    check_close("heated T", first_T, 872.099, provenance, rtol=1e-3)
    reservoir.phase.TP = 700.0, ct.one_atm
    network.reinitialize()
    network.advance(2.0)
    second_T = float(reactor.T)
    check_close("cooled T", second_T, 747.27, provenance, rtol=1e-3)
    return {"time": float(network.time), "first_temperature": first_T,
            "second_temperature": second_T, "reservoir_temperatures": [900.0, 700.0],
            "rtol": network.rtol, "atol": network.atol,
            "temperature_comparison_rtol": 1e-3, "reference_assertions_passed": True}


def moving_oxygen_pair(ct, provenance, mechanism, *, pressures=(101325.0, 101325.0),
                       volumes=(1.0, 1.0), area=1.0, K=0.0):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 300.0, pressures[0], "O2:1.0"
    left = ct.IdealGasReactor(gas, clone=True, volume=volumes[0])
    gas.TPX = 300.0, pressures[1], "O2:1.0"
    right = ct.IdealGasReactor(gas, clone=True, volume=volumes[1])
    wall = ct.Wall(left, right, A=area, K=K)
    return left, right, wall, ct.ReactorNet([left, right])


def reference_wall_velocity(ct, provenance, mechanism):
    left, right, wall, network = moving_oxygen_pair(ct, provenance, mechanism,
                                                  volumes=(2.0, 5.0), area=0.2)
    velocity = ct.Tabulated1([0.0, 1.0, 2.0], [0.0, 1.0, 0.0])
    wall.velocity = velocity
    network.advance(1.0)
    check_close("wall velocity at 1", wall.velocity, velocity(1.0), provenance)
    check_close("expansion rate at 1", wall.expansion_rate, 0.2, provenance, rtol=1e-7)
    at_one = {"velocity": float(wall.velocity), "expansion_rate": float(wall.expansion_rate)}
    network.advance(2.0)
    check_close("expansion rate at 2", wall.expansion_rate, 0.0, provenance, rtol=1e-7)
    check_close("left final volume", left.volume, 2.2, provenance, rtol=1e-7)
    check_close("right final volume", right.volume, 4.8, provenance, rtol=1e-7)
    return {"time": float(network.time), "at_one": at_one,
            "left_volume": float(left.volume), "right_volume": float(right.volume),
            "final_expansion_rate": float(wall.expansion_rate),
            "rtol": network.rtol, "atol": network.atol, "reference_assertions_passed": True}


def reference_equalize_pressure(ct, provenance, mechanism):
    left, right, wall, network = moving_oxygen_pair(ct, provenance, mechanism,
                                                  pressures=(101325.0, 300000.0), K=0.1)
    if len(left.walls) != 1 or len(right.walls) != 1 or left.walls[0] != wall or right.walls[0] != wall:
        raise AssertionError("Moving wall attachment mismatch")
    network.advance(1.0)
    check_close("time", network.time, 1.0, provenance)
    check_close("final pressure", left.phase.P, right.phase.P, provenance)
    if abs(left.T - right.T) <= max(provenance["assertion_atol"], provenance["assertion_rtol"] * abs(right.T)):
        raise AssertionError("Pressure equalization must not also equalize temperatures")
    return {"time": float(network.time), "left_pressure": float(left.phase.P),
            "right_pressure": float(right.phase.P), "left_temperature": float(left.T),
            "right_temperature": float(right.T), "left_volume": float(left.volume),
            "right_volume": float(right.volume), "K": 0.1,
            "rtol": network.rtol, "atol": network.atol, "reference_assertions_passed": True}


def reference_invalid_empty_network(ct, provenance, mechanism):
    try:
        ct.ReactorNet([])
    except ct.CanteraError as error:
        message = str(error)
        if "No reactors in network" not in message:
            raise
    else:
        raise AssertionError("An empty ReactorNet must be rejected")
    return {"exception": "CanteraError", "message": message,
            "equivalent_upstream_ids": [
                f"test/python/test_reactor.py::{name}::test_invalid_empty_network"
                for name in ("TestReactor", "TestMoleReactor", "TestIdealGasReactor", "TestIdealGasMoleReactor")],
            "reference_assertions_passed": True}


def reference_equilibrium(ct, provenance, mechanism, mode):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 1100.0, 10 * ct.one_atm, "H2:1.0,O2:0.5,AR:8.0"
    constructor = ct.IdealGasReactor if mode == "UV" else ct.IdealGasConstPressureReactor
    reactor = constructor(gas, clone=True)
    network = ct.ReactorNet([reactor])
    network.advance(1.0)
    equilibrium = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    equilibrium.TPX = 1100.0, 10 * ct.one_atm, "H2:1.0,O2:0.5,AR:8.0"
    equilibrium.equilibrate(mode)
    check_close("equilibrium temperature", reactor.T, equilibrium.T, provenance)
    check_close("equilibrium density", reactor.phase.density, equilibrium.density, provenance)
    expected_pressure = equilibrium.P if mode == "UV" else 10 * ct.one_atm
    check_close("equilibrium pressure", reactor.phase.P, expected_pressure, provenance)
    for k, expected in enumerate(equilibrium.X):
        check_close(f"equilibrium X[{k}]", float(reactor.phase.X[k]), float(expected), provenance)
    return {"time": float(network.time), "mode": mode, "species_names": gas.species_names,
            "temperature": float(reactor.T), "pressure": float(reactor.phase.P),
            "density": float(reactor.phase.density), "mole_fractions": list(reactor.phase.X),
            "equilibrium_temperature": float(equilibrium.T),
            "equilibrium_pressure": float(equilibrium.P),
            "equilibrium_density": float(equilibrium.density),
            "equilibrium_mole_fractions": list(equilibrium.X),
            "rtol": network.rtol, "atol": network.atol, "reference_assertions_passed": True}


def reference_set_initial_time(ct, provenance, mechanism):
    results = []
    for initial_time in (0.0, 0.2):
        left, right, valve, network = valve_pair(ct, provenance, mechanism)
        valve.valve_coeff = 1.0
        pressure_function = lambda dp: 5e-3 * math.sqrt(dp) if dp > 0 else 0.0
        valve.pressure_function = pressure_function
        network.rtol = 1e-12
        network.initial_time = initial_time
        network.advance(initial_time + 0.5)
        check_close("final time", network.time, initial_time + 0.5, provenance)
        dp = left.phase.P - right.phase.P
        check_close("pressure function", valve.pressure_function, pressure_function(dp), provenance)
        results.append({"initial_time": initial_time, "time": float(network.time),
                        "left_pressure": float(left.phase.P), "right_pressure": float(right.phase.P),
                        "pressure_function": float(valve.pressure_function)})
    for side in ("left_pressure", "right_pressure"):
        check_close(side, results[0][side], results[1][side], provenance)
    return {"runs": results, "rtol": network.rtol, "atol": network.atol,
            "reference_assertions_passed": True}


def reference_valve3(ct, provenance, mechanism):
    left, right, valve, network = valve_pair(ct, provenance, mechanism,
                                            composition="AR:0.5,O2:0.5")
    mdot = lambda dp: 5e-3 * math.sqrt(dp) if dp > 0 else 0.0
    valve.valve_coeff = 1.0
    valve.pressure_function = mdot
    if valve.valve_coeff != 1.0:
        raise AssertionError("Expected unit valve coefficient")
    initial_y = left.Y.copy()
    species = [left.phase.species_index(s) for s in ("AR", "O2")]
    def species_mass(k):
        return left.Y[k] * left.mass + right.Y[k] * right.mass
    initial_mass = [species_mass(k) for k in species]
    network.rtol, network.atol = 1e-12, 1e-20
    steps = 0
    while network.time < 1.0:
        network.step()
        check_close("valve flow", mdot(left.phase.P - right.phase.P), valve.mass_flow_rate, provenance)
        for k, y in enumerate(initial_y):
            check_close(f"upstream Y[{k}]", float(y), float(left.Y[k]), provenance)
        for k, expected in zip(species, initial_mass):
            check_close(f"species mass {k}", species_mass(k), expected, provenance)
        steps += 1
    return {"time": float(network.time), "accepted_steps": steps,
            "initial_upstream_mass_fractions": list(initial_y),
            "conserved_species": ["AR", "O2"], "initial_species_masses": list(initial_mass),
            "final_species_masses": [float(species_mass(k)) for k in species],
            "final": valve_snapshot(left, right, valve), "valve_coeff": float(valve.valve_coeff),
            "rtol": network.rtol, "atol": network.atol, "reference_assertions_passed": True}


def reference_pressure_controller2(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 300.0, ct.one_atm, "O2:1.0"
    reactor = ct.IdealGasReactor(gas, clone=True)
    gas.TPX = 500.0, 2 * ct.one_atm, "H2:1.0"
    inlet = ct.Reservoir(gas, clone=True)
    gas.TP = 300.0, ct.one_atm
    outlet = ct.Reservoir(gas, clone=True)
    mdot = lambda t: math.exp(-100 * (t - 0.5)**2)
    mfc = ct.MassFlowController(inlet, reactor)
    mfc.mass_flow_coeff, mfc.time_function = 1.0, mdot
    pc = ct.PressureController(reactor, outlet, primary=mfc)
    pfunc = lambda dp: 1e-5 * abs(dp)**0.5
    pc.pressure_function = pfunc
    if pc.pressure_coeff != 1.0:
        raise AssertionError("Expected unit pressure coefficient")
    network = ct.ReactorNet([reactor])
    steps = 0
    while network.time < 1.0:
        t = network.step()
        check_close("primary flow", mdot(t), mfc.mass_flow_rate, provenance)
        dp = reactor.phase.P - outlet.phase.P
        check_close("controller flow", mdot(t) + pfunc(dp), pc.mass_flow_rate, provenance)
        steps += 1
    return {"time": float(network.time), "accepted_steps": steps,
            "temperature": float(reactor.T), "pressure": float(reactor.phase.P),
            "mass": float(reactor.mass), "primary_flow": float(mfc.mass_flow_rate),
            "controller_flow": float(pc.mass_flow_rate), "pressure_coeff": float(pc.pressure_coeff),
            "rtol": network.rtol, "atol": network.atol, "reference_assertions_passed": True}


def reference_mass_flow_controller(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 300.0, ct.one_atm, "O2:1.0"
    reactor = ct.IdealGasReactor(gas, clone=True)
    gas.TPX = 300.0, 10 * ct.one_atm, "H2:1.0"
    reservoir = ct.Reservoir(gas, clone=True)
    def mdot(t):
        return 0.2 - 0.4 * abs(t - 0.7) if 0.2 <= t < 1.2 else 0.0
    mfc = ct.MassFlowController(reservoir, reactor)
    mfc.mass_flow_rate = mdot
    if mfc.mass_flow_coeff != 1.0 or mfc.type != type(mfc).__name__:
        raise AssertionError("Mass-flow controller coefficient/type mismatch")
    if (len(reservoir.inlets) != 0 or len(reservoir.outlets) != 1
            or reservoir.outlets[0] != mfc or len(reactor.outlets) != 0
            or len(reactor.inlets) != 1 or reactor.inlets[0] != mfc):
        raise AssertionError("Mass-flow controller attachment mismatch")
    initial_mass, initial_y = reactor.mass, reactor.Y.copy()
    inlet_y = reservoir.Y.copy()
    network = ct.ReactorNet([reactor])
    network.rtol, network.max_time_step = 1e-11, 0.05
    samples = []
    for t, expected in ((0.1, 0.0), (0.3, 0.04), (1.0, 0.08), (1.2, 0.0)):
        network.advance(t)
        check_close("pulse flow", mfc.mass_flow_rate, expected, provenance)
        samples.append({"time": float(t), "mass_flow_rate": float(mfc.mass_flow_rate)})
    network.advance(2.5)
    check_close("injected total mass", initial_mass + 0.1, reactor.mass, provenance)
    for k in range(gas.n_species):
        check_close(f"injected species mass {k}", float(initial_mass * initial_y[k] + 0.1 * inlet_y[k]),
                    float(reactor.mass * reactor.Y[k]), provenance)
    return {"time": float(network.time), "samples": samples, "initial_mass": float(initial_mass),
            "initial_mass_fractions": list(initial_y), "inlet_mass_fractions": list(inlet_y),
            "final_mass": float(reactor.mass), "final_mass_fractions": list(reactor.Y),
            "temperature": float(reactor.T), "pressure": float(reactor.phase.P),
            "rtol": network.rtol, "atol": network.atol, "max_time_step": network.max_time_step,
            "mass_flow_coeff": mfc.mass_flow_coeff, "reference_assertions_passed": True}


def idle_network(ct, provenance, mechanism, n=2):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 300.0, ct.one_atm, "O2:1.0"
    reactors = [ct.IdealGasReactor(gas, clone=True) for _ in range(n)]
    return reactors, ct.ReactorNet(reactors)


def reference_timestepping(ct, provenance, mechanism):
    _, network = idle_network(ct, provenance, mechanism)
    network.max_time_step, network.initial_time = 0.07, 0.3
    if network.max_time_step != 0.07 or network.initial_time != 0.3:
        raise AssertionError("Time-step options were not retained")
    check_close("initial time", network.time, 0.3, provenance)
    steps, maximum_step = 0, 0.0
    while network.time < 10.0:
        previous = network.time
        t = network.step()
        dt = t - previous
        if dt > 1.0001 * 0.07:
            raise AssertionError(f"Maximum step exceeded: {dt}")
        check_close("step return time", t, network.time, provenance)
        maximum_step = max(maximum_step, dt)
        steps += 1
    return {"initial_time": network.initial_time, "time": float(network.time),
            "accepted_steps": steps, "maximum_observed_step": maximum_step,
            "max_time_step": network.max_time_step, "reference_assertions_passed": True}


def reference_maxsteps(ct, provenance, mechanism):
    _, network = idle_network(ct, provenance, mechanism)
    network.initial_time, network.max_time_step, network.max_steps = 0.0, 1e-7, 10
    try:
        network.advance(1e-4)
    except ct.CanteraError as error:
        message = str(error)
        if "Maximum number of timesteps" not in message:
            raise
    else:
        raise AssertionError("Expected maximum-timestep failure")
    if network.time > 10 * 1e-7 or network.max_steps != 10:
        raise AssertionError("Step-limit failure state/options mismatch")
    return {"time": float(network.time), "max_steps": network.max_steps,
            "max_time_step": network.max_time_step, "exception": message,
            "reference_assertions_passed": True}


def reference_tolerances(ct, provenance, mechanism):
    counts = []
    for rtol, atol in ((1e-10, 1e-20), (1e-8, 1e-20), (1e-10, 1e-5)):
        gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
        gas.TPX = 1100.0, 10 * ct.one_atm, "H2:1.0,O2:0.5,AR:8.0"
        reactor = ct.IdealGasReactor(gas, clone=True)
        network = ct.ReactorNet([reactor])
        network.rtol, network.atol = rtol, atol
        if network.rtol != rtol or network.atol != atol:
            raise AssertionError("Integration tolerances were not retained")
        steps = 0
        while network.time < 1.0:
            network.step()
            steps += 1
        counts.append({"rtol": rtol, "atol": atol, "accepted_steps": steps,
                       "time": float(network.time)})
    if not (counts[0]["accepted_steps"] > counts[1]["accepted_steps"]
            and counts[0]["accepted_steps"] > counts[2]["accepted_steps"]):
        raise AssertionError("Looser tolerance did not reduce the accepted-step count")
    return {"runs": counts, "reference_assertions_passed": True}


def reference_derivative(ct, provenance, mechanism):
    _, network = idle_network(ct, provenance, mechanism, n=1)
    network.advance(1.0)
    derivative, before, initial_time = network.get_derivative(1).copy(), network.get_state().copy(), network.time
    network.step()
    finite_difference = (network.get_state() - before) / (network.time - initial_time)
    for k, (a, b) in enumerate(zip(derivative, finite_difference)):
        check_close(f"state derivative {k}", float(a), float(b), provenance)
    return {"initial_time": float(initial_time), "time": float(network.time),
            "derivative": list(derivative), "finite_difference": list(finite_difference),
            "reference_assertions_passed": True}


def reference_advance_reverse(ct, provenance, mechanism):
    _, network = idle_network(ct, provenance, mechanism, n=1)
    network.advance(0.1)
    try:
        network.advance(0.09)
    except ct.CanteraError as error:
        message = str(error)
        if "backwards in time" not in message:
            raise
    else:
        raise AssertionError("Expected backward-advance rejection")
    return {"time": float(network.time), "requested_time": 0.09, "exception": message,
            "reference_assertions_passed": True}


def reference_finite_difference_jacobian(ct, provenance, mechanism):
    gas = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas.TPX = 900.0, ct.one_atm, "H2:0.4,O2:0.4,N2:0.2"
    reactor = ct.IdealGasReactor(gas, clone=True)
    network = ct.ReactorNet([reactor])
    index_h2 = gas.species_index("H2")
    steps = 0
    while reactor.phase.X[index_h2] > 0.3:
        network.step()
        steps += 1

    def state_snapshot():
        return {"temperature": float(reactor.T), "pressure": float(reactor.phase.P),
                "mass": float(reactor.mass), "volume": float(reactor.volume),
                "mass_fractions": [float(y) for y in reactor.Y]}

    advanced = state_snapshot()

    def check_same_state(label, actual):
        for field in ("temperature", "pressure", "mass", "volume"):
            check_close(f"{label} {field}", actual[field], advanced[field], provenance)
        for k, (a, b) in enumerate(zip(actual["mass_fractions"], advanced["mass_fractions"])):
            check_close(f"{label} Y[{k}]", a, b, provenance)

    jacobian = reactor.finite_difference_jacobian
    if jacobian.shape != (reactor.n_vars, reactor.n_vars):
        raise AssertionError("Finite-difference Jacobian shape mismatch")
    first_names = []
    for i in range(3):
        name = reactor.component_name(i)
        first_names.append(name)
        if name in {"mass", "volume", "int_energy", "enthalpy", "pressure"}:
            if not all(jacobian[i, :] == 0):
                raise AssertionError(f"Nonzero constant-state Jacobian row {name}")
        elif name == "temperature" and not any(jacobian[i, :] != 0):
            raise AssertionError("Temperature Jacobian row should be nonzero")
    reactor.energy_enabled = False
    jacobian = reactor.finite_difference_jacobian
    energy_disabled = state_snapshot()
    check_same_state("energy disabled", energy_disabled)
    for i in range(3):
        if reactor.component_name(i) == "temperature" and not all(jacobian[i, :] == 0):
            raise AssertionError("Disabled energy should zero the temperature row")
    reactor.energy_enabled, reactor.chemistry_enabled = True, False
    jacobian = reactor.finite_difference_jacobian
    chemistry_disabled = state_snapshot()
    check_same_state("chemistry disabled", chemistry_disabled)
    species_start = reactor.component_index(gas.species_name(0))
    for i in range(reactor.n_vars):
        if reactor.component_name(i) in gas.species_names and not all(jacobian[i, species_start:] == 0):
            raise AssertionError("Disabled chemistry should zero the species Jacobian block")
    return {"time": float(network.time), "accepted_steps": steps,
            "temperature": float(reactor.T), "pressure": float(reactor.phase.P),
            "mole_fractions": list(reactor.phase.X), "n_vars": reactor.n_vars,
            "first_component_names": first_names, "jacobian_shape": list(jacobian.shape),
            "advanced_state": advanced, "energy_disabled_state": energy_disabled,
            "chemistry_disabled_state": chemistry_disabled,
            "reference_assertions_passed": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=("hydrogen_const_pressure", "hydrogen_single_jacobian", "connector_mfc_constant", "connector_species_subset", "connector_mfc_energy", "connector_heat_jacobian", "disable_chemistry", "disjoint", "disable_energy",
                                          "heat_transfer1", "heat_transfer2", "heat_flux_func", "reactor_heat_flux_func",
                                          "reactor_heat_transfer1", "reactor_heat_transfer2",
                                          "valve1", "valve2", "valve_timing", "reinitialize",
                                          "reservoir_sync", "wall_velocity", "equalize_pressure",
                                          "invalid_empty_network", "equilibrium_UV", "equilibrium_HP",
                                          "set_initial_time", "valve3", "pressure_controller2",
                                          "mass_flow_controller", "timestepping", "maxsteps",
                                          "tolerances", "derivative", "advance_reverse",
                                          "finite_difference_jacobian", "wall_step", "wall_advance",
                                          "const_pressure_closed", "zerodim_simple", "combustor_step", "combustor_advance", "combustor_invasive", "wsr_nonreacting", "wsr_ignition1", "wsr_ignition2", "wsr_ignition3"),
                        default="disable_chemistry", help="Upstream ideal-gas reactor case")
    parser.add_argument("--source-dir", type=Path, required=True,
                        help="Clean Cantera checkout at the pinned commit")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-environment", action="store_true")
    mode.add_argument("--output", type=Path, help="Write a new reference JSON record")
    args = parser.parse_args()
    if args.output is not None and args.output.exists():
        parser.error("Output already exists; choose a new path to preserve prior evidence")
    ct, provenance, mechanism, record = environment(args.source_dir)
    record["upstream_test"] = (
        "test/python/test_reactor.py::TestIdealGasReactor::test_" + args.case
    )
    if args.case.startswith("reactor_heat_"):
        record["upstream_test"] = "test/python/test_reactor.py::TestReactor::test_" + args.case.removeprefix("reactor_")
    if args.case in ("wall_step", "wall_advance"):
        from reactor_wall_reference import wall_inputs, reference_wall
        method = "test_integrateWithStep" if args.case == "wall_step" else "test_integrateWithAdvance"
        record["upstream_test"] = "test/python/test_reactor.py::TestWall::" + method
        _, record["wall_inputs"] = wall_inputs(args.source_dir, provenance)
    elif args.case in ("combustor_step", "combustor_advance", "combustor_invasive"):
        from reactor_combustor_reference import combustor_inputs, reference_combustor
        record["combustor_inputs"] = combustor_inputs(args.source_dir, provenance)
        record["upstream_test"] = record["combustor_inputs"][
            {"combustor_step": "upstream_test", "combustor_advance": "advance_upstream_test",
             "combustor_invasive": "invasive_upstream_test"}[args.case]]
    elif args.case == "const_pressure_closed":
        from reactor_const_pressure_reference import const_pressure_inputs, reference_const_pressure
        folder, manifest = const_pressure_inputs(args.source_dir, provenance)
        record["upstream_test"] = "test/python/test_reactor.py::TestIdealGasConstPressureReactor::test_closed"
        record["common_environment_gate_mechanism"] = {"path": record["mechanism"],
            "phase": record["phase"], "sha256_lf": record["mechanism_sha256_lf"]}
        mechanism = folder / manifest["normalized_file"]
        record["mechanism"], record["phase"] = str(mechanism), manifest["phase"]
        record["mechanism_sha256_lf"] = manifest["normalized_sha256_lf"]
        record["const_pressure_inputs"] = manifest
    elif args.case == "zerodim_simple":
        from reactor_cpp_reference import cpp_inputs, reference_cpp_simple
        mechanism, manifest = cpp_inputs(ct, args.source_dir, provenance)
        record["upstream_test"] = manifest["upstream_test"]
        record["common_environment_gate_mechanism"] = {"path": record["mechanism"],
            "phase": record["phase"], "sha256_lf": record["mechanism_sha256_lf"]}
        record["mechanism"], record["phase"] = str(mechanism), manifest["phase"]
        record["mechanism_sha256_lf"] = manifest["mechanism_sha256_lf"]
        record["cpp_inputs"] = manifest
    elif args.case in ("wsr_nonreacting", "wsr_ignition1", "wsr_ignition2", "wsr_ignition3"):
        from reactor_wsr_reference import wsr_inputs, reference_wsr
        mechanism, wsr_manifest = wsr_inputs(args.source_dir, provenance)
        record["upstream_test"] = "test/python/test_reactor.py::TestWellStirredReactorIgnition::test_" + args.case.removeprefix("wsr_")
        record["common_environment_gate_mechanism"] = {"path": record["mechanism"],
            "phase": record["phase"], "sha256_lf": record["mechanism_sha256_lf"]}
        record["mechanism"], record["phase"] = str(mechanism), wsr_manifest["phase"]
        record["mechanism_sha256_lf"] = wsr_manifest["mechanism_sha256_lf"]
        record["wsr_inputs"] = wsr_manifest
    if args.case == "connector_heat_jacobian":
        from reactor_connector_reference import reference_connector_heat
        record["upstream_test"] = "test/python/test_reactor.py::TestConnectorJacobians::test_wall_heat_transfer_cross_reactor_temperature"
    if args.case == "connector_mfc_energy":
        from reactor_connector_reference import reference_connector_mfc_energy
        record["upstream_test"] = "test/python/test_reactor.py::TestConnectorJacobians::test_mfc_energy_enabled_cross_reactor"
    if args.case == "connector_species_subset":
        from reactor_subset_reference import reference_subset, subset_inputs
        record["subset_inputs"] = subset_inputs(args.source_dir,provenance)
        record["upstream_test"] = record["subset_inputs"]["upstream_test"]
    if args.case == "connector_mfc_constant":
        from reactor_constant_reference import reference_constant
        record["upstream_test"] = "test/python/test_reactor.py::TestConnectorJacobians::test_mfc_const_flow_cross_reactor_species"
    if args.case == "hydrogen_single_jacobian":
        from reactor_hydrogen_reference import reference_hydrogen
        record["upstream_test"] = "test/python/test_reactor.py::TestReactorJacobians::test_const_volume_hydrogen_single"
    if args.case == "hydrogen_const_pressure":
        from reactor_hydrogen_reference import reference_hydrogen
        record["upstream_test"] = "test/python/test_reactor.py::TestReactorJacobians::test_const_pressure_hydrogen_single"
    if args.check_environment:
        record["status"] = "environment_checked_only"
    else:
        run = {"hydrogen_const_pressure": lambda ct, p, m: reference_hydrogen(ct, p, m, args.source_dir, constant_pressure=True),
               "hydrogen_single_jacobian": lambda ct, p, m: reference_hydrogen(ct, p, m, args.source_dir),
               "connector_mfc_constant": lambda ct, p, m: reference_constant(ct, p, m, args.source_dir),
               "connector_heat_jacobian": lambda ct, p, m: reference_connector_heat(ct, p, m),
               "connector_species_subset": lambda ct, p, m: reference_subset(ct, p, m, args.source_dir),
               "connector_mfc_energy": lambda ct, p, m: reference_connector_mfc_energy(ct, p, m),
               "disable_chemistry": reference, "disjoint": reference_disjoint,
               "disable_energy": reference_disable_energy,
               "wsr_nonreacting": lambda ct, p, m: reference_wsr(ct, wsr_manifest, m),
               "wsr_ignition1": lambda ct, p, m: reference_wsr(ct, wsr_manifest, m, "ignition1"),
               "wsr_ignition2": lambda ct, p, m: reference_wsr(ct, wsr_manifest, m, "ignition2"),
               "wsr_ignition3": lambda ct, p, m: reference_wsr(ct, wsr_manifest, m, "ignition3"),
               "heat_transfer1": reference_heat_transfer1, "heat_transfer2": reference_heat_transfer2,
               "heat_flux_func": reference_heat_flux_func,
               "reactor_heat_transfer1": lambda ct, p, m: reference_heat_transfer1(ct, p, m, reactor_type=ct.Reactor),
               "reactor_heat_transfer2": lambda ct, p, m: reference_heat_transfer2(ct, p, m, reactor_type=ct.Reactor),
               "reactor_heat_flux_func": lambda ct, p, m: reference_heat_flux_func(ct, p, m, reactor_type=ct.Reactor),
               "valve1": reference_valve1, "valve2": reference_valve2,
               "valve_timing": reference_valve_timing, "reinitialize": reference_reinitialize,
               "reservoir_sync": reference_reservoir_sync, "wall_velocity": reference_wall_velocity,
               "equalize_pressure": reference_equalize_pressure,
               "invalid_empty_network": reference_invalid_empty_network,
               "equilibrium_UV": lambda ct, p, m: reference_equilibrium(ct, p, m, "UV"),
               "equilibrium_HP": lambda ct, p, m: reference_equilibrium(ct, p, m, "HP"),
               "set_initial_time": reference_set_initial_time, "valve3": reference_valve3,
               "pressure_controller2": reference_pressure_controller2,
               "mass_flow_controller": reference_mass_flow_controller,
               "timestepping": reference_timestepping, "maxsteps": reference_maxsteps,
               "tolerances": reference_tolerances, "derivative": reference_derivative,
               "advance_reverse": reference_advance_reverse,
               "finite_difference_jacobian": reference_finite_difference_jacobian,
               "wall_step": lambda ct, p, m: reference_wall(ct, p, m, args.source_dir, "step"),
               "wall_advance": lambda ct, p, m: reference_wall(ct, p, m, args.source_dir, "advance"),
               "combustor_step": lambda ct, p, m: reference_combustor(ct, p, m, args.source_dir),
               "combustor_advance": lambda ct, p, m: reference_combustor(ct, p, m, args.source_dir, "advance"),
               "combustor_invasive": lambda ct, p, m: reference_combustor(ct, p, m, args.source_dir, "invasive"),
               "const_pressure_closed": lambda ct, p, m: reference_const_pressure(ct, p, m),
               "zerodim_simple": lambda ct, p, m: reference_cpp_simple(ct, p, m, args.source_dir, args.output)}[args.case]
        record["result"] = run(ct, provenance, mechanism)
        record["status"] = ("reference_passed_native_not_verified" if
            record["result"]["reference_assertions_passed"] else "reference_failed")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(record, stream, indent=2, allow_nan=False)
            stream.write("\n")
    print(json.dumps(record, indent=2, allow_nan=False))
    if record["status"] == "reference_failed":
        sys.exit(1)


if __name__ == "__main__":
    main()
