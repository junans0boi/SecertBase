# REST API Documentation (Phase 3)

**Base URL**: `http://localhost:4100/api`

---

## 1. Setlog API (OOTD & 데이트 사진)

### GET `/api/setlog`
셋로그 포스트 목록 조회

**Query Parameters:**
- `month` (optional): YYYY-MM 형식 (예: 2026-06)

**Response:**
```json
{
  "ok": true,
  "posts": [
    {
      "id": 1,
      "user_id": "jun",
      "photo_url": "/uploads/photo-1730000000000.jpg",
      "caption": "한강 데이트 🌊",
      "tags": ["#데이트", "#한강", "#OOTD"],
      "taken_at": "2026-06-17",
      "created_at": "2026-06-17T10:00:00Z",
      "updated_at": "2026-06-17T10:00:00Z"
    }
  ]
}
```

### POST `/api/setlog`
셋로그 포스트 생성

**Content-Type:** `multipart/form-data`

**Form Fields:**
- `photo`: File (이미지 파일, 최대 10MB)
- `user_id`: String ('jun' or 'gf')
- `caption`: String (optional)
- `tags`: JSON Array String (예: `["#데이트", "#한강"]`)
- `taken_at`: Date (YYYY-MM-DD)

**Response:**
```json
{
  "ok": true,
  "post": { ... }
}
```

### DELETE `/api/setlog/:id`
셋로그 포스트 삭제

**Response:**
```json
{
  "ok": true
}
```

---

## 2. Map API (데이트 장소 핀)

### GET `/api/map`
지도 핀 목록 조회

**Response:**
```json
{
  "ok": true,
  "pins": [
    {
      "id": 1,
      "place_name": "을지로 술집",
      "latitude": 37.5665,
      "longitude": 126.9780,
      "category": "restaurant",
      "rating": 5,
      "visit_date": "2026-06-15",
      "memo": "분위기 좋고 맛있었음 ⭐",
      "photos": [],
      "created_by": "gf",
      "created_at": "2026-06-15T18:00:00Z",
      "updated_at": "2026-06-15T18:00:00Z"
    }
  ]
}
```

### POST `/api/map`
지도 핀 생성

**Request Body:**
```json
{
  "place_name": "을지로 술집",
  "latitude": 37.5665,
  "longitude": 126.9780,
  "category": "restaurant",
  "rating": 5,
  "visit_date": "2026-06-15",
  "memo": "분위기 좋음",
  "created_by": "gf"
}
```

**Response:**
```json
{
  "ok": true,
  "pin": { ... }
}
```

### PATCH `/api/map/:id`
지도 핀 업데이트 (별점/메모)

**Request Body:**
```json
{
  "rating": 4,
  "memo": "재방문 의향 있음"
}
```

**Response:**
```json
{
  "ok": true,
  "pin": { ... }
}
```

---

## 3. Q&A API (10시의 질문)

### GET `/api/qa/today`
오늘의 질문 조회

**Response:**
```json
{
  "ok": true,
  "question": {
    "id": 1,
    "question": "오늘 가장 행복했던 순간은?",
    "scheduled_date": "2026-06-17",
    "created_at": "2026-06-01T00:00:00Z"
  },
  "answers": [
    {
      "id": 1,
      "question_id": 1,
      "user_id": "jun",
      "answer": "저녁 먹을 때!",
      "answered_at": "2026-06-17T22:15:00Z"
    }
  ]
}
```

### POST `/api/qa/answer`
질문 답변 제출

**Request Body:**
```json
{
  "question_id": 1,
  "user_id": "jun",
  "answer": "저녁 먹을 때!"
}
```

**Response:**
```json
{
  "ok": true,
  "answer": { ... }
}
```

---

## 4. Challenges API (목표 챌린지)

### GET `/api/challenges`
활성 챌린지 목록

**Response:**
```json
{
  "ok": true,
  "challenges": [
    {
      "id": 1,
      "title": "벤치프레스 100kg",
      "description": "3개월 안에 달성",
      "target_value": 100,
      "current_value": 85,
      "unit": "kg",
      "owner_id": "jun",
      "status": "active",
      "start_date": "2026-06-01",
      "target_date": "2026-09-01",
      "progress_pct": 85,
      "log_count": 12,
      "created_at": "2026-06-01T00:00:00Z",
      "updated_at": "2026-06-17T10:00:00Z"
    }
  ]
}
```

### POST `/api/challenges`
챌린지 생성

**Request Body:**
```json
{
  "title": "벤치프레스 100kg",
  "description": "3개월 안에 달성",
  "target_value": 100,
  "unit": "kg",
  "owner_id": "jun",
  "start_date": "2026-06-01",
  "target_date": "2026-09-01"
}
```

**Response:**
```json
{
  "ok": true,
  "challenge": { ... }
}
```

### POST `/api/challenges/:id/log`
챌린지 진행 기록

**Request Body:**
```json
{
  "value": 5,
  "note": "오늘 5kg 증량!"
}
```

**Response:**
```json
{
  "ok": true
}
```

**Note:** `current_value`가 `target_value` 이상이 되면 자동으로 `status`가 'completed'로 변경됨.

---

## 5. Jukebox API (음원 관리)

### GET `/api/jukebox`
트랙 목록 조회

**Response:**
```json
{
  "ok": true,
  "tracks": [
    {
      "id": 1,
      "title": "Cover - 좋은 날",
      "artist": "준 (Logic Pro Mix)",
      "file_url": "/uploads/audio-1730000000000.mp3",
      "duration_sec": 245,
      "cover_art_url": null,
      "uploaded_by": "jun",
      "uploaded_at": "2026-06-17T12:00:00Z"
    }
  ]
}
```

### POST `/api/jukebox`
트랙 업로드

**Content-Type:** `multipart/form-data`

**Form Fields:**
- `audio`: File (MP3/WAV 파일, 최대 10MB)
- `title`: String
- `artist`: String (optional)
- `duration_sec`: Number (optional)
- `uploaded_by`: String ('jun' or 'gf')

**Response:**
```json
{
  "ok": true,
  "track": { ... }
}
```

---

## Error Responses

### 400 Bad Request
```json
{
  "ok": false,
  "reason": "missing_fields"
}
```

### 500 Internal Server Error
```json
{
  "ok": false,
  "reason": "internal_error"
}
```

---

## File Upload Notes

- **Supported Image Types**: JPEG, PNG, GIF, WebP
- **Supported Audio Types**: MP3, WAV, OGG
- **Max File Size**: 10MB
- **Upload Directory**: `/uploads` (gitignored)
- **URL Format**: `http://localhost:4100/uploads/filename.ext`

---

## Database Schema

모든 테이블 스키마는 `schema.sql` 참고.

---

**Last Updated**: 2026-06-17 17:45
