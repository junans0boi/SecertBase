# 23: 그림 맞히기 2.0

**Type:** server+client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

그림 맞히기를 2.0으로 다시 만든다: 획 프로토콜 v2와 서버 획 기록, 서버 타이머·자동 힌트, 1,500 제시어와 방별 무반복, 아틀리에 스케치북 화면(00 §3, 01 Q19–Q24).

## Acceptance criteria

- [ ] `src/data/catch-words.json` 약 1,500개 `{w, cat, diff:1|2|3, aliases}`: 중복·상표·무기·그리기 어려운 말·영문 혼용·띄어쓰기 단어 제거, 분야당 약 70. 불러올 때 검증. 옛 `catch_words.js` 대체
- [ ] 엔진 TDD(`src/catch-engine.js`): 단어 뽑기(본 단어 제외, 라운드별 난이도), 판정(공백·NFC·소문자·동의어, 한 글자 차이 = 아까워요), 점수(맞힌 사람 3 + 20초당 1, 그린 사람 2, 직접 힌트 -1), 힌트 공개 일정(30·15초, 3글자 이상). **연속 50판(6라운드) 중복 없음** 테스트
- [ ] 모듈 `src/games/catch.js`: `startFromLobby`(`rounds` 6|4|8), 라운드 60초 서버 타이머, 획 `stroke {round,id,seq,tool,color,w,pts}`·`undo`·`clear`(그리는 사람만, 묶음 속도 제한), 라운드별 획 기록(상한) + `sync` 재생, 추측 0.7초 제한·라운드 번호 확인, 본 단어 `catch:<room>:seen`(90일·600개), 그리는 사람 번갈아, `restart`(시리즈), `restore`, `afk`, `recordGameOutcome(gameId)`. 옛 catch 코드 삭제
- [ ] 로비 옵션 `catch.rounds`
- [ ] 소켓 테스트 `test/catch-socket.test.js`: 서버 시작, 획 전달·재생(재접속), 실행 취소·지우기, 타이머 종료, 힌트 일정, 정답·아까워요, 제시어 비노출, 재대결
- [ ] 화면(`games/catch/`): 아틀리에 테마(`GameTheme.atelier`), 4:3 고정 보드(키보드에도 안 줄어듦), 크림 종이 + 스프링 철 + 파란 테두리, 한 손가락 `Listener`(점 찍기 포함, 33ms 묶음, 손 떼면 즉시), 완료 획 캐시 + 진행 획만 다시 그리기, 12색(44px)·굵기 3단계·연필/마커·지우개(같은 굵기)·실행 취소(20)·전체 지우기 확인, 양옆 배지·점수, 글자 칸 힌트·카운트다운, 추측 말풍선(그리는 사람도), 정답 연출, 결과 갤러리. 시작 버튼 없음
- [ ] 위젯 테스트(360·430 넘침 없음, 도구 상태, 비율 고정), `docs/socket-events/catch.md`

## Likely files
- `services/realtime-server/src/catch-engine.js`, `src/games/catch.js`, `src/data/catch-words.json`, `src/socket.js`, `src/lobby-options.js`, tests
- `apps/secret_base_app/lib/screens/arcade/games/catch/`, `games/catch_screen.dart`, `lobby_options.dart`, `game_theme.dart`(atelier)
