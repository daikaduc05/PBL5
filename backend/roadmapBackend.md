# Backend Roadmap và Phân tích Chi tiết cho PBL5 PoseTrack

## 1. Mục tiêu của Backend

Backend là trung tâm điều phối giữa ba thành phần chính:

- **Mobile app**
- **Raspberry Pi**
- **AI model / inference pipeline**

Backend không chỉ là nơi nhận request, mà còn phải quản lý toàn bộ luồng xử lý:

1. App gửi yêu cầu.
2. Backend tạo session hoặc job.
3. Backend điều phối Raspberry Pi nếu cần.
4. Backend nhận ảnh hoặc video.
5. Backend chạy AI inference.
6. Backend lưu kết quả.
7. App lấy trạng thái và hiển thị kết quả.

## 2. Vai trò của Backend trong hệ thống

### 2.1. Đối với Mobile App

Backend cung cấp API để app:

- Tạo phiên làm việc.
- Kết nối thiết bị.
- Gửi lệnh capture.
- Upload ảnh hoặc video.
- Theo dõi trạng thái xử lý.
- Lấy kết quả.
- Xem lại lịch sử.

### 2.2. Đối với Raspberry Pi

Backend là nơi Raspberry Pi giao tiếp đến để:

- Đăng ký thiết bị.
- Gửi heartbeat.
- Polling để nhận lệnh.
- Upload media đã capture.

### 2.3. Đối với AI Model

Backend là lớp trung gian giữa dữ liệu đầu vào và model:

- Nhận media.
- Tạo job.
- Gọi inference service.
- Ghi kết quả đầu ra.
- Trả kết quả đã chuẩn hóa cho app.

## 3. Tại sao cần làm Backend trước, chưa tích hợp Pi ngay

Ở giai đoạn đầu, cần ưu tiên backend trước vì:

- Pi chưa cần tham gia ngay để backend vận hành.
- App cần API sẵn để test flow giao diện.
- Backend là “xương sống” của toàn hệ thống.
- Nếu chưa có backend mà tích hợp Pi ngay sẽ rất dễ rối.

### Chiến lược hợp lý

1. Dựng backend chạy ổn định.
2. Test API thủ công qua Swagger hoặc Postman.
3. Cho mobile gọi API được.
4. Sau đó mới tích hợp Raspberry Pi.

## 4. Kiến trúc Backend đề xuất

Backend nên đi theo kiến trúc module hóa, đơn giản nhưng dễ mở rộng.

### 4.1. Kiến trúc tổng quát

- **FastAPI** làm web framework.
- **SQLite** dùng cho giai đoạn đầu.
- **SQLAlchemy** quản lý database.
- **Local storage** để lưu file upload và output.
- **Polling** cho app và Pi.
- **Inference chạy cùng server** ở giai đoạn đầu.
- Sau này có thể tách inference thành worker riêng.

### 4.2. Nguyên tắc thiết kế

- Đơn giản để làm được.
- Đủ rõ để mở rộng.
- Đồng bộ với flow mobile.
- Tách module để dễ maintain.
- Ưu tiên làm MVP trước.

## 5. Cấu trúc thư mục Backend

```text
backend/
  app/
    api/
      routes/
    core/
    models/
    schemas/
    services/
    utils/
    main.py
  storage/
    uploads/
    outputs/
    temp/
  requirements.txt
```

### Ý nghĩa các thư mục

- `app/api/routes/`: Chứa các endpoint API như `session`, `device`, `media`, `jobs`, `results`, `history`.
- `app/core/`: Chứa phần lõi của hệ thống như config, database connection, settings.
- `app/models/`: Chứa model database như `Session`, `Device`, `Media`, `Job`, `Result`, `Command`.
- `app/schemas/`: Chứa request/response schema cho FastAPI và Pydantic.
- `app/services/`: Chứa business logic chính như tạo session, register device, upload media, tạo job, inference stub hoặc inference thật, lấy kết quả.
- `app/utils/`: Chứa các hàm hỗ trợ như enum trạng thái, xử lý file, format response, helper.
- `storage/`: Chứa dữ liệu thực tế.

### Cấu trúc storage

