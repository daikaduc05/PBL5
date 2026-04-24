# PBL5 - Implementation Plan cho `form_checker.py`

## 1. Muc tieu cua buoc nay

Hien tai pipeline dang di theo luong:

```text
YOLO -> Pose -> Keypoints -> Angles -> SquatTracker
```

Muc tieu cua buoc tiep theo la nang len thanh:

```text
YOLO -> Pose -> Keypoints -> Angle Validation -> Form Checker -> Visual Feedback
```

Ket qua mong muon:

- phat hien squat dung/sai dang tin cay hon
- giam bao sai khi keypoint bi nhieu hoac thieu
- co 3 trang thai ro rang:
  - `GOOD_FORM`
  - `BAD_FORM`
  - `UNKNOWN`

`UNKNOWN` la trang thai rat quan trong. Khi tu the khong du dieu kien de ket luan, he thong phai bao "khong chac chan" thay vi bao sai.

---

## 2. Vi sao can tach `form_checker.py`

`inference.py` hien dang ganh qua nhieu trach nhiem:

- load model
- detect nguoi
- pose estimation
- tinh angle
- tracking rep
- visualize
- camera demo

Neu tiep tuc nhoi full logic form checker vao `inference.py`, file se kho doc, kho debug, va kho mo rong.

Tach `core_model/form_checker.py` se giup:

- gom toan bo logic danh gia form vao mot cho
- de test doc lap
- de debug khi goc hoac rule bi sai
- de mo rong sang push-up hoac bai khac sau nay
- giu `inference.py` la pipeline ky thuat, con `form_checker.py` la business logic

---

## 3. File can tao

```text
core_model/form_checker.py
```

---

## 4. Nhung gi `form_checker.py` nen chua

### 4.1. Constants cho keypoints

Nen dinh nghia ro cac index dang dung:

```python
KP_L_SHOULDER = 5
KP_R_SHOULDER = 6
KP_L_HIP = 11
KP_R_HIP = 12
KP_L_KNEE = 13
KP_R_KNEE = 14
KP_L_ANKLE = 15
KP_R_ANKLE = 16
```

Co the import tu `inference.py`, nhung tot hon la de rieng hoac gom ve mot file constants sau nay.

---

### 4.2. Form status constants

Nen chuan hoa trang thai:

```python
GOOD_FORM = "GOOD_FORM"
BAD_FORM = "BAD_FORM"
UNKNOWN = "UNKNOWN"
```

---

### 4.3. Angle helper

Co 2 lua chon:

- tiep tuc dung `calculate_angle()` tu `inference.py`
- hoac tao helper rieng trong `form_checker.py`

Khuyen nghi:

- cho phep `form_checker.py` dung doc lap
- tranh phu thuoc nguoc qua nhieu vao `inference.py`

---

### 4.4. Validate keypoints

Tao ham:

```python
validate_squat_keypoints(keypoints: np.ndarray) -> dict
```

#### Muc tieu

Kiem tra xem frame hien tai co du du lieu de danh gia squat hay khong.

#### Dieu kien toi thieu

- phai thay du cac diem can thiet de tinh squat:
  - shoulder
  - hip
  - knee
  - ankle
- it nhat mot ben co the phai day du:
  - ben trai, hoac
  - ben phai

#### Output goi y

```python
{
    "valid": True,
    "reason": None,
    "side": "right"
}
```

hoac:

```python
{
    "valid": False,
    "reason": "Move back - full body required",
    "side": None
}
```

---

### 4.5. Chon ben co the de tinh angle

Tao ham:

```python
select_body_side(keypoints: np.ndarray) -> dict
```

#### Logic de xuat

- neu ben phai du diem va on hon, dung `right`
- neu ben phai khong on nhung ben trai on, dung `left`
- neu ca hai deu on, chon ben on dinh hon
- neu ca hai deu khong du dieu kien, tra `UNKNOWN`

#### Vi sao can buoc nay

