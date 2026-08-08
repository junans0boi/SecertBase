# 마블 작전 UI 전면 개편 스펙

> 다음 세션 시작 멘트:  
> **"docs/product/marble_ui_spec.md 읽고 전부 구현해줘"**

---

## 0. 공통 설계 원칙

- **게임 분위기**: 스파이 / 첩보 / 세계여행. 어둡고 세련된 다크 테마.
- **색상 팔레트** (변경 금지):
  - 배경: `#0D1117` (거의 검정)
  - 카드 배경: `#161B22`
  - 강조 골드: `#FFD700`
  - 강조 시안: `#00D4FF`
  - 내 팀: `#7C4DFF` (보라)
  - 상대 팀: `#E91E63` (핑크레드)
  - 성공/구매: `#00C853`
  - 위험/경고: `#FF3D00`
- **폰트**: GoogleFonts.notoSans 유지. 타이틀은 w900, 본문은 w600.
- **돈 포맷**: 아래 함수로 전역 통일. **절대 콤마(,) 방식 사용 금지.**
  ```dart
  String fmm(int n) {
    if (n == 0) return '0';
    final abs = n.abs();
    final sign = n < 0 ? '-' : '';
    final man = abs ~/ 10000;
    final rem = abs % 10000;
    if (man == 0) return '$sign${rem}원';
    if (rem == 0) return '$sign${man}만원';
    return '$sign${man}만${rem}원';
  }
  // 예: 3000020 → '300만20원'  /  5000000 → '500만원'  /  900 → '900원'
  ```
  - marble_screen.dart, marble_board.dart 내 모든 금액 표시를 이 함수로 교체.
  - 파일 상단 top-level 함수로 선언하여 양쪽 파일에서 import 없이 사용.

---

## 1. 프로필 카드 (`_MarbleHud` 전면 교체)

### 1-1. 레퍼런스
`docs/img/UI/프로필카드.png`, `docs/img/UI/주사위_굴리기(Roll)버튼_홀_짝.png`

레퍼런스 요약:
- 좌상단/우상단에 캐릭터 상체 초상화 카드
- 카드 안: 등급(A) 배지, 캐릭터 이름, **총자산 Xman**, **보유마블 Xman**
- 우측에 순위 원형 뱃지 (1위/2위)
- 마블머니는 **콤마 없이** `200만` `1000만` 형식

### 1-2. 현재 파일 위치
`apps/secret_base_app/lib/screens/arcade/games/marble_screen.dart`
- `_MarbleHud` (line 345) 전체 교체
- `_CoinChip` (line 444) 제거 → 새 카드 위젯으로 대체

### 1-3. 새 레이아웃 명세

```
┌───────────────────────────────────────────────┐
│ [내 프로필카드]   [중앙 HUD]   [상대 프로필카드] │
└───────────────────────────────────────────────┘
```

**`_ProfileCard` 위젯 (새로 작성):**
```dart
// 크기: width 130, height 60 (compact), 배경 반투명 다크
// 구성 요소:
// - 좌측: 캐릭터 상체 CustomPaint (width 44, height 56)
//         character ID → _CharacterBustPainter (아래 §9 참조)
//         등급 배지(A/S 등): 좌하단 겹침 원형
// - 우측:
//     [닉네임 (최대 6자)]
//     [💰 총자산: fmm(totalAssets)]   // totalAssets = coins + landValue
//     [🏠 보유마블: fmm(coins)]
// - 내 턴일 때: 테두리 골드 glow 효과 (BoxShadow + border)
```

**`_RankBadge` 위젯:**
```dart
// 플레이어 순위 (자산 기준 1위/2위) 원형 뱃지
// - 1위: 금색(#FFD700) 배경, '1위'
// - 2위: 은색(#B0BEC5) 배경, '2위'
// - 크기: 직경 36
// - 위치: 프로필카드 우측 끝에 겹치게 배치
```

**중앙 HUD:**
```dart
// 라운드: 'Round 7 / 30'  
// 시간: MM:SS 남은시간 (타이머 없으면 생략)
// 현재 턴: 내 턴이면 '⚡ 내 턴!' 골드, 상대 턴이면 '⏳' 흰색 흐리게
```

**전체 HUD 높이**: SafeArea 포함 72px  
**위치**: `Positioned(top: 0, left: 0, right: 0)`

---

## 2. 주사위 UI (전면 교체)