- `storage/uploads/`: Lưu file gốc upload lên.
- `storage/outputs/`: Lưu kết quả xử lý.
- `storage/temp/`: Lưu file tạm.

## 6. Luồng hoạt động của Backend theo mobile flow

Flow mobile đã chốt:

`Splash -> Home -> Connect -> Capture -> Processing -> Result -> History`

Backend cần map được với từng màn hình như sau.

### 6.1. Connect Screen

**Mục tiêu**

- Hiển thị danh sách thiết bị.
- Biết Pi có online hay không.
- Biết server có đang hoạt động hay không.

**API liên quan**

- `GET /health`
- `GET /devices`
- `POST /devices/register`
- `POST /devices/{device_id}/heartbeat`

### 6.2. Capture Screen

**Mục tiêu**

- App gửi lệnh chụp ảnh hoặc quay video.
- Hoặc app upload trực tiếp file.

**API liên quan**

- `POST /devices/{device_id}/commands`
- `GET /devices/{device_id}/commands/pending`
- `POST /media/upload`

### 6.3. Processing Screen

**Mục tiêu**

- Theo dõi job đang xử lý.
- Biết trạng thái `queued`, `processing`, `done`, `failed`.

**API liên quan**

- `POST /jobs`
- `GET /jobs/{job_id}`

### 6.4. Result Screen

**Mục tiêu**

- Lấy keypoints.
- Lấy ảnh overlay.
- Lấy video đã xử lý nếu có.

**API liên quan**

- `GET /results/job/{job_id}`

### 6.5. History Screen

**Mục tiêu**

- Xem lại các job đã xử lý trước đó.
- Mở lại kết quả cũ.

**API liên quan**

- `GET /history`
- `GET /history/{item_id}`

## 7. Các module Backend cần có

### 7.1. Session Module

**Mục đích**

Quản lý phiên làm việc của app.

**Chức năng**

- Tạo session mới.
- Cấp token session.
- Lưu thông tin phiên.

**Ý nghĩa**

Ngay cả khi chưa làm đăng nhập người dùng, vẫn cần session để:

- Phân biệt các lần sử dụng.
- Gắn media, job, result vào đúng phiên.
- Thuận tiện cho history.

### 7.2. Device Module

**Mục đích**

Quản lý Raspberry Pi như một thiết bị ngoại vi.

**Chức năng**

- Đăng ký device.
- Lưu device code.
- Heartbeat cập nhật trạng thái.
- Liệt kê danh sách device.
- Xác định device nào online hoặc offline.

**Trạng thái đề xuất**

- `offline`
- `online`
- `idle`
- `capturing`
- `uploading`
- `error`

### 7.3. Command Module

**Mục đích**

Làm trung gian để app ra lệnh cho Pi.

**Cách hoạt động**

1. App gửi command vào backend.
2. Backend lưu command ở trạng thái `pending`.
3. Pi polling để lấy command.
4. Pi thực hiện xong thì báo lại.

**Loại command đề xuất**

- `capture_photo`
- `start_recording`
- `stop_recording`

**Trạng thái command**

- `pending`
- `acknowledged`
- `completed`
- `failed`

### 7.4. Media Module

**Mục đích**

Quản lý dữ liệu đầu vào.

**Chức năng**

- Nhận file upload.
- Lưu vào storage.
- Tạo metadata trong database.
- Trả `media_id`.

**Loại media**

- `image`
- `video`
- `frame_batch`

**Nguồn media**

- `app`
- `pi`

### 7.5. Job Module

**Mục đích**

Quản lý tiến trình xử lý AI.

**Lý do cần job**

Không nên upload xong là xử lý trực tiếp rồi trả kết quả ngay, vì:

- Video có thể xử lý lâu.
- Inference có thể chậm.
- App cần màn hình processing.
- Dễ scale hơn về sau.

**Trạng thái job**

- `queued`
- `processing`
- `done`
- `failed`

**Thông tin job cần có**

- `job_id`
- `media_id`
- `session_id`
- `device_id`
- `task_type`
- `progress`
- `created_at`
- `started_at`
- `finished_at`
- `error_message`

### 7.6. Inference Module

**Mục đích**

Chứa logic xử lý AI.

**Giai đoạn đầu**

