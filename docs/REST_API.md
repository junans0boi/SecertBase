# REST API Documentation

Last updated: 2026-06-20

Base URLs:

```text
Production: https://secertbase.kro.kr/api
Local:      http://localhost:4100/api
```

File uploads are served from:

```text
Production: https://secertbase.kro.kr/uploads/<filename>
Local:      http://localhost:4100/uploads/<filename>
```

The backend uses MariaDB through `DATABASE_URL`.

## Auth

### POST `/auth/register`

Creates a user and default `User_Preference` row.

Request:

```json
{
  "email": "user@example.com",
  "password": "password",
  "user_name": "Jun"
}
```

Response:

```json
{
  "ok": true,
  "userCode": "ABC123"
}
```

Failure reasons:

```text
missing_fields
email_already_exists
internal_error
```

### POST `/auth/login`

Returns a 7-day JWT and basic user info.

Request:

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

Response:

```json
{
  "ok": true,
  "token": "jwt",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "userName": "Jun",
    "userCode": "ABC123"
  }
}
```

Failure reasons:

```text
invalid_credentials
internal_error
```

## User / Partner

### POST `/user/partner`

Pairs the current user with a partner by `UserCode`. The server updates both users' `PartnerCode` and creates a deterministic couple room.

Request:

```json
{
  "userId": 1,
  "partnerCode": "XYZ789"
}
```

Response:

```json
{ "ok": true }
```

Failure reasons:

```text
missing_fields
partner_not_found
cannot_pair_with_self
internal_error
```

### GET `/user/profile/:userId`

Returns the user profile, partner code, and room credentials used for Socket.IO.

Response:

```json
{
  "ok": true,
  "user": {
    "UserId": 1,
    "Email": "user@example.com",
    "UserName": "Jun",
    "UserCode": "ABC123",
    "UserIcon": null,
    "PartnerCode": "XYZ789",
    "RoomCode": "room_1_2",
    "RoomSecret": "secret"
  }
}
```

## Couple

### GET `/couple/info?user_id=1`

Returns couple metadata for the home screen.

Response:

```json
{
  "ok": true,
  "coupleId": 1,
  "startDate": "2026-06-01",
  "dDay": 20,
  "partnerName": "Partner",
  "partnerCode": "XYZ789"
}
```

### PATCH `/couple/info`

Updates the couple start date.

Request:

```json
{
  "user_id": 1,
  "start_date": "2026-06-01"
}
```

Response:

```json
{ "ok": true }
```

## Setlog / Moment Loop

Setlog supports text, image, and video records. Upload field name is `media`.

### GET `/setlog`

Query parameters:

- `month`: optional `YYYY-MM`
- `user_id`: optional. If the user belongs to a couple, the API returns the couple's records.

Response:

```json
{
  "ok": true,
  "posts": [
    {
      "id": 1,
      "couple_id": 1,
      "user_id": 1,
      "user_code": "ABC123",
      "media_type": "image",
      "media_url": "/uploads/media-1781760000000.png",
      "caption": "한강 데이트",
      "tags": "[\"date\"]",
      "taken_at": "2026-06-20",
      "captured_at": "2026-06-20T12:00:00.000Z",
      "UserName": "Jun"
    }
  ]
}
```

### POST `/setlog`

Content type:

```text
multipart/form-data
```

Fields:

- `media`: optional file, max 30MB
- `user_id`: required
- `user_code`: optional
- `caption`: required for text-only posts
- `tags`: JSON array string, optional
- `taken_at`: required `YYYY-MM-DD`
- `captured_at`: optional timestamp
- `media_type`: optional `text`, `image`, `video`

Response:

```json
{
  "ok": true,
  "post": {}
}
```

### DELETE `/setlog/:id`

Response:

```json
{ "ok": true }
```

## Map

### GET `/map`

Returns all map pins ordered by visit date.

### POST `/map`

Request:

```json
{
  "place_name": "을지로 술집",
  "latitude": 37.5665,
  "longitude": 126.978,
  "category": "restaurant",
  "rating": 5,
  "visit_date": "2026-06-20",
  "memo": "분위기 좋음",
  "created_by": "ABC123"
}
```

Response:

```json
{
  "ok": true,
  "id": 1
}
```

### PATCH `/map/:id`

Updates rating and/or memo.

Request:

```json
{
  "rating": 4,
  "memo": "재방문 의향 있음"
}
```

Response:

```json
{ "ok": true }
```

## Daily Q&A

### GET `/qa/today`

Creates today's question from the built-in pool if no row exists.

Response:

```json
{
  "ok": true,
  "question": {
    "id": 1,
    "question": "오늘 가장 행복했던 순간은?",
    "scheduled_date": "2026-06-20"
  },
  "answers": []
}
```

### POST `/qa/answer`

Request:

```json
{
  "question_id": 1,
  "user_id": 1,
  "answer": "저녁 먹을 때"
}
```

Response:

```json
{
  "ok": true,
  "id": 1
}
```

## Challenges

### GET `/challenges`

Returns active challenges.

### POST `/challenges`

Request:

```json
{
  "title": "벤치프레스 100kg",
  "description": "3개월 안에 달성",
  "target_value": 100,
  "unit": "kg",
  "owner_id": "ABC123",
  "start_date": "2026-06-20",
  "target_date": "2026-09-20"
}
```

Response:

```json
{
  "ok": true,
  "id": 1
}
```

### POST `/challenges/:id/log`

Adds progress and completes the challenge when `current_value >= target_value`.

Request:

```json
{
  "value": 5,
  "note": "오늘 운동"
}
```

Response:

```json
{ "ok": true }
```

## Jukebox

### GET `/jukebox`

Returns uploaded tracks.

### POST `/jukebox`

Content type:

```text
multipart/form-data
```

Fields:

- `audio`: required file
- `title`: required
- `artist`: optional
- `duration_sec`: optional
- `uploaded_by`: required

Response:

```json
{
  "ok": true,
  "id": 1
}
```

## Time Capsules

### GET `/capsules`

Returns capsules with computed `is_openable`.

### POST `/capsules`

`open_date` must be in the future.

Request:

```json
{
  "title": "1년 뒤 편지",
  "message": "보고 싶을 때 열기",
  "created_by": "ABC123",
  "open_date": "2027-06-20"
}
```

Response:

```json
{ "ok": true }
```

### PATCH `/capsules/:id/open`

Opens a capsule only when `open_date <= today`.

Response:

```json
{ "ok": true }
```

Failure reasons:

```text
not_found
not_yet
internal_error
```

## Health

### GET `/health`

Not under `/api`.

```text
https://secertbase.kro.kr/health
```

Response:

```json
{ "ok": true }
```
