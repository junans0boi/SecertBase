# 04: 재시작 합의·gameId·시리즈 (서버, 5종 공통)

**Type:** server

**Blocked by:** –

**Status:** ready-for-agent

## What to build

블랙잭·도둑잡기·패널티킥·해적 룰렛·제로가 **재대결 합의 절차**를 쓰고, 판마다 `gameId`로 결과를 한 번만 기록하며, 재대결 사이에 방 전적(`series`)을 이어받게 한다.

## Acceptance criteria

- [ ] `RESTARTABLE_GAME_TYPES`에 `blackjack`, `oldmaid`, `rps`(제로), `pirate`, `penalty` 추가
- [ ] 게임별 `restart*Game(roomCode, series)` 구현(탱크의 `restartTankGame` 틀). 상대가 수락한 경우에만 새 판. 거절·무응답은 요청자에게 안내
- [ ] 모든 새 판에 `gameId`(`crypto.randomUUID()`) 부여, 상태와 이벤트에 포함
- [ ] 종료 시 `recordGameOutcome({ gameId })`만 호출(해적 룰렛의 `saveGameResult` 직접 호출·await 없는 XP 제거). 같은 `gameId`는 한 번만 기록됨
- [ ] `series`를 새 판으로 이어받고 무승부는 더하지 않는다. 종료 이벤트에 `series` 포함
- [ ] AFK 기권(`forfeit`) 경로도 같은 `gameId`·`series` 규칙을 따른다
- [ ] 소켓 회귀 테스트: 5종 각각 재시작 요청/수락/거절, 위조된 respond 거부, `gameId` 중복 기록 없음, 시리즈 이어받기

## Notes

이 티켓은 **엔진 규칙을 바꾸지 않는다.** 각 게임 엔진 티켓(06, 09, 11, 13, 15)이 새 상태 모양을 얹는다. 먼저 5종에 같은 뼈대를 달아 두는 목적이다.

## Likely files

- `services/realtime-server/src/socket.js`
- `services/realtime-server/test/socket-game-regression.test.js`
- `docs/SOCKET_EVENTS.md`