Chưa cần inference thật, có thể dùng stub:

- Tạo kết quả giả.
- Ghi progress.
- Tạo overlay path mẫu.
- Trả keypoints mẫu.

**Giai đoạn sau**

Thay stub bằng:

- Load checkpoint thật.
- Đọc ảnh hoặc video thật.
- Chạy model.
- Sinh ra keypoints thật.
- Tạo output thật.

**Lưu ý**

Ở bản đầu, inference có thể chạy cùng server. Sau này nếu nặng quá thì tách thành worker riêng.

### 7.7. Result Module

**Mục đích**

Chuẩn hóa đầu ra để mobile dễ dùng.

**Với ảnh**

- Overlay image.
- Keypoints JSON.
- Confidence.
- Summary.

**Với video**

- Processed video path.
- Frame summary.
- Average confidence.
- Số frame detect được.

### 7.8. History Module

**Mục đích**

Cho phép app xem lại kết quả cũ.

**Dữ liệu có thể hiển thị**

- Danh sách job gần đây.
- Thumbnail hoặc overlay path.
- Loại xử lý.
- Thời gian tạo.
- Trạng thái.
- Kết quả cuối.

## 8. Thiết kế database sơ bộ

### 8.1. Bảng `sessions`

Lưu phiên làm việc của app.

| Trường | Mô tả |
| --- | --- |
| `id` | ID của session |
| `token` | Token phiên làm việc |
| `status` | Trạng thái session |
| `created_at` | Thời điểm tạo session |

### 8.2. Bảng `devices`

Lưu thông tin Raspberry Pi.

| Trường | Mô tả |
| --- | --- |
| `id` | ID của thiết bị |
| `device_name` | Tên thiết bị |
| `device_code` | Mã định danh thiết bị |
| `auth_token` | Token xác thực |
| `status` | Trạng thái thiết bị |
| `last_seen` | Thời điểm heartbeat gần nhất |
| `created_at` | Thời điểm tạo thiết bị |

### 8.3. Bảng `device_commands`

Lưu các command gửi cho Pi.

| Trường | Mô tả |
| --- | --- |
| `id` | ID của command |
| `device_id` | Thiết bị nhận lệnh |
| `session_id` | Session phát sinh lệnh |
| `command_type` | Loại lệnh |
| `command_payload` | Payload của lệnh |
| `status` | Trạng thái command |
| `created_at` | Thời điểm tạo lệnh |
| `executed_at` | Thời điểm thực thi |

### 8.4. Bảng `media`

Lưu metadata của file upload.

| Trường | Mô tả |
| --- | --- |
| `id` | ID của media |
| `session_id` | Session liên quan |
| `device_id` | Thiết bị nguồn nếu có |
| `source_type` | Nguồn upload (`app` hoặc `pi`) |
| `media_type` | Loại media |
| `file_name` | Tên file |
| `file_path` | Đường dẫn lưu file |
| `created_at` | Thời điểm tạo record |

### 8.5. Bảng `jobs`

Lưu job xử lý AI.

| Trường | Mô tả |
| --- | --- |
| `id` | ID của job |
| `session_id` | Session liên quan |
| `media_id` | Media đầu vào |
| `device_id` | Thiết bị liên quan nếu có |
| `task_type` | Loại tác vụ xử lý |
| `status` | Trạng thái job |
| `progress` | Tiến độ xử lý |
| `error_message` | Nội dung lỗi nếu thất bại |
| `created_at` | Thời điểm tạo job |
| `started_at` | Thời điểm bắt đầu xử lý |
| `finished_at` | Thời điểm kết thúc xử lý |

### 8.6. Bảng `results`

Lưu kết quả xử lý.

| Trường | Mô tả |
| --- | --- |
| `id` | ID của result |
| `job_id` | Job tương ứng |
| `result_type` | Loại kết quả |
| `overlay_path` | Đường dẫn ảnh overlay |
| `processed_video_path` | Đường dẫn video đã xử lý |
| `keypoints_json` | Dữ liệu keypoints |
| `confidence` | Độ tin cậy |
| `summary_json` | Dữ liệu tổng hợp |
| `created_at` | Thời điểm tạo result |

## 9. Hệ API Backend cần xây

