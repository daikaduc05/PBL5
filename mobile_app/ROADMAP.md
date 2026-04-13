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

## 📱 2. Prompt chi tiết cho từng màn hình (Detailed Screens)

### 2.1. Splash Screen (Màn hình chờ)
```text
Design a mobile splash screen for a human pose estimation app called PoseTrack.
This must be a single mobile app screen only, portrait 9:16, smartphone UI, not a website, not desktop, not tablet.
Use a dark futuristic blue background with subtle grid lines and soft neon cyan glow.
Place a rounded app icon near the upper center, then the app name “PoseTrack” below it, with the subtitle “Precision AI Motion Analysis”.
Add a slim loading bar and small status text “System Ready”.
Make it look like a polished Android/iPhone splash screen, clean, minimal, elegant, high-tech.
```

### 2.2. Home / Dashboard Screen (Màn hình chính)
```text
Design a mobile home dashboard screen for the PoseTrack app.
This must be a single smartphone UI screen in portrait 9:16, not a website, not desktop.
Use a modern mobile layout with a dark blue futuristic theme, cyan highlights, rounded cards, and soft shadows.
Include a top header with the app name, a system overview section, a Raspberry Pi status card, a server status card, and a recent session summary card.
Add large rounded action buttons for “Connect Device”, “Start Capture”, “View Results”, “History”, and “Settings”.
Make the design clean, professional, minimal, and easy to use for an AI + IoT engineering project.
```

### 2.3. Device Connection Screen (Màn hình kết nối thiết bị)
```text
Design a mobile device connection screen for the PoseTrack app.
This must be a single mobile app screen only, portrait 9:16, smartphone layout, not a website, not desktop.
Use a modern dark blue high-tech style with neon cyan accents, rounded cards, and subtle glow.
Show two main connection cards: one for Raspberry Pi and one for Processing Server.
Each card should display connection status, device name, IP address, and a small icon.
Include rounded buttons for “Scan”, “Connect”, and “Reconnect”.
Make it feel like a clean IoT control interface for a mobile application.
```

### 2.4. Capture Control Screen (Màn hình điều khiển quay/chụp)
```text
Design a mobile capture control screen for the PoseTrack app.
This must be a single smartphone screen in portrait 9:16, not a website, not desktop, not tablet.
Use a clean modern mobile UI with dark futuristic blue colors, cyan glowing accents, rounded elements, and soft shadows.
Include a large camera preview area, a recording timer, capture mode selection for image or video, duration options like 5s, 10s, and 15s, and prominent rounded buttons for “Start Recording”, “Stop Recording”, and “Capture Image”.
The layout should feel practical, minimal, and polished for an engineering project demo.
```

### 2.5. Processing Status Screen (Màn hình trạng thái xử lý AI)
```text
Design a mobile processing status screen for the PoseTrack app.
This must be a real mobile app screen only, portrait 9:16, smartphone UI, not a website, not desktop.
Use a futuristic dark blue theme with cyan highlights, rounded cards, thin progress indicators, and a clean technical look.
Show a clear progress bar and a step-by-step processing timeline with stages: “Uploading Video”, “Saving to Server”, “Extracting Frames”, “Running Pose Estimation”, and “Generating Results”.
Include percentage progress and a subtle loading animation feel.
Make it look modern, minimal, and suitable for an AI processing workflow on mobile.
```

### 2.6. Result Screen (Màn hình kết quả)
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

### 2.7. History Screen (Màn hình lịch sử)
```text
Design a mobile history screen for the PoseTrack app.
This must be a single mobile app screen only, portrait 9:16, smartphone UI, not a website, not desktop.
Use a dark futuristic blue mobile style with cyan accents, rounded cards, and clear spacing.
Show a scrollable list of previous session cards, each with a thumbnail, date and time, processing status, and a short result summary.
Statuses may include completed, processing, or failed.
Make the design minimal, elegant, and easy to read for a project demo mobile app.
```

### 2.8. Settings Screen (Màn hình cài đặt)
```text
Design a mobile settings screen for the PoseTrack app.
This must be a single smartphone UI screen in portrait 9:16, not a website, not desktop.
Use a clean dark blue modern mobile style with cyan accent highlights, rounded setting cards, and simple icons.
Include settings sections for Raspberry Pi IP address, server address, default capture mode, recording duration, and auto-upload toggle.
Make the layout clear, balanced, minimal, and realistic as a mobile app settings screen.
```

