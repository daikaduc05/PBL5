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
- Result screens now share one backend result source of truth through `ResultApi`.
- `History` now opens the exact backend session via `session_key` instead of jumping to the generic results list.
- Fixed backend result contract mismatch:

```text
result_json_path vs result_json_url
```

so the backend result screen can open sessions produced by the real flow.

## What Is Still Not Done

### Results Layer

- `BackendResultsService` has been reduced to a compatibility shim.
- The active result flow now uses `ResultApi` + `result_models.dart`.

### History

- `History` now routes to the exact backend result session for each job item.
- History detail still does not include attached result metadata from backend `history/{job_id}`.

### Docs

- `backend_api_spec.md` still needs to be updated to match the current `session_id/session_key` result flow.

## MVP Flow Today

```text
Home -> Connect -> Capture -> Processing -> Result
```

This flow is now backed by real API calls for the main orchestration path.

## Recommended Next Task

1. Update backend API documentation
2. Attach result metadata to backend `history/{job_id}` detail
3. Remove the compatibility shim once you are sure no old imports are needed

## Verification Done

- `python -m compileall backend/app`
- `dart analyze` on the modified Flutter files

Both checks passed.
