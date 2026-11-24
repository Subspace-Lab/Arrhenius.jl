"""Pinned WSR nonreacting and ignition1/2/3 references."""
import json
from pathlib import Path
import time
import tomllib

import numpy as np
from export_const_pressure_fixture import digest
from reactor_reference import check_close

FOLDER = Path(__file__).resolve().parent / "fixtures/cantera-726522be/wsr24"


def wsr_inputs(source, provenance):
    inputs = tomllib.loads((FOLDER / "fixture.toml").read_text())
    assert inputs["cantera_commit"] == provenance["cantera_commit"]
    assert digest((source / "data/gri30.yaml").read_bytes()) == inputs["source_gri30_sha256_lf"]
    assert digest((FOLDER / inputs["mechanism_file"]).read_bytes()) == inputs["mechanism_sha256_lf"]
    assert digest((FOLDER / "equivalence.json").read_bytes()) == inputs["equivalence_sha256_lf"]
    assert json.loads((FOLDER / "equivalence.json").read_text())["input_equivalence_passed"]
    return FOLDER / inputs["mechanism_file"], inputs


def reference_wsr(ct, inputs, mechanism, mode="nonreacting"):
    if mode not in ("nonreacting", "ignition1", "ignition2", "ignition3"):
        raise ValueError("Unknown WSR mode")
    gas = ct.Solution(str(mechanism), inputs["phase"])
    assert gas.species_names == inputs["species_names"] and gas.n_reactions == 129
    gas.TPX = 900, 10*ct.one_atm, "CH4:1"
    fuel = ct.Reservoir(gas)
    gas.TPX = 900, 10*ct.one_atm, "N2:3.76,O2:1"
    oxidizer = ct.Reservoir(gas)
    gas.TPX = 900, 10*ct.one_atm, "N2:1"
    vessel = ct.IdealGasReactor(gas)
    vessel.volume = 1.0
    exhaust = ct.Reservoir(gas)
    m1 = ct.MassFlowController(fuel,vessel)
    m1.mass_flow_rate = 1.0
    m2 = ct.MassFlowController(oxidizer,vessel)
    oxidizer_mdot = 80.0 if mode == "ignition3" else 20.0 if mode == "ignition2" else 5.0
    m2.mass_flow_rate = oxidizer_mdot
    valve = ct.Valve(vessel,exhaust)
    valve.valve_coeff = 1.0
    net = ct.ReactorNet([vessel])
    net.max_err_test_fails = 10
    if mode == "ignition3":
        net.max_time_step = 0.5
    if mode == "nonreacting":
        vessel.phase.set_multiplier(0.0)
    assert all(vessel.phase.multiplier(i)==(0 if mode=="nonreacting" else 1) for i in range(129))
    assert (net.rtol,net.atol)==(inputs["integration_rtol"],inputs["integration_atol"])
    rows,previous,failure = [],0.0,None
    final_time = 100.0 if mode in ("nonreacting", "ignition3") else 10.0
    ignition = None
    started = time.perf_counter()
    try:
        while net.time < final_time:
            previous = net.time
            net.step()
            if net.time <= previous:
                raise RuntimeError("WSR reference did not advance")
            rows.append([float(net.time),float(vessel.T),float(vessel.phase.P),*map(float,vessel.phase.Y)])
    except Exception as error:
        failure = {"kind":"solver_failed","exception":str(error)}
    elapsed = time.perf_counter()-started
    if failure is None:
        try:
            assert previous < final_time <= net.time and np.isfinite(rows).all()
            if mode == "nonreacting":
                for row in rows:
                    check_close("temperature",row[1],900.0,inputs,rtol=inputs["temperature_rtol"])
                check_close("Y_CH4",float(vessel.phase["CH4"].Y[0]),1/6,inputs)
            elif mode == "ignition3":
                assert net.max_time_step == 0.5
                assert rows[-1][1] < 910.0, "Mixture ignited"
            else:
                assert rows[-1][1] > 1200.0, "Mixture did not ignite"
                threshold = 0.5*(rows[0][1]+rows[-1][1])
                index = next((i for i,row in enumerate(rows) if row[1]>threshold),None)
                assert index is not None, "No ignition threshold crossing"
                expected_time = 1.4856 if mode == "ignition2" else 2.2249
                ignition = {"threshold":threshold,"index_1based":index+1,"time":rows[index][0],
                            "preceding_row":rows[index-1] if index else None,"crossing_row":rows[index],
                            "expected_time":expected_time,"rtol":1e-3,"atol":1e-12}
                check_close("ignition_time",rows[index][0],expected_time,inputs,rtol=1e-3,atol=1e-12)
        except AssertionError as error:
            failure = {"kind":"assertion_failed","exception":str(error)}
    return {"mode":mode,"fuel_mdot":1.0,"oxidizer_mdot":oxidizer_mdot,"ignition":ignition,"trajectory":rows,"columns":["t","T","P",*["Y_"+s for s in gas.species_names]],
            "time":float(net.time),"previous_time":float(previous),"retcode":"not exposed by Cantera Python",
            "max_temperature_error":max((abs(r[1]-900) for r in rows),default=None),
            "final_CH4":float(vessel.phase["CH4"].Y[0]),"transport_model":gas.transport_model,
            "solver_stats":dict(net.solver_stats),"stepping_elapsed_seconds":elapsed,
            "integration_rtol":net.rtol,"integration_atol":net.atol,"max_err_test_fails":10,
            "max_time_step":net.max_time_step,
            "failure_control_scope":"CVodeSetMaxErrTestFails per internal step; no native mapping",
            "failure":failure,"reference_assertions_passed":failure is None}
