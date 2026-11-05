"""Regression tests for evidence gates; no NumPy, Cantera, or Julia required."""

import copy
import contextlib
import importlib.util
import io
import json
import math
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

from xresid_gates import (
    AGREE_MAX, RELB_MAX, RTOL, InvalidReport, aggregate_residuals, assess_report,
    validate_residual_scales,
)


def report():
    return {
        "kind": "free",
        "roundtrip": {
            chain: {"T": 0.0, "velocity": 0.0, "Y": 0.0}
            for chain in (
                "native_self_A", "native_self_B", "ct_to_native_B",
                "ct_self_A", "ct_self_B", "native_to_ct_A",
            )
        },
        "aggregates": {
            "agreement_A": 0.0, "agreement_B": 0.0,
            "rel_max_B_native": 0.0, "rel_max_B_cantera": 0.0,
        },
    }


class TestXresidGates(unittest.TestCase):
    def test_valid_complete_report(self):
        checks, bad = assess_report(report())
        self.assertEqual(len(checks), 5)
        self.assertEqual(bad, {})

    def test_existing_limits_are_unchanged(self):
        self.assertEqual((RTOL, AGREE_MAX, RELB_MAX), (1e-11, 1e-9, 5e-2))

    def test_equal_to_limit_passes(self):
        data = report()
        for chain in data["roundtrip"].values():
            for component in chain:
                chain[component] = RTOL
        data["aggregates"].update(
            agreement_A=AGREE_MAX, agreement_B=AGREE_MAX,
            rel_max_B_native=RELB_MAX, rel_max_B_cantera=RELB_MAX,
        )
        self.assertEqual(assess_report(data)[1], {})

    def test_each_aggregate_above_limit_fails(self):
        for name, limit in (
            ("agreement_A", AGREE_MAX), ("agreement_B", AGREE_MAX),
            ("rel_max_B_native", RELB_MAX), ("rel_max_B_cantera", RELB_MAX),
        ):
            with self.subTest(name=name):
                data = report()
                value = math.nextafter(limit, math.inf)
                data["aggregates"][name] = value
                self.assertEqual(assess_report(data)[1], {name: value})

    def test_roundtrip_above_limit_fails(self):
        data = report()
        value = math.nextafter(RTOL, math.inf)
        data["roundtrip"]["native_to_ct_A"]["Y"] = value
        self.assertEqual(assess_report(data)[1], {"roundtrip": value})

    def test_all_aggregate_nonfinite_values_are_rejected(self):
        for name in report()["aggregates"]:
            for value in (math.nan, math.inf, -math.inf):
                with self.subTest(name=name, value=value):
                    data = report()
                    data["aggregates"][name] = value
                    with self.assertRaisesRegex(InvalidReport, f"aggregates.{name}"):
                        assess_report(data)

    def test_every_raw_roundtrip_nonfinite_value_is_rejected(self):
        for chain, raw in report()["roundtrip"].items():
            for component in raw:
                for value in (math.nan, math.inf, -math.inf):
                    with self.subTest(chain=chain, component=component, value=value):
                        data = report()
                        data["roundtrip"][chain][component] = value
                        with self.assertRaisesRegex(InvalidReport, f"{chain}.{component}"):
                            assess_report(data)

    def test_nan_hidden_by_max_is_rejected(self):
        data = report()
        data["roundtrip"]["native_to_ct_A"]["Y"] = math.nan
        raw = [v for chain in data["roundtrip"].values() for v in chain.values()]
        self.assertEqual(max(raw), 0.0)  # Demonstrate the original failure mode.
        with self.assertRaises(InvalidReport):
            assess_report(data)

    def test_missing_and_malformed_reports_are_rejected(self):
        for data in (None, [], "", {}, {"kind": "free"}, {"kind": []}):
            with self.subTest(data=data):
                with self.assertRaises(InvalidReport):
                    assess_report(data)

    def test_error_and_refusal_cannot_pass_even_with_valid_metrics(self):
        for marker in ("error", "refusal"):
            for value in ("failed", "", None):
                with self.subTest(marker=marker, value=value):
                    data = report()
                    data[marker] = value
                    with self.assertRaisesRegex(InvalidReport, marker):
                        assess_report(data)

    def test_each_missing_aggregate_is_rejected(self):
        for name in report()["aggregates"]:
            with self.subTest(name=name):
                data = report()
                del data["aggregates"][name]
                with self.assertRaisesRegex(InvalidReport, name):
                    assess_report(data)

    def test_each_missing_roundtrip_chain_is_rejected(self):
        for chain in report()["roundtrip"]:
            with self.subTest(chain=chain):
                data = report()
                del data["roundtrip"][chain]
                with self.assertRaisesRegex(InvalidReport, chain):
                    assess_report(data)

    def test_each_missing_roundtrip_component_is_rejected(self):
        for chain, raw in report()["roundtrip"].items():
            for component in raw:
                with self.subTest(chain=chain, component=component):
                    data = report()
                    del data["roundtrip"][chain][component]
                    with self.assertRaisesRegex(InvalidReport, f"{chain}.{component}"):
                        assess_report(data)

    def test_malformed_nested_values_are_rejected(self):
        for field in ("roundtrip", "aggregates"):
            for value in (None, [], "", {}):
                with self.subTest(field=field, value=value):
                    data = report()
                    data[field] = value
                    with self.assertRaises(InvalidReport):
                        assess_report(data)
        for value in (None, [], "", {}):
            with self.subTest(chain=value):
                data = report()
                data["roundtrip"]["native_self_A"] = value
                with self.assertRaises(InvalidReport):
                    assess_report(data)

    def test_nonnumeric_boolean_negative_and_overflow_values_are_rejected(self):
        for value in (None, "0", False, True, [], {}, -1e-12, 10**1000):
            with self.subTest(value=value):
                data = report()
                data["aggregates"]["agreement_A"] = value
                with self.assertRaises(InvalidReport):
                    assess_report(data)
                data = report()
                data["roundtrip"]["native_self_A"]["Y"] = value
                with self.assertRaises(InvalidReport):
                    assess_report(data)

    def test_counterflow_requires_spread_rate_and_lambda(self):
        data = report()
        data["kind"] = "stagnation"
        with self.assertRaises(InvalidReport):
            assess_report(data)
        for chain in data["roundtrip"].values():
            chain.update(spreadRate=0.0, Lambda=0.0)
        self.assertEqual(assess_report(data)[1], {})
        for name in ("spreadRate", "Lambda"):
            broken = copy.deepcopy(data)
            broken["roundtrip"]["ct_self_A"][name] = math.nan
            with self.assertRaises(InvalidReport):
                assess_report(broken)

    def test_extra_roundtrip_values_are_also_validated(self):
        data = report()
        data["roundtrip"]["native_self_A"]["extra"] = math.nan
        with self.assertRaisesRegex(InvalidReport, "extra"):
            assess_report(data)

    def test_input_is_not_mutated(self):
        data = report()
        before = copy.deepcopy(data)
        assess_report(data)
        self.assertEqual(data, before)


