# 12: 패널티킥 2.0 화면

**Type:** client

**Blocked by:** 02, 03, 11

**Status:** ready-for-agent

## What to build

귀여운 마스코트와 밝은 낮 경기장, 한 번에 이해되는 조작으로 패널티킥을 새로 만든다. 처음 하는 사람도 쉽게 즐길 수 있어야 한다.

## Acceptance criteria

- [ ] `games/penalty/` 폴더 + 얇은 진입점
- [ ] 경기장: 파스텔 하늘, 먼 관중석, 밝은 잔디 줄무늬, 큼직한 골대(3개 터치 영역) + 아래 큰 버튼 3개(왼쪽/가운데/오른쪽). 거칠거나 어두운 요소 없음
- [ ] 마스코트: 둥근 몸 + 유니폼(나=민트, 상대=분홍) + **얼굴은 프로필 이모지**(`profileEmojis`). 키커 걷기→킥, 키퍼 다이브 모션
- [ ] 상단: 점수판 ●○ 5개씩, **상대의 지난 킥 방향 기록 최근 5번**, 남은 시간 링(20초)
- [ ] 조작: 탭으로 방향 선택(하이라이트) + 큰 "슛!"/"막기!" 버튼 하나로 확정
- [ ] 연출: 공 비행 0.9초 + 키퍼 다이브 + 그물 출렁 + 관중 환호/탄식 + 색종이 또는 "나이스!". 탭으로 건너뛰기
- [ ] 첫 판 요약 오버레이(3줄 이내: "골대 세 칸 중 하나를 골라요. 키퍼가 같은 쪽을 고르면 막혀요!") + 상단 `?` 버튼. `penalty_tutorial_seen` 저장
- [ ] 효과음: 휘슬, 킥, 그물, 환호, 탄식, 선방 (`recipes/soccer.dart`)
- [ ] 결과 `GameResultSheet`(무승부 포함, 전적, 재대결). 게임 안 별도 시작 제거, 로비 설명 문구 갱신
- [ ] `GameMenuListener`/`GameScaffold(gameType: 'penalty')`
- [ ] 위젯 테스트: 3영역 탭 선택, 확정 버튼 상태, 상대 킥 기록 표시, 첫 판 오버레이 1회 표시, 폭 360
- [ ] 두 계정 실플레이 한 판(골·선방·서든데스·시간 초과 자동 선택)을 확인하고 PR에 기록

## Notes

사용자 요구: "너무 투박하고 여성도 쉽게 플레이할 수 있었으면 함". 사람 그림은 쓰지 않는다(D5에서 대안을 고르면 반영).

## Likely files

- `apps/secret_base_app/lib/screens/arcade/games/penalty/`
- `apps/secret_base_app/lib/screens/arcade/arcade_screen.dart`
