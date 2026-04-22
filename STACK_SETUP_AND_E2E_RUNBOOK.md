# PoseTrack Stack Setup And E2E Runbook

## 1. Purpose

This file is the current setup guide for running the real PoseTrack stack and
verifying the end-to-end flow:

```text
mobile app -> backend -> Pi agent -> ZeroMQ worker -> results -> history
```

Use this file when you need to:

- boot the stack from scratch
- run the first real manual verification
- collect evidence for pass/fail
- continue Phase 5 work from `PROJECT_COMPLETION_PLAN.md`
- verify the embedded Raspberry Pi live preview on the `Capture` screen

Current verified milestone:

- On 2026-04-21, a real Raspberry Pi CSI camera image run passed end-to-end.
- Verified canonical run:
  - command id `7`
  - session key `sess_000008`
  - result files written under `backend/workers/results/sess_000008`
  - app opened the processed session successfully from `Result`

## 2. Source Of Truth Order

When docs conflict, trust them in this order:

1. `PROJECT_COMPLETION_PLAN.md`
2. `status.md`
3. `STACK_SETUP_AND_E2E_RUNBOOK.md`
4. `backend/backend_api_spec.md`

Do not use `OVERVIEW.md` as the setup guide. It is stale.

## 3. Current Canonical Flow

The current real orchestration path is:

```text
Mobile App
-> POST /api/session/create
-> GET /api/devices
-> POST /api/devices/{device_id}/commands

Pi Agent
-> GET /api/devices/{device_id}/commands/pending
-> PATCH /api/devices/{device_id}/commands/{command_id}/status

ZeroMQ Worker
-> writes backend/workers/results/<session_key>

Mobile App
-> GET /api/devices/{device_id}/commands/{command_id}
-> GET /api/results/{session_key}
-> GET /api/history
```

`session_key` is the shared public id between app, Pi payloads, worker output,
history, and result APIs.

The current capture UX can also embed a lightweight live preview feed directly
from the Pi agent:

```text
Capture screen -> http://<pi-ip>:8081/preview/latest.jpg
```

This preview is served directly by the Pi agent and is separate from the
backend REST API.

## 4. What This Runbook Should Prove

A successful verification run proves all of the following:

- the mobile app can reach the backend
- the Pi agent can register, heartbeat, and claim commands
- the worker can receive frames from the Pi agent
- the model can write processed output files
- the result API can read those files
- the history API points back to the same real session run

## 5. Prerequisites

Before starting, confirm these are true:

- Backend host and Raspberry Pi are on the same network.
- The mobile device can reach `http://<backend-host>:8002`.
- The Raspberry Pi can reach `tcp://<backend-host>:5555`.
- Python is available on the backend/worker machine.
- Flutter SDK is available for the mobile app machine.
- Model assets exist:
  - `core_model/checkpoint/checkpoint_manual_epoch39.pth`
  - `core_model/yolov8n.pt`
- Ports `8002` and `5555` are free on the backend/worker machine.

Important current caveat:

- `backend/pi_agent/pi_agent.py` imports `requests`, but
  `backend/requirements.txt` does not currently install it. Install `requests`
  explicitly for the Pi agent runtime until the requirements files are cleaned
  up.

## 6. Recommended Runtime Layout

Use one machine for:

- FastAPI backend
- ZeroMQ worker
- model inference

Use the Raspberry Pi for:

- Pi agent
- optional real camera capture

Use a phone or Flutter desktop build for:

- mobile app UI

## 7. Python Environment Setup

### Backend + Worker Host

From the repo root:

```powershell
python -m venv .venv
.\.venv\Scripts\pip.exe install -r backend\requirements.txt
.\.venv\Scripts\pip.exe install -r core_model\requirements.txt
.\.venv\Scripts\pip.exe install requests
```

This single environment is enough for:

- FastAPI backend
- ZeroMQ worker
- local Pi-agent simulation, if needed

### Raspberry Pi Agent Runtime

If the Pi runs its own Python environment, install at least:

```bash
python3 -m venv ~/posetrack-venv
source ~/posetrack-venv/bin/activate
pip install requests pyzmq opencv-python
```

If the Pi is also running backend code from this repo, installing
`backend/requirements.txt` plus `requests` is the safer option.

For Raspberry Pi CSI cameras that are exposed through `rpicam/libcamera` rather
than `/dev/video0`, also install:

```bash
sudo apt update
sudo apt install -y python3-picamera2 rpicam-apps v4l-utils
```

The current Pi agent will try `Picamera2` first for live camera capture, then
fall back to OpenCV/V4L2 if needed.

For the verified CSI camera path, prefer running the Pi agent with the system
Python so `Picamera2` is available:

```bash
/usr/bin/python3 pi_agent.py --backend http://<backend-host>:8002 --device-name "Raspberry Pi 4B" --device-code pi-001
```

## 8. Flutter Setup

