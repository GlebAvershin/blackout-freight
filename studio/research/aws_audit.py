"""Sensitivity of the synthetic 90-second delivery difference to solo/crew mix."""
import csv
import json

SOURCE = "analysis/synthetic_compass_counts.csv"


def load_input(root):
    data = {}
    with (root / SOURCE).open() as stream:
        for row in csv.DictReader(stream):
            if row["event"] in ("exposed", "delivered_90"):
                data.setdefault(row["segment"], {}).setdefault(row["variant"], {})[row["event"]] = int(row["count"])
    return data


def analyze(data):
    lift = {}
    for segment, groups in data.items():
        rates = {arm: values["delivered_90"] / values["exposed"] for arm, values in groups.items()}
        lift[segment] = 100 * (rates["compass"] - rates["control"])
    mixes = [share * lift["solo"] / 100 + (100 - share) * lift["crew"] / 100 for share in range(101)]
    crossing = next((i for i, gain in enumerate(mixes) if gain >= 8), None)
    return {"lift_pp": {s: round(value, 5) for s, value in lift.items()},
            "mixes_checked": len(mixes), "first_solo_percent_at_8pp": crossing,
            "mix_20_pp": round(mixes[20], 5), "mix_80_pp": round(mixes[80], 5)}


def verify(root, result):
    fixture = next(c["metrics"] for c in json.loads((root / "docs/evidence/research.json").read_text())["cases"]
                   if c["scenario"] == "fixture")
    assert round(result["mix_20_pp"] * 100) == fixture["crew_heavy_lift_bp"]
    assert round(result["mix_80_pp"] * 100) == fixture["solo_heavy_lift_bp"]
    # Solve the crossing analytically using exact fractions, independently of the sweep.
    from fractions import Fraction
    from math import ceil
    gains = {}
    for segment, arms in load_input(root).items():
        rate = {arm: Fraction(row["delivered_90"], row["exposed"]) for arm, row in arms.items()}
        gains[segment] = 100 * (rate["compass"] - rate["control"])
    assert result["mixes_checked"] == 101
    assert result["first_solo_percent_at_8pp"] == ceil(100 * (8 - gains["crew"]) / (gains["solo"] - gains["crew"]))
