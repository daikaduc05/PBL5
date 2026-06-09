from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

import numpy as np

# COCO-17 keypoint indices
KP_L_SHOULDER, KP_R_SHOULDER = 5, 6
KP_L_ELBOW,    KP_R_ELBOW    = 7, 8
KP_L_WRIST,    KP_R_WRIST    = 9, 10
KP_L_HIP,      KP_R_HIP      = 11, 12
KP_L_KNEE,     KP_R_KNEE     = 13, 14
KP_L_ANKLE,    KP_R_ANKLE    = 15, 16

MIN_CONFIDENCE = 0.3


def calculate_angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """Return the angle at vertex b in degrees using the Law of Cosines.

    side_a = dist(b, c),  side_b = dist(a, c),  side_c = dist(a, b)
    θ = arccos( (side_a² + side_c² − side_b²) / (2 · side_a · side_c) )
    """
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    c = np.asarray(c, dtype=np.float64)

    side_a = float(np.linalg.norm(c - b))
    side_b = float(np.linalg.norm(c - a))
    side_c = float(np.linalg.norm(b - a))

    denom = 2.0 * side_a * side_c
    if denom < 1e-9:
        return 0.0

    cosine = (side_a ** 2 + side_c ** 2 - side_b ** 2) / denom
    return math.degrees(math.acos(max(-1.0, min(1.0, cosine))))


@dataclass(frozen=True)
class ExerciseConfig:
    name: str
    # (a_index, b_index, c_index) — b is the vertex joint whose angle is measured
    joint_triplets: tuple[tuple[int, int, int], ...]
    # all tracked angles must exceed this to enter/reset to "Initial"
    initial_threshold: float
    # all tracked angles must be below this (while stage == "Initial") to count a rep
    final_threshold: float
    min_confidence: float = MIN_CONFIDENCE

    @property
    def required_keypoints(self) -> frozenset[int]:
        return frozenset(idx for triplet in self.joint_triplets for idx in triplet)


SQUAT_CONFIG = ExerciseConfig(
    name="Squat",
    joint_triplets=(
        (KP_L_HIP, KP_L_KNEE, KP_L_ANKLE),
        (KP_R_HIP, KP_R_KNEE, KP_R_ANKLE),
    ),
    initial_threshold=175.0,
    final_threshold=100.0,
)

PUSHUP_CONFIG = ExerciseConfig(
    name="Pushup",
    joint_triplets=(
        (KP_L_SHOULDER, KP_L_ELBOW, KP_L_WRIST),
        (KP_R_SHOULDER, KP_R_ELBOW, KP_R_WRIST),
    ),
    initial_threshold=175.0,
    final_threshold=150.0,
)


class ExerciseCounter:
    """Generic rep counter driven by an ExerciseConfig.

    One full Initial → Final cycle counts as one rep.
    The user must return to Initial before another rep is counted.
    Frames where any required keypoint has confidence < min_confidence are skipped.
    """

    def __init__(self, config: ExerciseConfig) -> None:
        self.config = config
        self.stage: str = "Initial"
        self.count: int = 0
        self._angles: list[float] = []

    def update(self, keypoints: np.ndarray) -> dict[str, Any]:
        """Process one frame.

        keypoints: shape (17, 3) — (x, y, confidence) per COCO joint.
        Returns the current state dict; does not mutate state on a skipped frame.
        """
        keypoints = np.asarray(keypoints, dtype=np.float32)

        for idx in self.config.required_keypoints:
            if float(keypoints[idx, 2]) < self.config.min_confidence:
                return self._build_state()

        angles = [
            calculate_angle(keypoints[a, :2], keypoints[b, :2], keypoints[c, :2])
            for a, b, c in self.config.joint_triplets
        ]
        self._angles = angles

        all_final   = all(angle < self.config.final_threshold   for angle in angles)
        all_initial = all(angle > self.config.initial_threshold for angle in angles)

        if all_final and self.stage == "Initial":
            self.count += 1
            self.stage = "Final"
        elif all_initial:
            self.stage = "Initial"

        return self._build_state()

    def reset(self) -> None:
        self.stage = "Initial"
        self.count = 0
        self._angles = []

    def _build_state(self) -> dict[str, Any]:
        return {
            "exercise": self.config.name,
            "count": self.count,
            "stage": self.stage,
            "angles": list(self._angles),
        }


