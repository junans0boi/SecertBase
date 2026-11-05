# 25: 벡터 화투 그림

**Type:** client

**Blocked by:** –

**Status:** ready-for-agent

## What to build

저해상도 PNG(60×91) 대신 직접 그린 **벡터 화투 48장 + 뒷면**을 만든다. 현대적인 평면 일러스트로 열두 달 모티프를 살리고, 작은 크기에서도 월과 종류가 구분되게 한다(01 Q28).

## Acceptance criteria

- [ ] `lib/widgets/hwatu/hwatu_art.dart`(+ 필요 시 월별 파일): `HwatuArt(cardId, size)` 위젯. 카드 id는 서버 엔진(`services/realtime-server/src/gostop-engine.js`)의 표기를 그대로 받는다
- [ ] 열두 달: 1 송학(소나무·학·해), 2 매조(매화·꾀꼬리), 3 벚꽃(벚꽃·막), 4 흑싸리(등나무·두견새), 5 난초(창포·다리), 6 모란(모란·나비), 7 홍싸리(싸리·멧돼지), 8 공산(억새·달·기러기), 9 국화(국화·술잔), 10 단풍(단풍·사슴), 11 오동(오동·봉황), 12 비(버들·제비·우산 쓴 사람은 단순한 실루엣). 광·열끗·띠(홍단·청단·초단 띠 색과 글씨 대신 무늬)·피의 차이가 분명할 것
- [ ] 모서리 종류 배지(광·열·띠·피), 쌍피에 "2" 표시, 월 숫자 작은 표시(색맹도 구분 가능)
- [ ] 고급 뒷면(진홍 바탕 + 금박 격자·문양)
- [ ] 크기 3종(손패·바닥·딴 패)에서 선명, 한 레이어 `CustomPainter`로 가볍게
- [ ] 갤러리 위젯 테스트(48장 + 뒷면 렌더, 예외 없음)와 골든 렌더로 직접 눈 확인(골든은 커밋하지 않음)
- [ ] 기존 `hwatu_card.dart`의 공개 API와 맞추거나 교체 가이드를 남긴다(통합 때 24 화면에 연결)

## Likely files
- `apps/secret_base_app/lib/widgets/hwatu/`
- `apps/secret_base_app/test/hwatu_art_test.dart`
