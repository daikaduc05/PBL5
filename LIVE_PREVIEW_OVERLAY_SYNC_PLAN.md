# PBL5 - Implementation Plan cho live preview sync + overlay

## 1. Purpose

File nay la working plan cho huong can bang:

```text
preview Pi phai muot hon
+ overlay live chi duoc ve khi frame khop hoac gan khop
```

Muc tieu khong phai la viet lai toan bo sang RTSP/WebRTC ngay.
Muc tieu la giu duoc kien truc hien tai cang nhieu cang tot, nhung van cai thien
ro ret trai nghiem tren man `Capture`.

---

## 2. Current Problem

Hien tai he thong co 2 luong rieng:

```text
Luong 1: Pi preview socket -> mobile app -> Image.memory
Luong 2: Pi frame -> ZMQ -> worker -> result JSON -> app poll -> overlay
```

Van de:

- preview socket hien dang cap FPS thap
- overlay live dang dua tren result moi nhat, nhung khong biet co dung cung
  frame voi preview hien tai hay khong
- preview va overlay vi the co the bi "lech nhau"
- neu worker cham, user thay camera live va bbox/status khong khop

---

## 3. Target Outcome

Sau khi hoan thanh plan nay:

- camera preview tu Raspberry Pi muot hon ro ret tren man `Capture`
- overlay live chi hien khi frame preview va frame inference du khop
- neu frame chua khop, app van hien status text nhu:
  - `GOOD`
  - `BAD`
  - `UNKNOWN`
  - `rep`
  - `stage`
- he thong van tiep tuc dung worker + result JSON cho MVP hien tai

---

## 3.1. Phase 0 Baseline Snapshot

Baseline tu codebase hien tai truoc khi tune:

- idle preview FPS mac dinh: `3`
- recording preview FPS mac dinh: `3`
- camera capture FPS mac dinh: `10`
- preview JPEG quality mac dinh: `55`
- preview max size mac dinh: `480x360`
- mobile app hien chua gui ro:
  - `camera_fps`
  - `camera_width`
  - `camera_height`

Ket luan Phase 0:

- preview lag co kha nang cao den tu viec preview bi cap FPS qua thap
- can tune preview truoc khi sua protocol sync

---

## 4. Non-Goals

Buoc nay chua lam cac viec sau:

- khong chuyen sang RTSP
- khong chuyen sang WebRTC
- khong chay PyTorch bang GPU cua Raspberry Pi
- khong giai quyet multi-person identity tracking
- khong dat muc "perfect realtime overlay"

Neu can muc realtime cao hon nua, do se la phase sau va co the can doi transport.

---

## 5. Architecture Decision

Huong duoc chon:

```text
giu preview socket rieng de uu tien do muot
+ them frame_id vao preview protocol
+ app chi ve overlay khi preview frame va inference frame match
```

Ly do:

- it pha vo code hien tai
- preview khong bi chan boi worker
- overlay bot "troi" so voi hinh
- co duong nang cap dan dan, khong can rewrite lon ngay

---

## 6. Current Flow vs Target Flow

### 6.1. Current flow

```text
Pi camera
-> preview jpeg socket
-> app hien preview

Pi camera
-> jpeg frame qua ZMQ
-> worker infer
-> ghi pose.jpg + result.json
-> app poll /results/{session}/{frame}
-> ve overlay bang result moi nhat
```

### 6.2. Target flow

```text
Pi camera
-> tao frame_id tang dan trong luc record
-> preview socket gui: metadata + jpeg bytes
-> ZMQ frame gui: cung frame_id do

Worker
-> infer
-> ghi result.json cho frame_id do

App
-> nhan preview frame + frame_id
-> poll inference result + frame_id
-> chi ve overlay khi abs(preview_frame_id - result_frame_id) <= 1
```

---

## 7. Preview Protocol V2

### 7.1. Current protocol

Hien tai preview socket chi gui:

```text
[4 bytes image_length][jpeg bytes]
```

Nhuoc diem:

- khong co `frame_id`
- khong co `timestamp`
- app khong biet overlay nao thuoc ve preview nao

### 7.2. Proposed protocol

De xuat doi sang:

```text
[4 bytes meta_length][meta_json_bytes][4 bytes image_length][jpeg_bytes]
```

`meta_json` toi thieu:

```json
{
  "frame_id": 27,
  "timestamp": 1713940000.123,
  "session_id": "sess_000010",
  "mode": "recording_preview"
}
```

Trong idle preview:

- `frame_id` co the la counter rieng
- `session_id` co the la `null`
- `mode` = `idle_preview`

Luu y:

- protocol cu se khong duoc giu song song neu muon code don gian
- neu can migration mem hon, co the them `protocol_version`

---

## 8. File Scope

### 8.1. Pi agent

Files chinh se bi anh huong:

- `backend/pi_agent/pi_capture.py`
- `backend/pi_agent/pi_preview.py`
- co the can nho trong `backend/pi_agent/pi_agent.py`

### 8.2. Mobile app

Files chinh se bi anh huong:

- `mobile_app/lib/screens/capture_control_screen.dart`
- co the tach parser preview packet neu can

### 8.3. Backend worker

Backend worker khong can doi nhieu ve architecture.

Chi can dam bao:

- `frame_id` giu nguyen contract hien tai
- result JSON tiep tuc la source of truth cho inference result

---

## 9. Phase Plan

### Phase 0 - Baseline va tuning target

Muc tieu:

- chot muc uu tien la "preview muot hon" truoc "overlay khop tuyet doi"
- co baseline de so sanh truoc/sau

Checklist:

- [x] ghi lai current config:
  - preview FPS
  - camera FPS
  - preview JPEG quality
  - preview size
- [ ] test cam giac preview khi:
  - chua record
  - dang record
- [ ] ghi lai 3 nhan xet ngan:
  - preview co giat khong
  - overlay co lech khong
  - overlay co den tre khong

Done criteria:

- co baseline ro rang trong note hoac status

### Phase 1 - Preview tuning khong doi protocol

Muc tieu:

- cai thien do muot cua camera preview truoc

Gia tri de test truoc:

- `POSETRACK_IDLE_PREVIEW_FPS = 5`
- `POSETRACK_PREVIEW_STREAM_FPS = 6`
- `POSETRACK_PREVIEW_JPEG_QUALITY = 50`
- `camera_fps = 8`

Bo tuning V1 duoc chon cho commit dau:

- idle preview FPS: `5`
- recording preview FPS: `6`
- preview JPEG quality: `50`
- preview max size: giu nguyen `480x360`
- video capture FPS: `8`
- video capture size: `640x480`

Checklist:

- [x] chot bo config V1 cho preview
- [ ] test preview idle
- [ ] test preview trong luc record
- [ ] xac nhan preview da "de nhin" hon truoc

Done criteria:

- preview tren `Capture` muot hon ro ret truoc khi sua overlay logic

### Phase 1.5 - Idle preview optimization sau test thuc te

Feedback sau lan test dau:

- preview tren man `Capture` van lag ro ngay ca khi chua record
- dieu nay cho thay bottleneck nam o idle preview path, khong phai worker

Huong toi uu bo sung:

- tang idle preview FPS len `6`
- giam preview JPEG quality xuong `45`
- dat idle preview source size thanh `480x360`
- giam buffer cho Picamera2 idle preview de uu tien do tre thap hon

Checklist:

- [x] cap nhat plan theo feedback thuc te
- [ ] verify lai idle preview tren Pi that sau khi restart agent
- [ ] xac nhan preview da bot giat truoc khi sang Phase 2

Done criteria:

- idle preview tren Pi that nhin muot hon va co do tre thap hon lan test dau

### Phase 1.6 - Picamera2 idle path cleanup

Feedback sau Phase 1.5:

- preview van lag nang tren thiet bi that
- can giam tiep chi phi moi frame trong Picamera2 idle preview path

Huong toi uu bo sung:

- giam idle preview source size xuong `320x240`
- bo phep chuyen mau `RGB -> BGR` moi frame neu Picamera2 da tra ve layout hop voi OpenCV

Checklist:

- [x] cap nhat target cho idle preview source size
- [x] loai bo phep convert mau du thua trong Picamera2 path
- [ ] verify lai preview tren Pi that sau khi restart agent

Done criteria:

- idle preview tren Pi that giam do tre va bot giat hon nua so voi Phase 1.5

### Phase 2 - Them frame_id vao preview protocol

Muc tieu:

- de app biet preview frame nao dang hien tren man hinh

Checklist:

- [x] trong `pi_capture.py`, xac dinh noi tao `frame_id` recording
- [x] truyen `frame_id` do vao preview publish
- [x] nang `pi_preview.py` de gui metadata + image
- [x] metadata toi thieu gom:
  - `frame_id`
  - `timestamp`
  - `session_id`
  - `mode`
- [x] khong lam vo idle preview

Done criteria:

- app co the nhan duoc preview frame va metadata frame cua no
- luu y: day la protocol breaking change, Pi va app phai duoc rollout cung version

### Phase 3 - App parse preview packet moi

Muc tieu:

