# Realtime Upgrade Brief

## Vấn đề hiện tại

```
Pi Camera → ZMQ → Worker → ghi frame disk → inference → ghi result disk → REST poll ← Mobile
                               ~30ms            ~1500ms (CPU)  ~30ms       0–3000ms
```

**Tổng latency worst case: ~5 giây/frame**

Hai nguyên nhân chính:
1. Disk I/O không cần thiết cho realtime path (ghi frame vào để đọc lại)
2. Mobile dùng REST polling thay vì push — thêm delay biến đổi

---

## Phương án: In-memory inference + WebSocket push

```
Pi Camera → ZMQ → Worker → inference (RAM) → WebSocket push → Mobile
                               ~50ms (GPU)        ~5ms
```

**Tổng latency mục tiêu: ~80ms**

Disk write vẫn chạy nhưng **async** (background thread) — giữ nguyên lịch sử/replay, không block inference.

---

## Thay đổi cần làm

### 1. `backend/workers/zmq_worker.py`

**Hiện tại:**
```python
output_path.write_bytes(image_bytes)          # ghi disk
run_pose_for_saved_frame(output_path, ...)    # đọc lại từ disk
```

**Cần đổi thành:**
- Decode `image_bytes` → `np.ndarray` bằng `cv2.imdecode`
- Gọi `_run_pose_pipeline(numpy_array, ...)` trực tiếp (đã hỗ trợ numpy)
- Ghi disk trong `threading.Thread(daemon=True)` — async, không block
- Sau inference: push result JSON qua ZMQ PUSH socket nội bộ tới FastAPI

**Thêm:**
- ZMQ PUSH socket (port 5556) để publish kết quả inference sang FastAPI

---

### 2. `backend/app/main.py`

**Thêm:**
```python
from fastapi import WebSocket
```

**Thêm WebSocket endpoint:**
```
GET /ws/realtime/{session_id}
```

- FastAPI lắng nghe ZMQ SUB socket (port 5556) từ worker
- Khi nhận result → broadcast tới tất cả WebSocket client đang subscribe `session_id` đó
- Dùng `asyncio` để chạy ZMQ listener song song với FastAPI event loop

**Quản lý connections:**
```python
# Dict session_id → list[WebSocket]
active_connections: dict[str, list[WebSocket]] = {}
```

---

### 3. `mobile_app/lib/services/` — file mới `realtime_ws_service.dart`

Thay thế `ResultApi.getFrameResult()` polling bằng WebSocket stream.

**Cần implement:**
```dart
class RealtimeWsService {
  Stream<FrameResultDetail> subscribe(String sessionId);
  void disconnect();
}
```

- Connect tới `ws://{serverAddress}/ws/realtime/{session_id}`
- Parse JSON message → `FrameResultDetail` (dùng lại model hiện có)
- Auto-reconnect khi mất kết nối
- Expose stream để UI listen

---

### 4. `mobile_app/lib/screens/` — màn hình dùng realtime

Màn hình hiện đang poll REST cần đổi sang listen stream:

**Trước:**
```dart
// Timer poll mỗi N giây
_timer = Timer.periodic(Duration(seconds: 2), (_) async {
  final result = await resultApi.getFrameResult(sessionId, frameId);
  setState(() => _result = result);
});
```

**Sau:**
```dart
_realtimeService.subscribe(sessionId).listen((result) {
  setState(() => _result = result);
});
```

---

## Tóm tắt file thay đổi

| File | Loại thay đổi | Độ phức tạp |
|---|---|---|
| `backend/workers/zmq_worker.py` | Sửa — in-memory inference + async disk + ZMQ push | Trung bình |
| `backend/app/main.py` | Sửa — thêm WebSocket endpoint + ZMQ subscriber | Trung bình |
| `mobile_app/lib/services/realtime_ws_service.dart` | Tạo mới | Nhỏ |
| `mobile_app/lib/screens/[realtime screen]` | Sửa — đổi polling → stream | Nhỏ |

REST API cũ (`/api/results/...`) **giữ nguyên** — vẫn dùng cho lịch sử/replay.

---

## Trước và sau

| | Trước | Sau |
|---|---|---|
| Inference | CPU ~1500ms | GPU ~50ms |
| Disk input frame | Sync ~30ms | Async (không block) |
| Disk result JSON | Sync ~30ms | Async (không block) |
| Kết quả về mobile | REST poll 0–3000ms | WebSocket push ~5ms |
| **Tổng latency** | **~3–5 giây** | **~80ms** |