def run_demo(keypoints_sequence: list[np.ndarray]) -> None:
    """Feed a sequence of (17, 3) keypoint arrays and print live state for both exercises."""
    squat  = ExerciseCounter(SQUAT_CONFIG)
    pushup = ExerciseCounter(PUSHUP_CONFIG)

    for i, kps in enumerate(keypoints_sequence):
        sq = squat.update(kps)
        pu = pushup.update(kps)

        sq_angles = [f"{a:.1f}°" for a in sq["angles"]]
        pu_angles = [f"{a:.1f}°" for a in pu["angles"]]

        print(
            f"[{i:03d}] "
            f"Squat  stage={sq['stage']:8s} reps={sq['count']} angles={sq_angles} | "
            f"Pushup stage={pu['stage']:8s} reps={pu['count']} angles={pu_angles}"
        )


# ---------------------------------------------------------------------------
# Synthetic demo — run this file directly to verify the state machine.
# Replace _make_frame with real pose-model output in production.
# ---------------------------------------------------------------------------

def _make_frame(*, knee_angle: float, elbow_angle: float, confidence: float = 0.95) -> np.ndarray:
    """Build a geometrically consistent (17, 3) keypoints array for testing."""
    kps = np.zeros((17, 3), dtype=np.float32)
    kps[:, 2] = confidence

    for hip_i, knee_i, ankle_i in (
        (KP_L_HIP, KP_L_KNEE, KP_L_ANKLE),
        (KP_R_HIP, KP_R_KNEE, KP_R_ANKLE),
    ):
        hip   = np.array([0.0, 0.0])
        knee  = np.array([0.0, 1.0])
        rad   = math.radians(knee_angle)
        ankle = knee + np.array([math.sin(math.pi - rad), math.cos(math.pi - rad)])
        kps[hip_i,   :2] = hip
        kps[knee_i,  :2] = knee
        kps[ankle_i, :2] = ankle

    for sh_i, el_i, wr_i in (
        (KP_L_SHOULDER, KP_L_ELBOW, KP_L_WRIST),
        (KP_R_SHOULDER, KP_R_ELBOW, KP_R_WRIST),
    ):
        shoulder = np.array([5.0, 0.0])
        elbow    = np.array([5.0, 1.0])
        rad      = math.radians(elbow_angle)
        wrist    = elbow + np.array([math.sin(math.pi - rad), math.cos(math.pi - rad)])
        kps[sh_i, :2] = shoulder
        kps[el_i, :2] = elbow
        kps[wr_i, :2] = wrist

    return kps


if __name__ == "__main__":
    frames = [
        # --- 2 squat reps ---
        _make_frame(knee_angle=180.0, elbow_angle=180.0),  # standing
        _make_frame(knee_angle=88.0,  elbow_angle=180.0),  # squat down
        _make_frame(knee_angle=180.0, elbow_angle=180.0),  # stand up  → squat rep 1
        _make_frame(knee_angle=85.0,  elbow_angle=180.0),  # squat down again
        _make_frame(knee_angle=180.0, elbow_angle=180.0),  # stand up  → squat rep 2
        # --- 2 pushup reps ---
        _make_frame(knee_angle=180.0, elbow_angle=100.0),  # elbows bent
        _make_frame(knee_angle=180.0, elbow_angle=180.0),  # arms extended → pushup rep 1
        _make_frame(knee_angle=180.0, elbow_angle=95.0),   # bend again
        _make_frame(knee_angle=180.0, elbow_angle=180.0),  # extend      → pushup rep 2
        # --- low-confidence frame (should be skipped) ---
        _make_frame(knee_angle=88.0,  elbow_angle=90.0,  confidence=0.1),
        _make_frame(knee_angle=180.0, elbow_angle=180.0),  # counters unchanged from skip
    ]

    run_demo(frames)