Code hien tai dang thien ve fix cung mot ben. Dieu do de lam angle sai khi nguoi tap quay lech hoac mot ben bi che.

---

### 4.6. Tinh squat angles on dinh hon

Tao ham:

```python
compute_squat_angles_stable(keypoints: np.ndarray) -> dict
```

#### Output goi y

```python
{
    "valid": True,
    "side_used": "right",
    "knee": 92.3,
    "hip": 58.7,
    "reason": None
}
```

hoac:

```python
{
    "valid": False,
    "side_used": None,
    "knee": None,
    "hip": None,
    "reason": "Move back - full body required"
}
```

---

### 4.7. Rule check cho squat form

Tao ham:

```python
check_squat_form(knee_min: float, hip_min: float, standing_knee: float) -> dict
```

#### Rule 1: Not deep enough

- neu `knee_min > 100`
- ket qua:

```text
BAD FORM: Not deep enough
```

#### Rule 2: Back leaning too much

- neu `hip_min < 45`
- ket qua:

```text
BAD FORM: Back leaning too much
```

#### Rule 3: Stand up fully

- neu `standing_knee < 155`
- ket qua:

```text
BAD FORM: Stand up fully
```

#### Neu khong vi pham rule nao

```text
GOOD FORM
```

#### Output goi y

```python
{
    "status": GOOD_FORM,
    "message": "GOOD FORM",
    "reasons": []
}
```

hoac:

```python
{
    "status": BAD_FORM,
    "message": "BAD FORM: Not deep enough",
    "reasons": ["not_deep_enough"]
}
```

Luu y:

- cac threshold nay nen de duoi dang constants hoac config, khong hard-code rai rac
- sau khi test thuc te co the can tune lai

---

### 4.8. Tracker theo tung rep

Tao class:

```python
class SquatFormTracker:
    ...
```

Day la phan quan trong nhat cua feature nay.

---

## 5. `SquatFormTracker` nen lam gi

### 5.1. State can co

- `counter`
- `stage`
- `up_threshold`
- `down_threshold`
- `current_rep_knee_min`
- `current_rep_hip_min`
- `last_form_status`
- `last_feedback_text`
- `last_feedback_until`
- `last_rep_summary`

Co the bo sung:

- `standing_knee_latest`
- `side_used`
- `valid_pose`

---

### 5.2. Logic `update()`

Tao method:

```python
update(angle_info: dict) -> dict
```

#### Flow de xuat

1. neu keypoint invalid:
   - khong tang rep
   - tra `UNKNOWN`
2. neu valid:
   - update `knee_min`, `hip_min`
   - cap nhat `stage`
3. khi rep ket thuc:
   - evaluate form theo rep
   - tang counter
   - luu feedback
   - reset state cho rep tiep theo

---

### 5.3. Vi sao phai danh gia theo rep

Khong nen ket luan dua tren mot frame don le:

- frame nay angle xau khong co nghia ca rep xau
- frame nay thieu keypoint khong co nghia nguoi tap sai

Nen lam:

- theo doi mot rep hoan chinh
- lay cac gia tri quan trong nhu:
  - `knee_min`
  - `hip_min`
  - `standing_knee`
- chi ket luan khi rep ket thuc

Loi ich:

- giam nhieu
- tranh doi mau lien tuc theo tung frame
- feedback dang tin cay hon nhieu

---

## 6. Output cua tracker nen co gi

Moi lan `update()` nen tra ra object kieu:

```python
{
    "rep_count": 3,
    "stage": "up",
    "status": "GOOD_FORM",
    "message": "GOOD FORM",
    "knee_angle": 168.2,
    "hip_angle": 171.1,
    "knee_min": 94.0,
    "hip_min": 58.2,
    "side_used": "right",
    "valid_pose": True
}
```

hoac neu khong du dieu kien:

```python
{
    "rep_count": 3,
    "stage": "up",
    "status": "UNKNOWN",
    "message": "Move back - full body required",
    "valid_pose": False
}
```

