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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=("disable_chemistry",), default="disable_chemistry")
    parser.add_argument("--source-dir", type=Path, required=True,
                        help="Clean Cantera checkout at the pinned commit")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-environment", action="store_true")
    mode.add_argument("--output", type=Path, help="Write a new reference JSON record")
    args = parser.parse_args()
    if args.output is not None and args.output.exists():
        parser.error("Output already exists; choose a new path to preserve prior evidence")
    ct, provenance, mechanism, record = environment(args.source_dir)
    if args.check_environment:
        record["status"] = "environment_checked_only"
    else:
        record["result"] = reference(ct, provenance, mechanism)
        record["status"] = "reference_passed_native_not_verified"
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(record, stream, indent=2, allow_nan=False)
            stream.write("\n")
    print(json.dumps(record, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
