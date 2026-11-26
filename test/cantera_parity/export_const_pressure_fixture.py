"""Reproducibly export and audit the pinned 18-species constant-pressure input.

The original Cantera export is valid with its explicit skip flag. Only the
normalized copy removes absent efficiency keys and uses strict loading.
"""

import argparse
import ast
from collections import Counter
from copy import deepcopy
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from ruamel.yaml import YAML

from reactor_reference import environment, check_close, FIXTURE


SPECIES = ["H2", "H", "O", "O2", "OH", "H2O", "HO2", "H2O2", "CH3", "CH4",
           "CO", "CO2", "HCO", "CH2O", "CH3O", "CH3OH", "N2", "AR"]
REMOVALS = {i: (1.5 if i == 16 else 3.0) for i in (1, 2, 8, 16, 22, 26, 32, 34, 36, 38, 42, 44, 49, 69)}
GRI_SHA = "06650b1e0ee0012f6903d5328b1bb218cb6007d07f8ebe375d18f24811039345"
DEFINITION_SHA = "801614428053e316519d0ad57e4ae9a34fc4646a970c4a5acc825165cab9bee6"


def digest(data):
    if isinstance(data, str):
        data = data.encode("utf-8")
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def source_definition(source_dir):
    source = Path(source_dir) / "test/python/test_reactor.py"
    tree = ast.parse(source.read_text(encoding="utf-8"))
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "TestConstPressureReactor")
    method = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == "create_reactors")
    assignment = next(n for n in method.body if isinstance(n, ast.Assign)
                      and any(isinstance(t, ast.Name) and t.id == "gas_def" for t in n.targets))
    definition = ast.literal_eval(assignment.value)
    if digest(definition) != DEFINITION_SHA:
        raise RuntimeError("Pinned gas_def digest mismatch")
    return definition


def snapshot(gas, third_indices):
    return {"temperature": float(gas.T), "pressure": float(gas.P),
            "mole_fractions": list(gas.X),
            "forward_rate_constants": list(gas.forward_rate_constants),
            "reverse_rate_constants": list(gas.reverse_rate_constants),
            "net_rates_of_progress": list(gas.net_rates_of_progress),
            "net_production_rates": list(gas.net_production_rates),
            "partial_molar_enthalpies": list(gas.partial_molar_enthalpies),
            "third_body_concentrations": [float(gas.third_body_concentrations[i]) for i in third_indices]}


def check_raw_strict_rejection(ct, data):
    """The legal raw export must fail if only its third-body skip flag is disabled."""
    candidate = deepcopy(data)
    candidate["phases"][0]["skip-undeclared-third-bodies"] = False
    stream = io.StringIO()
    YAML(typ="safe").dump(candidate, stream)
    try:
        ct.Solution(yaml=stream.getvalue())
    except ct.CanteraError as error:
        message = str(error)
        if ("ThirdBody::checkSpecies" not in message or
                "efficiencies for undeclared species: 'C2H6'" not in message):
            raise AssertionError("Strict raw loading failed for an unexpected reason") from error
        return {"rejected": True, "exception_type": type(error).__name__,
                "message": message, "only_changed_field": "skip-undeclared-third-bodies"}
    raise AssertionError("Strict raw loading unexpectedly accepted undeclared efficiencies")


def compare_snapshots(label, before, after, provenance):
    metrics = {}
    for field, values in before.items():
        a = np.atleast_1d(values).astype(float)
        b = np.atleast_1d(after[field]).astype(float)
        if a.shape != b.shape:
            raise AssertionError(f"{label}: {field} dimensions differ")
        for k, (x, y) in enumerate(zip(a, b)):
            check_close(f"{label} {field}[{k}]", float(x), float(y), provenance)
        error = np.abs(a-b)
        relative = error[b != 0] / np.abs(b[b != 0])
        metrics[field] = {"count": len(a), "max_absolute_error": float(error.max()),
                          "max_relative_error_nonzero_expected": float(relative.max()) if len(relative) else None}
    return metrics