---

## ⚡ 3. Prompts Tóm Tắt (Quick Generate)

*Nếu bạn muốn tạo nhanh từng màn hình mà không cần copy nguyên đoạn dài, hãy dùng các câu lệnh rút gọn sau:*

* **🖼️ Splash:** `Mobile splash screen for PoseTrack, portrait 9:16 smartphone UI, not website, dark blue futuristic theme, centered app icon, title, subtitle, loading bar.`
* **🏠 Home:** `Mobile dashboard screen for PoseTrack, portrait 9:16 smartphone UI, not website, Raspberry Pi status, server status, big action buttons, dark blue high-tech style.`
* **🔗 Connection:** `Mobile device connection screen for PoseTrack, portrait 9:16 smartphone UI, not website, Raspberry Pi card, server card, connection status, scan and connect buttons.`
* **📷 Capture:** `Mobile capture control screen for PoseTrack, portrait 9:16 smartphone UI, not website, camera preview, timer, mode selector, start and stop buttons.`
* **⚙️ Processing:** `Mobile processing status screen for PoseTrack, portrait 9:16 smartphone UI, not website, progress bar, AI workflow steps, dark blue futuristic theme.`
* **📊 Result:** `Mobile result screen for PoseTrack, portrait 9:16 smartphone UI, not website, processed image with skeleton overlay, result cards, analysis section.`

---

## 🛠️ 4. Roadmap & Development Phases (Cho IDE AI)

*Các bước dùng AI để xây dựng Mobile App từ ý tưởng đến hoàn thiện*

### 🚀 Phase 1: Khởi tạo Project & Design System
**🎯 Mục tiêu:** Tạo bộ khung app sạch ngay từ đầu.
**📦 Cần có:**
- Project mobile
- Folder structure
- Theme màu
- Reusable components
- Typography
- Button/card style

**📂 Thư mục tổ chức mẫu:**
```text
src/
  screens/
  components/
  navigation/
  theme/
  services/
  utils/
  assets/
```

**💬 Prompt cho IDE:**
```text
Create the initial structure for a mobile app called PoseTrack.

Tech goals:
- clean scalable project structure
- folders: screens, components, navigation, theme, services, utils, assets
- modern reusable design system
- dark futuristic blue theme with cyan glow accents
- rounded cards, soft shadows, clean typography
- reusable components for AppButton, StatusCard, SectionTitle, ScreenContainer

Please generate:
1. folder structure suggestion
2. base theme file with colors, spacing, border radius, typography
3. reusable UI components
4. coding style that keeps the app modular and easy to extend

This is a mobile app for an AI + Raspberry Pi + server-based human pose estimation project.
Keep the code clean and beginner-friendly.
```

### 🚀 Phase 2: Code Splash Screen
**🎯 Mục tiêu:** Làm màn hình mở app đẹp, chuẩn UI mobile.
**📦 Thành phần:** Icon app, tên PoseTrack, subtitle, loading bar, status text.

**💬 Prompt cho IDE:**
```text
Create a SplashScreen for a mobile app called PoseTrack.

UI requirements:
- mobile portrait layout
- centered app icon
- app title: PoseTrack
- subtitle: Precision AI Motion Analysis
- slim loading bar
- small status text: System Ready
- dark futuristic blue background
- subtle grid effect or soft tech glow
- minimal, polished, professional style

Coding requirements:
- create this as a separate screen component
- use reusable styles from the theme
- keep the layout responsive for phone screens
- avoid web-like layout
- make it look like a real mobile splash screen

Also include a simple timed navigation placeholder to Home screen.
```

### 🚀 Phase 3: Code Home / Dashboard
**🎯 Mục tiêu:** Tạo màn hình trung tâm của app.
**📦 Thành phần:** Header, Raspberry Pi status, Server status, Recent session card, Các nút điều hướng chính.

