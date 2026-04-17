# PBL5 - Luồng triển khai tổng thể từ App → Pi → Backend → Model → Result

## 1. Mục tiêu cuối cùng của hệ thống

Người dùng mở app và đi theo flow:

**Splash → Home → Connect → Capture → Processing → Result → History**

Phía sau flow đó, hệ thống kỹ thuật phải chạy theo chuỗi:

**Flutter App → FastAPI Backend → Raspberry Pi Agent → Camera Pi → ZeroMQ Worker → Model Inference → Results API → Flutter App**

---

## 2. Những gì đã làm được

Hiện tại project đã hoàn thành được phần lõi xử lý:

### Đã xong

* Raspberry Pi gửi frame sang backend qua ZeroMQ
* `zmq_worker.py` nhận được frame
* worker lưu frame gốc
* worker gọi model pose estimation
* worker lưu:

  * ảnh pose output
  * file JSON result
* FastAPI đã bắt đầu có API đọc results

### Nghĩa là luồng này đã chạy:

```text
Raspberry Pi -> ZeroMQ -> backend worker -> model -> pose result + json result
```

---

## 3. Những gì chưa xong

Hiện tại hệ thống vẫn còn thủ công ở phần điều phối:

* chưa phải app bấm là Pi tự quay/gửi
* chưa có agent chạy nền trên Pi để nhận lệnh
* app chưa điều khiển toàn bộ pipeline
* processing status chưa nối theo phiên thật
* app chưa full end-to-end control flow

---

## 4. Kiến trúc đúng cần hướng tới

```text
[Flutter App]
    ↓ gọi API
[FastAPI Backend]
    ├── quản lý device / session / command / result
    ├── trả status và result cho app
    └── điều phối Raspberry Pi

[Raspberry Pi Agent]
    ├── heartbeat về backend
    ├── poll command từ backend
    ├── mở camera khi có lệnh
    └── gửi frame qua ZeroMQ

[ZMQ Worker]
    ├── nhận frame
    ├── lưu frame
    ├── chạy model
    └── sinh pose result + json result

[FastAPI Results API]
    └── đọc file result và trả cho app
```

---

## 5. Giải thích đúng về “app kết nối camera Pi”

App **không nên kết nối trực tiếp camera Pi**.

### Sai tư duy

```text
App -> camera Pi trực tiếp
```

### Đúng tư duy

```text
App -> Backend -> Pi Agent -> Camera Pi
```

Nghĩa là:

* app chỉ gọi backend
* backend quản lý trạng thái và lệnh
* Pi agent mới là thứ mở camera thật

---

## 6. Flow người dùng và flow kỹ thuật tương ứng

### 6.1 Flow UI

```text
Splash
→ Home
→ Connect
→ Capture
→ Processing
→ Result
→ History
```

### 6.2 Flow kỹ thuật tương ứng

#### Splash

* app load cấu hình
* chuẩn bị navigation

#### Home

* app hiển thị overview
* có thể lấy status nhanh từ backend

#### Connect

* app gọi backend để kiểm tra:

  * Pi online/offline
  * server online/offline
* backend đọc từ device heartbeat / status

#### Capture

* app bấm Start Capture
* backend tạo session
* backend tạo command cho Pi

#### Processing

* Pi agent poll command
* Pi thấy lệnh `start_capture`
* Pi mở camera / đọc frame
* Pi gửi frame qua ZeroMQ
* worker chạy model
* backend cập nhật status xử lý

#### Result

* app gọi Results API
* backend trả JSON result + ảnh pose URL
* app hiển thị kết quả

#### History

* app lấy danh sách session cũ
* xem lại các phiên đã xử lý

---

## 7. Trạng thái hiện tại đang đứng ở đâu

### Đã hoàn thành

```text
Pi -> backend worker -> model -> results
FastAPI -> đọc results
```

### Chưa hoàn thành

```text
App -> backend -> Pi agent -> camera -> full auto flow
```

Nói ngắn gọn:

**Pipeline xử lý đã xong phần dưới.**
**Pipeline điều khiển từ app xuống Pi chưa xong.**

---

## 8. Luồng triển khai đúng để follow

## Phase A - Kết quả đã xử lý

### Mục tiêu

Chứng minh hệ thống xử lý ảnh hoạt động.

### Đã làm

* Pi gửi frame
* worker nhận frame
* model chạy
* sinh ảnh pose + JSON result
* API đọc results