### 2-1. 레퍼런스
`docs/img/UI/주사위_굴리기(Roll)버튼누를시_게이지바.png`  
참조 코드: 사용자가 제공한 `Gamble` 위젯 (바운스+회전 애니메이션)

레퍼런스 요약:
- 보드 중앙에 큰 **ROLL** 버튼 (원형, 핑크~레드 그라디언트)
- 버튼 누르면 주사위 이미지가 **위로 솟구쳤다가 회전하며 떨어짐**
- 주사위 결과(dice1, dice2)가 좌우에 표시됨
- 홀/짝 선택 버튼 두 개 (파란 원형)

### 2-2. 현재 파일 위치
`apps/secret_base_app/lib/ui/marble_board.dart`
- `_DiceRollButton` (line 2343) 전면 교체
- `_DiceArea` 새 위젯으로 통합

### 2-3. 새 주사위 명세

**`_DiceWidget` (StatefulWidget, TickerProviderStateMixin):**
```dart
// 애니메이션 2개:
// 1. _bounceAnim: Tween(0 → -180px) → reverse  (1초)
// 2. _spinAnim:   Tween(0 → 10π) → reverse      (1초)

// 주사위 페이스 이미지: AssetImage 또는 CustomPaint로 1~6 그리기
// 크기: 56×56 (주사위 하나)
// 굴리기 중: 이미지 랜덤 전환 (매 100ms) + 바운스+스핀

// 결과 표시: 굴린 후 dice1, dice2 값 고정 표시
// 더블: 테두리 골드 강조 + '더블!' 텍스트 
```

**`_DiceArea` (보드 중앙 배치):**
```dart
// 구성:
// [주사위1] [주사위2]  ← 결과 또는 ? 표시
//      [ROLL 버튼]     ← 원형, 크기 80×80
//  [홀] [짝] 버튼     ← oddEven 선택 (round 3배수 등 특정 조건)

// ROLL 버튼 스타일:
//   활성: 레드-핑크 방사형 그라디언트, 흰 텍스트 'ROLL', 드롭섀도
//   비활성: 회색 반투명
//   누를 때: InkWell splash + 0.95 scale 스케일 축소

// 홀/짝 버튼:
//   파란 원형, 각각 '홀' '짝', 크기 48×48
//   선택 가능한 경우에만 표시 (phase == 'odd_even')
```

---

## 3. 금액 표시 전면 수정

### 3-1. 수정 대상 파일
- `marble_screen.dart`: `_CoinChip`, `_LandPromptDialog`, `_MarbleResultDialog`, `_MarbleHud`
- `marble_board.dart`: 보드 내 금액 표시 모든 곳

### 3-2. 교체 규칙
- `NumberFormat('#,###').format(n)` → `fmm(n)` 으로 전부 교체
- `'${n} 💰'` 패턴 → `'${fmm(n)}'` 으로 교체
- `'$n MM'` 등 모든 패턴 → `fmm(n)` 으로 교체

---

## 4. 영지 구매/인수 다이얼로그 전면 교체 (`_LandPromptDialog`)

### 4-1. 레퍼런스
`docs/img/UI/도시 인수.png`, `docs/img/UI/상대 지역 인수.png`, `docs/img/UI/돈이 없을때 건물 매각.jpeg`

레퍼런스 요약 — **도시 인수 다이얼로그**:
```
┌─────────────────────────────────┐
│           도시 인수              │  ← 타이틀바 (갈색 배경)
├─────────────────────────────────┤
│   [도시명] 인수 할까요?           │  ← 말풍선 스타일 흰 박스
│   주의: 건설 가의 2배지불          │  ← 소자 경고
├─────────────────────────────────┤
│  인수비용 ➜  77만2000             │
│  [캐릭터효과] 인수 할인 ➜ 4만4004  │  ← 골드 뱃지
├─────────────────────────────────┤
│  [취소]        [인수 💴 72만7996] │  ← 파란/골든 버튼
├─────────────────────────────────┤
│  인수 후 남는 마블 ➜ 70만3332      │
└─────────────────────────────────┘
```

**상대 지역 인수 다이얼로그**:
- 타이틀: "인수" (파란 그라디언트 배경)
- "상대 병력을 인수할까요?" + 경고 텍스트
- 인수비용, 할인, 잔액 행
- [취소] [전투 💴] [무료] 버튼 (무료 조건이면)

