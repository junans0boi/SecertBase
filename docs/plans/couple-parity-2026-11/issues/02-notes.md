# 02 쪽지 (둘만의 짧은 대화)

용어: Couple, 활성 커플, 연결 해제. 표면 이름은 "쪽지".

## What to build
새 서버 모듈 `services/realtime-server/src/modules/notes/`, 앱 `lib/features/notes/`.

- 서버(JWT에서 사용자·활성 Couple 도출):
  - `GET /api/notes?before=<id>&limit=`: 커서 페이지네이션 메시지 목록.
  - `POST /api/notes`: 본문(텍스트 ≤1000자) + 선택 첨부(기존 업로드 스토어 재사용: 사진 1장), 선택 `map_pin_id`/`setlog_post_id` 참조(같은 Couple 소유 검증), `client_request_id`로 멱등.
  - `POST /api/notes/read`: 마지막 읽은 id 갱신(읽음 표시).
  - `DELETE /api/notes/:id`: 본인 쪽지 삭제(소프트 삭제, 상대에게는 "삭제된 쪽지").
  - `POST /api/notes/:id/reaction`: 이모지 반응 1개.
  - 예약 열람: `open_at`(미래)을 지정하면 그 시각 전에는 수신자에게 본문·첨부를 숨기고 "열리기 전" 상태만 보인다(서버가 강제, 푸시도 열릴 때 발송).
  - 실시간: 기존 Socket.IO 인증을 재사용해 새 쪽지·읽음 이벤트 전달. 소켓 이벤트는 활성 Couple 방으로만.
  - 알림: 기존 `notifier`에 `partner_note` 타입 추가. **본문은 푸시에 싣지 않는다**("쪽지가 도착했어요" 고정 문구).
  - 마이그레이션 `0052_notes.sql`(`couple_id` 필수, 인덱스 `(couple_id, id)`).
  - 연결 해제 시 비활성 Couple에서는 접근 불가, 재결합 시 복원(기존 `couple-separation.js` 정책과 정합, 테스트).
- 앱: 홈 상단 쪽지 진입(읽지 않은 수 점), 대화 화면(말풍선 최소 디자인, 장소·순간 첨부 미리보기, 읽음, 반응, 예약 열람 설정), 푸시 탭 시 쪽지 화면으로 이동(`push_target.dart` 확장), 오프라인 시 보내기 큐(기존 `upload_outbox` 패턴 참고).
- 하단 탭 구조는 바꾸지 않는다.

## Acceptance
- [ ] 서버 통합 테스트: Couple 격리, 예약 열람 전 본문 미노출(REST·소켓·푸시), 멱등 전송, 참조 소유권 검증, 삭제, 읽음, 비활성 Couple 거부.
- [ ] 소켓 테스트: 상대에게만 전달, 타 Couple 미전달.
- [ ] 앱 위젯 테스트: 목록·전송·예약 설정·읽지 않은 수.
- [ ] 레이트리밋: 분당 전송 상한.
- [ ] CONTEXT.md에 용어 추가: **쪽지**.

## Blocked by
없음
