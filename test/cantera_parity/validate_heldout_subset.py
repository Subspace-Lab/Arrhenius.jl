"""Restricted gate stage of h/validate_heldout.sh using its original helpers.

Inputs are a file of authorized IDs and paired outputs from
h/nh3_native_server.jl and h/nh3_cantera.py. This deliberately supports a
branch and fewer than twelve cases without reading the remaining held-out IDs.
Artifacts are named ID.ct.npz and ID.native.npz.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

from extinction_gates import heldout_physical_validity

ACCURACY_GATES = ("speed_SL", "temperature", "species_profiles", "reference_converged", "elements")


def failing_gates(data):
    if not heldout_physical_validity(data):
        return ["physical_validity"]
    return [key for key in ACCURACY_GATES if not data["gates"].get(key, False)]


def main():
    parser = argparse.ArgumentParser()
    for name in ("root", "ids", "artifacts", "out"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    ids = [v.strip() for v in args.ids.read_text().splitlines() if v.strip()]
    assert ids and len(ids) == len(set(ids)), "empty or duplicate restricted selection"

    rows = []
    for case_id in ids:
        specs = [args.root / d / (case_id + ".json") for d in (
            "specs_free_ma", "specs_burner_respec", "specs_fixed_small", "ct_survey/specs_cf2")]
        refs = [args.root / d / (case_id + ".npz") for d in ("refs16", "refs_cf2/counterflow")]
        specs = [p for p in specs if p.is_file()]
        refs = [p for p in refs if p.is_file()]
        assert len(specs) == len(refs) == 1, "ambiguous or missing case mapping"
        result = args.out / (case_id + ".json")
        subprocess.run([
            os.environ["TRACE_CAP"], "60", os.environ["PY"], str(args.root / "h/nh3_gate.py"),
            str(specs[0]), str(refs[0]), str(args.artifacts / (case_id + ".ct.npz")),
            str(args.artifacts / (case_id + ".native.npz")), str(result),
        ], cwd=args.root, check=True)
        failures = failing_gates(json.loads(result.read_text()))
        rows.append({"id": case_id, "pass": not failures, "failing_gates": failures})
    summary = {"cases": len(rows), "accuracy_pass": sum(r["pass"] for r in rows), "results": rows}
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))
    return 0 if all(r["pass"] for r in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
