# 05: 공용 리액션 + 잠수 안내 게임별 필터

**Type:** server+client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

이모지 리액션으로 표정 연기를 할 수 있게 하고, 잠수 안내가 **지금 보고 있는 게임에서만** 뜨게 한다.

## Acceptance criteria

- [ ] 서버 `game:reaction { emoji }`: 허용 목록 6개만 통과, 사용자별 1.5초 쿨다운, 방 전체에 `{ by, emoji, at }`
- [ ] 서버 테스트: 허용되지 않은 값 거부, 쿨다운, 방 밖 사용자 거부
- [ ] 클라이언트 `SocketService`: 리액션 수신 상태(`lastReaction`, 시퀀스) + `sendReaction(emoji)`
- [ ] `GameScaffold(gameType:)` → `GameNoticeListener(gameType:)`: `game:afk:*`의 `gameType`이 현재 화면과 다르면 안내를 띄우지 않는다. 문구에 게임 이름을 넣는다
- [ ] 위젯 테스트: 다른 게임 AFK 안내는 무시, 같은 게임이면 표시
- [ ] `docs/SOCKET_EVENTS.md`에 `game:reaction` 추가

## Notes

원카드의 기존 리액션(`game:uno:reaction`)은 건드리지 않는다.

## Likely files

- `services/realtime-server/src/socket.js`
- `apps/secret_base_app/lib/core/socket_service.dart`
- `apps/secret_base_app/lib/widgets/game_scaffold.dart,game_notice_listener.dart`