**💬 Prompt cho IDE:**
```text
Create a HomeScreen / DashboardScreen for the PoseTrack mobile app.

UI requirements:
- top header with app title
- system overview area
- status cards for Raspberry Pi and Processing Server
- recent session summary card
- large rounded action buttons:
  - Connect Device
  - Start Capture
  - View Results
  - History
  - Settings
- dark blue futuristic theme with cyan accents
- clean spacing, rounded cards, soft shadows

Functional requirements:
- build this as a modular screen
- use reusable card and button components
- prepare button handlers for navigation, even if they are placeholders
- keep the code readable and scalable

This is a real mobile app screen, not a website layout.
```

### 🚀 Phase 4: Code Device Connection Screen
**🎯 Mục tiêu:** Hiển thị trạng thái kết nối và điều khiển (Scan / Connect).
**📦 Thành phần:** Card Raspberry Pi, Card Server, Device name, IP, Status, Nút Scan / Connect / Reconnect.

**💬 Prompt cho IDE:**
```text
Create a DeviceConnectionScreen for the PoseTrack mobile app.

UI requirements:
- mobile portrait layout
- two main connection cards:
  1. Raspberry Pi
  2. Processing Server
- each card should show:
  - device name
  - IP address
  - connection status
  - small status icon
- add buttons:
  - Scan
  - Connect
  - Reconnect
- use rounded cards, dark blue background, cyan highlights, modern mobile UI

Functional requirements:
- use mock connection state for now: connected, disconnected, connecting
- structure the code so real API logic can be added later
- create reusable status badge / connection chip if useful
- include placeholder functions for scan and connect actions

Keep the design simple, technical, and suitable for an engineering project demo.
```

### 🚀 Phase 5: Code Capture Control Screen
**🎯 Mục tiêu:** Màn hình thao tác quay/chụp ảnh để test AI Pose Tracking.
**📦 Thành phần:** Preview placeholder, Timer, Mode selector, Duration selector, Start/Stop/Capture buttons.

**💬 Prompt cho IDE:**
```text
Create a CaptureControlScreen for the PoseTrack mobile app.

UI requirements:
- large preview area for camera placeholder
- recording timer display
- capture mode selector: Image / Video
- duration selector: 5s / 10s / 15s
- rounded action buttons:
  - Start Recording
  - Stop Recording
  - Capture Image
- modern mobile layout
- dark futuristic blue theme with cyan accents
- clean spacing and polished card-based design

Functional requirements:
- use local state for selected mode, selected duration, and recording state
- simulate recording timer behavior
- prepare callback handlers for future backend integration
- keep business logic separated from UI as much as possible

Make this look like a practical smartphone control screen, not a web dashboard.
```

### 🚀 Phase 6: Code Processing Status Screen
**🎯 Mục tiêu:** Hiển thị cho người dùng biết app đang xử lý ở tiến trình nào.
**📦 Thành phần:** Progress bar, Step list, Trạng thái từng bước, Animation loading.

**💬 Prompt cho IDE:**
```text
Create a ProcessingStatusScreen for the PoseTrack mobile app.

UI requirements:
- a progress bar at the top or center
- step-by-step processing timeline with stages:
  - Uploading Video
  - Saving to Server
  - Extracting Frames
  - Running Pose Estimation
  - Generating Results
- current percentage progress
- active stage highlight
- modern, futuristic mobile UI
- dark blue theme with cyan accent color
- rounded cards and clean spacing

Functional requirements:
- simulate progress using mock data or timed state updates
- structure the code so real processing status from backend can replace the mock state later
- add a placeholder behavior to navigate to Result screen when processing is complete

Keep it simple, readable, and suitable for a mobile engineering demo.
```

### 🚀 Phase 7: Code Result Screen
**🎯 Mục tiêu:** Trình bày kết quả AI xuất ra sau khi Tracking.
**📦 Thành phần:** Result image, Skeleton layout overlay placeholder, Result cards, Feedback, Action buttons

**💬 Prompt cho IDE:**
```text
Create a ResultScreen for the PoseTrack mobile app.

UI requirements:
- top section showing a processed image placeholder with human skeleton overlay style
- result info cards for:
  - keypoints count
  - confidence score
  - session ID
  - timestamp
- analysis section with text like:
  - Pose detected successfully
  - posture feedback placeholder
- action buttons:
  - View Details
  - Save Result
  - Back to Home
- dark blue futuristic mobile design
- cyan glow accents, rounded cards, soft shadows

Functional requirements:
- use mock result data for now
- keep the screen modular so real backend result objects can be plugged in later
- separate display components for result items if appropriate

This should look like a real mobile analytics result screen.
```