### 9.1. Health API

**Mục đích**

Kiểm tra backend còn hoạt động hay không.

**Endpoint**

- `GET /health`

### 9.2. Session API

**Mục đích**

Tạo session cho app.

**Endpoint**

- `POST /session/create`

**Output**

- `session_id`
- `token`

### 9.3. Device API

**Mục đích**

Quản lý thiết bị Pi.

**Endpoint**

- `GET /devices`
- `POST /devices/register`
- `POST /devices/{device_id}/heartbeat`
- `GET /devices/{device_id}`

### 9.4. Command API

**Mục đích**

Điều khiển Pi.

**Endpoint**

- `POST /devices/{device_id}/commands`
- `GET /devices/{device_id}/commands/pending`
- `POST /devices/{device_id}/commands/{command_id}/ack`
- `POST /devices/{device_id}/commands/{command_id}/complete`

### 9.5. Media API

**Mục đích**

Upload ảnh hoặc video.

**Endpoint**

- `POST /media/upload`
- `GET /media/{media_id}`

### 9.6. Job API

**Mục đích**

Quản lý xử lý AI.

**Endpoint**

- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs`

### 9.7. Result API

**Mục đích**

Trả kết quả cho app.

**Endpoint**

- `GET /results/job/{job_id}`
- `GET /results/{result_id}`

### 9.8. History API

**Mục đích**

Xem lịch sử xử lý.

**Endpoint**

- `GET /history`
- `GET /history/{item_id}`

## 10. Polling Strategy

### 10.1. App Polling

App sẽ polling backend để lấy trạng thái job.

**Ví dụ**

- Cứ 2 giây gọi `GET /jobs/{job_id}`.

**Lý do chọn polling**

- Dễ làm.
- Ít bug hơn WebSocket.
- Phù hợp với MVP.
- Đủ cho demo.

### 10.2. Pi Polling

Pi sẽ polling backend để lấy command mới.

**Ví dụ**

- Cứ 2 giây gọi `GET /devices/{device_id}/commands/pending`.

**Ưu điểm**

- Đơn giản hơn backend push ngược.
- Không cần xử lý realtime phức tạp.
- Dễ chạy trong mạng nội bộ.

## 11. Roadmap triển khai Backend

### Phase 1: Dựng skeleton backend

**Mục tiêu**

Có backend chạy được trên FastAPI.

**Việc cần làm**

- Tạo cấu trúc thư mục.
- Tạo virtual environment.
- Cài dependencies.
- Tạo `main.py`.
- Chạy server ở port `8002`.
- Test `/docs`.

**Kết quả mong muốn**

- Backend boot thành công.
- Vào được Swagger docs.

### Phase 2: Tạo API cơ bản nhất

**Mục tiêu**

Có các API nền tảng để app bắt đầu dùng.

**Việc cần làm**

- `GET /health`
- `POST /session/create`
- Kết nối SQLite.
- Tạo model database đầu tiên.

**Kết quả mong muốn**

- App hoặc Swagger tạo được session.
- Backend trả response chuẩn.

### Phase 3: Device và command flow

**Mục tiêu**

Chuẩn bị hạ tầng cho Raspberry Pi.

**Việc cần làm**

- `POST /devices/register`
- `GET /devices`
- `POST /devices/{id}/heartbeat`
- `POST /devices/{id}/commands`
- `GET /devices/{id}/commands/pending`

**Kết quả mong muốn**

- Backend quản lý được device.
- Command đã có thể lưu và đọc ra.

### Phase 4: Upload media

**Mục tiêu**

Cho app hoặc Pi upload file.

**Việc cần làm**

- Tạo thư mục storage.
- `POST /media/upload`
- Lưu file vào disk.
- Lưu metadata vào database.

**Kết quả mong muốn**

- Upload ảnh thành công.
- Có `media_id`.
- Có file nằm trong `storage/uploads`.

### Phase 5: Job processing stub

**Mục tiêu**

Tạo flow Processing hoàn chỉnh dù chưa dùng model thật.

**Việc cần làm**

- `POST /jobs`
- `GET /jobs/{job_id}`
- Tạo `process_job_stub()`.
- Giả lập trạng thái `queued -> processing -> done`.
- Tạo result giả.

**Kết quả mong muốn**

- App có thể hiển thị Processing screen.
- Backend trả result mẫu.

### Phase 6: Result API

**Mục tiêu**

Cho app lấy kết quả cuối.

**Việc cần làm**

- `GET /results/job/{job_id}`
- Trả `keypoints JSON`.
- Trả `overlay path`.
- Trả `confidence`.

**Kết quả mong muốn**

- App có thể hiển thị Result screen.

### Phase 7: History API

**Mục tiêu**

Cho phép xem lại lịch sử.

**Việc cần làm**

- `GET /history`
- `GET /history/{item_id}`
- Query `jobs/results` theo session.

**Kết quả mong muốn**

- App có thể render History screen.

### Phase 8: Tích hợp Raspberry Pi

**Mục tiêu**

Pi trở thành client thiết bị thật.

**Việc cần làm**

- Pi register vào backend.
- Pi heartbeat định kỳ.
- Pi polling command.
- Pi capture và upload ảnh hoặc video.

**Kết quả mong muốn**

- App ra lệnh được cho Pi.
- Pi gửi dữ liệu thật về backend.

### Phase 9: Tích hợp inference thật

**Mục tiêu**

Thay stub bằng model AI thực sự.

**Việc cần làm**

- Viết `inference_service.py`.
- Load checkpoint.
- Xử lý ảnh thật.
- Xử lý video hoặc frame batch.
- Sinh keypoints thật.
- Tạo output thật.

**Kết quả mong muốn**

- Backend trả kết quả pose estimation thật.

### Phase 10: Tối ưu và hoàn thiện demo

**Mục tiêu**

Ổn định sản phẩm để demo và báo cáo.

**Việc cần làm**

- Xử lý lỗi tốt hơn.
- Giới hạn file upload.
- Thống nhất response format.
- Dọn log.
- Tối ưu storage.
- Bổ sung tài liệu API.

**Kết quả mong muốn**

- Demo mượt.
- Dễ thuyết trình.
- Dễ mở rộng về sau.

## 12. Response format đề xuất

Nên thống nhất format JSON như sau:

```json
{
  "success": true,
  "message": "Job created successfully",
  "data": {
    "job_id": 1,
    "status": "queued"
  }
}
```

Khi lỗi:

```json
{
  "success": false,
  "message": "Device not found",
  "data": null
}
```

### Lợi ích

- Mobile parse dễ.
- Route nào cũng thống nhất.
- Dễ debug.
- Nhìn chuyên nghiệp hơn.

## 13. Rủi ro kỹ thuật và cách xử lý

### 13.1. Upload video quá nặng

**Rủi ro**

- File lớn.
- Upload lâu.
- Timeout.

**Cách xử lý**

- Giới hạn dung lượng.
- Giới hạn thời lượng video.
- Ưu tiên xử lý ảnh ở MVP trước.

### 13.2. Pi offline

**Rủi ro**

- App gửi lệnh nhưng Pi không nhận.
- User tưởng hệ thống bị lỗi.

**Cách xử lý**

- Heartbeat cập nhật trạng thái.
- Màn hình Connect hiển thị rõ `online/offline`.

### 13.3. Model xử lý lâu

**Rủi ro**

- App bị chờ lâu.
- Timeout nếu xử lý đồng bộ.

**Cách xử lý**

- Luôn tạo job.
- App polling trạng thái.
- Về sau tách worker nếu cần.

### 13.4. Dữ liệu file bị lộn xộn

**Rủi ro**

- Khó debug.
- Khó tìm kết quả cũ.

**Cách xử lý**

- Đặt tên file theo UUID.
- Chia thư mục `uploads/outputs/temp` rõ ràng.
- Gắn file với `media_id/job_id`.

## 14. Hướng phát triển sau MVP

Sau khi có MVP chạy được, có thể nâng cấp:

- `SQLite -> PostgreSQL`
- `local storage -> object storage`
- `polling -> WebSocket`
- `inference in-process -> background worker`
- `session tạm -> user login đầy đủ`
- `ảnh đơn -> video pipeline hoàn chỉnh`
- `một Pi -> nhiều Pi`
