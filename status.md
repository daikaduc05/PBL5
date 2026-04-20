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
- Removed the old `BackendResultsService` compatibility shim after cleaning imports.
- Fixed backend result contract mismatch:

```text
result_json_path vs result_json_url
```

so the backend result screen can open sessions produced by the real flow.

## Closed In This Snapshot

### Results Layer

- The active result flow now uses `ResultApi` + `result_models.dart`.

### History

- `History` now routes to the exact backend result session for each job item.
- Backend `history/{job_id}` now includes attached result-session metadata.

### Docs

- `backend_api_spec.md` now matches the current `session_id/session_key` result flow.

## MVP Flow Today

```text
Home -> Connect -> Capture -> Processing -> Result
```

This flow is now backed by real API calls for the main orchestration path.

## Current Snapshot

The action items from the previous snapshot are now completed:

1. backend API documentation updated
2. backend `history/{job_id}` attaches result metadata
3. old compatibility shim removed

## Optional Next Improvements

1. surface `history/{job_id}.result` in a dedicated mobile detail screen if needed
2. replace the stub `/jobs` pipeline with the real worker orchestration path
3. add Pi live-camera capture mode beyond folder replay

## Verification Done

- `python -m compileall backend/app`
- `dart analyze` on the modified Flutter files

Both checks passed.