### 🚀 Phase 8: Code History Screen
**🎯 Mục tiêu:** Xem lại danh sách các phiên chụp và theo dõi cũ.
**📦 Thành phần:** List sessions, Thumbnail, Date/Time, Status, Short summary.

**💬 Prompt cho IDE:**
```text
Create a HistoryScreen for the PoseTrack mobile app.

UI requirements:
- scrollable list of previous session cards
- each card should show:
  - thumbnail placeholder
  - date and time
  - processing status
  - short result summary
- statuses may include completed, processing, failed
- use rounded cards, dark blue background, cyan highlights, clean mobile layout

Functional requirements:
- use mock session history data
- create reusable history item component if helpful
- allow tapping a session card to navigate to the Result screen
- keep the code clean and ready for future backend integration
```

### 🚀 Phase 9: Code Settings Screen
**🎯 Mục tiêu:** Quản lý tham số kết nối hệ thống và thông tin mặc định.
**📦 Thành phần:** Raspberry Pi IP, Server address, Default mode, Default duration, Auto upload toggle.

**💬 Prompt cho IDE:**
```text
Create a SettingsScreen for the PoseTrack mobile app.

UI requirements:
- clean mobile settings layout with grouped cards
- fields for:
  - Raspberry Pi IP address
  - server address
  - default capture mode
  - recording duration
  - auto-upload toggle
- dark blue futuristic style
- rounded setting cards and simple clean controls

Functional requirements:
- use local state for all settings
- structure the code so settings can later be persisted
- create reusable settings row/item component if useful
- keep it mobile-friendly and easy to understand
```

### 🚀 Phase 10: Gắn Navigation (Router Flow) Tới Mọi Màn Hình
**🎯 Mục tiêu:** Liên kết các màn hình thành Flow luân chuyển tự nhiên.
**🧭 Luồng Navigation (Flow):** `Splash → Home → Connection → Capture → Processing → Result → History` (tất cả có thể Back về Home/Settings).

**💬 Prompt cho IDE:**
```text
Set up navigation for the PoseTrack mobile app.

Required app flow:
- Splash -> Home
- Home -> Device Connection
- Home -> Capture Control
- Home -> Result
- Home -> History
- Home -> Settings
- Device Connection -> Capture Control
- Capture Control -> Processing Status
- Processing Status -> Result
- Result -> History
- Result -> Home
- History -> Result
- Settings -> Home

Requirements:
- organize routes clearly
- use readable screen names
- keep navigation scalable and clean
- include placeholder params where useful, such as passing session info from Processing to Result
- keep the code beginner-friendly and modular
```

### 🚀 Phase 11: Setup Mock Data & Mock Service Layer
**🎯 Mục tiêu:** Giúp App có thể dùng thử (như thật) trước khi nối với System Server AI.
**📦 Thành phần:** Mock Pi status, Mock server status, Mock result, Mock history, Mock processing progress.

**💬 Prompt cho IDE:**
```text
Create a mock service layer for the PoseTrack mobile app so the UI can work before real backend integration.

Please generate:
- mock Raspberry Pi connection status
- mock server status
- mock capture session data
- mock processing progress stages
- mock pose estimation result data
- mock session history data

Architecture requirements:
- keep mock data separate from screens
- place it in services or mock data files
- provide simple functions that screens can call
- make it easy to replace these functions later with real API requests

The goal is to let the full app flow work in the IDE with realistic fake data.
```

### 🚀 Phase 12: Integate Real Backend (Kết nối API thật)
**🎯 Mục tiêu:** Bước cuối, chuyển các Endpoint Mocking sang Real Backend API Server / Raspberry Pi.

**💬 Prompt cho IDE:**
```text
Refactor the PoseTrack mobile app to prepare for real backend integration.

Requirements:
- separate API logic from UI components
- create service functions for:
  - get device status
  - connect device
  - start capture
  - stop capture
  - upload media
  - get processing status
  - get result by session ID
  - get history
  - save settings
- keep the UI unchanged as much as possible
- add loading states and basic error handling
- design the code so mock services can easily be swapped with real API calls later
```