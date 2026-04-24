from __future__ import annotations

from typing import Any

import numpy as np

KP_L_SHOULDER = 5
KP_R_SHOULDER = 6
KP_L_HIP = 11
KP_R_HIP = 12
KP_L_KNEE = 13
KP_R_KNEE = 14
KP_L_ANKLE = 15
KP_R_ANKLE = 16

GOOD_FORM = "GOOD_FORM"
BAD_FORM = "BAD_FORM"
UNKNOWN = "UNKNOWN"

DEFAULT_INVALID_MESSAGE = "Move back - full body required"
AWAITING_REP_MESSAGE = "Awaiting full rep"
GOOD_FORM_MESSAGE = "GOOD FORM"
BAD_FORM_PREFIX = "BAD FORM: "

MIN_KEYPOINT_SCORE = 0.20
KNEE_DEPTH_THRESHOLD = 100.0
HIP_LEAN_THRESHOLD = 45.0
STAND_KNEE_THRESHOLD = 155.0
UP_THRESHOLD = 169.0
DOWN_THRESHOLD = 120.0

_SIDE_INDEX_MAP = {
    "left": (KP_L_SHOULDER, KP_L_HIP, KP_L_KNEE, KP_L_ANKLE),
    "right": (KP_R_SHOULDER, KP_R_HIP, KP_R_KNEE, KP_R_ANKLE),
}

_REASON_LABELS = {
    "not_deep_enough": "Not deep enough",
    "back_leaning_too_much": "Back leaning too much",
    "stand_up_fully": "Stand up fully",
}


def calculate_angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    a = np.asarray(a, dtype=np.float32)
    b = np.asarray(b, dtype=np.float32)
    c = np.asarray(c, dtype=np.float32)
    radians = np.arctan2(c[1] - b[1], c[0] - b[0]) - np.arctan2(a[1] - b[1], a[0] - b[0])
    angle = float(np.abs(radians * 180.0 / np.pi))
    if angle > 180.0:
        angle = 360.0 - angle
    return angle


def _get_side_indices(side: str) -> tuple[int, int, int, int]:
    try:
        return _SIDE_INDEX_MAP[side]
    except KeyError as exc:
        raise ValueError(f"Unsupported side: {side}") from exc


def _is_joint_usable(point: np.ndarray, score: float, min_score: float) -> bool:
    point = np.asarray(point, dtype=np.float32)
    if point.shape != (2,):
        return False
    if not np.all(np.isfinite(point)):
        return False
    return bool(np.isfinite(score) and float(score) >= float(min_score))


def _get_side_score(keypoint_scores: np.ndarray, indices: tuple[int, ...]) -> float:
    scores = np.asarray(keypoint_scores, dtype=np.float32)
    if scores.ndim != 1 or scores.shape[0] <= max(indices):
        return 0.0

    side_scores = scores[list(indices)]
    if side_scores.size != len(indices) or not np.all(np.isfinite(side_scores)):
        return 0.0

    return float(np.mean(side_scores))


def _build_side_info(
    keypoints: np.ndarray,
    keypoint_scores: np.ndarray,
    side: str,
    min_score: float,
) -> dict[str, Any]:
    indices = _get_side_indices(side)
    keypoints = np.asarray(keypoints, dtype=np.float32)
    keypoint_scores = np.asarray(keypoint_scores, dtype=np.float32)

    if (
        keypoints.ndim != 2
        or keypoints.shape[1] != 2
        or keypoint_scores.ndim != 1
        or keypoints.shape[0] <= max(indices)
        or keypoint_scores.shape[0] <= max(indices)
    ):
        return {
            "side": side,
            "indices": indices,
            "usable": False,
            "score": 0.0,
        }

    usable = all(
        _is_joint_usable(keypoints[index], float(keypoint_scores[index]), min_score)
        for index in indices
    )
    return {
        "side": side,
        "indices": indices,
        "usable": usable,
        "score": _get_side_score(keypoint_scores, indices),
    }


