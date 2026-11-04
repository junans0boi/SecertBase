# 02: 무승부 결과 기록과 참여 보상

**What to build:** 무승부 판이 game_results에 기록되고 두 사람 모두 참여 XP와 game_play 미션 진행을 얻는다. 아케이드 기록 카드에 무승부가 보이고, 승패 없는 게임에는 기록 카드가 숨겨진다.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] 마이그레이션 0048: is_draw, winner/loser NULL 허용
- [ ] saveGameResult/grantGameXpAndMissions 무승부 경로
- [ ] /arcade/records가 draws 반환
- [ ] 블랙잭·패널티·볼링·그림 맞히기 무승부 기록
- [ ] 클라이언트 기록 카드: 무 표시, telepathy/dice 숨김
