"""AquaLog Fit Score prototype. Advisory only; never overrides husbandry review."""
from datetime import datetime, timezone
from typing import Optional

WEIGHTS = {"temperature_c": 28, "ph": 22, "gh_dgh": 15,
           "kh_dkh": 12, "tds_ppm": 3, "salinity_ppt": 20}
CRITICAL_WATER = ("ammonia_mg_l", "nitrite_mg_l", "chlorine_mg_l")


def _metric_score(value, bounds):
    low, high = (float(x) for x in bounds)
    if low >= high:
        return 100.0 if value == low else 0.0
    width = high - low
    inner_low, inner_high = low + width * .25, high - width * .25
    if inner_low <= value <= inner_high:
        return 100.0
    if low <= value <= high:
        fraction = ((value-low) / (inner_low-low) if value < inner_low
                    else (high-value) / (high-inner_high))
        return 82 + 18 * fraction
    distance = low-value if value < low else value-high
    return max(0.0, 65 - 65 * distance / max(width*.5, .1))


def _value(readings, key):
    datum = readings.get(key)
    if not isinstance(datum, dict) or datum.get("value") is None:
        return None
    try:
        result = float(datum["value"])
        return result if -float("inf") < result < float("inf") else None
    except (TypeError, ValueError, OverflowError):
        return None


def _is_stale(datum, now, days):
    if not isinstance(datum, dict) or not datum.get("observed_at"):
        return True
    try:
        observed = datetime.fromisoformat(datum["observed_at"].replace("Z", "+00:00"))
        if observed.tzinfo is None:
            return True
        age = (now-observed).total_seconds()/86400
        return age < -0.1 or age > days
    except (ValueError, TypeError, AttributeError):
        return True


def score_animal(profile: dict, tank: dict, now: Optional[datetime] = None) -> dict:
    """Calculate tentative chemical match and independently report readiness.

    Profile schema: id,name,group,ranges,water_type,review_status.
    Tank schema: water_type,volume_gal,cycled,compatibility_reviewed,
      same_species_count_after_add,readings[{value,observed_at}].
    Broad husbandry ranges are NOT validated optimal values.
    """
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    readings = tank.get("readings") or {}
    ranges = profile.get("ranges") or {}
    details, missing, stale, warnings, caps = [], [], [], [], []
    weighted_sum = weight_total = 0
    for key, weight in WEIGHTS.items():
        bounds = ranges.get(key)
        if not isinstance(bounds, (list, tuple)) or len(bounds) != 2:
            continue
        value = _value(readings, key)
        if value is None:
            missing.append(key)
            continue
        if _is_stale(readings[key], now, 7):
            stale.append(key)
        points = _metric_score(value, bounds)
        weighted_sum += weight * points
        weight_total += weight
        state = ("preferred_inferred" if points >= 99.9 else
                 "within_published_range" if points >= 82 else "outside_range")
        details.append({"parameter": key, "value": value, "bounds": bounds,
                        "score": round(points, 1), "state": state})
        if state == "outside_range":
            caps.append(65 if points > 35 else 35)
            warnings.append(key + " is outside the source range")

    for key in CRITICAL_WATER:
        value = _value(readings, key)
        if value is None:
            missing.append(key)
            continue
        if _is_stale(readings[key], now, 2):
            stale.append(key)
        if value > 0:
            caps.append(0 if key == "chlorine_mg_l" else (20 if value >= .25 else 39))
            warnings.append("Detectable " + key + "; investigate before stocking")
    nitrate = _value(readings, "nitrate_mg_l")
    if nitrate is not None:
        if _is_stale(readings["nitrate_mg_l"], now, 7):
            stale.append("nitrate_mg_l")
        if nitrate > 40:
            caps.append(45)
            warnings.append("Nitrate exceeds 40 mg/L")
        elif nitrate > 20:
            caps.append(75)
            warnings.append("Nitrate above preferred baseline")
    else:
        missing.append("nitrate_mg_l")

    min_volume = ranges.get("min_tank_gal")
    volume = tank.get("volume_gal")
    if min_volume is not None:
        try:
            if volume is None:
                missing.append("volume_gal")
            elif float(volume) < float(min_volume):
                caps.append(35)
                warnings.append("Tank below recorded minimum volume")
        except (TypeError, ValueError):
            missing.append("volume_gal")
    min_group = ranges.get("min_group")
    if min_group is not None:
        count = tank.get("same_species_count_after_add")
        if count is None:
            missing.append("same_species_count_after_add")
        elif int(count) < int(min_group):
            caps.append(55)
            warnings.append("Insufficient conspecific group size")
    required_water = profile.get("water_type")
    tank_water = tank.get("water_type")
    if required_water and tank_water and required_water != tank_water:
        caps.append(0)
        warnings.append("Freshwater/brackish/marine mismatch")
    elif not required_water or not tank_water:
        missing.append("water_type_review")
    if tank.get("cycled") is False:
        caps.append(0)
        warnings.append("Tank not cycled")
    elif tank.get("cycled") is not True:
        missing.append("cycled")
    if tank.get("compatibility_reviewed") is not True:
        missing.append("compatibility_reviewed")
        warnings.append("Tankmates and predation not checked")

    if profile.get("requires_salinity_verification") and _value(readings,"salinity_ppt") is None:
        missing.append("salinity_ppt")
    if profile.get("review_status") != "species_verified":
        warnings.append("Care-sheet parameters not independently verified")
    if not weight_total:
        missing.append("measured_in_range_parameters")
    numeric = round(weighted_sum/weight_total) if weight_total else None
    if numeric is not None and caps:
        numeric = min(numeric, min(caps))
    required = ["temperature_c", "ph"] + list(CRITICAL_WATER)
    if profile.get("group") in ("Shrimp", "Aquatic snail"):
        required += ["gh_dgh", "kh_dkh"]
    if profile.get("requires_salinity_verification"):
        required.append("salinity_ppt")
    missing_critical = any(key in missing for key in required)
    blocked = 0 in caps
    provisional = (bool(missing or stale or missing_critical) or
                   profile.get("review_status") != "species_verified")
    if blocked:
        status = "do_not_add"
    elif numeric is None:
        status = "insufficient_data"
    elif provisional:
        status = "provisional"
    elif numeric >= 90:
        status = "excellent"
    elif numeric >= 75:
        status = "good"
    elif numeric >= 60:
        status = "caution"
    else:
        status = "not_recommended"
    return {"id": profile.get("id"), "name": profile.get("name"),
            "fit_score": numeric, "status": status,
            "safe_to_add": False if provisional or blocked else None,
            "data_completeness": round(100*weight_total /
                sum(w for key,w in WEIGHTS.items() if key in ranges)) if
                any(key in ranges for key in WEIGHTS) else 0,
            "details": details, "missing": sorted(set(missing)),
            "stale": sorted(set(stale)), "warnings": warnings,
            "source_pdf": profile.get("source_pdf"),
            "source_page": profile.get("source_page")}