def validate_squat_keypoints(
    keypoints: np.ndarray,
    keypoint_scores: np.ndarray,
    min_score: float = MIN_KEYPOINT_SCORE,
) -> dict[str, Any]:
    keypoints = np.asarray(keypoints, dtype=np.float32)
    keypoint_scores = np.asarray(keypoint_scores, dtype=np.float32)

    if (
        keypoints.ndim != 2
        or keypoints.shape[1] != 2
        or keypoints.shape[0] == 0
        or keypoint_scores.ndim != 1
        or keypoint_scores.shape[0] == 0
    ):
        return {
            "valid": False,
            "reason": DEFAULT_INVALID_MESSAGE,
            "available_sides": [],
            "side_scores": {"left": 0.0, "right": 0.0},
        }

    left_info = _build_side_info(keypoints, keypoint_scores, "left", min_score)
    right_info = _build_side_info(keypoints, keypoint_scores, "right", min_score)

    available_sides = [
        side_info["side"]
        for side_info in (left_info, right_info)
        if side_info["usable"]
    ]
    side_scores = {
        "left": left_info["score"],
        "right": right_info["score"],
    }

    if not available_sides:
        return {
            "valid": False,
            "reason": DEFAULT_INVALID_MESSAGE,
            "available_sides": [],
            "side_scores": side_scores,
        }

    return {
        "valid": True,
        "reason": None,
        "available_sides": available_sides,
        "side_scores": side_scores,
    }


def select_body_side(
    keypoints: np.ndarray,
    keypoint_scores: np.ndarray,
    preferred_side: str | None = None,
    min_score: float = MIN_KEYPOINT_SCORE,
) -> dict[str, Any]:
    validation = validate_squat_keypoints(
        keypoints=keypoints,
        keypoint_scores=keypoint_scores,
        min_score=min_score,
    )
    if not validation["valid"]:
        return {
            "valid": False,
            "side_used": None,
            "reason": validation["reason"],
            "side_score": None,
        }

    available_sides = validation["available_sides"]
    if preferred_side in available_sides:
        side_used = preferred_side
    elif len(available_sides) == 1:
        side_used = available_sides[0]
    else:
        left_score = validation["side_scores"]["left"]
        right_score = validation["side_scores"]["right"]
        side_used = "right" if right_score >= left_score else "left"

    return {
        "valid": True,
        "side_used": side_used,
        "reason": None,
        "side_score": validation["side_scores"][side_used],
    }


def compute_squat_angles_stable(
    keypoints: np.ndarray,
    keypoint_scores: np.ndarray,
    preferred_side: str | None = None,
    min_score: float = MIN_KEYPOINT_SCORE,
) -> dict[str, Any]:
    keypoints = np.asarray(keypoints, dtype=np.float32)
    selection = select_body_side(
        keypoints=keypoints,
        keypoint_scores=keypoint_scores,
        preferred_side=preferred_side,
        min_score=min_score,
    )

    if not selection["valid"]:
        return {
            "valid": False,
            "side_used": None,
            "knee": None,
            "hip": None,
            "reason": selection["reason"],
        }

    shoulder_index, hip_index, knee_index, ankle_index = _get_side_indices(selection["side_used"])
    shoulder = keypoints[shoulder_index]
    hip = keypoints[hip_index]
    knee = keypoints[knee_index]
    ankle = keypoints[ankle_index]

    return {
        "valid": True,
        "side_used": selection["side_used"],
        "knee": calculate_angle(hip, knee, ankle),
        "hip": calculate_angle(shoulder, hip, knee),
        "reason": None,
    }


def _build_form_message(reasons: list[str]) -> str:
    if not reasons:
        return GOOD_FORM_MESSAGE
    labels = [_REASON_LABELS[reason] for reason in reasons]
    return BAD_FORM_PREFIX + "; ".join(labels)


def check_squat_form(
    knee_min: float | None,
    hip_min: float | None,
    standing_knee: float | None,
) -> dict[str, Any]:
    if knee_min is None or hip_min is None or standing_knee is None:
        return {
            "status": UNKNOWN,
            "message": AWAITING_REP_MESSAGE,
            "reasons": [],
            "primary_reason": None,
        }

    reasons: list[str] = []
    if knee_min > KNEE_DEPTH_THRESHOLD:
        reasons.append("not_deep_enough")
    if hip_min < HIP_LEAN_THRESHOLD:
        reasons.append("back_leaning_too_much")
    if standing_knee < STAND_KNEE_THRESHOLD:
        reasons.append("stand_up_fully")

    if not reasons:
        return {
            "status": GOOD_FORM,
            "message": GOOD_FORM_MESSAGE,
            "reasons": [],
            "primary_reason": None,
        }

    return {
        "status": BAD_FORM,
        "message": _build_form_message(reasons),
        "reasons": reasons,
        "primary_reason": reasons[0],
    }


