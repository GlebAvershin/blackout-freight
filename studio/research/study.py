"""Replay a synthetic compass funnel under two traffic mixes and an assignment defect."""
import csv

SOURCE = ["analysis/synthetic_compass_counts.csv"]
COLUMNS = "scenario,segment,arm,exposures,deliveries"
OPTIONS = ["investigate_assignment", "collect_player_data"]
QUESTION = ("These counts are synthetic. If any segment has an arm imbalance above 5% of combined "
            "exposures (assignment_flag=1 before rounding), investigate assignment first. Otherwise collect player data before rollout.")
CONTROL = "assignment_defect"


def samples(root):
    with (root / SOURCE[0]).open() as file:
        counts = {(r["segment"], r["variant"], r["event"]): int(r["count"]) for r in csv.DictReader(file)}
    for scenario in ("fixture", CONTROL, "at_threshold", "just_over_threshold"):
        for segment in ("solo", "crew"):
            for arm in ("control", "compass"):
                n = counts[segment, arm, "exposed"]
                delivered = counts[segment, arm, "delivered_90"]
                if (scenario, segment, arm) == (CONTROL, "crew", "compass"):
                    n, delivered = n // 2, delivered // 2
                if segment == "crew" and scenario in ("at_threshold", "just_over_threshold"):
                    extra = int(scenario == "just_over_threshold")
                    new_n = 105000 + extra if arm == "control" else 95000 - extra
                    delivered, n = delivered * new_n // n, new_n
                yield scenario, segment, arm, n, delivered


def decision(metrics):
    return OPTIONS[0] if metrics["assignment_flag"] else OPTIONS[1]