From `mobile_app`:

```powershell
flutter pub get
```

The app uses these compile-time defaults:

- `POSETRACK_BACKEND_ADDRESS`
- `POSETRACK_PI_DEVICE_CODE`
- `POSETRACK_PI_FRAMES_DIR`
- `POSETRACK_ZMQ_PORT`

Recommended first-run launch:

```powershell
flutter run --dart-define=POSETRACK_BACKEND_ADDRESS=<backend-host>:8002 --dart-define=POSETRACK_PI_DEVICE_CODE=pi-001 --dart-define=POSETRACK_PI_FRAMES_DIR=/home/pi/posetrack/frames
```

Notes:

- Backend address should be the real LAN IP that both mobile and Pi can reach.
- `POSETRACK_PI_FRAMES_DIR` matters because the app sends that path inside the
  command payload.
- After the app boots, confirm Settings still match the real backend host.

## 9. Replay Mode Versus Live Camera

Current app payloads send:

- `capture_source: auto`
- `frames_dir: <POSETRACK_PI_FRAMES_DIR>`

The Pi agent resolves `auto` like this:

- use replay mode if `frames_dir` exists and contains image files
- otherwise use the real camera path

This means:

- for the first reproducible verification, replay mode is recommended
- to verify live camera, make sure the replay directory is missing or empty

## 10. Preflight Checklist

Run this checklist before opening the app:

1. Backend host IP is known.
2. Worker machine has the model assets in `core_model`.
3. Raspberry Pi can ping or otherwise reach the backend host.
4. If testing replay mode, the Pi replay directory contains `.jpg`, `.jpeg`,
   or `.png` frames.
5. If testing live camera mode, the Pi camera is connected and OpenCV can open
   it.
6. No previous worker process is still bound to port `5555`.
7. No previous backend process is still bound to port `8002`.

## 11. Start The Stack

Open four terminals.

### Terminal 1: FastAPI Backend

From `backend`:

```powershell
    .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
```

If your virtual environment lives somewhere else, keep the same `uvicorn`
command and replace only the interpreter path. For example:

```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
```

The important part is to run it from the `backend` directory so `app.main:app`
resolves correctly.

Expected signals:

- backend starts without import errors
- `GET /api/health` returns success
- SQLite file is created for the backend working directory if needed

### Terminal 2: ZeroMQ Worker

From the repo root:

```powershell
.\.venv\Scripts\python.exe backend\workers\zmq_worker.py
```

Expected signal:

- log includes `Started and listening on tcp://*:5555`

### Terminal 3: Pi Agent

From the repo root on the Pi, or from the Pi workspace copy:

```bash
python3 backend/pi_agent/pi_agent.py --backend http://<backend-host>:8002 --device-name "Raspberry Pi 4B" --device-code pi-001
```

By default, the Pi agent now also starts a lightweight preview server on:

```text
http://<pi-ip>:8081/preview/latest.jpg
```

Use `--preview-port 0` only if you intentionally want to disable embedded live
preview in the mobile app.

If the Pi uses a CSI camera through `Picamera2`, prefer:

```bash
/usr/bin/python3 backend/pi_agent/pi_agent.py --backend http://<backend-host>:8002 --device-name "Raspberry Pi 4B" --device-code pi-001
```

Expected signals:

- device registers or reuses an existing `device_id`
- heartbeat logs repeat every poll cycle
- no `ConnectionError` against the backend

### Terminal 4: Mobile App

From `mobile_app`:

```powershell
flutter run --dart-define=POSETRACK_BACKEND_ADDRESS=<backend-host>:8002 --dart-define=POSETRACK_PI_DEVICE_CODE=pi-001 --dart-define=POSETRACK_PI_FRAMES_DIR=/home/pi/posetrack/frames
```

Expected signals in the UI:

- `Connect` shows backend reachable
- `Connect` shows Raspberry Pi online after heartbeat
- `Capture` shows the pipeline as ready

## 12. Quick API Sanity Checks

These are optional, but useful before the first capture.

```powershell
Invoke-RestMethod http://<backend-host>:8002/api/health
Invoke-RestMethod http://<backend-host>:8002/api/devices
Invoke-RestMethod http://<backend-host>:8002/api/history
Invoke-RestMethod http://<backend-host>:8002/api/results/sessions
```

Expected:

- health succeeds
- device list contains the Pi device code
- history may be empty before the first real run
- result sessions may be empty before the first real run

## 13. Scenario A: Replay Photo Verification

This is the recommended first pass because it avoids live camera variables.

### Preconditions

- Pi replay directory contains at least one image.
- Worker is already running.
- Mobile app points to the correct backend host.

### Steps

1. Open `Connect` and wait until backend and Pi both look healthy.
2. Open `Capture`.
3. Select image mode.
4. Start capture.
5. Let `Processing` finish and open `Result`.

### Expected Backend Behavior

