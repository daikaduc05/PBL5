# PBL5 - Status Snapshot

## Date

2026-04-20

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

## What Was Finished Recently

### Backend / Pi

- Added `session_key` as the public session id shared across app, Pi, and results.
- Locked command lifecycle to:

```text
pending -> acknowledged -> running -> completed | failed
```

- Added `executed_at` handling for command progress tracking.
- Added `GET /api/devices/{device_id}/commands/{command_id}` for mobile polling.

### Mobile App

- `Connect` no longer depends on fake connection state.
- `Capture` no longer creates only mock drafts for the MVP path.
- `Processing` no longer finishes by mock finalize when backend ids are available.
- Fixed backend result contract mismatch:

```text
result_json_path vs result_json_url
```

so the backend result screen can open sessions produced by the real flow.

## What Is Still Not Done

### Results Layer

- The app still has two result clients:
  - `ResultApi`
  - `BackendResultsService`
- These should be unified into one source of truth.

### History

- `History` is not yet tied to the exact session/result created by the latest run.
- History detail still needs a direct link to backend result sessions.

### Docs

- `backend_api_spec.md` still needs to be updated to match the current `session_id/session_key` result flow.

## MVP Flow Today

```text
Home -> Connect -> Capture -> Processing -> Result
```

This flow is now backed by real API calls for the main orchestration path.

## Recommended Next Task

1. Unify result client/models (`ResultApi` + `BackendResultsService`)
2. Wire `History` to open the exact backend session/result
3. Update backend API documentation

## Verification Done

- `python -m compileall backend/app`
- `dart analyze` on the modified Flutter files

Both checks passed.
