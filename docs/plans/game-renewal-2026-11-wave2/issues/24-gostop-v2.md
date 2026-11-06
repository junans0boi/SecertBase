# 24: 고스톱 규칙·서버·화면 2.0

**Type:** server+client

**Blocked by:** 25(화투 그림 연결은 통합 때. 그 전에는 기존 `hwatu_card.dart`를 써도 됨)

**Status:** ready-for-agent

## What to build

고스톱(맞고)의 규칙 오류를 모두 고치고, 25초 턴·정확한 정산·동의 재대결을 넣고, 초록 펠트 판 화면으로 다시 만든다(00 §4, 01 Q25–Q29).

## Acceptance criteria

- [ ] 엔진 TDD(분석의 재현 시나리오를 실패 테스트로 먼저): 쓸은 턴 끝 판정·마지막 턴 제외, 마지막 턴은 마지막에 난 사람만 승·고 후 무득점이면 나가리, 고 점수/배수(1고 +1, 2고 +2, 3고 +3 ×2, 이후 ×2), 흔들기·폭탄은 선언자 승리 때만 ×2, 피박(이긴 쪽 피 점수 + 진 쪽 피 7장 이하), 광박, 고박, 손패 두 장 매치 선택(`hand_choice`), 폭탄 후 도탄 2번, 바닥 같은 월 4장 재분배, 총통 10점 즉시 승리(거절 가능, 동시면 재분배), 흔들기는 그 월 패를 낼 때 선언
- [ ] 모듈 `src/games/gostop.js`: `startFromLobby`(1점당 판돈), 25초 마감 + 단계별 자동 행동(고/스톱 = 스톱, 패 = 코치 추천, 선택 = 점수 높은 쪽, 흔들기 = 안 함), 3회 자동이면 기권(실제 점수·배수로 지불), 모든 상태 변경 잠금 안, 정산 try/finally + `recordGameOutcome(gameId)`, 정산 내역(점수·고·박·흔들기·폭탄·배수·실제 이동 코인), 동의 재대결 + 이긴 사람이 선, 시리즈, `restore`, `afk`, 엔진 사유를 코드로. 옛 gostop 코드 삭제
- [ ] 소켓 테스트 `test/gostop-socket.test.js`: 서버 시작, 두 장 선택, 마감 자동 스톱, 기권 지불, 정산 한 번, 재대결 선
- [ ] 화면(`games/gostop/`): 초록 펠트 테마(`GameTheme.felt`), 상대·나의 딴 패(광·열·띠·피 묶음, 개수, 쌍피 표시), 열두 달 자리 바닥 + 더미 + 뻑 더미 표시, 360px에 들어가는 부채꼴 손패(들고 확정), 점수판(점수·고 횟수·×N 분해·예상 금액·힌트 칩), 손패→바닥·더미 뒤집기·먹은 패 날아가기·+피·피 뺏기·쓸·뻑·폭탄 연출, 고/스톱 전체 패널(지금 금액 vs 고 했을 때), 두 장 선택 시트, 정산 영수증(합계가 실제 코인과 일치), `GameSfx`, 도움말에 규칙 명시. 화투는 `HwatuCard` 인터페이스로 그려 25의 벡터 그림으로 바꾸기 쉽게
- [ ] 위젯 테스트(360·430 넘침 없음, 손패 10장, 고/스톱 패널, 영수증), `docs/socket-events/gostop.md`

## Likely files
- `services/realtime-server/src/gostop-engine.js`, `src/games/gostop.js`, `src/socket.js`, tests
- `apps/secret_base_app/lib/screens/arcade/games/gostop/`, `games/gostop_screen.dart`, `lib/screens/arcade/games/gostop_coach.dart`, `game_theme.dart`(felt)
