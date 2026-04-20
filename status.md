# PBL5 - Project Status Snapshot

## 1. Tổng quan trạng thái hiện tại

Dự án hiện đã hoàn thành được **phần lõi kỹ thuật quan trọng nhất**: truyền dữ liệu từ Raspberry Pi sang backend, chạy model AI, và sinh kết quả pose estimation.

Nói ngắn gọn:

```text
Raspberry Pi -> Backend -> Model -> Result
```

đã chạy được.

Tuy nhiên, hệ thống vẫn **chưa hoàn thiện full flow điều khiển từ mobile app**.
Hiện tại project đang ở giai đoạn chuyển từ **pipeline xử lý hoạt động** sang **pipeline điều phối hoàn chỉnh**.

---

## 2. Những phần đã hoàn thành

### 2.1. Raspberry Pi ↔ Backend communication

* Raspberry Pi đã gửi được frame thật sang backend qua ZeroMQ
* Backend worker đã nhận được frame thành công
* Hệ thống đã test được cả:

  * gửi 1 frame
  * gửi nhiều frame
  * gửi frame theo session
  * gửi từ folder frame cắt ra từ video

### 2.2. Backend worker processing

* `zmq_worker.py` đã:

  * nhận multipart message
  * parse metadata JSON
  * lưu frame gốc
  * gọi model inference
  * sinh ảnh pose output
  * sinh JSON result cho từng frame

### 2.3. Model AI integration

* `core_model/inference.py` đã được refactor để backend có thể import và gọi trực tiếp
* Model AI hiện đã chạy được từ worker backend
* Output pose estimation đã được lưu thành file thật

### 2.4. Result generation

Mỗi frame hiện tại đã có thể sinh ra:

* ảnh gốc
* ảnh pose
* file JSON result

Ví dụ:

```text
workers/output/<session_id>/frame_1.jpg
workers/results/<session_id>/frame_1_pose.jpg
workers/results/<session_id>/frame_1_result.json
```

### 2.5. Backend API nền tảng

Backend hiện đã có các nhóm API chính:

* device
* session
* results

Điều này tạo nền tảng để app mobile có thể:

* đọc session
* đọc frame result
* đọc JSON result
* hiển thị ảnh pose

---

## 3. Những phần đang làm

### 3.1. Pi Agent / Command orchestration

Hiện tại Raspberry Pi đã có agent polling backend:

* heartbeat OK
* pending command OK
* nhận được command thật từ backend

Pi agent cũng đã có thể:

* nhận lệnh `start_recording`
* parse `command_payload`
* tự gọi `pi_zmq_sender.py`

Tuy nhiên, phần **command lifecycle** vẫn đang được hoàn thiện:

* command sau khi xử lý xong chưa được acknowledge hoàn chỉnh
* dẫn tới nguy cơ command bị lặp lại nhiều lần

### 3.2. End-to-end control flow

Hiện tại hệ thống vẫn đang hơi thủ công:

* tạo command bằng Swagger / backend docs
* chạy Pi agent bằng terminal
* quan sát worker bằng terminal

Tức là **luồng điều khiển từ app xuống Pi chưa được đóng kín hoàn toàn**.

---

## 4. Những phần chưa hoàn thành

### 4.1. Full mobile app orchestration

App Flutter hiện chưa điều khiển toàn bộ flow:

* Connect thật với backend status
* Start Capture thật
* Trigger Pi capture thật
* Theo dõi Processing thật
* Xem Result / History bằng dữ liệu thật

### 4.2. Command status lifecycle

Cần hoàn thiện:

* command `pending`
* command `completed`
* command `failed`

để tránh Pi agent xử lý lặp vô hạn.

### 4.3. Processing status flow

Màn hình Processing trong app hiện chưa gắn chặt với trạng thái xử lý thật từ backend.

### 4.4. Camera capture thật từ Pi

Hiện tại Pi đang gửi frame từ folder frame cắt sẵn theo command payload `frames_dir`.

Đây là hợp lý để test flow.
Nhưng để hoàn thiện hơn, sau này cần thêm mode:

* mở camera thật
* capture theo thời lượng
* gửi frame realtime

---

## 5. Dự án hiện đang đứng ở đâu?

Nếu chia theo mức độ hoàn thành kỹ thuật:

### Đã xong

* Core AI pipeline
* Pi ↔ Backend data pipeline
* Backend inference pipeline
* Result generation pipeline

### Đang làm

* Pi agent command handling
* Command acknowledgment lifecycle
* Backend ↔ App ↔ Pi orchestration

### Chưa xong

* Full end-to-end mobile app integration
* Processing flow thật
* Control flow từ app đến camera Pi hoàn chỉnh

---

## 6. Trạng thái hiện tại theo 1 câu ngắn

```text
Dự án đã chạy được phần xử lý AI từ Raspberry Pi tới backend và sinh kết quả; hiện đang hoàn thiện lớp điều phối để mobile app có thể điều khiển toàn bộ flow một cách tự động.
```

---

## 7. Bước tiếp theo gần nhất

Bước cần làm ngay để không bị kẹt flow:

### Fix command lifecycle

* Pi agent xử lý xong command phải báo backend cập nhật trạng thái
* command không còn bị trả về liên tục dưới dạng `pending`

Sau khi bước này ổn, có thể chuyển sang:

### Nối app Flutter với backend thật

* đọc Results API
* hiển thị Result / History
* sau đó nối Connect / Capture / Processing thật

---

## 8. Hướng đi tiếp theo sau đó

1. Hoàn thiện command status update
2. Flutter gọi Results API
3. Flutter render pose image + result detail
4. Flutter Connect screen gọi API status thật
5. Flutter Capture screen tạo session + command thật
6. Pi agent nhận lệnh và tự gửi frame
7. App đi đúng full flow:

```text
Splash -> Home -> Connect -> Capture -> Processing -> Result -> History
```
