# 🏃 Human Pose Estimation với MoveNet

## 📋 Giới thiệu tổng quan

Notebook này hướng dẫn cách sử dụng **MoveNet** - mô hình phát hiện tư thế (Pose Detection) thế hệ mới từ Google Research. MoveNet có khả năng phát hiện **17 điểm keypoint** trên cơ thể người với độ chính xác cao và tốc độ xử lý nhanh.

---

## 🧠 Kiến trúc MoveNet

### Nguyên lý hoạt động

MoveNet sử dụng phương pháp **heatmap** để định vị chính xác các keypoint trên cơ thể người. Đây là mô hình **bottom-up estimation**, nghĩa là:

1. **Bước 1:** Phát hiện tất cả các khớp (joints) của mọi người trong ảnh
2. **Bước 2:** Ghép nối các khớp này thành tư thế hoàn chỉnh cho từng người

### 2 Thành phần chính

| Thành phần | Mô tả |
|------------|-------|
| **Feature Extractor** | Sử dụng MobileNetV2 kết hợp với Feature Pyramid Network (FPN) |
| **Predictor Heads** | Bộ các head dự đoán được gắn vào feature extractor |

### Các nhiệm vụ của Predictor Heads:
- 📍 Dự đoán **tâm hình học** của các instances (người)
- 🦴 Dự đoán **bộ đầy đủ keypoints** cho mỗi người
- 📌 Dự đoán **vị trí tất cả keypoints**
- 🎯 Tính toán **local offsets** từ mỗi pixel trong feature map đến vị trí sub-pixel chính xác của keypoint

---

## ⚡ Các phiên bản MoveNet

| Phiên bản | Mục đích sử dụng |
|-----------|------------------|
| **Lightning** | Ứng dụng yêu cầu độ trễ thấp (low latency) |
| **Thunder** | Ứng dụng yêu cầu độ chính xác cao |

> 📝 *Notebook này sử dụng phiên bản **Multipose Lightning**, có khả năng phát hiện nhiều người (tối đa 6 người) cùng lúc.*

---

## 📚 Thư viện sử dụng

```python
import cv2              # Thư viện Computer Vision
import imageio          # Tạo file GIF
import matplotlib.pyplot as plt  # Hiển thị đồ họa
import numpy as np      # Xử lý tính toán
import tensorflow as tf # Deep Learning framework
import tensorflow_hub as hub     # Tải model từ TF Hub
```

---

## 🔧 Các bước thực hiện

### 1️⃣ Thiết lập màu sắc cho các edges
- Định nghĩa màu **Cyan** và **Magenta** cho các cạnh nối giữa các keypoints
- Mapping các cặp keypoints với màu tương ứng

### 2️⃣ Tải model từ TensorFlow Hub
```python
model = hub.load("https://tfhub.dev/google/movenet/multipose/lightning/1")
movenet = model.signatures["serving_default"]
```

### 3️⃣ Điều chỉnh kích thước input
- Chiều cao/rộng phải là **bội số của 32**
- Tỷ lệ height/width gần với tỷ lệ gốc
- Cạnh lớn hơn đặt là **256 pixel**

### 4️⃣ Vẽ Keypoints
- Chuẩn hóa ngược (denormalize) tọa độ bằng cách nhân với kích thước input
- Vẽ hình tròn tại mỗi keypoint có confidence score > threshold

### 5️⃣ Vẽ Edges (cạnh nối)
- Duyệt qua các cặp keypoints đã định nghĩa
- Vẽ đường thẳng nối giữa 2 điểm nếu cả hai có confidence > threshold

### 6️⃣ Chạy Inference
- Đọc từng frame từ GIF input
- Resize về kích thước 256x256
- Đưa qua model để dự đoán keypoints
- Vẽ keypoints và edges lên frame
- Xuất ra file GIF kết quả

---

## 📊 Output của Model

**Shape:** `[1, 6, 56]`
- `1`: Batch size
- `6`: Số instances (tối đa 6 người)
- `56`: 51 giá trị đầu là tọa độ xy và score của 17 keypoints (17 × 3 = 51), 5 giá trị còn lại là bounding box

---

## 🎯 17 Keypoints được phát hiện

```
0: Mũi (nose)
1-2: Mắt trái/phải
3-4: Tai trái/phải
5-6: Vai trái/phải
7-8: Khuỷu tay trái/phải
9-10: Cổ tay trái/phải
11-12: Hông trái/phải
13-14: Đầu gối trái/phải
15-16: Mắt cá chân trái/phải
```

---

## 🔗 Tham khảo

- [TensorFlow Hub - MoveNet](https://tfhub.dev/google/movenet/multipose/lightning/1)
- [MobileNetV2 Paper](https://arxiv.org/pdf/1801.04381.pdf)
- [Bottom-up Pose Estimation Paper](https://arxiv.org/pdf/1807.09972.pdf)
- [TensorFlow Blog - MoveNet](https://blog.tensorflow.org/2021/05/next-generation-pose-detection-with-movenet-and-tensorflowjs.html)

---

## 👨‍💻 Tác giả

**Ibrahim SEROUIS** - 2022

---

*📌 Notebook này được sử dụng cho mục đích học tập và nghiên cứu về Human Pose Estimation.*
