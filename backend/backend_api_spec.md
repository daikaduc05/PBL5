# PoseTrack Backend API Specification

## 1. Overview

### Base URL

```text
http://<backend-host>:8002/api
```

### Standard response shape

Most REST endpoints return:

```json
{
  "success": true,
  "message": "string",
  "data": {}
}
```

### MVP orchestration flow

The current MVP flow is:

```text
Mobile App
  -> POST /session/create
  -> GET /devices
  -> POST /devices/{device_id}/commands
Pi Agent
  -> GET /devices/{device_id}/commands/pending
  -> PATCH /devices/{device_id}/commands/{command_id}/status
Worker
  -> writes backend/workers/results/<session_key>
Mobile App
  -> GET /devices/{device_id}/commands/{command_id}
  -> GET /results/{session_key}
  -> GET /results/{session_key}/{frame_id}
```

`session_key` is the public session identifier shared across:

- mobile app
- Pi agent payloads
- worker result directories
- result/history APIs

## 2. Health API

### `GET /health`

Check whether the backend is reachable.

**Response**

```json
{
  "success": true,
  "message": "Backend is running",
  "data": null
}
```

## 3. Session API

### `POST /session/create`

Create a new session for a capture run.

**Response**

```json
{
  "success": true,
  "message": "Session created successfully",
  "data": {
    "session_id": 12,
    "session_key": "session_0012",
    "token": "abc123xyz",
    "status": "active",
    "created_at": "2026-04-20T10:15:30.000000"
  }
}
```

## 4. Device API

### `GET /devices`

List registered devices and their resolved status.

**Response**

```json
{
  "success": true,
  "message": "Devices retrieved successfully",
  "data": [
    {
      "id": 1,
      "device_name": "Raspberry Pi 4",
      "device_code": "pi-001",
      "status": "online",
      "last_seen": "2026-04-20T10:16:11.000000",
      "created_at": "2026-04-20T09:58:04.000000"
    }
  ]
}
```

### `POST /devices/register`

Register a Raspberry Pi device.

**Request**

```json
{
  "device_name": "Raspberry Pi 4",
  "device_code": "pi-001"
}
```

**Response**

```json
{
  "success": true,
  "message": "Device registered successfully",
  "data": {
    "device_id": 1,
    "auth_token": "device_token",
    "status": "online"
  }
}
```

### `POST /devices/{device_id}/heartbeat`

Update device heartbeat status.

**Request**

```json
{
  "status": "online"
}
```

**Response**

```json
{
  "success": true,
  "message": "Heartbeat updated",
  "data": {
    "device_id": 1,
    "status": "online",
    "last_seen": "2026-04-20T10:16:11.000000"
  }
}
```

## 5. Command API

Command lifecycle currently follows:

```text
pending -> acknowledged -> running -> completed | failed
```

### `POST /devices/{device_id}/commands`

Create a command for the Pi agent.

**Request**

```json
{
  "session_id": 12,
  "command_type": "start_recording",
  "command_payload": {
    "session_id": 12,
    "session_key": "session_0012",
    "frames_dir": "/home/pi/posetrack/frames",
    "zmq_host": "192.168.1.10",
    "zmq_port": 5555,
    "capture_source": "auto",
    "capture_mode": "video",
    "target_duration_seconds": 10,
    "actual_duration_seconds": 10,
    "source": "mobile_app"
  }
}
```

**Response**

```json
{
  "success": true,
  "message": "Command created successfully",
  "data": {
    "command_id": 33,
    "session_id": 12,
    "session_key": "session_0012",
    "status": "pending"
  }
}
```

### `GET /devices/{device_id}/commands/pending`

Pi agent polling endpoint. The backend claims the oldest available command and
returns it as `acknowledged`.

**Response with command**

```json
{
  "success": true,
  "message": "Command claimed successfully",
  "data": {
    "command_id": 33,
    "session_id": 12,
    "session_key": "session_0012",
    "command_type": "start_recording",
    "command_payload": "{\"session_id\":12,\"session_key\":\"session_0012\",\"frames_dir\":\"/home/pi/posetrack/frames\"}",
    "status": "acknowledged",
    "created_at": "2026-04-20T10:17:02.000000",
    "executed_at": "2026-04-20T10:17:05.000000"
  }
}
```

**Response when no command is available**

```json
{
  "success": true,
  "message": "No pending commands",
  "data": null
}
```

