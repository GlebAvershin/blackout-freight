"""Analyze normalized Roblox FirstShiftCompassV1 counts."""
import argparse
import csv
import json
from itertools import product
from pathlib import Path

import duckdb
from scipy.stats import binomtest
from statsmodels.stats.proportion import confint_proportions_2indep

ROOT = Path(__file__).resolve().parent
FIXTURE = ROOT / "synthetic_compass_counts.csv"
EVENTS = ("exposed", "pickup_90", "delivered_90", "caught_90")
VARIANTS = ("control", "compass")
SEGMENTS = ("solo", "crew")
SOURCES = ("synthetic", "playtest", "production")
TARGET_PER_ARM = 1200
MIN_LIFT_PP = 8
MAX_CATCH_INCREASE_PP = 5
SRM_ALPHA = 0.01


def read_counts(path):
    """Read a complete grid of aggregate counts for one experiment window."""
    counts = {}
    expected = set(product(SEGMENTS, VARIANTS, EVENTS))
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["segment", "variant", "event", "count"]:
            raise ValueError("Expected columns segment,variant,event,count")
        for row in reader:
            key = row["segment"], row["variant"], row["event"]
            if None in row or key not in expected or key in counts:
                raise ValueError(f"Invalid or duplicate count row on line {reader.line_num}")
            try:
                count = int(row["count"])
            except (ValueError, TypeError) as error:
                raise ValueError(f"Invalid count on line {reader.line_num}") from error
            if not 0 <= count <= 2_147_483_647:
                raise ValueError(f"Count out of range on line {reader.line_num}")
            counts[key] = count
    if counts.keys() != expected:
        raise ValueError("Provide every segment, variant and event combination, including verified zeros")
    for segment, variant in product(SEGMENTS, VARIANTS):
        exposed, pickups, deliveries, catches = (counts[segment, variant, event] for event in EVENTS)
        if not deliveries <= pickups <= exposed or catches > exposed:
            raise ValueError(f"Impossible funnel for {segment}/{variant}")
    return counts


def build_report(counts, source):
    """Compute descriptive rates for every cohort and inference for eligible solo data."""
    if source not in SOURCES:
        raise ValueError("Unknown data source")
    with duckdb.connect() as db:
        db.execute("CREATE TABLE event_counts(segment VARCHAR, variant VARCHAR, event VARCHAR, count_value INTEGER)")
        db.executemany("INSERT INTO event_counts VALUES (?, ?, ?, ?)", [(*key, count) for key, count in counts.items()])
        rows = db.execute((ROOT / "compass_funnel.sql").read_text(encoding="utf-8")).fetchdf()

    report = {"experiment": "FirstShiftCompassV1", "source": source}
    for segment in SEGMENTS:
        by_variant = (
            rows[rows.segment == segment].drop(columns="segment").set_index("variant").to_dict("index")
        )
        # DuckDB's NULL rates are represented by pandas as NaN.
        for variant in by_variant.values():
            if variant["exposed"] == 0:
                for metric in ("pickup_rate", "delivery_rate", "catch_rate"):
                    variant[metric] = None
        control, compass = (by_variant[variant] for variant in VARIANTS)
        nc, nt = control["exposed"], compass["exposed"]
        infer = segment == "solo" and source != "production"
        srm = binomtest(nt, nc + nt, p=0.5).pvalue if infer and nc + nt else None
        report[segment] = {"by_variant": by_variant, "srm_p_value": srm}
        total = nc + nt
        gap = abs(nt - nc)
        report[segment]["assignment"] = {
            "gap_percent": 100 * gap / total if total else None,
            "needs_review": 20 * gap > total if total else None,
        }
        for metric, count in (("delivery", "deliveries"), ("catch", "catches")):
            lift, interval = None, None
            if nc and nt:
                lift = 100 * (compass[count] / nt - control[count] / nc)
                if infer:
                    interval = [100 * bound for bound in confint_proportions_2indep(
                        compass[count], nt, control[count], nc, method="newcomb",
                    )]
            report[segment][metric] = {"lift_pp": lift, "ci95_pp": interval}

    flagged = [segment for segment in SEGMENTS if report[segment]["assignment"]["needs_review"]]
    report["assignment_review_segments"] = flagged
    solo = report["solo"]
    delivery, catch = solo["delivery"], solo["catch"]
    if source == "synthetic":
        decision = "simulation_only"
    elif source == "production":
        decision = "descriptive_only"
    elif flagged or (solo["srm_p_value"] is not None and solo["srm_p_value"] < SRM_ALPHA):
        decision = "check_assignment"
    elif min(variant["exposed"] for variant in solo["by_variant"].values()) < TARGET_PER_ARM:
        decision = "insufficient_sample"
    elif delivery["lift_pp"] >= MIN_LIFT_PP and delivery["ci95_pp"][0] > 0 and catch["ci95_pp"][1] <= MAX_CATCH_INCREASE_PP:
        decision = "rollout_candidate"
    else:
        decision = "keep_control"
    report["decision"] = decision
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("counts", type=Path)
    parser.add_argument("--source", choices=SOURCES, required=True)
    args = parser.parse_args()
    try:
        if args.counts.resolve() == FIXTURE and args.source != "synthetic":
            raise ValueError("The bundled fixture must use --source synthetic")
        report = build_report(read_counts(args.counts), args.source)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(report, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
