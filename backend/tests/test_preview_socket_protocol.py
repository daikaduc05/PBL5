import importlib.util
import json
import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PREVIEW_MODULE_PATH = PROJECT_ROOT / "backend" / "pi_agent" / "pi_preview.py"

spec = importlib.util.spec_from_file_location("test_pi_preview_module", PREVIEW_MODULE_PATH)
assert spec is not None and spec.loader is not None
pi_preview = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = pi_preview
spec.loader.exec_module(pi_preview)


class PreviewSocketProtocolTests(unittest.TestCase):
    def test_normalize_preview_metadata_applies_defaults(self) -> None:
        metadata = pi_preview._normalize_preview_metadata(None, 123.45)

        self.assertIsNone(metadata["frame_id"])
        self.assertEqual(metadata["timestamp"], 123.45)
        self.assertIsNone(metadata["session_id"])
        self.assertEqual(metadata["mode"], "unknown")

    def test_normalize_preview_metadata_coerces_supported_types(self) -> None:
        metadata = pi_preview._normalize_preview_metadata(
            {
                "frame_id": "7",
                "timestamp": "12.5",
                "session_id": 42,
                "mode": "recording_preview",
            },
            0.0,
        )

        self.assertEqual(metadata["frame_id"], 7)
        self.assertEqual(metadata["timestamp"], 12.5)
        self.assertEqual(metadata["session_id"], "42")
        self.assertEqual(metadata["mode"], "recording_preview")

    def test_build_preview_socket_packet_encodes_metadata_and_image_bytes(self) -> None:
        packet = pi_preview._build_preview_socket_packet(
            b"\xff\xd8\xff",
            {
                "frame_id": 9,
                "timestamp": 77.0,
                "session_id": "sess_123",
                "mode": "recording_preview",
            },
        )

        metadata_length = int.from_bytes(packet[0:4], byteorder="big", signed=False)
        metadata_start = 4
        metadata_end = metadata_start + metadata_length
        metadata = json.loads(packet[metadata_start:metadata_end].decode("utf-8"))

        image_length = int.from_bytes(packet[metadata_end:metadata_end + 4], byteorder="big", signed=False)
        image_bytes = packet[metadata_end + 4:metadata_end + 4 + image_length]

        self.assertEqual(
            metadata,
            {
                "frame_id": 9,
                "timestamp": 77.0,
                "session_id": "sess_123",
                "mode": "recording_preview",
            },
        )
        self.assertEqual(image_length, 3)
        self.assertEqual(image_bytes, b"\xff\xd8\xff")

    def test_preview_frame_store_keeps_normalized_metadata_in_snapshot(self) -> None:
        store = pi_preview.PreviewFrameStore()

        snapshot = store.update(
            frame_bytes=b"frame",
            metadata={
                "frame_id": "11",
                "session_id": "sess_store",
                "mode": "idle_preview",
            },
        )

        self.assertEqual(snapshot.frame_bytes, b"frame")
        self.assertEqual(snapshot.metadata["frame_id"], 11)
        self.assertEqual(snapshot.metadata["session_id"], "sess_store")
        self.assertEqual(snapshot.metadata["mode"], "idle_preview")
        self.assertIsNotNone(snapshot.metadata["timestamp"])


if __name__ == "__main__":
    unittest.main()
