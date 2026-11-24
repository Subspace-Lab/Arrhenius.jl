"""Physical validity checks for counterflow parity evidence (standard library only)."""

import math
from numbers import Real

BURNING_MIN_TEMP_RISE_K = 500.0


def _finite_real(value):
    if isinstance(value, bool) or not isinstance(value, Real):
        return False
    try:
        return math.isfinite(value)
    except OverflowError:
        return False


def burning_rise(rise):
    return _finite_real(rise) and rise >= BURNING_MIN_TEMP_RISE_K


def temperature_rise(temperatures):
    """Return the peak rise above the hotter boundary, or None for invalid data."""
    try:
        if len(temperatures) == 0 or not all(map(_finite_real, temperatures)):
            return None
        rise = float(max(temperatures)) - max(float(temperatures[0]), float(temperatures[-1]))
    except (OverflowError, TypeError, ValueError):
        return None
    return rise if math.isfinite(rise) else None


def assess_temperatures(**profiles):
    """Every supplied profile must show a finite rise of at least 500 K."""
    rises = {f"{name}_temp_rise_K": temperature_rise(t) for name, t in profiles.items()}
    return {**rises, "physical_validity": bool(rises) and all(map(burning_rise, rises.values()))}


def heldout_physical_validity(data):
    """Require the producer's explicit verdict. Cross-check counterflow peak data if present."""
    gates = data.get("gates")
    if not isinstance(gates, dict) or gates.get("physical_validity") is not True:
        return False
    if data.get("physical_validity", True) is not True:
        return False
    if "physical_validity_details" in data:
        details = data["physical_validity_details"]
        if not isinstance(details, dict):
            return False
        for side in ("native", "reference", "coarse"):
            key = f"{side}_temp_rise_K"
            if side == "coarse" and key not in details and "coarse_burning" not in details:
                continue
            if not burning_rise(details.get(key)) or details.get(f"{side}_burning", True) is not True:
                return False
    spec = data.get("spec", {})
    if spec.get("kind") in ("diffusion", "stagnation") and "SL" in data:
        # The NH3 adapter stores peak T in SL for these two flame kinds.
        peaks = data["SL"]
        if not isinstance(peaks, dict):
            return False
        if spec["kind"] == "stagnation":
            left, right = spec.get("T_inlet", spec.get("T")), spec.get("T_surface")
        else:
            left, right = spec.get("T_fuel", spec.get("T")), spec.get("T_oxidizer", spec.get("T"))
        # Timed Cantera is diagnostic. Accuracy uses native and the refined reference.
        return assess_temperatures(**{
            side: [left, peaks.get(side), right] for side in ("native", "reference")
        })["physical_validity"]
    return True