**돈 부족 시 건물 매각 다이얼로그**:
- "부족한 금액" 빨간 강조
- 건물 매각 선택 목록
- 금액 새로 계산

### 4-2. 현재 파일 위치
`marble_screen.dart` line 501 `_LandPromptDialog`

### 4-3. 새 다이얼로그 명세

**공통 컨테이너 스타일:**
```dart
decoration: BoxDecoration(
  gradient: LinearGradient(
    colors: [Color(0xFF1A1230), Color(0xFF0D1117)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  ),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Color(0x44FFD700), width: 1.5),
  boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 24)],
)
```

**타이틀 배너:**
```dart
// 상단 가로 배너
// claim: 보라(#5B21B6) 그라디언트 + '🏴 영지 점령'
// acquire: 레드(#B91C1C) 그라디언트 + '🤝 도시 인수'
// upgrade: 오렌지(#C2410C) 그라디언트 + '🏗️ 건물 건설'
```

**정보 행 `_InfoRow`:**
```dart
// label: 왼쪽, 흰 60% 투명도
// value: 오른쪽, 굵은 흰색, fmm() 적용
// 구분선: 1px Border(0x22FFFFFF)
```

**버튼:**
```dart
// 취소: 둥근 회색 반투명
// 실행: 골든 그라디언트 [#F59E0B → #D97706], 검정 텍스트, 큰 폰트
// 돈 부족 시: 빨간 버튼 비활성화 + '마블이 부족합니다' 경고 텍스트
```

**버그 수정 (텍스트 안 보임 문제):**
- `_InfoRow`의 `value` Text에 `color: Colors.white` 명시
- `title` Text에 `color: Colors.white` 명시
- `AlertDialog(backgroundColor: ...)` 대신 `Dialog(child: Container(...))` 패턴으로 교체
  → AlertDialog의 기본 테마가 텍스트 색상을 덮어쓰는 버그 회피

---

## 5. 이벤트 타일 도착 오버레이 (신규 구현)

### 5-1. 레퍼런스
`docs/img/UI/선 정하기.png`, `docs/img/UI/관광지 독점.png`

레퍼런스 요약:
- 특수 타일 도착 시 화면 중앙에 **풀스크린 오버레이** (반투명 블랙)
- 타일 아이콘 + 이름 + 설명이 애니메이션으로 등장
- 자동으로 2초 후 사라짐 (또는 탭하면 사라짐)

### 5-2. 타일별 오버레이 내용

| pos | 이름 | 아이콘 | 설명 |
|-----|------|--------|------|
| 0 | 임무개시 | 🚀 | `fmm(MARBLE_SALARY)` 마블머니 수령! |
| 6 | 블랙사이트 | 🔒 | {N}턴 동안 구금됩니다 |
| 12 | 운영본부 | 🏛️ | `fmm(SPECIAL_FEE)` 세금 납부 |
| 18 | 비밀게이트 | 🌀 | 원하는 위치로 이동 가능 |
| 3,9,15,21 | 황금열쇠 | 🗝️ | 황금열쇠 카드를 뽑습니다 |
| 8,17 | 관광지 | ✈️ | 관광지에 도착! (소유자에게 통행료) |

### 5-3. 구현 명세

**`_TileEventOverlay` 위젯 (StatefulWidget, SingleTickerProviderStateMixin):**

```dart
// 트리거: marble_screen.dart에서 marblePendingMoves가 비고 말이 멈췄을 때
//         AND 현재 내 말 위치가 특수 타일일 때
//         → setState로 _showTileEvent = true, _eventPos = pos 설정

// 애니메이션:
// 1. 진입: 0.3초 scale 0.6→1.0 + opacity 0→1 (elasticOut curve)
// 2. 대기: 1.5초
// 3. 퇴장: 0.2초 opacity 1→0

// 레이아웃:
Container(
  color: Color(0xCC000000), // 반투명 블랙
  child: Center(
    child: Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 72)), // 이모지 아이콘
        SizedBox(height: 12),
        Text(name, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: w900)),
        SizedBox(height: 8),
        Text(description, style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
      ],
    ),
  ),
)

// 추가 효과 (pos별):
// - 임무개시(0): 금화 파티클 애니메이션 (간단한 confetti 또는 별 날리기)
// - 블랙사이트(6): 적색 펄스 테두리
// - 황금열쇠(3,9,15,21): 카드 뒤집기 애니메이션 힌트
// - 비밀게이트(18): 소용돌이/포탈 효과 (간단한 rotate 애니메이션)
```

