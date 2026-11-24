"""Regression tests for extinguished-reference false passes."""
import contextlib
import io
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from compare_profiles import compare_profiles
from extinction_gates import assess_temperatures
import validate_heldout_subset
from validate_heldout_subset import ACCURACY_GATES, failing_gates

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "validation"))
from counterflow_compare import compare_case

try:
    import numpy as np
except ImportError:
    np = None


def heldout(kind, temperatures):
    inlet, peak, wall = temperatures
    return {
        "gates": dict(physical_validity=True, **dict.fromkeys(ACCURACY_GATES, True)),
        "spec": {"kind": kind, "T": inlet, "T_surface": wall},
        "SL": dict.fromkeys(("native", "cantera", "reference"), peak),
    }


class TestExtinctionGates(unittest.TestCase):
    def test_extinguished_profiles_stop_before_accuracy(self):
        for kind, temperatures in (("diffusion", [300, 300, 300]), ("stagnation", [300, 450, 600])):
            with self.subTest(kind=kind):
                # Only T is available. Reading grid, species or residuals would fail.
                profile = {"T": temperatures}
                for report in (compare_profiles(profile, profile), compare_case(profile, profile, profile)):
                    self.assertIs(report["physical_validity"], False)
                    self.assertEqual(report["reference_temp_rise_K"], 0)
                    self.assertNotIn("temperature", report)
                    self.assertNotIn("T_max_abs_error", report)
                data = heldout(kind, [temperatures[0], max(temperatures), temperatures[-1]])
                self.assertEqual(failing_gates(data), ["physical_validity"])

    def test_threshold_and_burning_controls(self):
        for kind, wall, peak, expected in (
            ("diffusion", 300, 799.9, False), ("diffusion", 300, 800, True),
            ("stagnation", 600, 1099.9, False), ("stagnation", 600, 1100, True),
            ("diffusion", 300, 1850, True), ("stagnation", 600, 1650, True),
        ):
            with self.subTest(wall=wall, peak=peak):
                t = [300, peak, wall]
                report = assess_temperatures(native=t, reference=t, adaptive_reference=t)
                self.assertEqual(report["native_temp_rise_K"], peak - wall)
                self.assertIs(report["physical_validity"], expected)
                self.assertEqual(failing_gates(heldout(kind, t)), [] if expected else ["physical_validity"])

    def test_each_profile_is_required_to_burn(self):
        hot = {"T": [300, 1850, 300]}
        cold = {"T": [300, 300, 300]}
        for side in ("native", "reference", "adaptive"):
            with self.subTest(side=side):
                profiles = dict.fromkeys(("native", "reference", "adaptive"), hot)
                profiles[side] = cold
                self.assertFalse(compare_case(**profiles)["physical_validity"])
                if side != "adaptive":
                    self.assertFalse(compare_profiles(profiles["reference"], profiles["native"])["physical_validity"])
        for side in ("native", "reference"):
            data = heldout("diffusion", hot["T"])
            data["SL"][side] = 300
            self.assertEqual(failing_gates(data), ["physical_validity"])

    def test_empty_and_nonfinite_temperatures(self):
        hot = [300, 1850, 300]
        for invalid in ([], [math.nan, 1850, 300], [300, 1850, math.nan, 300],
                        [300, 1850, math.inf], [300, -math.inf, 1850, 300]):
            with self.subTest(invalid=invalid):
                report = compare_profiles({"T": invalid}, {"T": hot})
                self.assertFalse(report["physical_validity"])
                self.assertIsNone(report["reference_temp_rise_K"])
                report = compare_case({"T": hot}, {"T": hot}, {"T": invalid})
                self.assertFalse(report["physical_validity"])
                self.assertIsNone(report["adaptive_reference_temp_rise_K"])
        data = heldout("stagnation", [300, 1650, 600])
        for value in (math.nan, math.inf, None):
            data["SL"]["reference"] = value
            self.assertEqual(failing_gates(data), ["physical_validity"])

    def test_boolean_temperatures(self):
        for t in ([True, 800.0, True], [300.0, 800.0, False], [300.0, True, 800.0, 300.0]):
            with self.subTest(t=t):
                report = assess_temperatures(native=t)
                self.assertIsNone(report["native_temp_rise_K"])
                self.assertFalse(report["physical_validity"])

    def test_one_point_profile(self):
        report = assess_temperatures(native=[1500.0])
        self.assertEqual(report["native_temp_rise_K"], 0)
        self.assertFalse(report["physical_validity"])

    def test_heldout_rejects_boolean_numeric_fields(self):
        for kind, key in (("diffusion", "T"), ("diffusion", "T_fuel"), ("diffusion", "T_oxidizer"),
                          ("stagnation", "T_inlet"), ("stagnation", "T_surface")):
            with self.subTest(kind=kind, key=key):
                data = heldout(kind, [300.0, 800.0, 300.0])
                data["spec"][key] = True
                self.assertEqual(failing_gates(data), ["physical_validity"])
        for side in ("native", "reference"):
            data = heldout("diffusion", [300.0, 800.0, 300.0])
            data["SL"][side] = False
            self.assertEqual(failing_gates(data), ["physical_validity"])

    @unittest.skipUnless(np is not None, "requires NumPy scalars")
    def test_numpy_scalar_temperatures_and_rises(self):
        valid = heldout("diffusion", [np.int32(300), np.float32(800), np.int64(300)])
        valid["physical_validity_details"] = {"native_temp_rise_K": np.float32(500),
                                             "reference_temp_rise_K": np.int64(500)}
        self.assertEqual(failing_gates(valid), [])
        valid["spec"]["T"] = np.bool_(True)
        self.assertEqual(failing_gates(valid), ["physical_validity"])

    def test_heldout_requires_explicit_true_before_accuracy(self):
        data = heldout("diffusion", [300, 1850, 300])
        data["gates"]["temperature"] = False
        for invalid in (False, None, "true", 1):
            data["gates"]["physical_validity"] = invalid
            self.assertEqual(failing_gates(data), ["physical_validity"])
        del data["gates"]["physical_validity"]
        self.assertEqual(failing_gates(data), ["physical_validity"])
        data["gates"]["physical_validity"] = True
        self.assertEqual(failing_gates(data), ["temperature"])

    def test_free_flame_speed_is_not_a_temperature(self):
        data = heldout("free", [300, .2, 300])
        self.assertEqual(failing_gates(data), [])

    def test_heldout_cli_rejects_cold_and_accepts_burning(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "ids").write_text("control\n")
            for filename in ("ct_survey/specs_cf2/control.json", "refs_cf2/counterflow/control.npz"):
                path = root / filename
                path.parent.mkdir(parents=True)
                path.touch()
            for peak, valid in ((600, False), (1650, True)):
                data = heldout("stagnation", [300, peak, 600])

                def write_gate(command, **kwargs):
                    Path(command[-1]).write_text(json.dumps(data))

                argv = ["validate_heldout_subset.py", tmp, str(root / "ids"), tmp, str(root / "out")]
                with patch.dict(os.environ, TRACE_CAP="cap", PY="py"), patch.object(sys, "argv", argv), \
                        patch.object(subprocess, "run", side_effect=write_gate), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(validate_heldout_subset.main(), 0 if valid else 1)
                summary = json.loads((root / "out/summary.json").read_text())
                self.assertEqual(summary["accuracy_pass"], int(valid))
                self.assertEqual(summary["results"][0]["failing_gates"], [] if valid else ["physical_validity"])

    def test_heldout_cross_checks_reported_rises(self):
        data = heldout("stagnation", [300, 1650, 600])
        details = data["physical_validity_details"] = dict.fromkeys(
            ("native_temp_rise_K", "reference_temp_rise_K", "coarse_temp_rise_K"), 1050)
        self.assertEqual(failing_gates(data), [])
        for name in details:
            for value in (False, True, 0, 499.9, math.inf, math.nan, None):
                with self.subTest(name=name, value=value):
                    details[name] = value
                    self.assertEqual(failing_gates(data), ["physical_validity"])
            details[name] = 1050
        details["coarse_burning"] = False
        self.assertEqual(failing_gates(data), ["physical_validity"])


