import importlib.util
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
WORKER_PATH = PROJECT_ROOT / "backend" / "workers" / "zmq_worker.py"

spec = importlib.util.spec_from_file_location("test_zmq_worker_module", WORKER_PATH)
assert spec is not None and spec.loader is not None
zmq_worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(zmq_worker)


def make_detection(
    *,
    score: float,
    knee: float,
    hip: float,
    side: str = "right",
    valid_pose: bool = True,
    message: str = "Pose ready",
) -> dict:
    return {
        "bbox": {
            "x1": 10.0,
            "y1": 20.0,
            "x2": 120.0,
            "y2": 220.0,
            "score": score,
        },
        "angles": {
            "knee": knee,
            "hip": hip,
        },
        "valid_pose": valid_pose,
        "side_used": side,
        "form_feedback": message,
    }


class EnrichResultWithFormTrackingTests(unittest.TestCase):
    def setUp(self) -> None:
        zmq_worker._SESSION_TRACKERS.clear()

    def test_returns_unknown_when_no_detections_are_available(self) -> None:
        result = zmq_worker.enrich_result_with_form_tracking(
            "sess_empty",
            {
                "success": True,
                "num_detections": 0,
                "detections": [],
            },
        )

        self.assertIsNone(result["primary_detection_index"])
        self.assertEqual(result["form_tracking"]["status"], "UNKNOWN")
        self.assertEqual(result["form_tracking"]["rep_count"], 0)
        self.assertFalse(result["form_tracking"]["valid_pose"])

    def test_tracks_rep_state_per_session_and_flags_shallow_rep(self) -> None:
        session_id = "sess_shallow"

        first = zmq_worker.enrich_result_with_form_tracking(
            session_id,
            {
                "success": True,
                "num_detections": 1,
                "detections": [make_detection(score=0.92, knee=171.0, hip=162.0)],
            },
        )
        second = zmq_worker.enrich_result_with_form_tracking(
            session_id,
            {
                "success": True,
                "num_detections": 1,
                "detections": [make_detection(score=0.91, knee=118.0, hip=68.0)],
            },
        )
        third = zmq_worker.enrich_result_with_form_tracking(
            session_id,
            {
                "success": True,
                "num_detections": 1,
                "detections": [make_detection(score=0.93, knee=170.0, hip=160.0)],
            },
        )

        self.assertEqual(first["form_tracking"]["stage"], "up")
        self.assertEqual(first["form_tracking"]["rep_count"], 0)

        self.assertEqual(second["form_tracking"]["stage"], "down")
        self.assertEqual(second["form_tracking"]["knee_min"], 118.0)
        self.assertFalse(second["form_tracking"]["rep_completed"])

        self.assertEqual(third["form_tracking"]["rep_count"], 1)
        self.assertTrue(third["form_tracking"]["rep_completed"])
        self.assertEqual(third["form_tracking"]["status"], "BAD_FORM")
        self.assertEqual(third["form_tracking"]["message"], "BAD FORM: Not deep enough")
        self.assertEqual(third["primary_detection_index"], 0)
        self.assertEqual(third["detections"][0]["form_status"], "BAD_FORM")
        self.assertEqual(third["detections"][0]["form_feedback"], "BAD FORM: Not deep enough")
        self.assertEqual(third["detections"][0]["angles"]["knee"], 170.0)

    def test_primary_detection_uses_highest_bbox_score(self) -> None:
        result = zmq_worker.enrich_result_with_form_tracking(
            "sess_primary",
            {
                "success": True,
                "num_detections": 2,
                "detections": [
                    make_detection(score=0.35, knee=171.0, hip=165.0, side="left"),
                    make_detection(score=0.88, knee=170.0, hip=164.0, side="right"),
                ],
            },
        )

        self.assertEqual(result["primary_detection_index"], 1)
        self.assertEqual(result["detections"][1]["form_status"], "UNKNOWN")
        self.assertEqual(result["detections"][1]["side_used"], "right")
        self.assertNotIn("form_status", result["detections"][0])

    def test_different_sessions_do_not_share_rep_counter(self) -> None:
        completed_rep_frames = [
            make_detection(score=0.9, knee=170.0, hip=160.0),
            make_detection(score=0.9, knee=115.0, hip=70.0),
            make_detection(score=0.9, knee=171.0, hip=160.0),
        ]

        for detection in completed_rep_frames:
            session_one = zmq_worker.enrich_result_with_form_tracking(
                "sess_one",
                {
                    "success": True,
                    "num_detections": 1,
                    "detections": [detection],
                },
            )

        session_two = zmq_worker.enrich_result_with_form_tracking(
            "sess_two",
            {
                "success": True,
                "num_detections": 1,
                "detections": [make_detection(score=0.9, knee=170.0, hip=160.0)],
            },
        )

        self.assertEqual(session_one["form_tracking"]["rep_count"], 1)
        self.assertEqual(session_two["form_tracking"]["rep_count"], 0)
        self.assertEqual(session_two["form_tracking"]["stage"], "up")


if __name__ == "__main__":
    unittest.main()
