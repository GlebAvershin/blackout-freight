"""The external playtest funnel uses elapsed seconds from session start."""
import runpy
import unittest
from pathlib import Path

report = runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts/summarize-playtest.py"))


class PlaytestChronology(unittest.TestCase):
    def row(self, pickup, delivery, duration):
        row = dict.fromkeys(report["FIELDS"], "")
        row.update(participant_code="fixture", is_test="0", pickup_seconds=pickup,
                   delivery_seconds=delivery, session_seconds=duration)
        return row

    def test_rejects_impossible_order_and_out_of_session_actions(self):
        for times in [("60", "15", "90"), ("never", "30", "90"),
                      ("91", "never", "90"), ("", "91", "90")]:
            with self.subTest(times=times), self.assertRaises(ValueError):
                report["summarize"]([self.row(*times)])

    def test_unknown_and_unobserved_remain_distinct(self):
        for pickup, delivery, count in [("", "90", 1), ("never", "never", 0), ("90", "90", 1)]:
            with self.subTest(pickup=pickup):
                result = report["summarize"]([self.row(pickup, delivery, "90")])
                self.assertEqual(result["deliveryWithin90"]["success"], count)
                self.assertEqual(result["pickupWithin45"]["unknown"], int(pickup == ""))