**트리거 위치 (`marble_screen.dart` `_onSocket` 또는 `_MarbleBoardState`):**
```dart
// marblePendingMoves가 비어지고 phase가 'throwing'으로 바뀔 때
// 내 말의 현재 위치 확인 → 특수 타일이면 오버레이 표시
// (단, 구매 다이얼로그가 이미 뜨는 경우에는 오버레이 생략)
```

---

## 6. 승리/패배 결과 화면 전면 교체 (`_MarbleResultDialog`)

### 6-1. 레퍼런스
`docs/img/UI/승리.jpg`, `docs/img/UI/파산패배.jpg`, `docs/img/UI/트리플독점.jpg`

레퍼런스 요약:
- **승리**: 화면 가득 "WIN" 텍스트 (골드, 대형) + 캐릭터 프로필 + 최종 자산
- **파산 승리**: "파산 승리!" + 보너스 배율 표시
- **독점 승리**: 해당 독점 종류 (관광지독점 / 더블독점 / 라인독점) 강조

### 6-2. 현재 파일 위치
`marble_screen.dart` line 847 `_MarbleResultDialog`

### 6-3. 새 결과 화면 명세

**전체를 `Dialog` (not `AlertDialog`)로 교체. 풀스크린에 가까운 크기.**

```dart
// 배경: 반투명 블랙 오버레이 + 중앙 카드
// 카드: width 320, 다크 그라디언트

// 승리 레이아웃:
// 1. 상단: 결과 타입에 따른 애니메이션 타이틀
//    - 더블독점 → '🏆 더블 독점 승리!'  (골드)
//    - 라인독점 → '🏆 라인 독점 승리!'  (골드)
//    - 관광지독점→ '✈️ 관광지 독점 승리!' (시안)
//    - 파산     → '💀 파산 승리!'       (오렌지)
//    - timeout  → '⏱️ 자산 승리!'       (흰색)
//    - 패배     → '😢 패배'             (회색)
// 2. 중앙: 캐릭터 상체 (CharacterBust) + 순위뱃지
// 3. 하단:
//    - 내 최종 자산: fmm(myCoins) 큰 숫자
//    - 상대 최종 자산: fmm(opCoins) 작은 숫자
// 4. 버튼: '확인' 골든 버튼

// 파티클 효과:
// - 승리 시: 금화/별 confetti (간단한 AnimatedBuilder로 랜덤 위치 이동)
// - 패배 시: 없음 (심플하게)
```

---

## 7. 맵(보드) 내 프로필카드 크기 수정

### 7-1. 현재 문제
`marble_board.dart`의 내 캐릭터 토큰 / 상단 프로필이 너무 커서 맵을 가림

### 7-2. 수정 위치
`marble_board.dart` — `_CharacterTokenPainter` (이미 우리 세션에서 수정됨)

추가로 **맵 위 프로필 카드 오버레이**가 있다면:
- 프로필카드 높이: 현재 값의 **0.75배** 로 줄이기
- SafeArea 패딩 고려하여 top 여백 확보

### 7-3. 보드 내 캐릭터 토큰 크기
- 현재 `faceR = radius * 0.38` — 유지
- `radius` 자체가 너무 크면: 보드 타일 크기 대비 비율 확인
  → `_MarbleBoardState.build()`에서 token radius 계산 부분 찾아 `* 0.85` 적용

---

## 8. 캐릭터 렌더링 규칙

### 8-1. 두 가지 모드

| 모드 | 사용처 | 크기 | 그리는 범위 |
|------|--------|------|-------------|
| **Bust** (상체) | 프로필카드, 인벤토리 카드, 뽑기 | 100×120 px | 어깨~머리 |
| **Token** (말) | 게임 보드 위 말 | radius 기반 | 전신 (머리+몸통) |

현재 `_CharacterTokenPainter`는 Token 모드 (이미 구현됨).

### 8-2. `_CharacterBustPainter` (신규 구현)

`marble_board.dart` 또는 새 파일 `lib/ui/character_painters.dart` 에 추가:

```dart
// 프로필카드/인벤토리용 상체 화가
// canvas size: 100×120
// 좌표계: cx=50, hy=70 (얼굴 중심)
// 
// 캐릭터별 색상 (§9 참조)
// 그리기 순서:
// 1. 어깨/상의 (bodyCenter = cx, cy=105)
// 2. 머리카락 (face 뒤)
// 3. 얼굴 타원 (faceR=28)
// 4. 이목구비
// 5. 뱃지/악세서리
//
// 오메가: 마스크+후드, 초록 눈 (기존 Token 방식 그대로)
```