class SquatFormTracker:
    def __init__(
        self,
        up_threshold: float = UP_THRESHOLD,
        down_threshold: float = DOWN_THRESHOLD,
    ) -> None:
        self.counter = 0
        self.stage: str | None = None
        self.up_threshold = up_threshold
        self.down_threshold = down_threshold
        self.preferred_side: str | None = None
        self.current_rep_active = False
        self.current_rep_knee_min: float | None = None
        self.current_rep_hip_min: float | None = None
        self.current_rep_standing_knee: float | None = None
        self.last_form_status = UNKNOWN
        self.last_feedback_text = AWAITING_REP_MESSAGE
        self.last_feedback_until: float | None = None
        self.last_rep_summary: dict[str, Any] | None = None

    def _reset_current_rep(self) -> None:
        self.current_rep_active = False
        self.current_rep_knee_min = None
        self.current_rep_hip_min = None
        self.current_rep_standing_knee = None

    def _get_display_metric(self, metric: str) -> float | None:
        current_value = getattr(self, f"current_rep_{metric}", None)
        if self.current_rep_active and current_value is not None:
            return current_value
        if self.last_rep_summary is None:
            return None
        value = self.last_rep_summary.get(metric)
        return float(value) if value is not None else None

    def _build_output(
        self,
        *,
        valid_pose: bool,
        status: str,
        message: str,
        knee_angle: float | None,
        hip_angle: float | None,
        side_used: str | None,
        rep_completed: bool,
    ) -> dict[str, Any]:
        return {
            "rep_count": self.counter,
            "stage": self.stage,
            "status": status,
            "message": message,
            "knee_angle": knee_angle,
            "hip_angle": hip_angle,
            "knee_min": self._get_display_metric("knee_min"),
            "hip_min": self._get_display_metric("hip_min"),
            "standing_knee": self._get_display_metric("standing_knee"),
            "side_used": side_used,
            "valid_pose": valid_pose,
            "rep_completed": rep_completed,
            "last_rep_summary": dict(self.last_rep_summary) if self.last_rep_summary is not None else None,
        }

    def update(self, angle_info: dict[str, Any]) -> dict[str, Any]:
        valid = bool(angle_info.get("valid"))
        knee = angle_info.get("knee")
        hip = angle_info.get("hip")
        side_used = angle_info.get("side_used")
        reason = angle_info.get("reason") or DEFAULT_INVALID_MESSAGE

        if not valid or knee is None or hip is None:
            return self._build_output(
                valid_pose=False,
                status=UNKNOWN,
                message=reason,
                knee_angle=None,
                hip_angle=None,
                side_used=side_used,
                rep_completed=False,
            )

        knee = float(knee)
        hip = float(hip)
        if side_used is not None:
            self.preferred_side = side_used

        rep_completed = False
        status = self.last_form_status if self.last_rep_summary is not None else UNKNOWN
        message = self.last_feedback_text if self.last_rep_summary is not None else AWAITING_REP_MESSAGE

        if self.stage is None:
            if knee >= self.up_threshold:
                self.stage = "up"
        elif self.stage == "up" and knee <= self.down_threshold:
            self.stage = "down"
            self.current_rep_active = True
            self.current_rep_knee_min = knee
            self.current_rep_hip_min = hip
        elif self.stage == "down":
            if not self.current_rep_active:
                self.current_rep_active = True
                self.current_rep_knee_min = knee
                self.current_rep_hip_min = hip
            else:
                self.current_rep_knee_min = min(self.current_rep_knee_min, knee)
                self.current_rep_hip_min = min(self.current_rep_hip_min, hip)

            if knee >= self.up_threshold:
                self.current_rep_standing_knee = knee
                evaluation = check_squat_form(
                    knee_min=self.current_rep_knee_min,
                    hip_min=self.current_rep_hip_min,
                    standing_knee=self.current_rep_standing_knee,
                )
                self.counter += 1
                rep_completed = True
                status = evaluation["status"]
                message = evaluation["message"]
                self.last_form_status = evaluation["status"]
                self.last_feedback_text = evaluation["message"]
                self.last_rep_summary = {
                    "rep_count": self.counter,
                    "status": evaluation["status"],
                    "message": evaluation["message"],
                    "reasons": list(evaluation["reasons"]),
                    "primary_reason": evaluation["primary_reason"],
                    "knee_min": self.current_rep_knee_min,
                    "hip_min": self.current_rep_hip_min,
                    "standing_knee": self.current_rep_standing_knee,
                    "side_used": side_used,
                }
                self._reset_current_rep()
                self.stage = "up"

        return self._build_output(
            valid_pose=True,
            status=status,
            message=message,
            knee_angle=knee,
            hip_angle=hip,
            side_used=side_used,
            rep_completed=rep_completed,
        )
