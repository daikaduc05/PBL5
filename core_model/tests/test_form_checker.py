from __future__ import annotations

import unittest

import numpy as np

from core_model.form_checker import (
    AWAITING_REP_MESSAGE,
    BAD_FORM,
    DEFAULT_INVALID_MESSAGE,
    GOOD_FORM,
    KP_L_ANKLE,
    KP_L_HIP,
    KP_L_KNEE,
    KP_L_SHOULDER,
    KP_R_ANKLE,
    KP_R_HIP,
    KP_R_KNEE,
    KP_R_SHOULDER,
    UNKNOWN,
    SquatFormTracker,
    calculate_angle,
    check_squat_form,
    compute_squat_angles_stable,
    select_body_side,
    validate_squat_keypoints,
)


def _build_keypoints_and_scores(
    *,
    left_points: dict[int, tuple[float, float]] | None = None,
    right_points: dict[int, tuple[float, float]] | None = None,
    left_scores: dict[int, float] | None = None,
    right_scores: dict[int, float] | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    keypoints = np.zeros((17, 2), dtype=np.float32)
    scores = np.zeros(17, dtype=np.float32)

    left_points = left_points or {}
    right_points = right_points or {}
    left_scores = left_scores or {}
    right_scores = right_scores or {}

    for index, point in {**left_points, **right_points}.items():
        keypoints[index] = np.asarray(point, dtype=np.float32)

    for index, score in {**left_scores, **right_scores}.items():
        scores[index] = float(score)

    return keypoints, scores


def _make_valid_right_pose(
    *,
    shoulder_score: float = 0.95,
    hip_score: float = 0.95,
    knee_score: float = 0.95,
    ankle_score: float = 0.95,
) -> tuple[np.ndarray, np.ndarray]:
    return _build_keypoints_and_scores(
        right_points={
            KP_R_SHOULDER: (0.0, 0.0),
            KP_R_HIP: (0.0, 1.0),
            KP_R_KNEE: (1.0, 1.0),
            KP_R_ANKLE: (1.0, 2.0),
        },
        right_scores={
            KP_R_SHOULDER: shoulder_score,
            KP_R_HIP: hip_score,
            KP_R_KNEE: knee_score,
            KP_R_ANKLE: ankle_score,
        },
    )


def _make_valid_left_pose(
    *,
    shoulder_score: float = 0.95,
    hip_score: float = 0.95,
    knee_score: float = 0.95,
    ankle_score: float = 0.95,
) -> tuple[np.ndarray, np.ndarray]:
    return _build_keypoints_and_scores(
        left_points={
            KP_L_SHOULDER: (3.0, 0.0),
            KP_L_HIP: (3.0, 1.0),
            KP_L_KNEE: (2.0, 1.0),
            KP_L_ANKLE: (2.0, 2.0),
        },
        left_scores={
            KP_L_SHOULDER: shoulder_score,
            KP_L_HIP: hip_score,
            KP_L_KNEE: knee_score,
            KP_L_ANKLE: ankle_score,
        },
    )


class FormCheckerTests(unittest.TestCase):
    def test_calculate_angle_returns_ninety_for_right_angle(self) -> None:
        angle = calculate_angle(
            np.array([1.0, 0.0], dtype=np.float32),
            np.array([0.0, 0.0], dtype=np.float32),
            np.array([0.0, 1.0], dtype=np.float32),
        )

        self.assertAlmostEqual(angle, 90.0, places=4)

    def test_validate_squat_keypoints_rejects_pose_without_usable_side(self) -> None:
        keypoints = np.zeros((17, 2), dtype=np.float32)
        scores = np.zeros(17, dtype=np.float32)

        result = validate_squat_keypoints(keypoints, scores)

        self.assertFalse(result["valid"])
        self.assertEqual(result["reason"], DEFAULT_INVALID_MESSAGE)
        self.assertEqual(result["available_sides"], [])

    def test_validate_squat_keypoints_accepts_single_valid_side(self) -> None:
        keypoints, scores = _make_valid_right_pose()

        result = validate_squat_keypoints(keypoints, scores)

        self.assertTrue(result["valid"])
        self.assertEqual(result["available_sides"], ["right"])
        self.assertGreater(result["side_scores"]["right"], 0.0)

    def test_select_body_side_keeps_preferred_side_when_still_valid(self) -> None:
        left_keypoints, left_scores = _make_valid_left_pose(shoulder_score=0.85, hip_score=0.85, knee_score=0.85, ankle_score=0.85)
        right_keypoints, right_scores = _make_valid_right_pose()
        keypoints = left_keypoints + right_keypoints
        scores = left_scores + right_scores

        result = select_body_side(keypoints, scores, preferred_side="left")

        self.assertTrue(result["valid"])
        self.assertEqual(result["side_used"], "left")

    def test_select_body_side_falls_back_to_other_valid_side(self) -> None:
        left_keypoints, left_scores = _make_valid_left_pose()
        right_keypoints, right_scores = _make_valid_right_pose(knee_score=0.05)
        keypoints = left_keypoints + right_keypoints
        scores = left_scores + right_scores

        result = select_body_side(keypoints, scores, preferred_side="right")

        self.assertTrue(result["valid"])
        self.assertEqual(result["side_used"], "left")

    def test_select_body_side_prefers_right_when_scores_tie(self) -> None:
        left_keypoints, left_scores = _make_valid_left_pose()
        right_keypoints, right_scores = _make_valid_right_pose()
        keypoints = left_keypoints + right_keypoints
        scores = left_scores + right_scores

        result = select_body_side(keypoints, scores)

        self.assertEqual(result["side_used"], "right")

    def test_compute_squat_angles_stable_uses_left_side_when_right_invalid(self) -> None:
        left_keypoints, left_scores = _make_valid_left_pose()
        right_keypoints, right_scores = _make_valid_right_pose(knee_score=0.05)
        keypoints = left_keypoints + right_keypoints
        scores = left_scores + right_scores

        result = compute_squat_angles_stable(keypoints, scores, preferred_side="right")

        self.assertTrue(result["valid"])
        self.assertEqual(result["side_used"], "left")
        self.assertAlmostEqual(result["knee"], 90.0, places=4)
        self.assertAlmostEqual(result["hip"], 90.0, places=4)

    def test_compute_squat_angles_stable_returns_invalid_when_no_side_usable(self) -> None:
        keypoints = np.zeros((17, 2), dtype=np.float32)
        scores = np.zeros(17, dtype=np.float32)

        result = compute_squat_angles_stable(keypoints, scores)

        self.assertFalse(result["valid"])
        self.assertIsNone(result["knee"])
        self.assertIsNone(result["hip"])
        self.assertEqual(result["reason"], DEFAULT_INVALID_MESSAGE)

    def test_check_squat_form_returns_good_at_threshold_boundaries(self) -> None:
        result = check_squat_form(knee_min=100.0, hip_min=45.0, standing_knee=155.0)

        self.assertEqual(result["status"], GOOD_FORM)
        self.assertEqual(result["message"], "GOOD FORM")
        self.assertEqual(result["reasons"], [])

    def test_check_squat_form_collects_multiple_reasons_in_order(self) -> None:
        result = check_squat_form(knee_min=101.0, hip_min=44.0, standing_knee=154.0)

        self.assertEqual(result["status"], BAD_FORM)
        self.assertEqual(
            result["reasons"],
            ["not_deep_enough", "back_leaning_too_much", "stand_up_fully"],
        )
        self.assertEqual(
            result["message"],
            "BAD FORM: Not deep enough; Back leaning too much; Stand up fully",
        )
        self.assertEqual(result["primary_reason"], "not_deep_enough")

    def test_tracker_stays_unknown_until_full_rep_finishes(self) -> None:
        tracker = SquatFormTracker()

        output = tracker.update(
            {"valid": True, "knee": 172.0, "hip": 170.0, "side_used": "right", "reason": None}
        )

        self.assertEqual(output["rep_count"], 0)
        self.assertEqual(output["status"], UNKNOWN)
        self.assertEqual(output["message"], AWAITING_REP_MESSAGE)
        self.assertEqual(output["stage"], "up")

    def test_tracker_counts_good_rep_on_up_down_up_sequence(self) -> None:
        tracker = SquatFormTracker()
        frames = [
            {"valid": True, "knee": 172.0, "hip": 170.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 88.0, "hip": 70.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 84.0, "hip": 58.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 171.0, "hip": 168.0, "side_used": "right", "reason": None},
        ]

        for frame in frames:
            output = tracker.update(frame)

        self.assertEqual(output["rep_count"], 1)
        self.assertTrue(output["rep_completed"])
        self.assertEqual(output["status"], GOOD_FORM)
        self.assertEqual(output["message"], "GOOD FORM")
        self.assertAlmostEqual(output["knee_min"], 84.0, places=4)
        self.assertAlmostEqual(output["hip_min"], 58.0, places=4)
        self.assertAlmostEqual(output["standing_knee"], 171.0, places=4)

    def test_tracker_invalid_mid_rep_frame_does_not_increment_counter(self) -> None:
        tracker = SquatFormTracker()

        tracker.update({"valid": True, "knee": 172.0, "hip": 170.0, "side_used": "right", "reason": None})
        tracker.update({"valid": True, "knee": 88.0, "hip": 70.0, "side_used": "right", "reason": None})
        invalid_output = tracker.update(
            {"valid": False, "knee": None, "hip": None, "side_used": None, "reason": DEFAULT_INVALID_MESSAGE}
        )

        self.assertEqual(invalid_output["rep_count"], 0)
        self.assertEqual(invalid_output["status"], UNKNOWN)
        self.assertFalse(invalid_output["valid_pose"])

        final_output = tracker.update(
            {"valid": True, "knee": 171.0, "hip": 168.0, "side_used": "right", "reason": None}
        )

        self.assertEqual(final_output["rep_count"], 1)
        self.assertEqual(final_output["status"], GOOD_FORM)

    def test_tracker_counts_shallow_rep_as_bad_form(self) -> None:
        tracker = SquatFormTracker()
        frames = [
            {"valid": True, "knee": 172.0, "hip": 170.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 120.0, "hip": 70.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 171.0, "hip": 168.0, "side_used": "right", "reason": None},
        ]

        for frame in frames:
            output = tracker.update(frame)

        self.assertEqual(output["rep_count"], 1)
        self.assertTrue(output["rep_completed"])
        self.assertEqual(output["status"], BAD_FORM)
        self.assertEqual(output["message"], "BAD FORM: Not deep enough")
        self.assertAlmostEqual(output["knee_min"], 120.0, places=4)

    def test_tracker_does_not_count_rep_when_knee_stays_above_down_threshold(self) -> None:
        tracker = SquatFormTracker()
        frames = [
            {"valid": True, "knee": 172.0, "hip": 170.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 121.0, "hip": 90.0, "side_used": "right", "reason": None},
            {"valid": True, "knee": 171.0, "hip": 168.0, "side_used": "right", "reason": None},
        ]

        for frame in frames:
            output = tracker.update(frame)

        self.assertEqual(output["rep_count"], 0)
        self.assertFalse(output["rep_completed"])
        self.assertEqual(output["status"], UNKNOWN)
        self.assertEqual(output["message"], AWAITING_REP_MESSAGE)


if __name__ == "__main__":
    unittest.main()
