# PBL5 - Status Snapshot

## Date

2026-04-21

## Current State

The technical core is working:

- Raspberry Pi agent can register, heartbeat, poll command, and execute replay/send flow.
- Backend worker can receive frames, run inference, and write result files.
- Result API can read processed sessions from `backend/workers/results/<session_key>`.

The MVP app orchestration is now partially real:

- `Connect` reads real backend health and real device status.
- `Capture` creates a real session and a real device command.
- `Processing` polls real command status and waits for real result session output.
- `Open Result` from `Processing` now opens the backend result session directly.

The first live Raspberry Pi CSI camera verification has now passed:

- verified on 2026-04-21
- command `7` completed successfully
- session `sess_000008` produced real worker outputs
- app `Result` opened the same processed backend session

## What Was Finished Recently

### Backend / Pi

- Added `session_key` as the public session id shared across app, Pi, and results.
- Locked command lifecycle to:

```text
pending -> acknowledged -> running -> completed | failed
```

- Added `executed_at` handling for command progress tracking.
- Added `GET /api/devices/{device_id}/commands/{command_id}` for mobile polling.
- Pi agent now supports:
  - replay-to-ZMQ capture
  - live camera photo capture
  - live camera video streaming
  - background capture jobs so `stop_recording` can stop an active run
  - Raspberry Pi CSI camera fallback through `Picamera2` when `/dev/video0` is not available but `rpicam/libcamera` is
  - an embedded live preview server that can expose `http://<pi-ip>:8081/preview/latest.jpg`
  - idle preview mode so the mobile app can show the Pi camera on the `Capture` screen before a run starts
- Raspberry Pi CSI camera photo capture has been manually verified end-to-end with:
  - Pi agent
  - backend command lifecycle
  - ZeroMQ worker inference
  - backend results
  - mobile `Result`

### Mobile App

- `Home` now reads live endpoint status and backend history instead of showing a fixed demo dashboard.
- `Connect` now describes truthful refresh/status-check behavior instead of fake pairing semantics.
- `Connect` no longer depends on fake connection state.
- `Capture` no longer creates only mock drafts for the MVP path.
- `Capture` image mode now sends `capture_photo` instead of forcing everything through `start_recording`.
- `Capture` video mode now sends `start_recording` when recording begins and `stop_recording` when the user stops, then moves to `Processing`.
- `Capture` can now embed the Raspberry Pi live preview feed directly on the capture screen instead of showing only a decorative placeholder.
- While recording, `Capture` now surfaces the newest processed inference frame from the active backend session on top of the live preview card.
- `Processing` is now backend-only for the default flow and no longer falls back to local mock finalize behavior.
- Result screens now share one backend result source of truth through `ResultApi`.
- `Result` route now opens backend sessions only instead of accepting demo result objects on the main path.
- `History` now opens the exact backend session via `session_key` instead of jumping to the generic results list.
- `Settings` now persist the configured server, Raspberry Pi, and capture defaults locally across app restarts.
- Removed the old `BackendResultsService` compatibility shim after cleaning imports.
- Fixed a Windows desktop polling bug where `ApiService` could close `HttpClient` before fully reading `/api/*` responses, which made the app report intermittent offline errors even while the backend was returning `200 OK`.
- Fixed a small result-screen layout overflow in the frame browser on desktop builds.
- Fixed backend result contract mismatch:

```text
result_json_path vs result_json_url
```

so the backend result screen can open sessions produced by the real flow.

## Closed In This Snapshot

### Results Layer

- The active result flow now uses `ResultApi` + `result_models.dart`.

### History

- `History` now reads canonical capture runs from `device_commands` instead of the old stub-only `jobs` flow.
- Backend `history/{history_id}` now exposes `command_id`, raw `command_status`, mapped history `status`, and attached result-session metadata.
- Mobile `History` now labels entries as real runs rather than fake jobs.
- Verified against local backend data:
  - latest command `7`
  - latest session `sess_000008`
  - `backend/workers/results/sess_000008` contains `frame_1_pose.jpg` and `frame_1_result.json`
  - this means the newest real run is eligible to appear in `History` and open the same session in `Result`

### Docs

- `backend_api_spec.md` now matches the current `session_id/session_key` result flow.
- `STACK_SETUP_AND_E2E_RUNBOOK.md` now acts as the current stack setup and manual verification guide for Phase 5.

## MVP Flow Today

```text
Home -> Connect -> Capture -> Processing -> Result
```

This flow is now backed by real API calls for the main orchestration path.

## Current Snapshot

The action items from the previous snapshot are now completed:

1. backend API documentation updated
2. backend history now follows the canonical `session + command + results` flow
3. old compatibility shim removed
4. legacy `/jobs` create path retired so it no longer creates fake processing runs
5. `Home`, `Connect`, and `Settings` now reflect the real runtime model more closely
6. the default `Processing -> Result` path is now backend-only instead of quietly dropping into mock finalize/result behavior
7. a current stack setup and end-to-end runbook now exists so the next verification pass can follow one documented path

## Optional Next Improvements

1. verify `video mode` end-to-end on the live Raspberry Pi camera path
2. surface `history/{history_id}.result` in a dedicated mobile detail screen if needed
3. rewrite or retire stale docs such as `OVERVIEW.md`
4. decide whether the remaining demo-only methods in `MockPoseTrackingService` should be kept for explicit demos or removed entirely

## Verification Done

- `python -m compileall backend/app`
- `python -m compileall backend/pi_agent`
- local backend database check confirmed newest canonical run:
  - command `7`
  - session `sess_000008`
  - command status `completed`
  - result files exist under `backend/workers/results/sess_000008`
- `dart analyze` was attempted for the modified Flutter files, but it timed out in this environment and still needs a clean rerun locally.
