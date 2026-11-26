"""Pinned TestWall references; called after the common environment gate."""

import hashlib
import importlib.util
from pathlib import Path
import tomllib

import numpy as np


FIXTURE = Path(__file__).resolve().parent / "fixtures" / "cantera-726522be"


def wall_inputs(source_dir, provenance):
    with (FIXTURE / "wall_provenance.toml").open("rb") as stream:
        inputs = tomllib.load(stream)
    if inputs["cantera_commit"] != provenance["cantera_commit"]:
        raise RuntimeError("Wall fixture/source commit mismatch")
    records = []
    for name, source_key, hash_key in (
            ("air.yaml", "air_source", "air_sha256_lf"),
            ("WallTest-integrateWithAdvance.csv", "profile_source", "profile_sha256_lf")):
        digest = hashlib.sha256((FIXTURE / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        source = Path(source_dir) / inputs[source_key]
        source_digest = hashlib.sha256(source.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        if digest != inputs[hash_key] or source_digest != digest:
            raise RuntimeError(f"Pinned wall input mismatch: {name}")
        records.append({"name": name, "source": str(source), "sha256_lf": digest})
    return inputs, records


def reference_wall(ct, provenance, mechanism, source_dir, mode):
    inputs, files = wall_inputs(source_dir, provenance)
    utilities = Path(source_dir) / "test/python/utilities.py"
    spec = importlib.util.spec_from_file_location("pinned_cantera_profile_utils", utilities)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    compare_profiles = module.compareProfiles
    with (Path(__file__).parent / "profile_comparison_cases.toml").open("rb") as stream:
        checks = tomllib.load(stream)
    selfchecks = []
    for case in checks["cases"]:
        report = compare_profiles(case["reference"], case["sample"],
                                  rtol=checks["rtol"], atol=checks["atol"], xtol=checks["xtol"])
        if (report is None) != case["passes"]:
            raise AssertionError(f"Profile comparator selfcheck failed: {case['name']}")
        selfchecks.append({"name": case["name"], "expected_pass": case["passes"],
                           "actual_pass": report is None})

    gas0 = ct.Solution(str(FIXTURE / "air.yaml"), inputs["air_phase"])
    gas0.TP = 300.0, ct.one_atm
    env = ct.Reservoir(gas0, clone=True)
    gas1 = ct.Solution(str(FIXTURE / "air.yaml"), inputs["air_phase"])
    gas1.TPX = 1000.0, 30 * ct.one_atm, "AR:1.0"
    r1 = ct.Reactor(gas1, clone=True, volume=1.0)
    gas2 = ct.Solution(str(mechanism), provenance["phase"], transport_model=None)
    gas2.TPX = 500.0, 1.5 * ct.one_atm, "H2:0.5,O2:1.0,AR:10.0"
    r2 = ct.Reactor(gas2, clone=True, volume=1.0)
    w1 = ct.Wall(r2, r1, A=1.0, K=2e-4, U=400.0)
    w2 = ct.Wall(r2, env, A=1.0, U=2000.0)
    network = ct.ReactorNet([r1, r2])
    if (network.rtol, network.atol) != (provenance["integration_rtol"], provenance["integration_atol"]):
        raise RuntimeError("Cantera wall integration defaults differ from provenance")
    rows = []
    def append_row():
        rows.append([float(network.time), float(r1.T), float(r2.T),
                     float(r1.phase.P), float(r2.phase.P), float(r1.volume), float(r2.volume)])
    if mode == "step":
        while network.time < 0.01:
            previous = network.time
            network.step()
            if network.time <= previous:
                raise RuntimeError("Wall reference stopped before 0.01 s")
            append_row()
        if network.time < 0.01:
            raise AssertionError("Wall step reference did not cross final time")
        rtol, atol = 1e-3, 1e-8
    else:
        for t in np.linspace(0.0, 0.01, 200)[1:]:
            network.advance(float(t))
            append_row()
        rtol, atol = 2e-5, 1e-9
    data = np.asarray(rows)
    if not np.isfinite(data).all():
        raise AssertionError("Non-finite wall trajectory")
    profile = FIXTURE / "WallTest-integrateWithAdvance.csv"
    if np.genfromtxt(profile, delimiter=",").shape != (199, 7):
        raise RuntimeError("Unexpected fixed profile shape")
    report = compare_profiles(profile, data, rtol=rtol, atol=atol)
    if report:
        raise AssertionError(report)
    return {"time": float(network.time), "mode": mode,
            "columns": ["t", "T_r1", "T_r2", "P_r1", "P_r2", "V_r1", "V_r2"],
            "trajectory": rows, "inputs": files, "air_species_names": gas1.species_names,
            "environment_mole_fractions": list(env.phase.X),
            "r2_transport_model": gas2.transport_model, "rtol": network.rtol, "atol": network.atol,
            "comparison": {"rtol": rtol, "atol": atol, "xtol": 1e-5,
                           "source": str(utilities), "source_sha256_lf": hashlib.sha256(
                               utilities.read_bytes().replace(b"\r\n", b"\n")).hexdigest()},
            "comparator_selfchecks": selfchecks, "solver_stats": dict(network.solver_stats),
            "reference_assertions_passed": True}
