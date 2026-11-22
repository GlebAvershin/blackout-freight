#!/usr/bin/env python3
"""Unit tests for Blackout Freight Sentinel Sensory AI."""
import unittest
from analysis.sentinel_sensory_ai import SentinelSensoryAI


class TestSentinelSensory(unittest.TestCase):
    def setUp(self):
        self.ai = SentinelSensoryAI(seed=42)

    def test_visual_detection_occlusion(self):
        drone_pos = (0.0, 0.0)
        player_pos = (5.0, 0.0)
        # Blocked by cover -> never seen
        seen = self.ai.evaluate_visual_detection(
            drone_pos, 0.0, player_pos, is_blackout=False,
            flashlight_active=False, is_crouching=False, has_cover=True
        )
        self.assertFalse(seen)

    def test_visual_flashlight_amplification(self):
        drone_pos = (0.0, 0.0)
        player_pos = (20.0, 0.0)  # Beyond normal blackout range (8m)
        # With flashlight, 8m * 3.5 = 28m -> should be detected
        seen_with_light = self.ai.evaluate_visual_detection(
            drone_pos, 0.0, player_pos, is_blackout=True,
            flashlight_active=True, is_crouching=False, has_cover=False
        )
        self.assertTrue(seen_with_light)

        # Without flashlight in blackout -> out of range
        seen_without_light = self.ai.evaluate_visual_detection(
            drone_pos, 0.0, player_pos, is_blackout=True,
            flashlight_active=False, is_crouching=False, has_cover=False
        )
        self.assertFalse(seen_without_light)

    def test_acoustic_detection_decibels(self):
        drone_pos = (0.0, 0.0)
        # SPRINT at 5m -> loud
        heard_sprint, db_sprint = self.ai.evaluate_acoustic_detection(drone_pos, (5.0, 0.0), "SPRINT")
        self.assertTrue(heard_sprint)
        self.assertGreater(db_sprint, 20.0)

        # CROUCH at 15m -> inaudible
        heard_crouch, _ = self.ai.evaluate_acoustic_detection(drone_pos, (15.0, 0.0), "CROUCH_WALK")
        self.assertFalse(heard_crouch)


if __name__ == "__main__":
    unittest.main()
