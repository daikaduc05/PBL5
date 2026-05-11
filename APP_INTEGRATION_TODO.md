# 🚀 PoseTrack App - Checklist Nối API Thật (End-to-End)

Tài liệu này liệt kê các bước cuối cùng để hoàn thiện dự án, gỡ bỏ toàn bộ **Mock Data** trong ứng dụng Flutter và đấu nối trực tiếp với **Real Backend API**.

---

## 📍 1. Màn hình Capture (Chụp/Quay thật)
**Mục tiêu:** Khi người dùng bấm "Start Recording" hoặc "Capture Image", lệnh phải được gửi xuống Pi để camera bật lên.
- **File cần sửa:** `mobile_app/lib/screens/capture_control_screen.dart`
- **Việc cần làm:**
  - Thay vì gọi `MockPoseTrackingService().createCaptureDraft()`, hãy gọi `ApiService().createSession()` để tạo một phiên xử lý mới.
  - Sau khi có `session_id`, tiếp tục gọi `ApiService().createDeviceCommand()` truyền vào `command_type` (ví dụ: `start_recording` hoặc `capture_photo`).
  - Lắng nghe phản hồi từ API để xác nhận lệnh đã được đẩy vào queue của Pi thành công.

## 📍 2. Màn hình Processing Status (Tiến trình xử lý thật)
**Mục tiêu:** Thanh Progress Bar phải phản ánh đúng tốc độ mạng và tốc độ xử lý AI thật của Server.
- **File cần sửa:** `mobile_app/lib/screens/processing_status_screen.dart`
- **Việc cần làm:**
  - Thiết lập cơ chế **Polling** (gọi API định kỳ mỗi 2-3 giây) bằng hàm `ApiService().getDeviceCommandStatus()` hoặc kiểm tra trạng thái của Session.
  - Mapping trạng thái backend (ví dụ: `queued`, `processing`, `done`, `failed`) tương ứng với các step UI hiển thị: "Uploading...", "Extracting Frames...", "Running Pose Estimation...".
  - Khi trạng thái chuyển sang `done`, tự động điều hướng (Navigate) sang màn hình Result.

## 📍 3. Màn hình History (Hiển thị lịch sử phiên thật)
**Mục tiêu:** Hiển thị danh sách tất cả các phiên người dùng đã chụp từ trước đến nay được lưu trên database.
- **File cần sửa:** `mobile_app/lib/screens/history_screen.dart`
- **Việc cần làm:**
  - Xóa mảng `_history` tĩnh từ Mock Service.
  - Gọi hàm `ApiService().getHistory()` khi màn hình khởi tạo (`initState`).
  - Bóc tách mảng trả về thành danh sách hiển thị, lưu ý xử lý các trạng thái lỗi hoặc empty (nếu chưa có phiên chụp nào).

## 📍 4. Màn hình Result (Hiển thị kết quả AI thật)
**Mục tiêu:** Hiển thị chính xác ảnh đã vẽ khung xương và các thông số Pose (độ chính xác, tọa độ điểm) từ Server.
- **File cần sửa:** `mobile_app/lib/screens/result_screen.dart` (và có thể là `result_frame_detail_screen.dart`)
- **Việc cần làm:**
  - Gọi hàm `ApiService().getHistoryDetail(historyId)` để lấy toàn bộ thông tin chi tiết về phiên xử lý.
  - Lấy `pose_image_url` từ kết quả trả về, kết hợp với IP của Server (từ Settings) để tải ảnh hiển thị lên UI bằng `Image.network()`.
  - Hiển thị các phân tích (số khớp nhận diện, form squat có chuẩn không,...) từ object JSON thật.

---

> [!TIP]
> **Thứ tự thực hiện đề xuất:** 
> Nên làm **Màn hình History** trước (vì data dễ kéo và hiển thị nhất), sau đó làm màn **Result** để xem được ảnh thật. 
> Cuối cùng mới làm luồng **Capture -> Processing** vì nó đòi hỏi tương tác hai chiều và đợi kết quả từ Pi.
