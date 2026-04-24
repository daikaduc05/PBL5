from __future__ import annotations

import argparse
import logging
import time
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import torch
import torch.nn as nn
from torchvision import models
from ultralytics import YOLO

try:
    from .form_checker import (
        AWAITING_REP_MESSAGE,
        BAD_FORM,
        DEFAULT_INVALID_MESSAGE,
        GOOD_FORM,
        SquatFormTracker,
        UNKNOWN,
        compute_squat_angles_stable,
    )
except ImportError:
    from form_checker import (
        AWAITING_REP_MESSAGE,
        BAD_FORM,
        DEFAULT_INVALID_MESSAGE,
        GOOD_FORM,
        SquatFormTracker,
        UNKNOWN,
        compute_squat_angles_stable,
    )


logger = logging.getLogger(__name__)

MODULE_DIR = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT_PATH = MODULE_DIR / "checkpoint" / "checkpoint_manual_epoch39.pth"
DEFAULT_DETECTOR_PATH = MODULE_DIR / "yolov8n.pt"
BN_MOMENTUM = 0.1

_POSE_MODEL: nn.Module | None = None
_POSE_MODEL_PATH: Path | None = None
_PERSON_DETECTOR: YOLO | None = None
_PERSON_DETECTOR_PATH: Path | None = None


def get_runtime_device() -> torch.device:
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def get_detector_device() -> int | str:
    return 0 if torch.cuda.is_available() else "cpu"


def resolve_asset_path(path: str | Path | None, default_path: Path) -> Path:
    candidate = Path(path).expanduser() if path is not None else default_path
    if not candidate.is_absolute():
        if candidate.exists():
            return candidate.resolve()
        candidate = MODULE_DIR / candidate
    return candidate.resolve()


def save_image(image: np.ndarray, output_path: str | Path) -> Path:
    resolved_path = Path(output_path).expanduser()
    resolved_path.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(resolved_path), image):
        raise OSError(f"Failed to write output image: {resolved_path}")
    return resolved_path.resolve()


def load_image(image_source: str | Path | np.ndarray) -> np.ndarray:
    if isinstance(image_source, np.ndarray):
        if image_source.size == 0:
            raise ValueError("Input image array is empty.")
        return image_source.copy()

    if isinstance(image_source, (str, Path)):
        image_path = Path(image_source).expanduser()
        image = cv2.imread(str(image_path))
        if image is None:
            raise FileNotFoundError(f"Unable to read image: {image_path.resolve()}")
        return image

    raise TypeError("image_source must be a file path or a numpy.ndarray.")


