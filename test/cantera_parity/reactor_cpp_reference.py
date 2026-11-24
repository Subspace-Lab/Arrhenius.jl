"""Run the unchanged pinned C++ zeroD test, retaining its original assertions."""

import hashlib
import os
from pathlib import Path
import re
import subprocess
import time
import tomllib
import xml.etree.ElementTree as ET

from reactor_reference import FIXTURE


def digest(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def cpp_inputs(ct, source_dir, provenance):
    source_dir = Path(source_dir).resolve()
    with (FIXTURE / "gri30_provenance.toml").open("rb") as stream:
        manifest = tomllib.load(stream)
    if manifest["cantera_commit"] != provenance["cantera_commit"]:
        raise RuntimeError("C++ fixture commit mismatch")
    mechanism = FIXTURE / manifest["mechanism_file"]
    if digest(mechanism) != manifest["mechanism_sha256_lf"]:
        raise RuntimeError("C++ fixture digest mismatch")
    if (source_dir / manifest["source_file"]).read_bytes() != mechanism.read_bytes():
        raise RuntimeError("Original GRI30 and fixture are not byte-identical")
    if digest(source_dir / "test/zeroD/test_zeroD.cpp") != manifest["source_cpp_sha256_lf"]:
        raise RuntimeError("C++ test source digest mismatch")
    gas = ct.Solution(str(mechanism), manifest["phase"], transport_model=None)
    if (gas.n_species, gas.n_reactions, gas.species_names) != (
        manifest["species_count"], manifest["reaction_count"], manifest["species_names"]
    ):
        raise RuntimeError("C++ fixture phase/order/count mismatch")
    return mechanism, manifest


def reference_cpp_simple(ct, provenance, mechanism, source_dir, output):
    source_dir = Path(source_dir).resolve()
    binary = source_dir / "build/test/zeroD/zeroD"
    if not binary.is_file():
        raise RuntimeError("Build the pinned build-zeroD target before reference execution")
    artifacts = output.with_suffix("").resolve()
    artifacts.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env["CANTERA_DATA"] = str(FIXTURE)
    env["LD_LIBRARY_PATH"] = str(source_dir / "build/lib") + os.pathsep + env.get("LD_LIBRARY_PATH", "")
    linked = subprocess.run(["ldd", str(binary)], cwd=artifacts, env=env,
                            capture_output=True, text=True)
    (artifacts / "linked_libraries.log").write_text(linked.stdout + linked.stderr)
    library_match = re.search(r"libcantera_shared\.so\S* => (\S+)", linked.stdout)
    library = source_dir / "build/lib/libcantera_shared.so"
    if linked.returncode or not library_match or Path(library_match[1]).resolve() != library.resolve():
        raise RuntimeError("C++ reference does not resolve the pinned source-tree Cantera library")
    xml = artifacts / "gtest.xml"
    command = [str(binary), "--gtest_filter=zerodim.simple", "--gtest_color=no",
               "--gtest_output=xml:" + str(xml)]
    started = time.perf_counter()
    process = subprocess.run(command, cwd=artifacts, env=env, capture_output=True, text=True)
    elapsed = time.perf_counter() - started
    (artifacts / "gtest.log").write_text(process.stdout + process.stderr)
    cases, xml_error = [], None
    if xml.exists():
        try:
            cases = ET.parse(xml).getroot().findall(".//testcase")
        except ET.ParseError as error:
            xml_error = str(error)
    selected = [(c.get("classname"), c.get("name")) for c in cases]
    selection_ok = selected == [("zerodim", "simple")]
    passed = (process.returncode == 0 and selection_ok
              and all(c.get("status") == "run" and c.find("failure") is None
                      and c.find("error") is None and c.find("skipped") is None for c in cases))
    gas = ct.Solution(str(mechanism), "gri30", transport_model=None)
    gas.TPX = 1050.0, 5 * ct.one_atm, "CH4:1,O2:2,N2:7.52"
    result = {
        "reference_kind": "unchanged upstream C++ gtest; not a Python rewrite",
        "command": command, "working_directory": str(artifacts),
        "data_directory": env["CANTERA_DATA"], "library_path": env["LD_LIBRARY_PATH"],
        "binary": str(binary), "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "linked_cantera_library": str(library.resolve()),
        "linked_cantera_library_sha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "exit_code": process.returncode, "elapsed_seconds": elapsed,
        "selected_tests": selected, "executed_test_count": len(cases),
        "xml_error": xml_error, "gtest_cases": [c.attrib for c in cases],
        "artifacts": {"stdout_stderr": str(artifacts / "gtest.log"), "xml": str(xml),
                      "linked_libraries": str(artifacts / "linked_libraries.log")},
        "input": {"temperature": 1050.0, "pressure": 5 * ct.one_atm,
                  "mole_amounts": {"CH4": 1.0, "O2": 2.0, "N2": 7.52},
                  "volume": 1.0, "transport_model": "none", "constraint": "constant_volume",
                  "energy": "adiabatic", "chemistry_enabled": True,
                  "species_names": gas.species_names, "initial_density": gas.density,
                  "rtol": provenance["integration_rtol"], "atol": provenance["integration_atol"]},
        "assertion": "T >= 1050 K before each 0.005 s advance until t >= 0.1 s; no trajectory-accuracy assertion",
        "last_reported_time": None, "solver_stats": None,
        "unavailable_fields_reason": "the unchanged gtest does not print its final time, states or solver counters",
        "reference_assertions_passed": passed,
    }
    if not passed:
        result["failure_kind"] = "upstream_test_failed" if selection_ok else "invalid_reference_test_selection"
    return result