class TestResidualAggregation(unittest.TestCase):
    def row(self, value=0.0):
        return {
            "scale": 1.0,
            "max": dict.fromkeys(("A_native", "A_cantera", "B_native", "B_cantera"), value),
            "rel": dict.fromkeys(("A_native", "A_cantera", "B_native", "B_cantera"), value),
        }

    def test_finite_maxima_and_input_preserved(self):
        rows = [self.row(0.25), self.row(0.5), self.row(None)]
        rows[0]["rel"]["B_native"] = 0.75
        agreement = {"A": [0.25, 0.5], "B": [0.5, 0.125]}
        before = copy.deepcopy((rows, agreement))
        self.assertEqual(aggregate_residuals(rows, agreement), {
            "rel_max_A_native": 0.5, "rel_max_A_cantera": 0.5,
            "rel_max_B_native": 0.75, "rel_max_B_cantera": 0.5,
            "agreement_A": 0.5, "agreement_B": 0.5,
        })
        self.assertEqual((rows, agreement), before)

    def test_empty_and_structurally_absent_stay_none(self):
        for rows in ([], [self.row(None)]):
            values = aggregate_residuals(rows, {"A": [], "B": []})
            self.assertEqual(len(values), 6)
            self.assertTrue(all(value is None for value in values.values()))

    def test_nan_in_either_row_order_is_rejected(self):
        for key in self.row()["rel"]:
            for index in (0, 1):
                with self.subTest(key=key, index=index):
                    rows = [self.row(), self.row()]
                    rows[index]["rel"][key] = math.nan
                    with self.assertRaisesRegex(InvalidReport, rf"rows\[{index}\].rel.{key}"):
                        aggregate_residuals(rows, {"A": [0.0], "B": [0.0]})

    def test_agreement_nan_in_either_order_is_rejected(self):
        for state in ("A", "B"):
            for values in ([0.0, math.nan], [math.nan, 0.0]):
                with self.subTest(state=state, values=values):
                    agreement = {"A": [0.0], "B": [0.0]}
                    agreement[state] = values
                    with self.assertRaisesRegex(InvalidReport, f"agreement.{state}"):
                        aggregate_residuals([self.row()], agreement)

    def test_invalid_raw_maximum_rejected_without_relative_norm(self):
        for key in self.row()["max"]:
            for value in (math.nan, math.inf, -math.inf, -1.0):
                with self.subTest(key=key, value=value):
                    row = self.row(None)
                    row["max"][key] = value
                    with self.assertRaisesRegex(InvalidReport, f"max.{key}"):
                        aggregate_residuals([row], {"A": [], "B": []})

    def test_invalid_metrics_cannot_be_hidden_by_other_rows(self):
        for value in (math.inf, -math.inf, -1.0, True, "0", 10**1000):
            for key in self.row()["rel"]:
                with self.subTest(key=key, value=value):
                    rows = [self.row(), self.row()]
                    rows[1]["rel"][key] = value
                    with self.assertRaises(InvalidReport):
                        aggregate_residuals(rows, {"A": [0.0], "B": [0.0]})
            for state in ("A", "B"):
                with self.subTest(state=state, value=value):
                    agreement = {"A": [0.0], "B": [0.0]}
                    agreement[state].append(value)
                    with self.assertRaises(InvalidReport):
                        aggregate_residuals([self.row()], agreement)

    def test_explicit_scales_accept_zero_but_reject_invalid_values(self):
        scales = {"closure": 1.0, "species/1": 0.0}
        validate_residual_scales(scales)
        self.assertEqual(scales, {"closure": 1.0, "species/1": 0.0})
        for value in (math.nan, math.inf, -math.inf, -1.0, None, True, "0", 10**1000):
            with self.subTest(value=value):
                with self.assertRaisesRegex(InvalidReport, "scales.species/1"):
                    validate_residual_scales({"closure": 1.0, "species/1": value})

    def test_missing_scale_sentinel_and_structural_rows_still_work(self):
        # A Cantera-only boundary equation can have no native scale. Its
        # finite maximum / infinity is zero, not invalid residual evidence.
        row = self.row(None)
        row["scale"] = math.inf
        row["max"]["B_cantera"] = 2.0
        row["rel"]["B_cantera"] = 0.0
        values = aggregate_residuals([row], {"A": [], "B": []})
        self.assertEqual(values["rel_max_B_cantera"], 0.0)
        self.assertIsNone(values["rel_max_B_native"])
        self.assertIsNone(values["agreement_B"])