### `GET /devices/{device_id}/commands/{command_id}`

Read the latest state of one command.

**Response**

```json
{
  "success": true,
  "message": "Command status retrieved successfully",
  "data": {
    "command_id": 33,
    "session_id": 12,
    "session_key": "session_0012",
    "status": "running",
    "executed_at": "2026-04-20T10:17:05.000000"
  }
}
```

### `PATCH /devices/{device_id}/commands/{command_id}/status`

Update command state from the Pi agent.

**Request**

```json
{
  "status": "completed"
}
```

### Capture source behavior

The Pi agent now resolves capture source like this:

- `capture_source = "replay"`: force replay from `frames_dir`
- `capture_source = "camera"`: force live camera capture
- `capture_source = "auto"`: use replay if `frames_dir` exists and contains
  frames, otherwise use the live camera

`capture_photo` and `start_recording` both follow this rule.

**Response**

```json
{
  "success": true,
  "message": "Command status updated successfully",
  "data": {
    "command_id": 33,
    "session_id": 12,
    "session_key": "session_0012",
    "status": "completed",
    "executed_at": "2026-04-20T10:17:05.000000"
  }
}
```

## 6. Media API

### `POST /media/upload`

Upload media from the mobile app or Raspberry Pi.

**Form fields**

| Field | Type | Example |
| --- | --- | --- |
| `file` | file | `image.jpg` |
| `source_type` | string | `app` / `pi` |
| `media_type` | string | `image` / `video` |
| `session_id` | int | `12` |
| `device_id` | int | `1` |

**Response**

```json
{
  "success": true,
  "message": "Media uploaded successfully",
  "data": {
    "media_id": 5,
    "file_name": "capture.jpg",
    "file_path": "storage/uploads/capture.jpg",
    "media_type": "image"
  }
}
```

## 7. Job API

The `/jobs` endpoints are now legacy compatibility endpoints. They are not the
canonical execution model.

### `POST /jobs`

This endpoint is retired and no longer creates a stub processing record.

**Request**

```json
{
  "media_id": 5,
  "session_id": 12,
  "device_id": 1,
  "task_type": "image_pose"
}
```

**Response**

```json
{
  "success": false,
  "message": "The /jobs create endpoint is retired. Use POST /api/session/create and POST /api/devices/{device_id}/commands instead.",
  "data": {
    "session_id": 12,
    "media_id": 5,
    "device_id": 1,
    "task_type": "image_pose"
  }
}
```

### `GET /jobs/{job_id}`

Read a legacy-compatible status view backed by the canonical command/history
record when `job_id` matches a capture command id.

**Response**

```json
{
  "success": true,
  "message": "Legacy job status retrieved from canonical command history",
  "data": {
    "job_id": 33,
    "command_id": 33,
    "session_id": 12,
    "session_key": "session_0012",
    "media_id": null,
    "device_id": 1,
    "command_type": "start_recording",
    "command_status": "completed",
    "task_type": "video_pose",
    "status": "done",
    "progress": 100,
    "error_message": null,
    "created_at": "2026-04-20T10:20:00.000000",
    "started_at": "2026-04-20T10:20:02.000000",
    "finished_at": "2026-04-20T10:20:07.000000"
  }
}
```

## 8. Result API

Results are indexed by `session_key`, not by `job_id`.

### `GET /results/sessions`

List all processed result session ids available under
`backend/workers/results`.

**Response**

```json
{
  "sessions": [
    "session_0012",
    "session_0011"
  ]
}
```

### `GET /results/{session_key}`

List processed frames for one result session.

**Response**

```json
{
  "session_id": "session_0012",
  "frames": [
    {
      "frame_id": 1,
      "pose_image_path": "backend/workers/results/session_0012/frame_1_pose.jpg",
      "result_json_path": "backend/workers/results/session_0012/frame_1_result.json",
      "pose_image_url": "/static/results/session_0012/frame_1_pose.jpg"
    }
  ]
}
```

### `GET /results/{session_key}/{frame_id}`

Read the worker JSON result for one frame.

**Response**

