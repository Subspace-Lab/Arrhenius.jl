"""Compare stored counterflow profiles using the existing validation reader.

Usage: python test/cantera_parity/compare_profiles.py reference.npz native.npz report.json
The comparison uses fixed physical coordinates, with no flame translation.
"""
import json
from pathlib import Path
import sys

from extinction_gates import assess_temperatures

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "validation"))


def compare_profiles(ref, native):
    report = assess_temperatures(native=native["T"], reference=ref["T"])
    if not report["physical_validity"]:
        return report

    from flame_benchmarks import profile_errors

    names = bytes(ref["species_names_utf8"]).decode().split("\n")
    native_names = bytes(native.get("species_names_utf8", ref["species_names_utf8"])).decode().split("\n")
    report.update(profile_errors(dict(ref, species_names=names), dict(native, species_names=native_names), "burner"))
    return report


def main():
    import numpy as np

    with np.load(sys.argv[1]) as ref, np.load(sys.argv[2]) as native:
        report = compare_profiles(ref, native)
    Path(sys.argv[3]).write_text(json.dumps(report, indent=2) + "\n")
    if not report["physical_validity"]:
        print(json.dumps(report))
        return 1
    print(json.dumps(report["temperature"]))
    print("all_species_pass:", report["all_species_pass"])
    return 0 if report["all_species_pass"] and report["temperature"]["normalized_peak_error"] < .01 else 1


if __name__ == "__main__":
    raise SystemExit(main())
