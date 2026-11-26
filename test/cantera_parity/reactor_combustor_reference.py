"""Pinned TestCombustor Step/Advance references and unchanged profile criteria."""

import hashlib
import importlib.util
import math
from pathlib import Path
import time
import tomllib

import numpy as np

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "cantera-726522be"


def combustor_inputs(source_dir, provenance):
    inputs = tomllib.loads((FIXTURE / "combustor_provenance.toml").read_text())
    if inputs["cantera_commit"] != provenance["cantera_commit"]:
        raise RuntimeError("Combustor commit mismatch")
    for local, source, expected in (
        (inputs["mechanism_file"], "data/h2o2.yaml", inputs["mechanism_sha256_lf"]),
        (inputs["profile_file"], inputs["profile_source"], inputs["profile_sha256_lf"])):
        for path in (FIXTURE / local, Path(source_dir) / source):
            if hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest() != expected:
                raise RuntimeError(f"Combustor input mismatch: {path}")
    if np.loadtxt(FIXTURE / inputs["profile_file"], delimiter=",").shape != (100, 12):
        raise RuntimeError("Combustor reference dimensions differ")
    return inputs


def reference_combustor(ct, provenance, mechanism, source_dir, mode="step"):
    if mode not in ("step", "advance", "invasive"):
        raise ValueError("Unknown combustor mode")
    inputs = combustor_inputs(source_dir, provenance)
    gas = ct.Solution(str(mechanism), inputs["phase"], transport_model=None)
    if (gas.n_species, gas.n_reactions, gas.species_names) != (
            inputs["species_count"], inputs["reaction_count"], inputs["species_names"]):
        raise RuntimeError("Combustor phase/order/count mismatch")
    gas.TPX = 300.0, ct.one_atm, "H2:1.0"
    fuel = ct.Reservoir(gas, clone=True)
    fuel_mw = gas.mean_molecular_weight
    gas.TPX = 300.0, ct.one_atm, "O2:1.0,AR:3.0"
    oxidizer = ct.Reservoir(gas, clone=True)
    oxidizer_mw = gas.mean_molecular_weight
    gas.TPX = 300.0, ct.one_atm, "H:1.0"
    igniter = ct.Reservoir(gas, clone=True)
    gas.TPX = 300.0, ct.one_atm, "AR:1.0"
    vessel = ct.IdealGasReactor(gas, clone=True, volume=1.0, energy="on")
    exhaust = ct.Reservoir(gas, clone=True)
    fuel_mdot, oxidizer_mdot = 0.1 * fuel_mw, 4 * 0.1 * oxidizer_mw
    m1 = ct.MassFlowController(fuel, vessel, mdot=fuel_mdot)
    m2 = ct.MassFlowController(oxidizer, vessel, mdot=oxidizer_mdot)
    m3 = ct.MassFlowController(igniter, vessel, mdot=ct.Func1("Gaussian", [0.1, 0.1, 0.05]))
    valve = ct.Valve(vessel, exhaust, K=1.0)
    network = ct.ReactorNet([vessel])
    density_reads = 0
    min_density, max_density = math.inf, -math.inf
    expected_density = float(igniter.density)
    if mode == "invasive":
        def invasive_mdot(t, t0=0.1, fwhm=0.05, amplitude=0.1):
            nonlocal density_reads, min_density, max_density
            density = float(igniter.density)
            density_reads += 1
            min_density, max_density = min(min_density, density), max(max_density, density)
            return amplitude * math.exp(-(t-t0)**2 * 4 * math.log(2) / fwhm**2)
        # Match the source: configure the existing controller before integrating.
        m3.mass_flow_rate = invasive_mdot
    if (network.rtol, network.atol) != (inputs["integration_rtol"], inputs["integration_atol"]):
        raise RuntimeError("Cantera integration defaults differ")
    utilities = Path(source_dir) / "test/python/utilities.py"
    spec = importlib.util.spec_from_file_location("pinned_combustor_utils", utilities)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    rows, previous, failure = [], 0.0, None
    times = np.linspace(0.0, 0.25, 101)[1:]
    rtol = inputs["profile_rtol" if mode == "step" else "advance_profile_rtol"]
    atol = inputs["profile_atol" if mode == "step" else "advance_profile_atol"]
    started = time.perf_counter()
    try:
        if mode == "step":
            while network.time < 0.25:
                previous = network.time
                network.step()
                if network.time <= previous:
                    raise RuntimeError("Combustor reference did not advance")
                rows.append([float(network.time), float(vessel.T), *map(float, vessel.phase.X)])
        else:
            for t in times:
                previous = network.time
                network.advance(float(t))
                if network.time != t:
                    raise AssertionError("Advance did not return the requested output time")
                rows.append([float(t), float(vessel.T), *map(float, vessel.phase.X)])
    except Exception as error:
        failure = {"kind": "solver_failed", "exception": str(error)}
    elapsed = time.perf_counter() - started
    callback_observation = None
    if mode == "invasive":
        callback_observation = {"reads_during_solve": density_reads, "expected_density": expected_density,
            "min_density": min_density if density_reads else None,
            "max_density": max_density if density_reads else None}
        if failure is None and (density_reads == 0 or min_density != expected_density or max_density != expected_density):
            failure = {"kind": "callback_observation_failed", "message": "Missing or incorrect igniter density reads"}
    if failure is None:
        valid_time = (previous < 0.25 <= network.time if mode == "step" else
                      len(rows) == 100 and np.array_equal(np.asarray(rows)[:, 0], times))
        if not valid_time or not np.isfinite(rows).all():
            failure = {"kind": "invalid_output", "message": "Crossing or finite-state guard failed"}
        else:
            report = module.compareProfiles(FIXTURE / inputs["profile_file"], rows,
                rtol=rtol, atol=atol)
            if report:
                failure = {"kind": "profile_exceeded", "message": report}
    return {"time": float(network.time), "previous_time": float(previous), "mode": mode,
            "output_rows": len(rows), "accepted_steps": int(network.solver_stats["steps"]),
            "trajectory": rows, "columns": ["t", "T", *["X_"+s for s in gas.species_names]],
            "inputs": inputs, "fuel_mdot": fuel_mdot, "oxidizer_mdot": oxidizer_mdot,
            "transport_model": gas.transport_model, "rtol": network.rtol, "atol": network.atol,
            "solver_stats": dict(network.solver_stats), "stepping_elapsed_seconds": elapsed,
            "comparison": {"rtol": rtol, "atol": atol,
                "xtol": inputs["profile_xtol"], "source_sha256_lf": hashlib.sha256(
                    utilities.read_bytes().replace(b"\r\n", b"\n")).hexdigest()},
            "callback_observation": callback_observation,
            "failure": failure, "reference_assertions_passed": failure is None}