```json
{
  "frame_id": 1,
  "success": true,
  "num_detections": 1,
  "pose_output_path": "backend/workers/results/session_0012/frame_1_pose.jpg",
  "inference_result": {
    "success": true,
    "num_detections": 1,
    "primary_detection_index": 0,
    "form_tracking": {
      "rep_count": 3,
      "stage": "up",
      "status": "GOOD_FORM",
      "message": "GOOD FORM",
      "knee_angle": 171.3,
      "hip_angle": 162.4,
      "knee_min": 95.7,
      "hip_min": 57.8,
      "standing_knee": 171.3,
      "side_used": "right",
      "valid_pose": true,
      "rep_completed": true,
      "last_rep_summary": {
        "rep_count": 3,
        "status": "GOOD_FORM",
        "message": "GOOD FORM",
        "reasons": [],
        "primary_reason": null,
        "knee_min": 95.7,
        "hip_min": 57.8,
        "standing_knee": 171.3,
        "side_used": "right"
      }
    },
    "detections": [
      {
        "bbox": {
          "x1": 233.1,
          "y1": 41.8,
          "x2": 418.4,
          "y2": 470.2,
          "score": 0.94
        },
        "angles": {
          "knee": 171.3,
          "hip": 162.4
        },
        "form_status": "GOOD_FORM",
        "form_feedback": "GOOD FORM",
        "side_used": "right",
        "valid_pose": true,
        "keypoint_scores": [0.92, 0.91, 0.94]
      }
    ],
    "error": null
  }
}
```

## 9. History API

### `GET /history`

List canonical capture history entries in reverse chronological order.

History is now backed by `device_commands` for real app-started runs, not by
the old stub-only `/jobs` execution path.

**Response**

```json
{
  "success": true,
  "message": "History retrieved successfully",
  "data": [
    {
      "history_id": 33,
      "command_id": 33,
      "device_id": 1,
      "session_id": 12,
      "session_key": "session_0012",
      "command_type": "start_recording",
      "command_status": "completed",
      "status": "done",
      "task_type": "video_pose",
      "progress": 100,
      "created_at": "2026-04-20T10:20:00.000000"
    }
  ]
}
```

### `GET /history/{history_id}`

Read detail for one capture history entry plus attached result-session metadata.

**Response**

```json
{
  "success": true,
  "message": "History entry retrieved successfully",
  "data": {
    "history_id": 33,
    "command_id": 33,
    "device_id": 1,
    "session_id": 12,
    "session_key": "session_0012",
    "command_type": "start_recording",
    "command_status": "completed",
    "status": "done",
    "task_type": "video_pose",
    "progress": 100,
    "error_message": null,
    "created_at": "2026-04-20T10:20:00.000000",
    "started_at": "2026-04-20T10:20:02.000000",
    "finished_at": "2026-04-20T10:20:07.000000",
    "result": {
      "session_id": "session_0012",
      "session_exists": true,
      "result_session_url": "/api/results/session_0012",
      "frame_count": 16,
      "pose_ready_count": 16,
      "result_ready_count": 16,
      "updated_at": "2026-04-20T10:20:07+00:00",
      "latest_frame": {
        "frame_id": 16,
        "pose_image_path": "backend/workers/results/session_0012/frame_16_pose.jpg",
        "result_json_path": "backend/workers/results/session_0012/frame_16_result.json",
        "pose_image_url": "/static/results/session_0012/frame_16_pose.jpg"
      },
      "latest_pose_frame": {
        "frame_id": 16,
        "pose_image_path": "backend/workers/results/session_0012/frame_16_pose.jpg",
        "result_json_path": "backend/workers/results/session_0012/frame_16_result.json",
        "pose_image_url": "/static/results/session_0012/frame_16_pose.jpg"
      },
      "latest_result_frame": {
        "frame_id": 16,
        "pose_image_path": "backend/workers/results/session_0012/frame_16_pose.jpg",
        "result_json_path": "backend/workers/results/session_0012/frame_16_result.json",
        "pose_image_url": "/static/results/session_0012/frame_16_pose.jpg"
      }
    }
  }
}
```

## 10. Important Notes

- The current MVP app should use `session + command + results` as the primary
  orchestration path.
- `/history` now tracks canonical capture runs through `device_commands`.
- `POST /jobs` is retired and no longer creates a fake processing pipeline.
- `GET /jobs/{job_id}` is a legacy read-only compatibility view over the
  canonical command/history model.
- Result files are served from:

```text
/static/results/<session_key>/<frame>_pose.jpg
```

- Result JSON files are read from:

```text
backend/workers/results/<session_key>/frame_<id>_result.json
```

- Polling is used throughout the MVP. No WebSocket flow is required for the
  current app path.