- app doc duoc preview metadata ma van render anh binh thuong

Checklist:

- [x] cap nhat parser trong `capture_control_screen.dart`
- [x] luu trong state:
  - `latestPreviewFrameId`
  - `latestPreviewTimestamp`
  - `latestPreviewBytes`
- [x] giu reconnect behavior hien tai
- [x] giu fallback neu preview mat ket noi

Done criteria:

- preview van render anh
- app biet frame id cua preview moi nhat

### Phase 4 - Overlay gate theo frame match

Muc tieu:

- chi ve overlay khi preview va inference du khop

Rule de xuat:

- `match`: `preview_frame_id == inference_frame_id`
- `near match`: `abs(preview_frame_id - inference_frame_id) <= 1`
- `no match`: lon hon 1

Checklist:

- [x] trong app, lay `latestInferenceDetail.frameId`
- [x] them helper xac dinh match state
- [x] chi render `_LivePoseMetadataOverlay` neu:
  - `match`
  - hoac `near match`
- [x] neu `no match`, khong ve bbox/skeleton
- [x] nhung van hien panel text:
  - status
  - rep
  - stage
  - feedback

Done criteria:

- preview van muot
- overlay khong con bi "ve len frame sai" mot cach lo ro

### Phase 5 - UX polish

Muc tieu:

- user de hieu tai sao luc co border, luc chi co text

Checklist:

- [ ] hien nhan nho khi overlay dang matched, vi du:
  - `LIVE`
  - `SYNCED`
- [x] neu no match, hien text nhe:
  - `Preview live, AI syncing...`
- [x] khong de user nghi he thong bi hong khi tam thoi chua ve bbox

Done criteria:

- hanh vi UI ro rang va giai thich duoc

### Phase 6 - Verification

Checklist:

- [ ] test preview idle tren Pi that
- [ ] test preview + record tren Pi that
- [ ] test squat 3-5 rep
- [ ] xac nhan:
  - preview muot hon
  - overlay bot lech
  - result screen van dung
  - worker result JSON khong bi vo

Done criteria:

- pass manual test tren stack that

---

## 10. Data Contracts

### 10.1. Preview metadata contract

Required:

- `frame_id: int`
- `timestamp: float`
- `mode: str`

Optional:

- `session_id: str | null`

### 10.2. App overlay decision contract

Input:

- `preview_frame_id`
- `inference_frame_id`

Output:

- `match`
- `near_match`
- `no_match`

Rule:

```text
0 diff  -> match
1 diff  -> near_match
>=2 diff -> no_match
```

---

## 11. Risks

### 11.1. Preview muot hon nhung overlay it hien

Neu worker qua cham, app co the thuong xuyen roi vao `no_match`.

Dieu nay khong sai.
No cho thay worker chua theo kip preview.

### 11.2. Preview protocol doi se can sua ca Pi va app dong bo

Can rollout co thu tu:

1. Pi protocol
2. app parser
3. overlay gating

### 11.3. JSON polling van gay tre

Day la gioi han cua kien truc hien tai.
Plan nay giai quyet "overlay sai frame" truoc, khong xoa hoan toan network + worker latency.

---

## 12. Suggested Rollout Order

Thu tu nen lam:

1. Preview tuning
2. Preview protocol V2
3. App preview parser
4. Overlay gating by frame match
5. UX polish
6. Real-device verification

Khong nen nhay vao UX truoc khi co `frame_id` matching.

---

## 13. Acceptance Criteria

Buoc nay duoc coi la xong khi:

- preview tren `Capture` muot hon ro ret so voi hien tai
- overlay live khong con ve len preview sai frame mot cach de thay
- app van hoat dong binh thuong khi preview mat tam thoi
- result flow hien tai van dung
- khong can rewrite sang RTSP/WebRTC de demo on dinh

---

## 14. Open Questions

Tinh trang hien tai:

1. khong giu backward compatibility cho preview protocol cu trong Phase 2 de code don gian
2. `near_match` dang dung `abs(preview_frame_id - inference_frame_id) <= 1`
3. van con mo viec co can hien icon/label phan biet:
   - `preview live`
   - `ai synced`
4. van con mo viec co can ghi them `preview_frame_id` vao log/debug hay khong

---

## 15. First Implementation Slice

Da hoan thanh:

1. preview tuning bang config
2. them `frame_id` vao preview protocol
3. app parse `frame_id`
4. overlay gating theo `match/near_match`

Con lai:

- verify hardware tren Pi + app desktop/mobile sau khi deploy dong bo
- can nhac them label `SYNCED` neu can UX ro hon
