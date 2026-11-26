"""Export the pinned 24-species WSR fixture without changing its mechanism."""
import argparse
import ast
from copy import deepcopy
import io
import json
from pathlib import Path

from ruamel.yaml import YAML
from reactor_reference import environment, check_close
from export_const_pressure_fixture import digest, snapshot, compare_snapshots, GRI_SHA

DEFINITION_SHA = "a07a7bf3b424469e681b2060da41b0bee7802c860680428cd6dc018f754a5a90"
UPSTREAM = "test/python/test_reactor.py::TestWellStirredReactorIgnition::test_nonreacting"
SPECIES = "H2 H O O2 OH H2O HO2 H2O2 CH2 CH2(S) CH3 CH4 CO CO2 HCO CH2O CH2OH CH3O CH3OH C2H4 C2H5 C2H6 N2 AR".split()


def compare_parameters(source, exported, provenance, path="reactions", differences=None):
    """Keep structure exact; use the planned upstream roundtrip gate for numbers."""
    if differences is None:
        differences = []
    if isinstance(source, dict):
        assert source.keys() == exported.keys(), path
        for key in source:
            compare_parameters(source[key], exported[key], provenance, path+"."+key, differences)
    elif isinstance(source, (list, tuple)):
        assert len(source) == len(exported), path
        for i, (a, b) in enumerate(zip(source, exported)):
            compare_parameters(a, b, provenance, f"{path}[{i+1}]", differences)
    elif isinstance(source, (int, float)) and not isinstance(source, bool):
        check_close(path, exported, source, provenance)
        if source != exported:
            differences.append({"path": path, "source": source, "exported": exported,
                                "absolute_error": abs(source-exported),
                                "relative_error": abs((source-exported)/source) if source else None})
    else:
        assert source == exported, path
    return differences


def export_fixture(source, output):
    ct, provenance, _, env = environment(source)
    env["upstream_test"] = UPSTREAM
    tree = ast.parse((source / "test/python/test_reactor.py").read_text())
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "TestWellStirredReactorIgnition")
    method = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == "setup_reactor")
    definition = next(ast.literal_eval(n.value) for n in method.body if isinstance(n, ast.Assign)
        and any(isinstance(t, ast.Name) and t.id == "gas_def" for t in n.targets))
    assert digest(definition) == DEFINITION_SHA
    assert digest((source / "data/gri30.yaml").read_bytes()) == GRI_SHA
    ct.add_data_directory(str(source / "data"))
    original = ct.Solution(yaml=definition)
    assert original.species_names == SPECIES and original.n_reactions == 129
    raw = original.write_yaml(precision=17)
    yaml = YAML(typ="safe")
    data = yaml.load(raw)
    assert data["phases"][0]["skip-undeclared-third-bodies"] is True
    assert not [(i, s) for i, r in enumerate(data["reactions"])
                for s in r.get("efficiencies", {}) if s not in SPECIES]
    assert sum(bool(r.get("duplicate")) for r in data["reactions"]) == 6
    reloaded = ct.Solution(yaml=raw)
    # A validation-only strict reload; both integrations use the untouched export.
    strict_data = deepcopy(data)
    strict_data["phases"][0]["skip-undeclared-third-bodies"] = False
    stream = io.StringIO()
    yaml.dump(strict_data, stream)
    strict = ct.Solution(yaml=stream.getvalue())
    for phase in (reloaded, strict):
        assert phase.species_names == SPECIES
        assert phase.reaction_equations() == original.reaction_equations()
    parameter_differences = compare_parameters([dict(r.input_data) for r in original.reactions()],
        [dict(r.input_data) for r in reloaded.reactions()], provenance)
    assert [dict(r.input_data) for r in strict.reactions()] == [dict(r.input_data) for r in reloaded.reactions()]
    third = [i for i, r in enumerate(original.reactions()) if r.third_body is not None]
    states = [(900, 10*ct.one_atm, "N2:1"), (900, 10*ct.one_atm, "CH4:1"),
              (900, 10*ct.one_atm, "O2:1,N2:3.76"),
              (2000, 10*ct.one_atm, {s: 1 for s in SPECIES})]
    equivalence = []
    for T, P, X in states:
        values = {}
        for name, gas in (("source", original), ("export", reloaded), ("strict_probe", strict)):
            gas.TPX = T, P, X
            values[name] = snapshot(gas, third)
        metrics = {name: compare_snapshots(name, values["source"], values[name], provenance)
                   for name in ("export", "strict_probe")}
        equivalence.append({"input": {"T": T, "P": P, "X": X}, "snapshots": values, "metrics": metrics})
    output.mkdir(parents=True, exist_ok=False)
    (output / "gri30-24.raw.yaml").write_text(raw)
    record = {"environment": env, "gas_def": definition, "gas_def_sha256_lf": DEFINITION_SHA,
              "gri30_sha256_lf": GRI_SHA, "export_precision": 17,
              "species_names": SPECIES, "reaction_equations": original.reaction_equations(),
              "reaction_count": 129, "duplicate_count": 6, "removed_efficiencies": [],
              "strict_probe_passed": True, "third_body_indices_1based": [i+1 for i in third],
              "roundtrip_parameter_differences": parameter_differences,
              "equivalence_rtol": provenance["assertion_rtol"], "equivalence_atol": provenance["assertion_atol"],
              "equivalence_source": "test_composite.py TestSolutionSerialization.test_yaml_simple",
              "equivalence": equivalence, "input_equivalence_passed": True}
    (output / "equivalence.json").write_text(json.dumps(record, indent=2, allow_nan=False)+"\n")
    manifest = {"cantera_commit": provenance["cantera_commit"], "upstream_test": UPSTREAM,
                "phase": "gas", "species_names": SPECIES, "species_count": 24, "reaction_count": 129,
                "duplicate_count": 6, "mechanism_file": "gri30-24.raw.yaml", "mechanism_sha256_lf": digest(raw),
                "source_gri30_sha256_lf": GRI_SHA, "source_gas_def_sha256_lf": DEFINITION_SHA,
                "equivalence_sha256_lf": digest((output / "equivalence.json").read_bytes()),
                "integration_rtol": 1e-9, "integration_atol": 1e-15,
                "temperature_rtol": 1e-5, "assertion_rtol": 1e-6, "assertion_atol": 1e-12}
    notes = ("# No normalization is needed: all third-body efficiency species are in this\n"
             "# 24-species phase (including C2H6). export_wsr_fixture.py checks the empty\n"
             "# absent-species set and a strict reload with the skip flag disabled; see\n"
             "# equivalence.json: removed_efficiencies=[], strict_probe_passed=true.\n"
             "# Both solvers use the untouched raw export; strict reload is validation only.\n")
    (output / "fixture.toml").write_text(notes + "".join(f"{k} = {json.dumps(v)}\n" for k,v in manifest.items()))
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(export_fixture(args.source_dir, args.output_dir), indent=2))