### 8-3. 현재 얼굴 안 보이는 캐릭터 수정

아티팩트 URL: https://claude.ai/code/artifact/2b5e7784-cda4-4ab9-a2c9-bb961b11b172

문제 캐릭터: **루나(luna), 렉스(rex), 지아(zia), 하윤(hayun)** — 얼굴/눈 NaN 버그 또는 그리기 순서 오류

수정 규칙 (이미 이 세션에서 `_CharacterTokenPainter`에 적용됨):
- 머리카락은 반드시 face drawCircle **이전**에 그리기
- 머리카락 너비 ≥ faceR × 2.2 (얼굴보다 넓게)
- 머리카락 top ≥ faceCenter.dy - faceR × 1.2 (얼굴 위까지 덮기)
- `quadraticCurveTo` 항상 4개 인수 확인

**`_drawSpyAgent`에서 각 캐릭터별 추가 특징 (Token 말에서 전신 표현):**

```dart
// 현재 구현: 머리카락 아크 + 얼굴 + 몸통 사각형 + 이니셜
// 개선: 각 캐릭터 특징 추가

// k (케이): 검정 짧은 헤어 + 네이비 수트 + 넥타이
// ria (리아): 다크 밥컷 + 네이비 블레이저 + 크림슨 핀
// luna (루나): 보라 짧은 헤어 + 보라 재킷
// rex (렉스): 갈색 헤어 + 짙은 갈색 야전복
// zia (지아): 검정 헤어 + 틸 재킷
// drv (닥터V): 은발 + 흰 실험복
// hayun (하윤): 검정 헤어 + 올리브 전투복
// jake (제이크): 갈색 헤어 + 네이비 해군복
// nova (노바): 다크브라운 헤어 + 주황 봄버 + 고글
// omega (오메가): 전신 후드 + 마스크 + 초록 눈만
```

---

## 9. 캐릭터 색상 데이터 (전역 상수)

`lib/ui/marble_board.dart` 또는 `lib/ui/character_painters.dart` 상단에 상수 맵으로 정의:

```dart
const _spyCharData = {
  'k':     (skin: 0xFFC88F60, hair: 0xFF141420, outfit: 0xFF0C1B2A, symbol: 'K', 
             hairStyle: 'short', special: 'tie'),
  'ria':   (skin: 0xFFE0BFAA, hair: 0xFF160810, outfit: 0xFF1E2D4A, symbol: 'R',
             hairStyle: 'bob', special: 'pin'),
  'luna':  (skin: 0xFFF2D8BC, hair: 0xFF5B21B6, outfit: 0xFF5B21B6, symbol: 'L',
             hairStyle: 'short_purple', special: 'none'),
  'rex':   (skin: 0xFFC07840, hair: 0xFF6B3A12, outfit: 0xFF5C3010, symbol: 'X',
             hairStyle: 'medium', special: 'none'),
  'zia':   (skin: 0xFFDCCAB4, hair: 0xFF070C14, outfit: 0xFF0E7490, symbol: 'Z',
             hairStyle: 'long', special: 'none'),
  'drv':   (skin: 0xFFDCC8A8, hair: 0xFF8898AA, outfit: 0xFFD0D8E8, symbol: 'V',
             hairStyle: 'silver', special: 'coat'),
  'hayun': (skin: 0xFFC89060, hair: 0xFF1C1008, outfit: 0xFF3D5A2A, symbol: 'H',
             hairStyle: 'short', special: 'none'),
  'jake':  (skin: 0xFFEACBA0, hair: 0xFF7B4A18, outfit: 0xFF1D3461, symbol: 'J',
             hairStyle: 'medium', special: 'anchor'),
  'nova':  (skin: 0xFFD4956A, hair: 0xFF2C1810, outfit: 0xFFC2410C, symbol: 'N',
             hairStyle: 'spiky', special: 'goggles'),
  'omega': (skin: 0xFF101418, hair: 0xFF050810, outfit: 0xFF080C10, symbol: 'Ω',
             hairStyle: 'hood', special: 'mask'),
};
```

---

## 10. 게임 이펙트 (신규 구현)

### 10-1. 현재 문제
이벤트 타일 도착 / 독점 달성 / 건물 건설 등 어떤 이벤트에도 시각 효과 없음