### Kết quả

* backend đã có output thật
* app có thể bắt đầu đọc result

---

## Phase B - App đọc kết quả

### Mục tiêu

Cho app hiển thị kết quả backend đã xử lý.

### Việc cần làm

* Flutter gọi:

  * `GET /api/results/sessions`
  * `GET /api/results/{session_id}`
  * `GET /api/results/{session_id}/{frame_id}`
* render ảnh qua `pose_image_url`
* map vào:

  * Result screen
  * History screen

### Kết quả

* app xem được kết quả thật
* app xem được lịch sử thật

---

## Phase C - Pi Agent hóa

### Mục tiêu

Biến Pi từ sender test thành agent thật.

### Việc cần làm

Tạo `pi_agent.py` chạy nền trên Pi, có nhiệm vụ:

* gửi heartbeat định kỳ
* poll command từ backend
* nếu có `start_capture`

  * mở camera
  * capture/gửi frame
* nếu có `stop_capture`

  * dừng

### Kết quả

* Pi hoạt động như một thiết bị IoT đúng nghĩa
* không cần chạy sender thủ công nữa

---

## Phase D - App điều khiển hệ thống

### Mục tiêu

Cho app bấm nút là cả flow chạy.

### Việc cần làm

* màn Connect gọi API status thiết bị
* màn Capture gọi API tạo session + tạo command
* backend phát lệnh cho Pi
* Pi agent tự chạy camera và gửi frame

### Kết quả

* app điều khiển được Pi gián tiếp qua backend

---

## Phase E - Processing thật

### Mục tiêu

Hiển thị trạng thái xử lý đúng trong màn Processing.

### Việc cần làm

* backend lưu trạng thái session/job
* app polling hoặc gọi API status
* map trạng thái vào UI:

  * Uploading
  * Extracting Frames
  * Running Pose Estimation
  * Generating Results

### Kết quả

* màn Processing không còn là mock
* theo dõi được tiến trình thật

---

## Phase F - Full flow end-to-end

### Mục tiêu

Hoàn thiện đúng flow demo cuối cùng.

### Flow hoàn chỉnh

```text
User mở app
-> Splash
-> Home
-> Connect
-> app kiểm tra Pi + server online
-> Capture
-> app bấm Start
-> backend tạo session + command
-> Pi agent mở camera
-> Pi gửi frame
-> worker chạy model
-> backend sinh results
-> Processing hiển thị tiến trình
-> Result hiển thị kết quả
-> History lưu lại phiên cũ
```

---

## 9. Checklist cần follow từ giờ

## Bước 1

* [ ] Hoàn thiện Flutter đọc Results API
* [ ] Render `pose_image_url`
* [ ] Dùng được Result screen
* [ ] Dùng được History screen

## Bước 2

* [ ] Tạo `pi_agent.py`
* [ ] Pi gửi heartbeat
* [ ] Pi poll pending commands
* [ ] Pi nhận được lệnh start/stop

## Bước 3

* [ ] Backend tạo session thật
* [ ] Backend tạo command cho Pi
* [ ] Backend quản lý trạng thái session

## Bước 4

* [ ] App Connect screen gọi API status thiết bị
* [ ] App Capture screen gọi API start capture
* [ ] App Processing screen theo dõi tiến trình thật

## Bước 5

* [ ] App Result screen hiển thị result thật
* [ ] App History screen hiển thị session cũ
* [ ] Demo full flow hoàn chỉnh

---

## 10. Bước tiếp theo nên làm ngay

### Nếu bám đúng flow:

**Bước tiếp theo nên là làm `pi_agent.py`**

Vì:

* app muốn điều khiển camera Pi
* mà hiện tại Pi chưa có agent chạy nền để nhận lệnh
* sender hiện tại vẫn đang chạy thủ công

### Mục tiêu của `pi_agent.py`

* heartbeat
* poll command
* mở camera khi được backend yêu cầu
* gửi frame qua ZeroMQ

Đây là bước biến hệ thống từ:

```text
test thủ công
```

thành:

```text
app điều khiển được pipeline thật
```

---

## 11. Tóm tắt 1 dòng dễ nhớ

```text
Đã xong phần xử lý ảnh và AI; tiếp theo phải làm Pi Agent để app có thể điều khiển camera Pi qua backend đúng flow.
```
