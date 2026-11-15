import csv
import tempfile
import unittest
from pathlib import Path

from compass_report import FIXTURE, build_report, read_counts


class ExperimentReportTests(unittest.TestCase):
    def test_demo_is_explicit_and_has_reproducible_effect(self):
        report = build_report(read_counts(FIXTURE), "synthetic")
        self.assertEqual(report["source"], "synthetic")
        self.assertEqual(report["decision"], "simulation_only")
        self.assertAlmostEqual(report["solo"]["delivery"]["lift_pp"], 8.75)
        self.assertGreater(report["solo"]["delivery"]["ci95_pp"][0], 0)
        self.assertEqual(report["solo"]["by_variant"]["control"]["exposed"], 1200)

    def test_production_has_no_causal_decision_or_intervals(self):
        report = build_report(read_counts(FIXTURE), "production")
        self.assertEqual(report["decision"], "descriptive_only")
        self.assertIsNone(report["solo"]["delivery"]["ci95_pp"])

    def test_imbalanced_and_underpowered_playtests_hold(self):
        rows = read_counts(FIXTURE)
        small = {key: count // 10 for key, count in rows.items()}
        self.assertEqual(build_report(small, "playtest")["decision"], "insufficient_sample")
        rows["solo", "control", "exposed"] = 2400
        self.assertEqual(build_report(rows, "playtest")["decision"], "check_assignment")

    def test_playtest_decision_enforces_the_catch_guardrail(self):
        rows = read_counts(FIXTURE)
        self.assertEqual(build_report(rows, "playtest")["decision"], "rollout_candidate")
        rows["solo", "compass", "caught_90"] = 350
        self.assertEqual(build_report(rows, "playtest")["decision"], "keep_control")

    def test_invalid_grain_and_impossible_funnels_are_rejected(self):
        with FIXTURE.open(newline="", encoding="utf-8") as stream:
            rows = list(csv.reader(stream))
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "counts.csv"
            for invalid in (rows + [rows[1]], rows[:-1], [*rows[:-1], [*rows[-1][:-1], "5000"]]):
                with path.open("w", newline="", encoding="utf-8") as stream:
                    csv.writer(stream).writerows(invalid)
                with self.assertRaises(ValueError):
                    read_counts(path)

    def test_empty_valid_cohort_has_no_inference(self):
        rows = {key: 0 for key in read_counts(FIXTURE)}
        report = build_report(rows, "playtest")
        self.assertEqual(report["decision"], "insufficient_sample")
        self.assertIsNone(report["solo"]["delivery"]["lift_pp"])
        self.assertIsNone(report["solo"]["delivery"]["ci95_pp"])


if __name__ == "__main__":
    unittest.main()
