# PBL5 - Project Status Snapshot

## 1. Tổng quan trạng thái hiện tại

Dự án hiện đã chạy được **pipeline xử lý pose estimation thật** từ Raspberry Pi sang backend:

```text
Pi -> ZeroMQ Worker -> Model -> Result Files -> Results API
```

Backend cũng đã được khóa lại thêm một lớp điều phối quan trọng:

* session hiện có **public session key** dùng xuyên suốt cho Pi/worker/result
* command lifecycle hiện có các trạng thái rõ ràng:

  * `pending`
  * `acknowledged`
  * `running`
  * `completed`
  * `failed`

Điểm nghẽn hiện tại không còn nằm chủ yếu ở backend worker nữa, mà nằm ở **việc nối mobile app sang flow thật**.

---

## 2. Những phần đã hoàn thành

### 2.1. Pi ↔ Backend data pipeline

* Raspberry Pi gửi được frame thật qua ZeroMQ
* backend worker nhận được multipart message
* worker lưu frame gốc theo session
* worker chạy model pose estimation
* worker sinh ảnh pose và JSON result

### 2.2. Results API

Backend đã đọc được dữ liệu kết quả thật từ thư mục:

```text
workers/results/<session_key>/
```

và trả ra cho app qua:

* `GET /api/results/sessions`
* `GET /api/results/{session_key}`
* `GET /api/results/{session_key}/{frame_id}`

### 2.3. Session contract đã được chuẩn hóa

Backend hiện đã có session theo 2 lớp:

* `session_id`: khóa số trong database
* `session_key`: khóa public dạng chuỗi để Pi, worker và Results API cùng dùng

Điều này giúp tách rõ:

* quan hệ DB nội bộ
* định danh public dùng cho folder result và luồng xử lý ngoài DB

### 2.4. Command lifecycle đã được khóa lại

Backend và Pi agent hiện đã có lifecycle rõ hơn:

* khi Pi poll command, backend **claim command** và đổi sang `acknowledged`
* khi Pi bắt đầu xử lý, Pi cập nhật `running`
* khi xong, Pi cập nhật `completed` hoặc `failed`
* backend dùng `executed_at` để ghi nhận lúc command được bắt đầu xử lý

Ngoài ra, command đang ở `acknowledged` hoặc `running` quá lâu có thể được phát lại sau timeout để tránh kẹt vĩnh viễn.

### 2.5. Pi agent đã theo contract mới

Pi agent hiện đã:

* poll command đã được claim từ backend
* đọc được `session_key`
* cập nhật `running`
* cập nhật `completed` hoặc `failed`

### 2.6. Job / History response đã mang session key

Các API `jobs` và `history` hiện đã trả thêm `session_key`, giúp về sau app có thể nối từ history/job sang result session mà không cần đoán tên folder.

---

## 3. Những phần đang làm

### 3.1. Backend orchestration layer

Phần backend core cho điều phối đã tiến thêm một bước, nhưng vẫn còn dang dở ở chỗ:

* `jobs` hiện vẫn là stub progress giả
* `history` chưa trỏ thẳng vào result session cụ thể
* flow giữa `job` và `results` chưa được đóng kín hoàn toàn

### 3.2. Mobile app integration

Flutter hiện vẫn đang ở trạng thái nửa thật nửa mock:

* `Result Sessions` và một phần `History` đã chạm backend
* `Connect`, `Capture`, `Processing` vẫn chủ yếu dùng mock service

---

## 4. Những phần chưa hoàn thành

### 4.1. Full end-to-end app orchestration

App chưa đi trọn flow thật:

```text
Connect -> Capture -> Processing -> Result -> History
```

theo backend/Pi thật.

### 4.2. Connect screen gọi API thật

Màn Connect vẫn chưa đọc trực tiếp:

* backend health
* device list / Pi online status

### 4.3. Capture screen tạo session + command thật

Màn Capture vẫn chưa thực hiện đầy đủ:

* `POST /api/session/create`
* `POST /api/devices/{device_id}/commands`

### 4.4. Processing screen theo dõi tiến trình thật

Màn Processing hiện vẫn là progress giả bằng timer, chưa polling backend theo command/result thật.

### 4.5. Kết nối giữa History / Job / Result

Hiện đã có `session_key` trong response, nhưng app vẫn chưa dùng khóa đó để mở đúng result session từ history/job.

### 4.6. Camera thật trên Raspberry Pi

Pi hiện vẫn phù hợp nhất cho mode test:

* đọc frame từ folder
* gửi qua ZeroMQ theo command payload

Chưa phải luồng camera realtime hoàn chỉnh.

---

## 5. Dự án hiện đang đứng ở đâu?

### Đã xong

* Core AI pipeline
* Pi -> backend worker -> result pipeline
* Results API đọc file thật
* Session public key contract
* Command claim + lifecycle cơ bản giữa backend và Pi agent

### Đang làm

* Nối app Flutter sang backend thật
* Gắn processing flow với trạng thái thật
* Gắn history/job với result session thật

### Chưa xong

* Full mobile end-to-end orchestration
* Job pipeline thật thay cho stub
* Camera Pi realtime flow

---

## 6. Trạng thái hiện tại theo 1 câu ngắn

```text
Backend và Pi agent đã có contract session/command ổn định hơn; nút thắt hiện tại là nối Flutter vào flow thật thay cho các màn còn đang mock.
```

---

## 7. Bước tiếp theo gần nhất

Bước nên làm ngay bây giờ:

### Nối Connect screen vào backend thật

* gọi `GET /api/health`
* gọi `GET /api/devices`
* hiển thị Pi online/offline theo heartbeat thật

Sau đó nối tiếp:

### Nối Capture screen vào session + command thật

* tạo session từ backend
* tạo command cho Pi với `session_id`
* để backend tự gắn `session_key` vào command payload

Sau khi 2 bước này ổn, mới sang:

### Nối Processing screen vào status/result thật

* polling command status
* dò result session theo `session_key`
* chuyển sang Result khi đã có output thật

---

## 8. Hướng đi tiếp theo sau đó

1. Flutter Connect screen gọi API thật
2. Flutter Capture screen tạo session + command thật
3. Pi agent nhận lệnh và gửi frame theo `session_key`
4. Flutter Processing screen theo dõi trạng thái thật
5. Flutter Result / History mở đúng result session thật
6. Gộp các results client trùng nhau trong app
7. Thay job stub bằng processing pipeline thật nếu cần

---

## 9. Tóm tắt dễ nhớ

```text
Phần worker/model/results đã chạy ổn; backend vừa được khóa thêm session key và command lifecycle; bước kế tiếp là bỏ mock ở Flutter và nối app vào flow thật.
```
