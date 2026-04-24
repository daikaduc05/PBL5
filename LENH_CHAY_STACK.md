# Lenh chay stack PoseTrack

File nay tong hop cac lenh can dung de chay:

- backend server
- ZMQ worker
- Flutter app
- Pi agent

Gia su:

- may Windows dang chay `backend` + `zmq worker`
- Raspberry Pi dang chay `pi_agent.py`
- app Flutter co the chay tren Windows desktop hoac dien thoai

Baseline da verify runtime:

- Raspberry Pi IP: `172.20.10.2`
- backend server: `172.20.10.5:8002`

## 1. Thu tu mo terminal

Mo 4 terminal theo thu tu nay:

1. Backend server
2. ZMQ worker
3. Pi agent
4. Flutter app

## 2. Setup 1 lan cho backend + worker (PowerShell)

Chay tu thu muc goc repo:

```powershell
python -m venv .\backend\.venv
.\backend\.venv\Scripts\pip.exe install -r .\backend\requirements.txt
.\backend\.venv\Scripts\pip.exe install -r .\core_model\requirements.txt
.\backend\.venv\Scripts\pip.exe install requests
```

## 3. Chay backend server (PowerShell)

Chay tu thu muc goc repo:

```powershell
Set-Location .\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
```

Health check:

```text
http://<BACKEND_HOST>:8002/api/health
```

Vi du local:

```text
http://127.0.0.1:8002/api/health
```

## 4. Chay ZMQ worker (PowerShell)

Chay tu thu muc goc repo:

```powershell
Set-Location .\backend
.\.venv\Scripts\python.exe .\workers\zmq_worker.py
```

Worker mac dinh bind vao:

```text
tcp://*:5555
```

## 5. Chay Flutter app (PowerShell)

Chay tu thu muc goc repo:

```powershell
Set-Location .\mobile_app
flutter pub get
flutter run --dart-define=POSETRACK_BACKEND_ADDRESS=<BACKEND_HOST>:8002 --dart-define=POSETRACK_PI_DEVICE_CODE=pi-001 --dart-define=POSETRACK_PI_FRAMES_DIR=/home/pi/posetrack/frames --dart-define=POSETRACK_PREVIEW_PORT=8081 --dart-define=POSETRACK_PREVIEW_SOCKET_PORT=8082 --dart-define=POSETRACK_ZMQ_PORT=5555
```

Neu chay tren Windows desktop:

```powershell
flutter run -d windows --dart-define=POSETRACK_BACKEND_ADDRESS=<BACKEND_HOST>:8002 --dart-define=POSETRACK_PI_DEVICE_CODE=pi-001 --dart-define=POSETRACK_PI_FRAMES_DIR=/home/pi/posetrack/frames --dart-define=POSETRACK_PREVIEW_PORT=8081 --dart-define=POSETRACK_PREVIEW_SOCKET_PORT=8082 --dart-define=POSETRACK_ZMQ_PORT=5555
```

Vi du:

```powershell
flutter run -d windows --dart-define=POSETRACK_BACKEND_ADDRESS=192.168.1.10:8002 --dart-define=POSETRACK_PI_DEVICE_CODE=pi-001 --dart-define=POSETRACK_PI_FRAMES_DIR=/home/pi/posetrack/frames --dart-define=POSETRACK_PREVIEW_PORT=8081 --dart-define=POSETRACK_PREVIEW_SOCKET_PORT=8082 --dart-define=POSETRACK_ZMQ_PORT=5555
```

Baseline da verify tren Windows desktop:

```powershell
flutter run -d windows --dart-define=POSETRACK_BACKEND_ADDRESS=172.20.10.5:8002 --dart-define=POSETRACK_PREVIEW_SOCKET_PORT=8082
```
## 6. Chay Pi agent (Raspberry Pi / bash)

Neu Pi chua co moi truong:

```bash
python3 -m venv ~/posetrack-venv
source ~/posetrack-venv/bin/activate
pip install requests pyzmq opencv-python
sudo apt update
sudo apt install -y python3-picamera2 rpicam-apps v4l-utils
```

Di vao thu muc `backend/pi_agent` tren Raspberry Pi roi chay:

```bash
/usr/bin/python3 pi_agent.py --backend http://<BACKEND_HOST>:8002 --device-name "Raspberry Pi 4B" --device-code pi-001
```

Neu can ep bo tuning preview hien tai bang env khi test:

```bash
export POSETRACK_IDLE_PREVIEW_FPS=6
export POSETRACK_IDLE_PREVIEW_WIDTH=320
export POSETRACK_IDLE_PREVIEW_HEIGHT=240
export POSETRACK_PREVIEW_STREAM_FPS=6
export POSETRACK_PREVIEW_JPEG_QUALITY=45
export POSETRACK_CAMERA_FPS=8
/usr/bin/python3 pi_agent.py --backend http://<BACKEND_HOST>:8002 --device-name "Raspberry Pi 4B" --device-code pi-001
```

Neu khong can preview HTTP thi co the tat bang:

```bash
/usr/bin/python3 pi_agent.py --backend http://<BACKEND_HOST>:8002 --device-name "Raspberry Pi 4B" --device-code pi-001 --preview-port 0
```

Preview mac dinh tu Pi agent:

```text
http://<PI_IP>:8081/preview/latest.jpg
tcp://<PI_IP>:8082
```

Neu vua doi preview protocol Phase 2 tren may Windows, copy dong bo 3 file nay len Pi truoc khi chay lai:

```powershell
scp .\backend\pi_agent\pi_agent.py .\backend\pi_agent\pi_capture.py .\backend\pi_agent\pi_preview.py pi@<PI_IP>:/home/pi/PBL5_Project/backend/pi_agent/
```

Luu y:

- app Flutter va Pi agent phai cung version, vi preview socket packet da doi tu `jpeg only` sang `metadata + jpeg`
- neu app moi nhung Pi cu, hoac Pi moi nhung app cu, live preview socket co the khong parse duoc

## 7. Bo lenh nhanh de copy

### Terminal 1 - Backend

```powershell
Set-Location .\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
```

### Terminal 2 - Worker

```powershell
Set-Location .\backend
.\.venv\Scripts\python.exe .\workers\zmq_worker.py
```

### Terminal 3 - Pi

```bash
cd /home/pi/PBL5_Project/backend/pi_agent

export POSETRACK_IDLE_PREVIEW_FPS=6
export POSETRACK_IDLE_PREVIEW_WIDTH=320
export POSETRACK_IDLE_PREVIEW_HEIGHT=240
export POSETRACK_PREVIEW_STREAM_FPS=6
export POSETRACK_PREVIEW_JPEG_QUALITY=45
export POSETRACK_CAMERA_FPS=8

/usr/bin/python3 pi_agent.py --backend http://172.20.10.5:8002 --device-name "Raspberry Pi 4B" --device-code pi-001
```

### Terminal 4 - Flutter

```powershell
Set-Location .\mobile_app
flutter run -d windows --dart-define=POSETRACK_BACKEND_ADDRESS=172.20.10.5:8002 --dart-define=POSETRACK_PREVIEW_SOCKET_PORT=8082
```
