"""Validate the existing H2/O2 cross-residual gates without solver dependencies."""

import math
from collections.abc import Mapping
from numbers import Real

AGREE_MAX = 1e-9
RELB_MAX = 5e-2
RTOL = 1e-11

_ROUNDTRIP_CHAINS = (
    "native_self_A", "native_self_B", "ct_to_native_B",
    "ct_self_A", "ct_self_B", "native_to_ct_A",
)
_AGGREGATE_LIMITS = {
    "agreement_A": AGREE_MAX,
    "agreement_B": AGREE_MAX,
    "rel_max_B_native": RELB_MAX,
    "rel_max_B_cantera": RELB_MAX,
}
_COUNTERFLOW_KINDS = {"diffusion", "premixed", "twin", "stagnation"}


class InvalidReport(ValueError):
    """A report cannot support a pass/fail decision from its numeric gates."""


def _mapping(value, path):
    if not isinstance(value, Mapping):
        raise InvalidReport(f"{path} must be an object")
    return value


def _error_value(value, path):
    if isinstance(value, bool) or not isinstance(value, Real):
        raise InvalidReport(f"{path} must be a finite, nonnegative number")
    try:
        finite = math.isfinite(value)
    except OverflowError:
        finite = False
    if not finite or value < 0:
        raise InvalidReport(f"{path} must be a finite, nonnegative number")
    return value


def assess_report(report):
    """Return gate values/limits and exceeded gates; reject incomplete reports.

    Validate every raw round-trip component before taking a maximum. Python's
    max can otherwise hide NaN when it appears after a finite value. Invalid
    evidence raises InvalidReport; a value exactly on its limit still passes.
    """
    report = _mapping(report, "report")
    for marker in ("refusal", "error"):
        if marker in report:
            raise InvalidReport(f"report contains {marker}: {report[marker]}")
    kind = report.get("kind")
    if not isinstance(kind, str) or kind not in {"free", "burner", "fixed", *_COUNTERFLOW_KINDS}:
        raise InvalidReport("report.kind is missing or unsupported")
    roundtrip = _mapping(report.get("roundtrip"), "roundtrip")
    for chain in _ROUNDTRIP_CHAINS:
        if chain not in roundtrip:
            raise InvalidReport(f"roundtrip.{chain} is missing")
    components = {"T", "velocity", "Y"}
    if kind in _COUNTERFLOW_KINDS:
        components |= {"spreadRate", "Lambda"}
    values = []
    for chain, raw in roundtrip.items():
        path = f"roundtrip.{chain}"
        raw = _mapping(raw, path)
        for component in sorted(components):
            if component not in raw:
                raise InvalidReport(f"{path}.{component} is missing")
        for component, value in raw.items():
            values.append(_error_value(value, f"{path}.{component}"))
    aggregates = _mapping(report.get("aggregates"), "aggregates")
    checks = {"roundtrip": (max(values), RTOL)}
    for name, limit in _AGGREGATE_LIMITS.items():
        if name not in aggregates:
            raise InvalidReport(f"aggregates.{name} is missing")
        checks[name] = (_error_value(aggregates[name], f"aggregates.{name}"), limit)
    bad = {name: value for name, (value, limit) in checks.items() if value > limit}
    return checks, bad
