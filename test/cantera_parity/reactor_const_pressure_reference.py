"""The pinned closed constant-pressure versus expanding-wall regression."""

import json
from pathlib import Path
import tomllib

from export_const_pressure_fixture import digest, source_definition, GRI_SHA, SPECIES
from reactor_reference import FIXTURE, check_close


def const_pressure_inputs(source_dir, provenance):
    folder = FIXTURE / "const_pressure_18"
    with (folder / "fixture.toml").open("rb") as stream:
        manifest = tomllib.load(stream)
    if manifest["cantera_commit"] != provenance["cantera_commit"]:
        raise RuntimeError("Constant-pressure fixture commit mismatch")
    if digest((Path(source_dir) / "data/gri30.yaml").read_bytes()) != GRI_SHA:
        raise RuntimeError("Pinned source GRI30 mismatch")
    source_definition(source_dir)
    for key in ("raw", "normalized", "equivalence"):
        if digest((folder / manifest[key + "_file"]).read_bytes()) != manifest[key + "_sha256_lf"]:
            raise RuntimeError(f"Constant-pressure fixture mismatch: {key}")
    equivalence = json.loads((folder / manifest["equivalence_file"]).read_text())
    if not equivalence["input_equivalence_passed"] or len(equivalence["equivalence"]) != 4:
        raise RuntimeError("Missing formal four-state input equivalence")
    return folder, manifest


def reference_const_pressure(ct, provenance, mechanism):
    def phase():
        gas = ct.Solution(str(mechanism), "gas", transport_model=None)
        if gas.species_names != SPECIES or gas.n_reactions != 74:
            raise RuntimeError("Unexpected closed-reactor mechanism")
        return gas
    gas1, gas2, bath = phase(), phase(), phase()
    initial = (1200.0, 25 * ct.one_atm, "CH4:0.5,H2O:0.2,CO:0.3")
    gas1.TPX, gas2.TPX = initial, initial
    bath.TPX = 900.0, 25 * ct.one_atm, "H2:1.0"
    r1 = ct.IdealGasReactor(gas1, clone=True, volume=0.2)
    r2 = ct.IdealGasConstPressureReactor(gas2, clone=True, volume=0.2)
    env1, env2 = ct.Reservoir(bath, clone=True), ct.Reservoir(bath, clone=True)
    w1 = ct.Wall(r1, env1, K=1e3, A=0.1, U=0.0)
    w2 = ct.Wall(r2, env2, A=0.1, U=0.0)
    net1, net2 = ct.ReactorNet([r1]), ct.ReactorNet([r2])
    net1.max_time_step = net2.max_time_step = 0.05
    net2.max_err_test_fails = 10
    for net in (net1, net2):
        if (net.rtol, net.atol) != (provenance["integration_rtol"], provenance["integration_atol"]):
            raise RuntimeError("Constant-pressure Cantera defaults mismatch")

    def state(reactor):
        return {"temperature": float(reactor.T), "pressure": float(reactor.phase.P),
                "mass_fractions": list(reactor.Y), "mass": float(reactor.mass),
                "volume": float(reactor.volume)}

    def stats(net):
        try:
            return dict(net.solver_stats)
        except ct.CanteraError:
            return None

    result = {"species_names": SPECIES, "initial_moving": state(r1), "initial_constant_pressure": state(r2),
              "samples": [], "rtol": net1.rtol, "atol": net1.atol, "max_time_step": 0.05,
              "comparison": {"Y_rtol": 5e-4, "Y_atol": 1e-6, "T_rtol": 5e-5,
                             "P_rtol": 1e-6, "T_P_atol": 1e-12},
              "failure_control": {"reference_network": "constant_pressure",
                                  "setting": "max_err_test_fails", "value": 10,
                                  "underlying_call": "CVodeSetMaxErrTestFails",
                                  "source": "src/numerics/CVodesIntegrator.cpp:238-243,474-475",
                                  "meaning": "maximum local error-test failures permitted attempting one internal step",
                                  "native_equivalent": None,
                                  "native_behavior": "existing QNDF policy unchanged; maxiters is not an equivalent"}}
    for t in (0.5 + i for i in range(50)):
        try:
            net1.advance(t)
            net2.advance(t)
        except ct.CanteraError as error:
            result.update(failure_kind="solver_failed", error=str(error),
                          last_reported_time={"moving": float(net1.time), "constant_pressure": float(net2.time)},
                          solver_stats={"moving": stats(net1), "constant_pressure": stats(net2)},
                          reference_assertions_passed=False)
            return result
        moving, constant = state(r1), state(r2)
        result["samples"].append({"time": t, "moving": moving, "constant_pressure": constant})
        try:
            for k, (a, b) in enumerate(zip(moving["mass_fractions"], constant["mass_fractions"])):
                check_close(f"Y[{k}] at {t}", a, b, provenance, rtol=5e-4, atol=1e-6)
            check_close(f"T at {t}", moving["temperature"], constant["temperature"], provenance, rtol=5e-5)
            check_close(f"P at {t}", moving["pressure"], constant["pressure"], provenance)
        except AssertionError as error:
            result.update(failure_kind="solution_mismatch", error=str(error),
                          solver_stats={"moving": stats(net1), "constant_pressure": stats(net2)},
                          reference_assertions_passed=False)
            return result
    result.update(solver_stats={"moving": stats(net1), "constant_pressure": stats(net2)},
                  reference_assertions_passed=True)
    return result
