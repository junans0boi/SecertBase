# 22: 텔레파시 2.0 (밸런스 게임)

**Type:** server+client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

텔레파시를 2지선다 밸런스 게임으로 바꾸고, 320문제 은행과 방별 셔플 가방으로 반복을 없앤다. 서버가 문항·라운드·점수를 모두 가진다(00 §2, 01 Q14–Q18).

## Acceptance criteria

- [ ] `src/data/telepathy-questions.json` 320문제(8분야 × 40: 가벼운 취향·음식·데이트·여행·일상·연애·만약에·살짝 매운맛), `{id, cat, a, b, emojiA, emojiB, spicy}`, 한국어만, 보기 14자 이내, 부적절·중복 없음. 불러올 때 검증
- [ ] 엔진 TDD: `drawQuestions`(분야당 2개 상한, 매운맛 끄기 시 제외, 가방 소진 시 재셔플·최근 50개 뒤로), `judge`, `summary`(통한 수·연속·최고 연속·등급). **연속 32판(10문제) 중복 없음** 테스트
- [ ] 모듈 `src/games/telepathy.js`: `startFromLobby`(`rounds` 10|5|15, `spicy`), 가방 `telepathy:<room>:bag`(1년), `pick {round, choice:'A'|'B'}`, 15초 마감(시간 초과 = 불일치, 다음 문제), 3회 연속 둘 다 시간 초과면 판 종료, `sync`, `restart`, `restore`, `afk`(안 고른 사람), 시리즈(통한 비율·최고 연속), 승패 기록 없음. 옛 telepathy 코드 삭제(socket.js·엔진의 옛 함수)
- [ ] 로비 옵션 `telepathy.rounds`, `telepathy.spicy`
- [ ] 소켓 테스트 `test/telepathy-socket.test.js`: 서버 시작, 지난 판 답 섞이지 않음, 동시 선택, 마감, 재접속 sync, 재대결
- [ ] 화면(`games/telepathy/`): 별빛 편지 테마(`GameTheme.starlight`), 질문 + A/B 큰 카드(이모지) + VS 메달, 상대 "골랐어요", 동시 뒤집기, 통하면 빛줄기·색종이·🔥연속, 진행 점·타이머, 결과(N/10·등급·문제별 두 사람 선택·전적·한 판 더). 시작 버튼 없음
- [ ] 위젯 테스트, `docs/socket-events/telepathy.md`

## Likely files
- `services/realtime-server/src/telepathy-engine.js`, `src/games/telepathy.js`, `src/data/telepathy-questions.json`, `src/socket.js`, `src/lobby-options.js`, tests
- `apps/secret_base_app/lib/screens/arcade/games/telepathy/`, `games/telepathy_screen.dart`, `lobby_options.dart`, `game_theme.dart`(starlight)