class TestProducerRefusal(unittest.TestCase):
    def setUp(self):
        path = Path(__file__).with_name("xresid.py")
        spec = importlib.util.spec_from_file_location("xresid_producer_test", path)
        self.producer = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {
            "numpy": types.ModuleType("numpy"),
            "cantera": types.ModuleType("cantera"),
        }):
            spec.loader.exec_module(self.producer)

    def test_refusal_overwrites_stale_success_and_consumer_rejects_it(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            path.write_text(json.dumps(report()))
            output = io.StringIO()
            with contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as exc:
                self.producer.refuse_invalid_residuals(
                    InvalidReport("rows[1].rel.B_native must be finite"), "free", path)
            self.assertEqual(exc.exception.code, 2)
            data = json.loads(path.read_text())
            self.assertEqual(data["kind"], "free")
            self.assertIn("refusal", data)
            self.assertNotIn("aggregates", data)
            self.assertIn("rows[1].rel.B_native", data["detail"])
            self.assertIn("REFUSING", output.getvalue())
            with self.assertRaisesRegex(InvalidReport, "refusal"):
                assess_report(data)

    def test_refusal_without_json_still_exits_two(self):
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as exc:
            self.producer.refuse_invalid_residuals(InvalidReport("invalid scales"), "free", None)
        self.assertEqual(exc.exception.code, 2)


class TestH2O2GateIntegration(unittest.TestCase):
    """Exercise CLI status reporting without running any physical solver."""

    def setUp(self):
        path = Path(__file__).with_name("xresid_h2o2.py")
        spec = importlib.util.spec_from_file_location("xresid_h2o2_gate_test", path)
        self.harness = importlib.util.module_from_spec(spec)
        # Module import only defines functions/constants. Solver calls are
        # replaced below; neither package is needed for these integration tests.
        with patch.dict(sys.modules, {
            "numpy": types.ModuleType("numpy"),
            "cantera": types.ModuleType("cantera"),
        }):
            spec.loader.exec_module(self.harness)

    def run_harness(self, result):
        output = io.StringIO()
        with patch.object(sys, "argv", ["xresid_h2o2.py", "--kinds", "free"]), \
                patch.object(self.harness.tempfile, "mkdtemp", return_value="unused"), \
                patch.object(self.harness, "run_case", return_value=result), \
                contextlib.redirect_stdout(output):
            try:
                self.harness.main()
            except SystemExit as exc:
                return exc.code, output.getvalue()
        return 0, output.getvalue()

    def test_invalid_report_has_nonzero_exit_and_no_pass_line(self):
        invalid = report()
        invalid["aggregates"]["agreement_B"] = math.nan
        for data in (None, {}, invalid):
            with self.subTest(data=data):
                code, output = self.run_harness((data, None))
                self.assertEqual(code, 1)
                self.assertIn("FAIL free: invalid xresid report:", output)
                self.assertNotIn("pass free:", output)
                self.assertNotIn("all selected kinds pass", output)

    def test_subprocess_error_has_nonzero_exit(self):
        code, output = self.run_harness((None, "xresid exited 2"))
        self.assertEqual(code, 1)
        self.assertIn("FAIL free: xresid exited 2", output)
        self.assertNotIn("all selected kinds pass", output)

    def test_valid_report_still_passes(self):
        code, output = self.run_harness((report(), None))
        self.assertEqual(code, 0)
        self.assertIn("pass free:", output)
        self.assertIn("all selected kinds pass", output)


if __name__ == "__main__":
    unittest.main()