class PoseInput:
    PIXEL_STD = 200

    def __init__(
        self,
        image_source: str | Path | np.ndarray,
        image_size: tuple[int, int] = (192, 256),
        conf: float = 0.3,
        detector: YOLO | None = None,
    ) -> None:
        self.image_size = np.array(image_size)
        self.aspect_ratio = image_size[0] / image_size[1]
        self.image = load_image(image_source)
        self.crops: list[dict[str, Any]] = []

        detector = detector or get_person_detector()
        results = detector.predict(
            self.image,
            classes=[0],
            conf=conf,
            device=get_detector_device(),
            verbose=False,
        )

        for box in results[0].boxes:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            score = box.conf[0].item()
            bbox_xywh = [x1, y1, x2 - x1, y2 - y1]

            center, scale = self._box2cs(*bbox_xywh)
            model_input = self._preprocess(self.image, center, scale)

            self.crops.append(
                {
                    "input": model_input,
                    "center": center,
                    "scale": scale,
                    "bbox": [x1, y1, x2, y2, score],
                }
            )

    def visualize(self, save_path: str | Path | None = None) -> np.ndarray:
        vis = self.image.copy()
        for i, crop in enumerate(self.crops):
            x1, y1, x2, y2, score = crop["bbox"]
            cv2.rectangle(vis, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
            cv2.putText(
                vis,
                f"#{i} {score:.2f}",
                (int(x1), int(y1) - 5),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 255, 0),
                2,
            )

        if save_path is not None:
            save_image(vis, save_path)

        return vis

    def _box2cs(self, x: float, y: float, w: float, h: float) -> tuple[np.ndarray, np.ndarray]:
        center = np.array([x + w * 0.5, y + h * 0.5], dtype=np.float32)
        if w > self.aspect_ratio * h:
            h = w / self.aspect_ratio
        elif w < self.aspect_ratio * h:
            w = h * self.aspect_ratio
        scale = np.array([w / self.PIXEL_STD, h / self.PIXEL_STD], dtype=np.float32)
        scale *= 1.25
        return center, scale

    def _preprocess(self, image: np.ndarray, center: np.ndarray, scale: np.ndarray) -> torch.Tensor:
        trans = self._get_affine_transform(center, scale, self.image_size)
        warped = cv2.warpAffine(
            image,
            trans,
            (int(self.image_size[0]), int(self.image_size[1])),
            flags=cv2.INTER_LINEAR,
        )
        model_input = warped.astype(np.float32) / 255.0
        model_input = model_input[:, :, ::-1].copy()
        model_input = (model_input - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
        return torch.from_numpy(model_input.transpose(2, 0, 1)).float().unsqueeze(0)

    def _get_affine_transform(
        self,
        center: np.ndarray,
        scale: np.ndarray,
        output_size: np.ndarray,
    ) -> np.ndarray:
        src_w = scale[0] * self.PIXEL_STD
        src_h = scale[1] * self.PIXEL_STD
        dst_w, dst_h = output_size[0], output_size[1]

        src = np.array(
            [
                center,
                center + [0, -src_h * 0.5],
                center + [src_w * 0.5, 0],
            ],
            dtype=np.float32,
        )

        dst = np.array(
            [
                [dst_w * 0.5, dst_h * 0.5],
                [dst_w * 0.5, 0],
                [dst_w, dst_h * 0.5],
            ],
            dtype=np.float32,
        )

        return cv2.getAffineTransform(src, dst)


def conv3x3(in_planes: int, out_planes: int, stride: int = 1) -> nn.Conv2d:
    return nn.Conv2d(
        in_planes,
        out_planes,
        kernel_size=3,
        stride=stride,
        padding=1,
        bias=False,
    )


class BasicBlock(nn.Module):
    expansion = 1

    def __init__(
        self,
        inplanes: int,
        planes: int,
        stride: int = 1,
        downsample: nn.Module | None = None,
    ) -> None:
        super().__init__()
        self.conv1 = conv3x3(inplanes, planes, stride)
        self.bn1 = nn.BatchNorm2d(planes, momentum=BN_MOMENTUM)
        self.relu = nn.ReLU(inplace=True)
        self.conv2 = conv3x3(planes, planes)
        self.bn2 = nn.BatchNorm2d(planes, momentum=BN_MOMENTUM)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        residual = x
        out = self.conv1(x)
        out = self.bn1(out)
        out = self.relu(out)
        out = self.conv2(out)
        out = self.bn2(out)
        if self.downsample is not None:
            residual = self.downsample(x)
        out += residual
        out = self.relu(out)
        return out


class Bottleneck(nn.Module):
    expansion = 4

    def __init__(
        self,
        inplanes: int,
        planes: int,
        stride: int = 1,
        downsample: nn.Module | None = None,
    ) -> None:
        super().__init__()
        self.conv1 = nn.Conv2d(inplanes, planes, kernel_size=1, bias=False)
        self.bn1 = nn.BatchNorm2d(planes, momentum=BN_MOMENTUM)
        self.conv2 = nn.Conv2d(planes, planes, kernel_size=3, stride=stride, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(planes, momentum=BN_MOMENTUM)
        self.conv3 = nn.Conv2d(planes, planes * self.expansion, kernel_size=1, bias=False)
        self.bn3 = nn.BatchNorm2d(planes * self.expansion, momentum=BN_MOMENTUM)
        self.relu = nn.ReLU(inplace=True)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        residual = x
        out = self.conv1(x)
        out = self.bn1(out)
        out = self.relu(out)
        out = self.conv2(out)
        out = self.bn2(out)
        out = self.relu(out)
        out = self.conv3(out)
        out = self.bn3(out)
        if self.downsample is not None:
            residual = self.downsample(x)
        out += residual
        out = self.relu(out)
        return out


class PoseResNet(nn.Module):
    def __init__(self, block: type[nn.Module], layers: list[int], cfg: "PoseConfig", **kwargs: Any) -> None:
        super().__init__()
        self.inplanes = 64
        extra = cfg.MODEL.EXTRA
        self.deconv_with_bias = extra.DECONV_WITH_BIAS

        self.conv1 = nn.Conv2d(3, 64, kernel_size=7, stride=2, padding=3, bias=False)
        self.bn1 = nn.BatchNorm2d(64, momentum=BN_MOMENTUM)
        self.relu = nn.ReLU(inplace=True)
        self.maxpool = nn.MaxPool2d(kernel_size=3, stride=2, padding=1)
        self.layer1 = self._make_layer(block, 64, layers[0])
        self.layer2 = self._make_layer(block, 128, layers[1], stride=2)
        self.layer3 = self._make_layer(block, 256, layers[2], stride=2)
        self.layer4 = self._make_layer(block, 512, layers[3], stride=2)

        self.deconv_layers = self._make_deconv_layer(
            extra.NUM_DECONV_LAYERS,
            extra.NUM_DECONV_FILTERS,
            extra.NUM_DECONV_KERNELS,
        )

        self.final_layer = nn.Conv2d(
            in_channels=extra.NUM_DECONV_FILTERS[-1],
            out_channels=cfg.MODEL.NUM_JOINTS,
            kernel_size=extra.FINAL_CONV_KERNEL,
            stride=1,
            padding=1 if extra.FINAL_CONV_KERNEL == 3 else 0,
        )

    def _make_layer(
        self,
        block: type[nn.Module],
        planes: int,
        blocks: int,
        stride: int = 1,
    ) -> nn.Sequential:
        downsample = None
        if stride != 1 or self.inplanes != planes * block.expansion:
            downsample = nn.Sequential(
                nn.Conv2d(
                    self.inplanes,
                    planes * block.expansion,
                    kernel_size=1,
                    stride=stride,
                    bias=False,
                ),
                nn.BatchNorm2d(planes * block.expansion, momentum=BN_MOMENTUM),
            )

        layers = [block(self.inplanes, planes, stride, downsample)]
        self.inplanes = planes * block.expansion
        for _ in range(1, blocks):
            layers.append(block(self.inplanes, planes))

        return nn.Sequential(*layers)

    def _get_deconv_cfg(self, deconv_kernel: int, index: int) -> tuple[int, int, int]:
        if deconv_kernel == 4:
            padding = 1
            output_padding = 0
        elif deconv_kernel == 3:
            padding = 1
            output_padding = 1
        elif deconv_kernel == 2:
            padding = 0
            output_padding = 0
        else:
            raise ValueError(f"Unsupported deconv kernel: {deconv_kernel}")
        return deconv_kernel, padding, output_padding

    def _make_deconv_layer(
        self,
        num_layers: int,
        num_filters: list[int],
        num_kernels: list[int],
    ) -> nn.Sequential:
        layers: list[nn.Module] = []
        for i in range(num_layers):
            kernel, padding, output_padding = self._get_deconv_cfg(num_kernels[i], i)
            planes = num_filters[i]
            layers.append(
                nn.ConvTranspose2d(
                    in_channels=self.inplanes,
                    out_channels=planes,
                    kernel_size=kernel,
                    stride=2,
                    padding=padding,
                    output_padding=output_padding,
                    bias=self.deconv_with_bias,
                )
            )
            layers.append(nn.BatchNorm2d(planes, momentum=BN_MOMENTUM))
            layers.append(nn.ReLU(inplace=True))
            self.inplanes = planes
        return nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)
        x = self.maxpool(x)

        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        x = self.layer4(x)

        x = self.deconv_layers(x)
        x = self.final_layer(x)
        return x


resnet_spec = {
    18: (BasicBlock, [2, 2, 2, 2]),
    34: (BasicBlock, [3, 4, 6, 3]),
    50: (Bottleneck, [3, 4, 6, 3]),
    101: (Bottleneck, [3, 4, 23, 3]),
    152: (Bottleneck, [3, 8, 36, 3]),
}


class PoseConfig:
    class MODEL:
        NUM_JOINTS = 17

        class EXTRA:
            NUM_LAYERS = 101
            DECONV_WITH_BIAS = False
            NUM_DECONV_LAYERS = 3
            NUM_DECONV_FILTERS = [256, 256, 256]
            NUM_DECONV_KERNELS = [4, 4, 4]
            FINAL_CONV_KERNEL = 1


def get_pose_net(cfg: PoseConfig, is_train: bool = True) -> PoseResNet:
    num_layers = cfg.MODEL.EXTRA.NUM_LAYERS
    block_class, layers = resnet_spec[num_layers]
    model = PoseResNet(block_class, layers, cfg)

    if is_train:
        if num_layers == 101:
            resnet_tv = models.resnet101(weights=models.ResNet101_Weights.DEFAULT)
        elif num_layers == 50:
            resnet_tv = models.resnet50(weights=models.ResNet50_Weights.DEFAULT)
        else:
            raise ValueError(f"Unsupported pretrained ResNet depth: {num_layers}")

        pretrained_state_dict = {
            key: value
            for key, value in resnet_tv.state_dict().items()
            if not key.startswith("fc")
        }
        model.load_state_dict(pretrained_state_dict, strict=False)

        for module in model.deconv_layers.modules():
            if isinstance(module, nn.ConvTranspose2d):
                nn.init.normal_(module.weight, std=0.001)
                if cfg.MODEL.EXTRA.DECONV_WITH_BIAS:
                    nn.init.constant_(module.bias, 0)
            elif isinstance(module, nn.BatchNorm2d):
                nn.init.constant_(module.weight, 1)
                nn.init.constant_(module.bias, 0)

        for module in model.final_layer.modules():
            if isinstance(module, nn.Conv2d):
                nn.init.normal_(module.weight, std=0.001)
                nn.init.constant_(module.bias, 0)

    return model


def get_person_detector(weights_path: str | Path | None = None) -> YOLO:
    global _PERSON_DETECTOR, _PERSON_DETECTOR_PATH

    resolved_weights_path = resolve_asset_path(weights_path, DEFAULT_DETECTOR_PATH)
    if not resolved_weights_path.exists():
        raise FileNotFoundError(f"YOLO weights not found: {resolved_weights_path}")

    if _PERSON_DETECTOR is None or _PERSON_DETECTOR_PATH != resolved_weights_path:
        _PERSON_DETECTOR = YOLO(str(resolved_weights_path))
        _PERSON_DETECTOR_PATH = resolved_weights_path

    return _PERSON_DETECTOR


def get_pose_model(checkpoint_path: str | Path | None = None) -> nn.Module:
    global _POSE_MODEL, _POSE_MODEL_PATH

    resolved_checkpoint_path = resolve_asset_path(checkpoint_path, DEFAULT_CHECKPOINT_PATH)
    if not resolved_checkpoint_path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {resolved_checkpoint_path}")

    if _POSE_MODEL is None or _POSE_MODEL_PATH != resolved_checkpoint_path:
        checkpoint = torch.load(str(resolved_checkpoint_path), map_location="cpu")
        state_dict = checkpoint["state_dict"] if isinstance(checkpoint, dict) and "state_dict" in checkpoint else checkpoint

        pose_model = get_pose_net(PoseConfig(), is_train=False)
        pose_model.load_state_dict(state_dict)
        pose_model.to(get_runtime_device())
        pose_model.eval()

        _POSE_MODEL = pose_model
        _POSE_MODEL_PATH = resolved_checkpoint_path

    return _POSE_MODEL


def decode_heatmaps(
    heatmaps: np.ndarray,
    center: np.ndarray,
    scale: np.ndarray,
    pixel_std: int = 200,
) -> tuple[np.ndarray, np.ndarray]:
    num_joints, height, width = heatmaps.shape
    coords = np.zeros((num_joints, 2), dtype=np.float32)
    scores = np.zeros(num_joints, dtype=np.float32)

    for joint_index in range(num_joints):
        heatmap = heatmaps[joint_index]
        scores[joint_index] = float(np.max(heatmap))
        idx = np.argmax(heatmap)
        px, py = idx % width, idx // width

        if 0 < px < width - 1 and 0 < py < height - 1:
            dx = heatmap[py, px + 1] - heatmap[py, px - 1]
            dy = heatmap[py + 1, px] - heatmap[py - 1, px]
            px += 0.25 * np.sign(dx)
            py += 0.25 * np.sign(dy)

        coords[joint_index] = [px, py]

    src_w = scale[0] * pixel_std
    src_h = scale[1] * pixel_std

    src = np.array(
        [
            center,
            center + [0, -src_h * 0.5],
            center + [src_w * 0.5, 0],
        ],
        dtype=np.float32,
    )

    dst = np.array(
        [
            [width * 0.5, height * 0.5],
            [width * 0.5, 0],
            [width, height * 0.5],
        ],
        dtype=np.float32,
    )

    inv_trans = cv2.getAffineTransform(dst, src)
    for joint_index in range(num_joints):
        point = np.array([coords[joint_index][0], coords[joint_index][1], 1.0])
        coords[joint_index] = inv_trans @ point

    return coords, scores


# COCO-17 keypoint indices used by the pose model
KP_R_SHOULDER = 6
KP_L_SHOULDER = 5
KP_R_HIP = 12
KP_L_HIP = 11
KP_R_KNEE = 14
KP_L_KNEE = 13
KP_R_ANKLE = 16
KP_L_ANKLE = 15

COCO_SKELETON_EDGES: list[tuple[int, int]] = [
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 4),
    (5, 6),
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (5, 11),
    (6, 12),
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
]


