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

    def test_preview_denominator_only_counts_winners_and_keeps_missing_data(self):
        base = self.row("", "", "")
        rows = [dict(base, participant_code=str(i), device="phone", first_session_win=win,
                     post_win_aurora_preview=preview)
                for i, (win, preview) in enumerate([("", "1"), ("1", ""), ("0", "0")])]
        result = report["summarize"]([base, *rows])
        self.assertEqual(result["byDevice"]["unknown"]["firstSessionWin"]["unknown"], 1)
        self.assertEqual(result["firstSessionWin"], {"observed": 3, "unknown": 1, "success": 2})
        self.assertEqual(result["byDevice"]["phone"]["postWinAuroraPreviewAmongWinners"],
                         {"observed": 1, "unknown": 1, "success": 1})
        with self.assertRaises(ValueError):
            report["summarize"]([dict(base, first_session_win="0", post_win_aurora_preview="1")])
