# 🚀 PoseTrack App - UI Generation Prompts
*Tài liệu tổng hợp các prompt dùng để tạo thiết kế giao diện (UI) cho ứng dụng PoseTrack*

---

## 🎨 1. Prompt gốc thiết lập phong cách (Dùng chung cho toàn bộ app)

> **💡 Lưu ý:** Dùng prompt này đầu tiên để AI hiểu và giữ được sự đồng bộ về style cho các thành phần tiếp theo.

```text
Design a complete mobile app UI kit for a human pose estimation application called PoseTrack.
This must be a real smartphone app UI, not a website, not a desktop dashboard, not a tablet layout, and not a presentation slide.
Use portrait 9:16 aspect ratio, single mobile screen composition, vertical smartphone layout, with proper spacing like a real Android or iPhone app.
Style: dark futuristic blue theme, neon cyan glow accents, minimal modern UI, rounded cards, clean icons, soft shadows, elegant high-tech engineering aesthetic.
The app is used in an AI and IoT project with Raspberry Pi, server processing, and pose estimation results.
Create polished mobile screens suitable for a final-year engineering project demo.
```

---

## 📱 Prompt chi tiết cho từng màn hình (Detailed Screens)

### 2. Splash Screen (Màn hình chờ)
```text
Design a mobile splash screen for a human pose estimation app called PoseTrack.
This must be a single mobile app screen only, portrait 9:16, smartphone UI, not a website, not desktop, not tablet.
Use a dark futuristic blue background with subtle grid lines and soft neon cyan glow.
Place a rounded app icon near the upper center, then the app name “PoseTrack” below it, with the subtitle “Precision AI Motion Analysis”.
Add a slim loading bar and small status text “System Ready”.
Make it look like a polished Android/iPhone splash screen, clean, minimal, elegant, high-tech.
```

### 3. Home / Dashboard Screen (Màn hình chính)
```text
Design a mobile home dashboard screen for the PoseTrack app.
This must be a single smartphone UI screen in portrait 9:16, not a website, not desktop.
Use a modern mobile layout with a dark blue futuristic theme, cyan highlights, rounded cards, and soft shadows.
Include a top header with the app name, a system overview section, a Raspberry Pi status card, a server status card, and a recent session summary card.
Add large rounded action buttons for “Connect Device”, “Start Capture”, “View Results”, “History”, and “Settings”.
Make the design clean, professional, minimal, and easy to use for an AI + IoT engineering project.
```

### 4. Device Connection Screen (Màn hình kết nối thiết bị)
```text
Design a mobile device connection screen for the PoseTrack app.
This must be a single mobile app screen only, portrait 9:16, smartphone layout, not a website, not desktop.
Use a modern dark blue high-tech style with neon cyan accents, rounded cards, and subtle glow.
Show two main connection cards: one for Raspberry Pi and one for Processing Server.
Each card should display connection status, device name, IP address, and a small icon.
Include rounded buttons for “Scan”, “Connect”, and “Reconnect”.
Make it feel like a clean IoT control interface for a mobile application.
```

### 5. Capture Control Screen (Màn hình điều khiển quay/chụp)
```text
Design a mobile capture control screen for the PoseTrack app.
This must be a single smartphone screen in portrait 9:16, not a website, not desktop, not tablet.
Use a clean modern mobile UI with dark futuristic blue colors, cyan glowing accents, rounded elements, and soft shadows.
Include a large camera preview area, a recording timer, capture mode selection for image or video, duration options like 5s, 10s, and 15s, and prominent rounded buttons for “Start Recording”, “Stop Recording”, and “Capture Image”.
The layout should feel practical, minimal, and polished for an engineering project demo.
```

### 6. Processing Status Screen (Màn hình trạng thái xử lý AI)
```text
Design a mobile processing status screen for the PoseTrack app.
This must be a real mobile app screen only, portrait 9:16, smartphone UI, not a website, not desktop.
Use a futuristic dark blue theme with cyan highlights, rounded cards, thin progress indicators, and a clean technical look.
Show a clear progress bar and a step-by-step processing timeline with stages: “Uploading Video”, “Saving to Server”, “Extracting Frames”, “Running Pose Estimation”, and “Generating Results”.
Include percentage progress and a subtle loading animation feel.
Make it look modern, minimal, and suitable for an AI processing workflow on mobile.
```

### 7. Result Screen (Màn hình kết quả)
```text
Design a mobile result screen for the PoseTrack app.
This must be a single smartphone UI screen in portrait 9:16, not a website, not desktop.
Use a modern dark blue high-tech theme with cyan glow, rounded cards, soft shadows, and a clean analytics style.
Display a processed image with human skeleton overlay at the top.
Below that, show result cards for detected keypoints count, confidence score, session ID, and timestamp.
Add a short analysis section with text like “Pose detected successfully” and basic posture feedback.
Include rounded buttons for “View Details”, “Save Result”, and “Back to Home”.
Make it look polished and suitable for an AI engineering mobile app.
```

### 8. History Screen (Màn hình lịch sử)
```text
Design a mobile history screen for the PoseTrack app.
This must be a single mobile app screen only, portrait 9:16, smartphone UI, not a website, not desktop.
Use a dark futuristic blue mobile style with cyan accents, rounded cards, and clear spacing.
Show a scrollable list of previous session cards, each with a thumbnail, date and time, processing status, and a short result summary.
Statuses may include completed, processing, or failed.
Make the design minimal, elegant, and easy to read for a project demo mobile app.
```

### 9. Settings Screen (Màn hình cài đặt)
```text
Design a mobile settings screen for the PoseTrack app.
This must be a single smartphone UI screen in portrait 9:16, not a website, not desktop.
Use a clean dark blue modern mobile style with cyan accent highlights, rounded setting cards, and simple icons.
Include settings sections for Raspberry Pi IP address, server address, default capture mode, recording duration, and auto-upload toggle.
Make the layout clear, balanced, minimal, and realistic as a mobile app settings screen.
```

---

## ⚡ 10. Prompts tóm tắt (Dành cho việc generate nhanh từng màn)

Nếu bạn muốn tạo nhanh từng màn hình mà không cần copy nguyên đoạn dài, hãy dùng các câu lệnh rút gọn sau:

* **🖼️ Splash**
  ```text
  Mobile splash screen for PoseTrack, portrait 9:16 smartphone UI, not website, dark blue futuristic theme, centered app icon, title, subtitle, loading bar.
  ```

* **🏠 Home**
  ```text
  Mobile dashboard screen for PoseTrack, portrait 9:16 smartphone UI, not website, Raspberry Pi status, server status, big action buttons, dark blue high-tech style.
  ```

* **🔗 Connection**
  ```text
  Mobile device connection screen for PoseTrack, portrait 9:16 smartphone UI, not website, Raspberry Pi card, server card, connection status, scan and connect buttons.
  ```

* **📷 Capture**
  ```text
  Mobile capture control screen for PoseTrack, portrait 9:16 smartphone UI, not website, camera preview, timer, mode selector, start and stop buttons.
  ```

* **⚙️ Processing**
  ```text
  Mobile processing status screen for PoseTrack, portrait 9:16 smartphone UI, not website, progress bar, AI workflow steps, dark blue futuristic theme.
  ```

* **📊 Result**
  ```text
  Mobile result screen for PoseTrack, portrait 9:16 smartphone UI, not website, processed image with skeleton overlay, result cards, analysis section.
  ```
