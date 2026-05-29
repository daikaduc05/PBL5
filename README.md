# PBL5 - PoseTrack: Hệ thống Phân tích Tư thế Squat bằng AI

Hệ thống IoT kết hợp AI để phân tích tư thế tập squat theo thời gian thực, sử dụng Raspberry Pi làm thiết bị thu hình và mô hình Pose Estimation (ResNet-101 + YOLOv8) để đánh giá form tập.

## Kiến trúc hệ thống

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────────┐
│ Flutter App  │──────▶│  FastAPI Backend  │──────▶│ Raspberry Pi    │
│ (Mobile/PC)  │◀──────│  (Server chính)   │◀──────│ Agent (Camera)  │
└─────────────┘  REST  └──────────────────┘  REST  └─────────────────┘
                              │                           │
                              │                           │ ZeroMQ
                              ▼                           ▼
                       ┌──────────────┐          ┌──────────────┐
                       │  SQLite DB   │          │  ZMQ Worker  │
                       │ (Sessions)   │          │ (Inference)  │
                       └──────────────┘          └──────────────┘
                                                        │
                                                        ▼
                                                 ┌──────────────┐
                                                 │  Core Model  │
                                                 │ (Pose Est.)  │
                                                 └──────────────┘
```

## Luồng hoạt động

1. Người dùng mở app Flutter → kết nối tới backend
2. App gửi lệnh **Start Capture** → Backend tạo session và command
3. Pi Agent nhận lệnh → mở camera → gửi frame qua ZeroMQ
4. ZMQ Worker nhận frame → chạy model Pose Estimation → trả kết quả
5. Backend lưu kết quả → App hiển thị phân tích tư thế

## Cấu trúc thư mục

```
PBL5/
├── backend/              # FastAPI server + ZMQ worker + Pi agent
│   ├── app/              # FastAPI application
│   │   ├── api/          # API routes
│   │   ├── core/         # Config, database
│   │   ├── models/       # SQLAlchemy models
│   │   ├── schemas/      # Pydantic schemas
│   │   └── services/     # Business logic
│   ├── pi_agent/         # Code chạy trên Raspberry Pi
│   │   ├── pi_agent.py   # Agent chính (heartbeat, poll command)
│   │   ├── pi_capture.py # Điều khiển camera
│   │   └── pi_preview.py # Live preview stream
│   ├── workers/          # ZeroMQ worker xử lý inference
│   └── storage/          # Lưu trữ frame và kết quả
├── core_model/           # Mô hình AI Pose Estimation
│   ├── inference.py      # Pipeline inference chính
│   ├── form_checker.py   # Đánh giá form squat (góc khớp)
│   ├── checkpoint/       # Model weights (ResNet-101)
│   └── yolov8n.pt        # YOLOv8 person detector
├── mobile_app/           # Flutter app (Android/iOS/Windows)
│   ├── lib/              # Source code Dart
│   ├── assets/           # Hình ảnh, fonts
│   └── pubspec.yaml      # Dependencies
├── LENH_CHAY_STACK.md    # Hướng dẫn chạy chi tiết
└── OVERVIEW.md           # Tổng quan kiến trúc và roadmap
```

## Yêu cầu hệ thống

### Backend (Windows/Linux)
- Python 3.10+
- CUDA (khuyến nghị, cho GPU inference)

### Raspberry Pi
- Raspberry Pi 4B
- Camera Module (PiCamera2)
- Python 3.9+

### Mobile App
- Flutter SDK 3.11+
- Dart SDK 3.11+

## Cài đặt & Chạy

### 1. Backend + ZMQ Worker (Windows PowerShell)

```powershell
# Tạo virtual environment
python -m venv .\backend\.venv

# Cài dependencies
.\backend\.venv\Scripts\pip.exe install -r .\backend\requirements.txt
.\backend\.venv\Scripts\pip.exe install -r .\core_model\requirements.txt

# Chạy backend server
Set-Location .\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload

# Chạy ZMQ worker (terminal khác)
Set-Location .\backend
.\.venv\Scripts\python.exe .\workers\zmq_worker.py
```

### 2. Raspberry Pi Agent

```bash
# Cài đặt môi trường
python3 -m venv ~/posetrack-venv
source ~/posetrack-venv/bin/activate
pip install requests pyzmq opencv-python
sudo apt install -y python3-picamera2 rpicam-apps v4l-utils

# Chạy agent
/usr/bin/python3 pi_agent.py \
  --backend http://<BACKEND_IP>:8002 \
  --device-name "Raspberry Pi 4B" \
  --device-code pi-001
```

### 3. Flutter App

```powershell
Set-Location .\mobile_app
flutter pub get
flutter run -d windows `
  --dart-define=POSETRACK_BACKEND_ADDRESS=<BACKEND_IP>:8002 `
  --dart-define=POSETRACK_PREVIEW_SOCKET_PORT=8082
```

## Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| Backend API | FastAPI, Uvicorn, SQLAlchemy |
| Message Queue | ZeroMQ (PyZMQ) |
| AI Model | PyTorch, ResNet-101, YOLOv8 (Ultralytics) |
| Pose Analysis | OpenCV, NumPy |
| Mobile App | Flutter, Dart |
| IoT Device | Raspberry Pi 4B, PiCamera2 |
| Database | SQLite |
| Live Preview | HTTP MJPEG + TCP Socket |

## Mô hình AI

- **Person Detection**: YOLOv8n — phát hiện người trong frame
- **Pose Estimation**: PoseResNet-101 (17 keypoints COCO format) — ước lượng tư thế
- **Form Analysis**: Tính góc khớp gối và hông → đánh giá form squat (GOOD / BAD / UNKNOWN)
- **Squat Tracking**: Theo dõi rep, phát hiện giai đoạn (standing/descending/bottom/ascending)

## API Endpoints

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/api/health` | Health check |
| GET | `/api/devices` | Danh sách thiết bị |
| POST | `/api/sessions` | Tạo session mới |
| POST | `/api/commands` | Gửi lệnh tới Pi |
| GET | `/api/results/{session_id}` | Lấy kết quả phân tích |

## Biến môi trường (Pi Agent)

| Biến | Mô tả | Mặc định |
|---|---|---|
| `POSETRACK_IDLE_PREVIEW_FPS` | FPS preview khi idle | 6 |
| `POSETRACK_PREVIEW_STREAM_FPS` | FPS preview khi stream | 6 |
| `POSETRACK_PREVIEW_JPEG_QUALITY` | Chất lượng JPEG preview | 45 |
| `POSETRACK_CAMERA_FPS` | FPS camera capture | 8 |
| `POSETRACK_IDLE_PREVIEW_WIDTH` | Chiều rộng preview idle | 320 |
| `POSETRACK_IDLE_PREVIEW_HEIGHT` | Chiều cao preview idle | 240 |

## Flow UI trong App

```
Splash → Home → Connect → Capture → Processing → Result → History
```

- **Connect**: Kiểm tra trạng thái Pi và server
- **Capture**: Bắt đầu/dừng quay
- **Processing**: Theo dõi tiến trình xử lý
- **Result**: Hiển thị kết quả phân tích tư thế
- **History**: Xem lại các phiên trước

## Thành viên

Dự án PBL5 — Đại học Bách khoa Đà Nẵng (DUT)

## License

Private — Dự án học thuật, không phân phối công khai.
