#!/usr/bin/env python3
"""Cantera reference behavior for committed pathological h2o2 fixtures.

Run in the pinned Cantera environment:
  python test/pathological_mechanisms_cantera.py --case clean
  python test/pathological_mechanisms_cantera.py --solves --case nasa7_small
"""
from __future__ import annotations

import argparse
import json
import math
import warnings
from pathlib import Path

import cantera as ct
import numpy as np


def fixtures(directory):
    return {path.stem: path for path in sorted(directory.glob("*.yaml"))}

def evaluate(path, solves):
    row = {"path": path.name, "load": "ok", "evaluation": "not-run"}
    try:
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            gas = ct.Solution(str(path))
        row["warnings"] = [str(item.message).splitlines()[0] for item in caught]
    except Exception as exc:
        lines = [line.strip() for line in str(exc).splitlines()]
        message = next((line for line in lines if line and set(line) != {"*"}), "load failed")
        row.update(load="error", message=message)
        return row
    temps = (250.0, 999.999, 1000.0, 1000.001, 2500.0, 3500.0)
    finite = True
    for T in temps:
        gas.TPX = T, ct.one_atm, "H2:2, O2:1, AR:4"
        finite &= all(np.all(np.isfinite(x)) for x in (
            gas.net_production_rates, gas.standard_cp_R, gas.standard_enthalpies_RT, gas.standard_entropies_R))
    row.update(evaluation="finite" if finite else "nonfinite", temperatures_K=temps)
    if not solves:
        return row
    try:
        flame_gas = ct.Solution(str(path))
        flame_gas.TP = 300.0, ct.one_atm
        flame_gas.set_equivalence_ratio(1.1, "H2", "O2:1, AR:5")
        flame = ct.FreeFlame(flame_gas, width=0.03)
        flame.set_refine_criteria(ratio=3.0, slope=0.06, curve=0.12)
        flame.solve(loglevel=0, auto=True)
        solver_stats = flame.solver_stats
        row["free_flame"] = {
            "converged": True, "grid_points": len(flame.grid),
            "speed_m_s": float(flame.velocity[0]),
            "steps_total": sum(solver_stats.get("steps", [])),
            "jacobian_evals_total": sum(solver_stats.get("jacobian_evals", [])),
            "residual_evals_total": sum(solver_stats.get("residual_evals", [])),
            "solver_stats": solver_stats}
    except Exception as exc:
        row["free_flame"] = {"converged": False, "message": next((line.strip() for line in str(exc).splitlines() if line.strip() and set(line.strip()) != {"*"}), "solve failed")}
    try:
        ignition_gas = ct.Solution(str(path))
        ignition_gas.TPX = 1001.0, 3 * ct.one_atm, "H2:2, O2:1, AR:4"
        reactor = ct.IdealGasConstPressureReactor(ignition_gas, energy="on")
        network = ct.ReactorNet([reactor])
        t_end = 0.02
        while network.time < t_end and reactor.T < 1600:
            network.step()
        row["ignition"] = {
            "converged": math.isfinite(reactor.T), "time_s": float(network.time),
            "temperature_K": float(reactor.T),
            "ignited": bool(reactor.T >= 1600),
            "reached_t_end": bool(network.time >= t_end),
            "steps": int(network.solver_stats.get("steps", 0))}
    except Exception as exc:
        row["ignition"] = {"converged": False, "message": next((line.strip() for line in str(exc).splitlines() if line.strip() and set(line.strip()) != {"*"}), "solve failed")}
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--solves", action="store_true")
    parser.add_argument("--case")
    args = parser.parse_args()
    fixture_dir = Path(__file__).resolve().parent / "data" / "pathological_mechanisms"
    paths = fixtures(fixture_dir)
    selected = [(n, p) for n, p in paths.items() if args.case is None or n == args.case]
    if args.case is not None and not selected:
        raise SystemExit(f"unknown case: {args.case}")
    rows = [evaluate(p, args.solves) for _, p in selected]
    print(json.dumps({"cantera_version": ct.__version__, "fixtures": rows}, indent=2))


if __name__ == "__main__":
    main()