- a new session is created
- a `capture_photo` command is created
- Pi agent claims the command and moves it through:

```text
pending -> acknowledged -> running -> completed
```

- worker logs at least one received frame
- worker writes:
  - `backend/workers/results/<session_key>/frame_1_pose.jpg`
  - `backend/workers/results/<session_key>/frame_1_result.json`

### Expected App Behavior

- `Processing` waits for the real backend result session
- `Result` opens that exact `session_key`
- `History` shows a new run pointing to the same `session_key`

### API Checks After Pass

```powershell
Invoke-RestMethod http://<backend-host>:8002/api/history
Invoke-RestMethod http://<backend-host>:8002/api/results/<session_key>
Invoke-RestMethod http://<backend-host>:8002/api/history/<history_id>
```

Pass criteria:

- the newest history item matches the same `session_key`
- `/api/results/<session_key>` returns at least one frame
- history detail `result.frame_count` is at least `1`

## 14. Scenario B: Replay Or Live Video Verification

Run this after Scenario A passes.

### Steps

1. Open `Capture`.
2. Select video mode.
3. Press `Start Recording`.
4. Wait a few seconds.
5. Press `Stop Recording`.
6. Let `Processing` finish and open `Result`.

### Expected Runtime Behavior

- app creates a `start_recording` command when recording begins
- app creates a `stop_recording` command when recording stops
- Pi agent starts capture in a background thread
- `stop_recording` stops the active capture cleanly
- worker receives multiple frames
- result session contains multiple frame outputs

Pass criteria:

- result session contains more than one frame
- `History` shows the `start_recording` run as `done`
- app can open the processed session from both `Processing` and `History`

## 15. Scenario C: Live Camera Verification

Run this only after replay mode is stable.

Preconditions:

- replay directory is missing or empty
- Pi camera is physically connected and readable through `rpicam/libcamera`
- `python3-picamera2` is installed on the Pi
- if using a CSI camera, the Pi agent is started with `/usr/bin/python3` when
  needed so `Picamera2` is available

Expected differences:

- Pi logs should mention `camera` capture instead of `replay`
- for CSI cameras, Pi logs should mention `Picamera2` capture success rather
  than falling straight to OpenCV
- worker output should still land in the same
  `backend/workers/results/<session_key>` structure

Current verified result:

- image mode with a real Raspberry Pi CSI camera has passed on 2026-04-21
- `capture_photo` completed through the canonical command flow
- the worker wrote `frame_1_pose.jpg` and `frame_1_result.json`
- the app opened the same processed session successfully
- video mode still needs its own full live-camera verification pass

## 16. Evidence To Record For Each Real Run

Capture these values in the test notes:

- date and operator
- backend host IP
- Pi device code
- session id
- session key
- command id
- history id
- capture mode: image or video
- source used by Pi: replay or camera
- whether result frame count was correct
- whether `History` and `Result` matched the same session

## 17. Common Failure Modes

### Backend healthy, Pi offline

Likely causes:

- Pi agent is not running
- Pi agent cannot reach `http://<backend-host>:8002`
- device registered under an unexpected device code

### Pi online, processing never finishes

Likely causes:

- worker is not running
- Pi cannot reach `tcp://<backend-host>:5555`
- worker crashed during inference
- model dependencies or model assets are missing

### Worker starts but results never appear

Likely causes:

- ZMQ messages are not reaching the worker
- `core_model` dependencies are incomplete
- checkpoint or detector files are missing

### Replay was expected, but camera path was used

Likely causes:

- replay directory path in the command payload does not exist on the Pi
- replay directory is empty
- app was launched with the wrong `POSETRACK_PI_FRAMES_DIR`

### Pi agent crashes on startup with import errors

Likely causes:

- `requests` was not installed
- OpenCV is missing in the Pi runtime
- the agent is being run from an environment without the needed packages

### Worker fails with `Address in use`

Likely cause:

- another worker process is already bound to port `5555`

## 18. After The First Successful Full Run

When one full real run passes, do these follow-up actions:

1. update `status.md` with the exact date and what was verified
2. mark Phase 5 progress in `PROJECT_COMPLETION_PLAN.md`
3. save the verified startup commands if they differ from this runbook
4. rewrite or retire `OVERVIEW.md`
5. decide whether remaining demo-only helpers should stay or be removed

## 19. Minimum Exit Criteria For Phase 5

Phase 5 is not complete until:

- at least one image run passes end-to-end
- at least one video run passes end-to-end
- the verified steps are documented in this file
- stale docs no longer contradict the canonical flow

flutter run -d windows --dart-define=POSETRACK_BACKEND_ADDRESS=172.20.10.5:8002
D:\TaiLieuNam3_DUT\HKII\PBL5\PBL5\backend> .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
PS D:\TaiLieuNam3_DUT\HKII\PBL5\PBL5> .\backend\.venv\Scripts\python.exe backend\workers\zmq_worker.py 