### 10-2. 구현할 이펙트 목록

| 이벤트 | 이펙트 | 구현 방법 |
|--------|--------|-----------|
| 임무개시 통과 | 금화 파티클 + 노란 플래시 | `_ConfettiLayer` AnimatedBuilder |
| 블랙사이트 도착 | 빨간 테두리 펄스 3회 | BorderAnimation |
| 운영본부 세금 | 코인 빠져나가는 애니메이션 | SlideTransition |
| 비밀게이트 | 포탈 소용돌이 | RotationTransition |
| 황금열쇠 뽑기 | 카드 뒤집기 (FlipCard) | Transform perspective |
| 건물 건설 | 건물 팝업 (scale 0→1) | ScaleTransition |
| 독점 달성 | 전체 화면 번쩍 + 텍스트 | `_MonopolyFlash` |
| 말 잡기 | 불꽃 효과 | 파티클 |
| 더블 주사위 | '더블!' 골드 팝업 | AnimatedScale |

### 10-3. `_ConfettiLayer` 명세

```dart
// 20~30개 파티클, 각각:
// - 랜덤 시작 위치 (화면 상단)
// - 랜덤 색상 (골드, 시안, 흰색)
// - 아래로 떨어지며 좌우 흔들림 (sin 함수)
// - 크기 3~8px 원형
// - 1.5초 후 fade out

// 트리거: marble_screen.dart에서
// if (passedStart) _triggerConfetti();
```

### 10-4. `_MonopolyFlash` 명세

```dart
// 독점 종류 수신 시 (socket에서 winReason으로 pre-감지 또는 별도 이벤트)
// 0.5초 흰 flash → 텍스트 등장 → 2초 유지 → fade

// 독점 유형별 텍스트:
// double_monopoly: '더블 독점!'
// line_monopoly: '라인 독점!'
// tourist_monopoly: '관광지 독점!'
// bankrupt: '파산!'
```

---

## 11. 구현 순서 권장

1. **§3 돈 포맷 (`fmm`)** — 전역 함수 하나로 전부 교체. 가장 쉽고 가장 넓은 범위.
2. **§4 랜드 프롬프트 다이얼로그 버그 수정** — AlertDialog → Dialog + 텍스트 색상 명시.
3. **§1 프로필 카드** — `_MarbleHud` 전면 교체 (`_ProfileCard` + `_RankBadge`).
4. **§2 주사위** — `_DiceRollButton` → `_DiceWidget` + `_DiceArea`.
5. **§5 이벤트 타일 오버레이** — `_TileEventOverlay` 신규 작성.
6. **§6 결과 화면** — `_MarbleResultDialog` 전면 교체.
7. **§7 맵 내 카드 크기** — 숫자 조정.
8. **§8,9 캐릭터 페인터** — `_CharacterBustPainter` 신규 + Token 말 개선.
9. **§10 게임 이펙트** — 파티클/플래시/팝업 순.

---

## 12. 주요 파일 위치 요약

```
apps/secret_base_app/lib/
  screens/arcade/games/
    marble_screen.dart          ← 주요 UI (HUD, 다이얼로그, 결과창)
  ui/
    marble_board.dart           ← 보드 + 주사위 + 말 토큰
    character_painters.dart     ← (신규) CharacterBust/Token 분리
```

---

## 13. 아티팩트 캐릭터 수정 (별도 작업)

URL: https://claude.ai/code/artifact/2b5e7784-cda4-4ab9-a2c9-bb961b11b172

수정 대상: `agents.html` 내 `drawLuna`, `drawRex`, `drawZia`, `drawHayun` 함수

공통 수정 패턴:
```javascript
// 머리카락 먼저:
ctx.beginPath();
// hairPath — cx ±(faceRx+15), top at hy-90
ctx.fillStyle = hairColor;
ctx.fill();

// 그 다음 얼굴:
ctx.beginPath();
ctx.ellipse(cx, hy, 65, 72, 0, 0, Math.PI*2);
ctx.fillStyle = skinColor;
ctx.fill();

// 뱅 (앞머리 클리핑):
ctx.save();
ctx.beginPath();
ctx.ellipse(cx, hy, 65, 72, 0, 0, Math.PI*2);
ctx.clip();
ctx.fillStyle = hairColor;
// 앞머리 영역만 fill
ctx.restore();
```

수정 후 아티팩트 재배포.