def _get_form_color(form_status: str | None) -> tuple[int, int, int]:
    if form_status == GOOD_FORM:
        return (0, 200, 0)
    if form_status == BAD_FORM:
        return (0, 0, 255)
    return (0, 215, 255)


def _get_form_label(form_status: str | None) -> str:
    if form_status == GOOD_FORM:
        return "GOOD"
    if form_status == BAD_FORM:
        return "BAD"
    return "UNKNOWN"


def _select_primary_detection_index(results: list[dict[str, Any]]) -> int | None:
    if not results:
        return None
    return max(
        range(len(results)),
        key=lambda index: float(results[index].get("bbox", [0, 0, 0, 0, 0])[-1]),
    )


def visualize_pose(
    image: str | Path | np.ndarray,
    results: list[dict[str, Any]],
    save_path: str | Path | None = None,
) -> np.ndarray:
    canvas = load_image(image)

    for result in results:
        keypoints = result["keypoints"]
        color = _get_form_color(result.get("form_status", UNKNOWN))
        status_label = _get_form_label(result.get("form_status", UNKNOWN))

        for joint_start, joint_end in COCO_SKELETON_EDGES:
            pt1 = tuple(keypoints[joint_start].astype(int))
            pt2 = tuple(keypoints[joint_end].astype(int))
            cv2.line(canvas, pt1, pt2, color, 2)

        for point in keypoints:
            cv2.circle(canvas, tuple(point.astype(int)), 4, color, -1)

        x1, y1, x2, y2, score = result["bbox"]
        cv2.rectangle(canvas, (int(x1), int(y1)), (int(x2), int(y2)), color, 2)
        cv2.putText(
            canvas,
            f"{status_label} {score:.2f}",
            (int(x1), max(0, int(y1) - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            color,
            1,
        )

        angles = result.get("angles")
        if angles is not None:
            side_used = result.get("side_used") or "right"
            if side_used == "left":
                knee_pt = tuple(keypoints[KP_L_KNEE].astype(int))
                hip_pt = tuple(keypoints[KP_L_HIP].astype(int))
            else:
                knee_pt = tuple(keypoints[KP_R_KNEE].astype(int))
                hip_pt = tuple(keypoints[KP_R_HIP].astype(int))
            cv2.putText(
                canvas, f"{angles['knee']:.0f}", knee_pt,
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2, cv2.LINE_AA,
            )
            cv2.putText(
                canvas, f"{angles['hip']:.0f}", hip_pt,
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2, cv2.LINE_AA,
            )

    if save_path is not None:
        save_image(canvas, save_path)

    return canvas


def serialize_pose_results(
    results: list[dict[str, Any]],
    image_width: int,
    image_height: int,
) -> list[dict[str, Any]]:
    width = max(int(image_width), 1)
    height = max(int(image_height), 1)
    serialized: list[dict[str, Any]] = []

    for result in results:
        raw_bbox = result.get("bbox", [0, 0, 0, 0, 0])
        x1, y1, x2, y2, score = raw_bbox
        keypoints = np.asarray(result.get("keypoints", []), dtype=np.float32)
        keypoint_scores = np.asarray(result.get("keypoint_scores", []), dtype=np.float32)
        angles = result.get("angles")

        serialized.append(
            {
                "bbox": {
                    "x1": round(float(x1), 3),
                    "y1": round(float(y1), 3),
                    "x2": round(float(x2), 3),
                    "y2": round(float(y2), 3),
                    "score": round(float(score), 4),
                },
                "bbox_normalized": {
                    "x1": round(float(x1) / width, 6),
                    "y1": round(float(y1) / height, 6),
                    "x2": round(float(x2) / width, 6),
                    "y2": round(float(y2) / height, 6),
                },
                "keypoints": [
                    [round(float(point[0]), 3), round(float(point[1]), 3)]
                    for point in keypoints
                ],
                "keypoints_normalized": [
                    [
                        round(float(point[0]) / width, 6),
                        round(float(point[1]) / height, 6),
                    ]
                    for point in keypoints
                ],
                "keypoint_scores": [
                    round(float(score), 6)
                    for score in keypoint_scores
                ],
                "angles": None if angles is None else {
                    key: round(float(value), 3)
                    for key, value in angles.items()
                },
                "form_status": result.get("form_status", UNKNOWN),
                "form_feedback": result.get("form_feedback"),
                "side_used": result.get("side_used"),
                "valid_pose": bool(result.get("valid_pose", angles is not None)),
            }
        )

    return serialized


def predict_pose_for_crops(
    crops: list[dict[str, Any]],
    checkpoint_path: str | Path | None = None,
) -> list[dict[str, Any]]:
    if not crops:
        return []

    pose_model = get_pose_model(checkpoint_path)
    model_device = next(pose_model.parameters()).device
    results: list[dict[str, Any]] = []

    for crop in crops:
        with torch.no_grad():
            output = pose_model(crop["input"].to(model_device))
            if isinstance(output, (list, tuple)):
                output = output[-1]

        heatmaps = output.squeeze(0).detach().cpu().numpy()
        keypoints, keypoint_scores = decode_heatmaps(heatmaps, crop["center"], crop["scale"])
        angle_info = compute_squat_angles_stable(keypoints, keypoint_scores)
        angles = None
        form_feedback = angle_info["reason"] or DEFAULT_INVALID_MESSAGE
        if angle_info["valid"]:
            angles = {
                "knee": round(float(angle_info["knee"]), 2),
                "hip": round(float(angle_info["hip"]), 2),
            }
            form_feedback = AWAITING_REP_MESSAGE

        results.append({
            "bbox": crop["bbox"],
            "keypoints": keypoints,
            "keypoint_scores": keypoint_scores,
            "angles": angles,
            "side_used": angle_info["side_used"],
            "valid_pose": bool(angle_info["valid"]),
            "form_status": UNKNOWN,
            "form_feedback": form_feedback,
        })

    return results


def _run_pose_pipeline(
    image_source: str | Path | np.ndarray,
    output_path: str | Path | None = None,
    *,
    checkpoint_path: str | Path | None = None,
    conf: float = 0.5,
) -> tuple[dict[str, Any], np.ndarray, list[dict[str, Any]]]:
    pose_input = PoseInput(image_source, conf=conf, detector=get_person_detector())
    results = predict_pose_for_crops(pose_input.crops, checkpoint_path=checkpoint_path)
    visualized_image = visualize_pose(pose_input.image, results)

    resolved_output_path: str | None = None
    if output_path is not None:
        resolved_output_path = str(save_image(visualized_image, output_path))

    response = {
        "success": True,
        "num_detections": len(results),
        "output_path": resolved_output_path,
        "image_size": {
            "width": int(pose_input.image.shape[1]),
            "height": int(pose_input.image.shape[0]),
        },
        "skeleton_edges": [list(edge) for edge in COCO_SKELETON_EDGES],
        "detections": serialize_pose_results(
            results,
            image_width=int(pose_input.image.shape[1]),
            image_height=int(pose_input.image.shape[0]),
        ),
    }
    return response, visualized_image, results


def run_pose_inference(
    image_path: str,
    output_path: str | None = None,
    *,
    checkpoint_path: str | Path | None = None,
    conf: float = 0.5,
) -> dict[str, Any]:
    try:
        result, _, _ = _run_pose_pipeline(
            image_path,
            output_path,
            checkpoint_path=checkpoint_path,
            conf=conf,
        )
        return result
    except Exception as exc:
        logger.exception("Pose inference failed for image: %s", image_path)
        return {
            "success": False,
            "num_detections": 0,
            "output_path": None,
            "error": str(exc),
        }


def run_camera_demo(
    camera_index: int = 0,
    *,
    checkpoint_path: str | Path | None = None,
    conf: float = 0.5,
    skip_frames: int = 2,
) -> None:
    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        raise RuntimeError(f"Unable to open camera {camera_index}")

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    for _ in range(5):
        cap.read()

    window_name = "Pose Estimation"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)

    frame_count = 0
    last_results: list[dict[str, Any]] = []
    last_fps = 0.0
    tracker = SquatFormTracker()
    last_form_info: dict[str, Any] = {
        "rep_count": 0,
        "stage": None,
        "status": UNKNOWN,
        "message": AWAITING_REP_MESSAGE,
        "knee_angle": None,
        "hip_angle": None,
        "knee_min": None,
        "hip_min": None,
        "standing_knee": None,
        "side_used": None,
        "valid_pose": False,
        "rep_completed": False,
        "last_rep_summary": None,
    }

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                continue

            frame_count += 1
            should_infer = frame_count % (skip_frames + 1) == 0
            fresh_results = False

            if should_infer:
                t0 = time.time()
                try:
                    _, _, results = _run_pose_pipeline(
                        frame,
                        checkpoint_path=checkpoint_path,
                        conf=conf,
                    )
                    last_results = results
                    fresh_results = True
                except Exception:
                    logger.exception("Pose inference failed for camera frame.")
                    results = last_results

                elapsed = max(time.time() - t0, 1e-6)
                last_fps = 1.0 / elapsed
            else:
                results = last_results
            
            if fresh_results:
                primary_index = _select_primary_detection_index(results)
                if primary_index is None:
                    last_form_info = tracker.update({
                        "valid": False,
                        "knee": None,
                        "hip": None,
                        "side_used": None,
                        "reason": DEFAULT_INVALID_MESSAGE,
                    })
                else:
                    primary_result = results[primary_index]
                    angle_info = compute_squat_angles_stable(
                        primary_result["keypoints"],
                        primary_result["keypoint_scores"],
                        preferred_side=tracker.preferred_side,
                    )
                    last_form_info = tracker.update(angle_info)

                    primary_result["angles"] = None
                    if last_form_info["valid_pose"]:
                        primary_result["angles"] = {
                            "knee": round(float(last_form_info["knee_angle"]), 2),
                            "hip": round(float(last_form_info["hip_angle"]), 2),
                        }
                    primary_result["side_used"] = last_form_info["side_used"]
                    primary_result["valid_pose"] = last_form_info["valid_pose"]
                    primary_result["form_status"] = last_form_info["status"]
                    primary_result["form_feedback"] = last_form_info["message"]
                    last_results = results

            vis = visualize_pose(frame, results) if results else frame.copy()

            knee_min_text = "-" if last_form_info["knee_min"] is None else f"{last_form_info['knee_min']:.1f}"
            hip_min_text = "-" if last_form_info["hip_min"] is None else f"{last_form_info['hip_min']:.1f}"
            cv2.rectangle(vis, (10, 55), (520, 225), (0, 0, 0), -1)
            cv2.putText(
                vis, f"Reps: {last_form_info['rep_count']}  Stage: {last_form_info['stage'] or '-'}",
                (20, 85), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2, cv2.LINE_AA,
            )
            cv2.putText(
                vis, f"Status: {last_form_info['status']}",
                (20, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.6, _get_form_color(last_form_info["status"]), 2, cv2.LINE_AA,
            )
            cv2.putText(
                vis, f"Message: {last_form_info['message']}",
                (20, 150), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2, cv2.LINE_AA,
            )
            cv2.putText(
                vis, f"Knee min: {knee_min_text}    Hip min: {hip_min_text}",
                (20, 180), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2, cv2.LINE_AA,
            )
            cv2.putText(
                vis, f"FPS: {last_fps:.1f}  Det: {len(results)}",
                (20, 210), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1, cv2.LINE_AA,
            )

            cv2.imshow(window_name, vis)
            key = cv2.waitKey(1) & 0xFF

            if key in (ord("q"), ord("Q")):
                break
            if key in (ord("s"), ord("S")):
                save_name = f"capture_{int(time.time())}.jpg"
                save_image(vis, save_name)
                print(f"[INFO] Saved: {save_name}")
            if key in (ord("p"), ord("P")):
                print("[INFO] Paused - press any key to continue.")
                cv2.waitKey(0)
    finally:
        cap.release()
        cv2.destroyAllWindows()


def main() -> None:
    parser = argparse.ArgumentParser(description="Pose inference")
    parser.add_argument("--image", type=str, default=None, help="Input image path")
    parser.add_argument("--camera", type=int, default=None, help="Camera index")
    parser.add_argument(
        "--checkpoint",
        type=str,
        default=str(DEFAULT_CHECKPOINT_PATH),
        help="Checkpoint path",
    )
    parser.add_argument("--save", type=str, default=None, help="Save visualization to file")
    parser.add_argument("--conf", type=float, default=0.5, help="YOLO person confidence threshold")
    args = parser.parse_args()

    if args.camera is not None or args.image is None:
        camera_index = args.camera if args.camera is not None else 0
        print(f"[INFO] Starting camera {camera_index}")
        run_camera_demo(
            camera_index=camera_index,
            checkpoint_path=args.checkpoint,
            conf=args.conf,
        )
        return

    output_path = args.save or "pose_result.jpg"
    result = run_pose_inference(
        args.image,
        output_path,
        checkpoint_path=args.checkpoint,
        conf=args.conf,
    )
    print(result)
    if not result["success"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
