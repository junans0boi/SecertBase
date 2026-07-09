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
  "user_name": "junnie",
  "full_name": "Jun",
  "nickname": "junnie",
  "birth_date": "2000-01-01"
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
invalid_birth_date
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
    "fullName": "Jun",
    "nickname": "junnie",
    "birthDate": "2000-01-01",
    "userCode": "ABC123"
  }
}
```

Failure reasons:

```text
invalid_credentials
internal_error
```

### POST `/auth/google`

Verifies a Google ID token with `GOOGLE_CLIENT_ID`, creates or links a local user by email/Google subject, then returns the same app JWT format as email login.

Request:

```json
{
  "idToken": "google-id-token"
}
```

Response:

```json
{
  "ok": true,
  "token": "jwt",
  "user": {
    "UserId": 1,
    "Email": "user@gmail.com",
    "UserName": "Google User",
    "FullName": "Google User",
    "Nickname": "Google",
    "BirthDate": "2000-01-01",
    "UserCode": "ABC123",
    "PartnerCode": null,
    "RoomCode": null,
    "RoomSecret": null,
    "AuthProvider": "google",
    "GoogleLinked": true,
    "GooglePictureUrl": "https://..."
  }
}
```

Failure reasons:

```text
missing_id_token
google_login_not_configured
invalid_google_token
google_auth_failed
```

## User / Partner

### GET `/today?user_id=1`

Returns the Home Today Hub state for the current couple.

Response:

```json
{
  "ok": true,
  "date": "2026-06-21",
  "coupleId": 1,
  "streak": {
    "current": 7,
    "longest": 12,
    "completedToday": false,
    "myCompleted": true,
    "partnerCompleted": false
  },
  "question": {
    "id": 10,
    "text": "오늘 상대에게 고마웠던 순간은?",
    "scheduledDate": "2026-06-21",
    "myAnswered": true,
    "partnerAnswered": false,
    "revealAvailable": false,
    "answerCount": 1
  },
  "mission": {
    "instanceId": 3,
    "missionId": 2,
    "title": "칭찬 하나 남기기",
    "description": "오늘 상대에게 고마웠던 점이나 예뻤던 점을 하나 말해줘요.",
    "status": "active",
    "myCompleted": false,
    "partnerCompleted": true,
    "completed": false
  },
  "pending": {
    "wishTickets": 0,
    "capsulesToOpen": 0
  }
}
```

Failure reasons:

```text
missing_user_id
internal_error
```

### POST `/missions/:instanceId/complete`

Marks the current user's daily mission as complete and updates the couple streak if both partners have completed a qualifying daily action.

Request:

```json
{
  "user_id": 1
}
```

Response:

```json
{ "ok": true }
```

Failure reasons:

```text
missing_fields
mission_not_found
forbidden_user
internal_error
```

### GET `/timeline?user_id=1&limit=30`

Returns recent automatic couple timeline events.

Events are written by retention actions such as question answers, mission completions, and streak completion.

Response:

```json
{
  "ok": true,
  "events": [
    {
      "id": 1,
      "couple_id": 1,
      "event_type": "question_answered",
      "actor_user_id": 1,
      "ActorName": "Jun",
      "title": "오늘의 질문 답변 완료",
      "body": "한 사람이 오늘의 질문에 답했어요.",
      "event_date": "2026-06-21T00:00:00.000Z"
    }
  ]
}
```

Failure reasons:

```text
missing_user_id
internal_error
```

### GET `/user/profile/:userId`

Returns the user profile, partner code, and room credentials used for Socket.IO.

The display name for games should use `Nickname` first. `UserName` is retained for older client compatibility and is updated to the same value as `Nickname`.

### PATCH `/user/profile/:userId`

Updates editable profile fields.

Request:

```json
{
  "fullName": "Jun",
  "nickname": "junnie",
  "birthDate": "2000-01-01"
}
```

Response:

```json
{
  "ok": true,
  "user": {
    "UserId": 1,
    "Email": "user@example.com",
    "FullName": "Jun",
    "Nickname": "junnie",
    "BirthDate": "2000-01-01",
    "UserCode": "ABC123",
    "AuthProvider": "password",
    "GoogleLinked": false
  }
}
```

Failure reasons:

```text
missing_fields
invalid_length
invalid_birth_date
user_not_found
internal_error
```

### PATCH `/user/password/:userId`

Changes the password for password-login accounts.

Request:

```json
{
  "currentPassword": "old-password",
  "newPassword": "new-password"
}
```

Failure reasons:

```text
missing_fields
weak_password
password_login_not_enabled
invalid_current_password
user_not_found
internal_error
```

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

### GET `/places/search`

Searches external place providers through the backend. Kakao Local is preferred when configured. NAVER API HUB Search Local is used for Naver Local place search when `NAVER_SEARCH_CLIENT_ID` and `NAVER_SEARCH_CLIENT_SECRET` are configured. Naver Cloud Maps keys are separate and can be used for reverse geocoding/geocoding fallback.

When `lat` and `lng` are provided, the backend calculates `distanceMeters` for returned places and sorts nearby places first. Because NAVER Local does not natively support coordinate-biased local search, the backend may reverse-geocode the coordinate into region hints and merge region-augmented searches such as `강서구 철길부산집` with the original query.

Query parameters:

```text
q=성수 카페
limit=10
lat=37.544
lng=127.055
```

Response:

```json
{
  "ok": true,
  "places": [
    {
      "provider": "kakao",
      "providerPlaceId": "123",
      "name": "성수 카페",
      "category": "카페",
      "categoryCode": "CE7",
      "address": "서울 성동구 성수동",
      "roadAddress": "서울 성동구 성수이로",
      "phone": "02-123-4567",
      "placeUrl": "https://place.map.kakao.com/123",
      "latitude": 37.544,
      "longitude": 127.055,
      "distanceMeters": 140
    }
  ],
  "providers": {
    "kakao": { "enabled": false },
    "naver": { "enabled": true },
    "naverMaps": { "enabled": false }
  },
  "regionHints": ["마곡지구도시개발지구", "가양1동", "강서구", "서울특별시"],
  "errors": {}
}
```

Failure reasons:

```text
missing_query
place_search_not_configured
place_search_failed
```

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
