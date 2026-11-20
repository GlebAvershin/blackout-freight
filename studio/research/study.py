"""Replay a synthetic compass funnel under two traffic mixes and an assignment defect."""
import csv

SOURCE = ["analysis/synthetic_compass_counts.csv"]
COLUMNS = "scenario,segment,arm,exposures,deliveries"
OPTIONS = ["investigate_assignment", "collect_player_data"]
QUESTION = ("These counts are synthetic. If any segment has an arm imbalance above 5% of combined "
            "exposures, investigate assignment first. Otherwise collect player data before rollout.")
CONTROL = "assignment_defect"


def samples(root):
    with (root / SOURCE[0]).open() as file:
        counts = {(r["segment"], r["variant"], r["event"]): int(r["count"]) for r in csv.DictReader(file)}
    for scenario in ("fixture", CONTROL):
        for segment in ("solo", "crew"):
            for arm in ("control", "compass"):
                n = counts[segment, arm, "exposed"]
                delivered = counts[segment, arm, "delivered_90"]
                if (scenario, segment, arm) == (CONTROL, "crew", "compass"):
                    n, delivered = n // 2, delivered // 2
                yield scenario, segment, arm, n, delivered


def decision(metrics):
    return OPTIONS[0] if metrics["max_imbalance_bp"] > 500 else OPTIONS[1]