@unittest.skipUnless(np is not None, "NPZ integration requires NumPy")
class TestProfileCommands(unittest.TestCase):
    def test_independent_adaptive_reference_must_burn(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for kind in ("h2", "ethane", "methane"):
                for side in ("native", "reference-samegrid", "reference"):
                    peak = 300 if side == "reference" else 1850
                    np.savez(directory / f"counterflow-{kind}-{side}.npz", T=[300, peak, 300])
            proc = subprocess.run([sys.executable, ROOT / "validation/counterflow_compare.py",
                                   directory], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
            summary = json.loads((directory / "counterflow-comparison.json").read_text())
            for report in summary.values():
                self.assertFalse(report["physical_validity"])
                self.assertEqual(report["reference_temp_rise_K"], 1550)
                self.assertEqual(report["adaptive_reference_temp_rise_K"], 0)
                self.assertNotIn("T_max_abs_error", report)

    def test_exit_codes_and_saved_reports(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for wall, peak, valid in ((300, 1850, True), (600, 1650, True), (600, 1100, True),
                                     (600, 1099.9, False), (300, 300, False), (600, 600, False)):
                with self.subTest(wall=wall, peak=peak):
                    data = dict(T=[300., peak, wall], grid=[0., .01, .02], velocity=[1., 0., -1.],
                                spread_rate=[0., 1., 0.], Lambda=[-1.] * 3, residual=[0.] * 3,
                                Y=np.ones((1, 3)), species_names_utf8=np.frombuffer(b"H2", np.uint8))
                    for kind in ("h2", "ethane", "methane"):
                        for side in ("reference", "native"):
                            np.savez(directory / f"counterflow-{kind}-{side}.npz", **data)
                    profiles_json = directory / "profiles.json"
                    for script, args in (
                        ("validation/counterflow_compare.py", [directory]),
                        ("test/cantera_parity/compare_profiles.py", [
                            directory / "counterflow-h2-reference.npz",
                            directory / "counterflow-h2-native.npz", profiles_json]),
                    ):
                        proc = subprocess.run([sys.executable, ROOT / script, *args], capture_output=True, text=True)
                        self.assertEqual(proc.returncode, 0 if valid else 1, proc.stdout + proc.stderr)
                    profile = json.loads(profiles_json.read_text())
                    counterflow = json.loads((directory / "counterflow-comparison.json").read_text())["h2"]
                    for report in (profile, counterflow):
                        self.assertIs(report["physical_validity"], valid)
                        self.assertEqual(report["native_temp_rise_K"], peak - wall)
                    self.assertIs(counterflow["adaptive_reference_temp_rise_K"] >= 500, valid)
                    if valid:
                        self.assertTrue(counterflow["accuracy_pass"])
                        self.assertTrue(profile["all_species_pass"])
                        self.assertEqual(profile["temperature"]["normalized_peak_error"], 0)
                    else:
                        self.assertNotIn("T_max_abs_error", counterflow)
                        self.assertNotIn("all_species_pass", profile)


if __name__ == "__main__":
    unittest.main()
