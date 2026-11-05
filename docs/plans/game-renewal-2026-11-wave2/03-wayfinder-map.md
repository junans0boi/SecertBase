# 03. Wayfinder Map — 윷놀이·텔레파시·그림 맞히기·고스톱 2.0

> 상태: 진행 중(사용자가 구현까지 맡김). 근거: `00-analysis.md`, `01-grilling.md`, `02-spec.md`.

## Destination
`feat/games-v2-wave2` 브랜치에 네 게임 2.0이 반영되어 푸시되고, 서버·앱 테스트와 분석기가 통과하며, 두 계정 실플레이로 확인된 상태. main 머지는 사용자 확인 뒤.

## Notes
- 1차 파도 공용 기반 위에 쌓습니다(PR #242). 기반 사용법: `../game-renewal-2026-11/04-foundation-api.md`.
- 판돈 게임(윷·고스톱)은 정산 멱등과 끝난 판 거부를 테스트로 고정합니다.
- 참고 화면은 느낌만 참고, 저장소에 넣지 않음.

## Tickets

| # | 제목 | 종류 | 규모 | 의존 |
|---|---|---|---|---|
| 21 | [윷놀이 2.0](issues/21-yut-v2.md) | server+client | L | – |
| 22 | [텔레파시 2.0 (밸런스)](issues/22-telepathy-v2.md) | server+client | M | – |
| 23 | [그림 맞히기 2.0](issues/23-catch-v2.md) | server+client | L | – |
| 24 | [고스톱 규칙·서버·화면 2.0](issues/24-gostop-v2.md) | server+client | L | 25(그림 연결은 통합 때) |
| 25 | [벡터 화투 그림](issues/25-hwatu-art.md) | client | L | – |
| 26 | [통합·리뷰·실플레이·빌드](issues/26-wave2-verification.md) | verification | M | 21–25 |

로비 옵션 추가(`yut.pieces`, `telepathy.rounds/spicy`, `catch.rounds`)는 각 티켓이 자기 키만 `LOBBY_OPTIONS`와 `kLobbyOptions`에 더합니다(통합 때 충돌만 정리).

## 진행 순서
1. 21·22·23·24·25 병렬(각자 워크트리).
2. 통합(25의 화투 위젯을 24 화면에 연결) → 전체 테스트 → 독립 코드 리뷰 → 두 계정 실플레이 → 5050 빌드 → PR.

## 위험
| ID | 위험 | 대응 |
|---|---|---|
| R1 | 고스톱 규칙 해석 차이 | 01 Q25로 고정하고 도움말에 명시, 테스트로 고정 |
| R2 | 벡터 화투 48장 품질 | 골든 렌더로 반복 확인, 통합 때 브라우저 확인 |
| R3 | 그림 동기화 지연·데이터량 | 33ms 묶음, 서버 획 기록 상한(라운드당 점 수), 재생은 한 번에 |
| R4 | 문제·단어 은행 품질(맞춤법·중복·부적절) | 불러올 때 검증 + 테스트(중복·길이·한국어) |
| R5 | `socket.js` 병합 충돌 | 각자 자기 게임 블록만 삭제, 통합 때 정리(1차와 같음) |
