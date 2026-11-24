"""Compare independently solved counterflow profiles on their native grids."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "test/cantera_parity"))
from extinction_gates import assess_temperatures


def compare_case(native, reference, adaptive):
    metrics = assess_temperatures(native=native["T"], reference=reference["T"],
                                  adaptive_reference=adaptive["T"])
    if not metrics["physical_validity"]:
        return metrics

    import numpy as np

    for label, data in (("native", native), ("reference", reference), ("adaptive_reference", adaptive)):
        metrics[f"{label}_points"] = len(data["grid"])
        metrics[f"{label}_peak_T_K"] = float(max(data["T"]))
        metrics[f"{label}_Lambda_Pa_per_m2"] = float(data["Lambda"][0])
    metrics["same_grid"] = np.array_equal(native["grid"], reference["grid"])
    metrics["scaled_residual_max"] = float(abs(native["residual"]).max())
    metrics["minimum_Y"] = float(native["Y"].min())
    metrics["mass_fraction_sum_error"] = float(abs(native["Y"].sum(axis=0) - 1).max())
    adaptive_T = np.interp(native["grid"], adaptive["grid"], adaptive["T"])
    metrics["adaptive_reference_T_profile_max_abs_K"] = float(abs(native["T"] - adaptive_T).max())
    for key in ("T", "velocity", "spread_rate", "Lambda", "Y"):
        av, bv = native[key], reference[key]
        if av.ndim == 1:
            compare = np.interp(native["grid"], reference["grid"], bv)
        else:
            compare = np.array([np.interp(native["grid"], reference["grid"], v) for v in bv])
        error = float(abs(av - compare).max())
        metrics[key + "_max_abs_error"] = error
        metrics[key + "_scaled_error"] = error / max(float(abs(compare).max()), 1e-30)
    metrics["accuracy_pass"] = (
        metrics["scaled_residual_max"] < 1e-8 and metrics["mass_fraction_sum_error"] < 1e-10
        and metrics["T_max_abs_error"] < 1 and metrics["velocity_scaled_error"] < .001
        and metrics["Lambda_scaled_error"] < .0001 and metrics["Y_max_abs_error"] < .001
    )
    return metrics


def main():
    import numpy as np

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    directory = parser.parse_args().directory
    summary = {}
    for kind in ("h2", "ethane", "methane"):
        adaptive_path = directory / f"counterflow-{kind}-reference.npz"
        samegrid = directory / f"counterflow-{kind}-reference-samegrid.npz"
        with np.load(directory / f"counterflow-{kind}-native.npz") as native, np.load(adaptive_path) as adaptive:
            if samegrid.is_file():
                with np.load(samegrid) as reference:
                    summary[kind] = compare_case(native, reference, adaptive)
            else:
                summary[kind] = compare_case(native, adaptive, adaptive)
    output = json.dumps(summary, indent=2)
    (directory / "counterflow-comparison.json").write_text(output + "\n")
    print(output)
    return 0 if all(m["physical_validity"] and m["accuracy_pass"] for m in summary.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