---

## 7. Cach gan vao `inference.py`

### 7.1. Trong `predict_pose_for_crops()`

Hien tai moi detection dang co dang:

```python
{
    "bbox": ...,
    "keypoints": ...,
    "angles": ...
}
```

Can sua theo huong:

- thay `compute_squat_angles()` bang `compute_squat_angles_stable()`
- neu invalid thi dat:
  - `form_status = UNKNOWN`
  - `form_feedback = <reason>`

Vi du:

```python
{
    "bbox": ...,
    "keypoints": ...,
    "angles": {
        "knee": 92.0,
        "hip": 58.0
    },
    "form_status": "UNKNOWN",
    "form_feedback": "Move back - full body required",
    "side_used": "right",
    "valid_pose": True
}
```

---

### 7.2. Trong `run_camera_demo()`

Hien tai dang dung:

```python
tracker = SquatTracker()
```

Can thay bang:

```python
tracker = SquatFormTracker()
```

va goi:

```python
form_info = tracker.update(angle_info)
```

Sau do hien thi:

- rep count
- stage
- form status
- feedback message
- `knee_min`
- `hip_min`

---

### 7.3. Trong `visualize_pose()`

Hien tai dang to mau theo index detection.

Can doi sang to mau theo `form_status`:

- `GOOD_FORM` -> xanh la
- `BAD_FORM` -> do
- `UNKNOWN` -> vang

Dieu nay giup UI dung voi muc tieu:

- form dung -> xanh
- form sai -> do
- khong du dieu kien de ket luan -> vang

---

### 7.4. Trong `serialize_pose_results()`

Bo sung them cac field:

- `form_status`
- `form_feedback`
- `side_used`
- `valid_pose`

de backend/app co the doc JSON chi tiet hon.

Neu ve sau can overlay realtime tren app, nen giu them:

- `keypoints_normalized`
- `angles`
- `rep_count`
- `stage`

---

## 8. Thu tu code nen follow

### Buoc 1

Tao `form_checker.py` voi:

- constants
- `calculate_angle()`
- `validate_squat_keypoints()`
- `select_body_side()`
- `compute_squat_angles_stable()`

### Buoc 2

Viet `check_squat_form()`

### Buoc 3

Viet `SquatFormTracker`

### Buoc 4

Gan `form_checker.py` vao `inference.py`

### Buoc 5

Sua `visualize_pose()` de doi mau theo form

### Buoc 6

Sua `serialize_pose_results()` de output JSON day du

---

## 9. Cach test dung

### Test 1: full body valid

- dung thang truoc camera
- dam bao thay:
  - shoulder
  - hip
  - knee
  - ankle

Ky vong:

- `valid_pose = True`
- angles hop ly

### Test 2: body bi cat

- dung qua gan
- khong thay chan day du

Ky vong:

- `status = UNKNOWN`
- `message = Move back - full body required`

### Test 3: squat du sau

Ky vong:

- `GOOD_FORM`

### Test 4: squat nong

Ky vong:

- `BAD_FORM: Not deep enough`

### Test 5: gap nguoi nhieu

Ky vong:

- `BAD_FORM: Back leaning too much`

---

## 10. Nhung gi chua can lam ngay

- chua can train lai model
- chua can lam push-up song song trong cung buoc nay
- chua can toi uu da nguoi
- chua can dua het len app truoc khi camera demo chay on

---

## 11. Ket luan

Buoc tiep theo hop ly nhat la:

```text
Tao form_checker.py
-> on dinh angle
-> danh gia squat theo rep
-> doi mau UI theo GOOD/BAD/UNKNOWN
```

Day la huong di phu hop voi:

- code hien tai
- muc tieu form checker
- trang thai thuc te cua model

Neu di theo luong nay, du an se co mot `squat form checker` dang tin cay hon ma khong can dap lai toan bo pipeline hien co.
