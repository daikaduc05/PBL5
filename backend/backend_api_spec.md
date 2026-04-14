# Backend API Specification - PoseTrack

## 1. Tổng quan

### Base URL

```text
http://localhost:8002/api
```

### Response format chung

Tất cả response nên theo format thống nhất:

```json
{
  "success": true,
  "message": "string",
  "data": {}
}
```

## 2. Health API

### `GET /health`

Kiểm tra backend có đang hoạt động hay không.

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

Tạo session mới cho app.

**Response**

```json
{
  "success": true,
  "message": "Session created successfully",
  "data": {
    "session_id": 1,
    "token": "abc123xyz"
  }
}
```

## 4. Device API

### `GET /devices`

Lấy danh sách thiết bị.

**Response**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "device_name": "Raspberry Pi 4",
      "device_code": "pi-001",
      "status": "online"
    }
  ]
}
```

### `POST /devices/register`

Đăng ký thiết bị Raspberry Pi.

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
  "data": {
    "device_id": 1,
    "auth_token": "device_token",
    "status": "online"
  }
}
```

### `POST /devices/{device_id}/heartbeat`

Cập nhật trạng thái thiết bị.

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
    "status": "online"
  }
}
```

## 5. Command API

### `POST /devices/{device_id}/commands`

Gửi lệnh đến Pi.

**Request**

```json
{
  "session_id": 1,
  "command_type": "capture_photo",
  "command_payload": "{\"resolution\":\"1280x720\"}"
}
```

**Response**

```json
{
  "success": true,
  "data": {
    "command_id": 10,
    "status": "pending"
  }
}
```

### `GET /devices/{device_id}/commands/pending`

Pi polling để lấy lệnh đang chờ.

**Response**

```json
{
  "success": true,
  "data": {
    "command_id": 10,
    "command_type": "capture_photo",
    "command_payload": "{\"resolution\":\"1280x720\"}",
    "status": "pending"
  }
}
```

## 6. Media API

### `POST /media/upload`

Upload ảnh hoặc video từ app hoặc Pi.

**Form-data**

| Field | Type | Example |
| --- | --- | --- |
| `file` | file | `image.jpg` |
| `source_type` | string | `app` / `pi` |
| `media_type` | string | `image` / `video` |
| `session_id` | int | `1` |
| `device_id` | int | `1` |

**Response**

```json
{
  "success": true,
  "data": {
    "media_id": 5,
    "file_name": "abc.jpg",
    "file_path": "storage/uploads/abc.jpg",
    "media_type": "image"
  }
}
```

## 7. Job API

### `POST /jobs`

Tạo job xử lý AI.

**Request**

```json
{
  "media_id": 5,
  "session_id": 1,
  "device_id": 1,
  "task_type": "image_pose"
}
```

**Response**

```json
{
  "success": true,
  "data": {
    "job_id": 20,
    "status": "queued",
    "progress": 0
  }
}
```

### `GET /jobs/{job_id}`

Lấy trạng thái job.

**Response**

```json
{
  "success": true,
  "data": {
    "job_id": 20,
    "status": "processing",
    "progress": 60
  }
}
```

## 8. Result API

### `GET /results/job/{job_id}`

Lấy kết quả xử lý.

**Response**

```json
{
  "success": true,
  "data": {
    "result_id": 1,
    "job_id": 20,
    "overlay_path": "storage/outputs/result.jpg",
    "keypoints_json": "{\"nose\": [100, 120]}",
    "confidence": 0.92
  }
}
```

## 9. History API

### `GET /history`

Lấy danh sách lịch sử.

**Response**

```json
{
  "success": true,
  "data": [
    {
      "job_id": 20,
      "status": "done",
      "media_type": "image",
      "created_at": "2026-04-14T10:00:00"
    }
  ]
}
```

### `GET /history/{job_id}`

Lấy chi tiết một job trong lịch sử.

**Response**

```json
{
  "success": true,
  "data": {
    "job_id": 20,
    "status": "done",
    "result": {
      "overlay_path": "storage/outputs/result.jpg",
      "confidence": 0.92
    }
  }
}
```

## 10. Flow hoàn chỉnh

### Flow ảnh từ App

1. `POST /session/create`
2. `POST /media/upload`
3. `POST /jobs`
4. `GET /jobs/{id}` để polling trạng thái
5. `GET /results/job/{id}`

### Flow từ Raspberry Pi

1. `POST /devices/register`
2. `POST /devices/{id}/heartbeat`
3. `GET /devices/{id}/commands/pending`
4. `POST /media/upload`
5. `POST /jobs`

## 11. Ghi chú quan trọng

- App và Pi đều dùng polling, chưa dùng WebSocket ở giai đoạn MVP.
- Job luôn xử lý bất đồng bộ.
- Media và result lưu file trong `storage/`.
- Backend là trung tâm điều phối, không xử lý trực tiếp UI.