def export_fixture(source_dir, output_dir):
    ct, provenance, _, record = environment(source_dir)
    output_dir = Path(output_dir)
    if output_dir.exists():
        raise FileExistsError("Preserve the original export; choose a new output directory")
    gri = Path(source_dir) / "data/gri30.yaml"
    if digest(gri.read_bytes()) != GRI_SHA:
        raise RuntimeError("Pinned GRI30 digest mismatch")
    definition = source_definition(source_dir)
    ct.add_data_directory(str(gri.parent))
    original = ct.Solution(yaml=definition)
    if original.species_names != SPECIES or original.n_reactions != 74:
        raise RuntimeError("Unexpected source submechanism")
    raw = original.write_yaml(precision=17)
    yaml = YAML(typ="safe")
    data = yaml.load(raw)
    if data["phases"][0].get("skip-undeclared-third-bodies") is not True:
        raise RuntimeError("Original export lost its explicit Cantera skip flag")
    strict_negative = check_raw_strict_rejection(ct, data)
    output_dir.mkdir(parents=True, exist_ok=False)
    (output_dir / "gri30-18.raw.yaml").write_text(raw, encoding="utf-8")
    normalized = deepcopy(data)
    phase = normalized["phases"][0]
    phase["reactions"] = "all"
    phase["skip-undeclared-third-bodies"] = False
    if phase["species"] != SPECIES:
        raise RuntimeError("Exported species are not local and ordered")
    removed = []
    for i, reaction in enumerate(normalized["reactions"], start=1):
        efficiencies = reaction.get("efficiencies", {})
        for name in list(efficiencies):
            if name not in SPECIES:
                value = efficiencies[name]
                if name.casefold() in {s.casefold() for s in SPECIES}:
                    raise RuntimeError("Do not silently remove a case-variant species name")
                if name != "C2H6" or i not in REMOVALS or value != REMOVALS[i]:
                    raise RuntimeError(f"Unexpected efficiency normalization: {i}, {name}, {value}")
                removed.append({"reaction_index_1based": i, "equation": reaction["equation"],
                                "species": name, "original_efficiency": float(value)})
                del efficiencies[name]
    if {r["reaction_index_1based"] for r in removed} != set(REMOVALS) or len(removed) != 14:
        raise RuntimeError("Normalization did not remove exactly the pinned 14 entries")
    expected = deepcopy(data)
    expected["phases"][0]["reactions"] = "all"
    expected["phases"][0]["skip-undeclared-third-bodies"] = False
    for entry in removed:
        del expected["reactions"][entry["reaction_index_1based"]-1]["efficiencies"]["C2H6"]
    if normalized != expected:
        raise RuntimeError("Unlisted mechanism changes")
    stream = io.StringIO()
    yaml.default_flow_style = False
    yaml.dump(normalized, stream)
    normalized_text = stream.getvalue()
    (output_dir / "gri30-18.normalized.yaml").write_text(normalized_text, encoding="utf-8")
    reloaded = ct.Solution(yaml=raw)
    strict = ct.Solution(yaml=normalized_text)
    phases = {"source": original, "raw_reloaded": reloaded, "normalized_strict": strict}
    for name, gas in phases.items():
        if gas.species_names != SPECIES or gas.n_reactions != 74:
            raise AssertionError(f"{name}: structural mismatch")
        if gas.reaction_equations() != original.reaction_equations():
            raise AssertionError(f"{name}: changed reaction order/equations")
        if sum(r.duplicate for r in gas.reactions()) != 6:
            raise AssertionError(f"{name}: changed duplicate markings")
    third_indices = [i for i, r in enumerate(original.reactions()) if r.third_body is not None]
    if len(third_indices) != 22:
        raise RuntimeError("Unexpected third-body associated reaction count")
    states = [(1200.0, 25*ct.one_atm, {"CH4": 0.5, "H2O": 0.2, "CO": 0.3}),
              (900.0, 25*ct.one_atm, {"H2": 1.0}),
              (2000.0, 25*ct.one_atm, {s: 1.0 for s in SPECIES}),
              (3000.0, ct.one_atm, {s: 1.0 for s in SPECIES})]
    equivalence = []
    for t, p, composition in states:
        snapshots = {}
        for name, gas in phases.items():
            gas.TPX = t, p, composition
            snapshots[name] = snapshot(gas, third_indices)
        metrics = {"source_to_raw": compare_snapshots("source to raw", snapshots["source"], snapshots["raw_reloaded"], provenance),
                   "raw_to_normalized": compare_snapshots("raw to normalized", snapshots["raw_reloaded"], snapshots["normalized_strict"], provenance)}
        equivalence.append({"requested_state": {"T": t, "P": p, "X": composition},
                            "snapshots": snapshots, "metrics": metrics})
    record = {"environment_gate": record}
    record.update({"purpose": "constant_pressure_submechanism_export_and_equivalence",
                   "cantera_commit": provenance["cantera_commit"], "cantera_version": ct.__version__,
                   "source_gri30": str(gri), "source_gri30_sha256_lf": GRI_SHA,
                   "source_gas_def": definition, "source_gas_def_sha256_lf": DEFINITION_SHA,
                   "export_precision": 17, "phase": "gas", "species_names": SPECIES,
                   "raw_strict_negative_check": strict_negative,
                   "reaction_equations": original.reaction_equations(), "reaction_count": 74,
                   "reaction_types": dict(Counter(r.reaction_type for r in original.reactions())),
                   "duplicate_count": 6, "removed_efficiencies": removed,
                   "phase_changes": {"reactions": {"before": data["phases"][0].get("reactions", "implicit all"), "after": "all"},
                                     "skip-undeclared-third-bodies": {"before": True, "after": False}},
                   "raw_sha256_lf": digest(raw), "normalized_sha256_lf": digest(normalized_text),
                   "third_body_reaction_indices_1based": [i+1 for i in third_indices],
                   "equivalence_rtol": provenance["assertion_rtol"], "equivalence_atol": provenance["assertion_atol"],
                   "equivalence_source": "test/python/test_composite.py::TestSolutionSerialization::test_yaml_simple (lines 1217-1219)",
                   "equivalence": equivalence, "input_equivalence_passed": True})
    with (output_dir / "equivalence.json").open("x", encoding="utf-8") as f:
        json.dump(record, f, indent=2, allow_nan=False)
        f.write("\n")
    manifest = {"cantera_commit": provenance["cantera_commit"], "phase": "gas",
                "species_count": 18, "reaction_count": 74, "duplicate_count": 6,
                "source_gri30_sha256_lf": GRI_SHA, "source_gas_def_sha256_lf": DEFINITION_SHA,
                "raw_file": "gri30-18.raw.yaml", "raw_sha256_lf": digest(raw),
                "normalized_file": "gri30-18.normalized.yaml", "normalized_sha256_lf": digest(normalized_text),
                "equivalence_file": "equivalence.json", "equivalence_sha256_lf": digest((output_dir / "equivalence.json").read_bytes())}
    with (output_dir / "fixture.toml").open("x", encoding="utf-8") as f:
        for key, value in manifest.items():
            f.write(f"{key} = {json.dumps(value)}\n")
    return {"output_directory": str(output_dir), "input_equivalence_passed": True,
            "species_count": 18, "reaction_count": 74, "removed_efficiencies": removed,
            "raw_sha256_lf": digest(raw), "normalized_sha256_lf": digest(normalized_text),
            "state_metrics": [e["metrics"] for e in equivalence]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=FIXTURE / "const_pressure_18")
    args = parser.parse_args()
    print(json.dumps(export_fixture(args.source_dir, args.output_dir), indent=2, allow_nan=False))
