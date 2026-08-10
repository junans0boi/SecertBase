import 'dart:math';

// 마블 게임 나레이션 대사 SSoT
// _pick()으로 랜덤 선택. 이벤트별 static 메서드 호출.
class MarbleNarration {
  static final _rng = Random();
  static String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  // ─── 턴 / 순서 ─────────────────────────────────────────────────────────────

  static String rollOrder() => _pick([
    '주사위 굴려서 순서 정해봐요',
    '누가 먼저 갈지 정하는 시간이에요',
  ]);

  static String myFirst() => _pick([
    '제가 먼저 하겠습니다~',
    '선 갔어요! 고고',
  ]);

  static String mySecond() => _pick([
    '저는 두 번째네요',
    '나중에 가는 게 더 좋은 거라고요 (아님)',
  ]);

  static String myTurn() => _pick([
    '제 차례예요~',
    '마이 턴!',
    '자, 갑니다',
  ]);

  static String opponentTurn() => _pick([
    '상대 차례 기다리는 중...',
    '뭐 던질지 보자',
  ]);

  // ─── 주사위 ─────────────────────────────────────────────────────────────────

  static String double_() => _pick([
    '더블~! 한 번 더 던져요',
    '어, 더블이네요 한 번 더!',
  ]);

  // total: 주사위 두 개의 합 (2~12)
  static String dice(int total) {
    if (total <= 2) return _pick(['2... 뭐 어때요', '최솟값이에요 ㅠ']);
    if (total <= 5) return _pick(['이 정도면 나쁘지 않아요', '평범하게 나왔네요']);
    if (total <= 8) return _pick(['오, 나이스~', '잘 나왔어요!']);
    if (total <= 11) return _pick(['많이 나왔다~', '오 좋은데요?']);
    return _pick(['12! 최대예요~', '와, 12 나왔어요!']);
  }

  // ─── 통행료 ─────────────────────────────────────────────────────────────────

  static String tollPaid(int amount) {
    if (amount >= 1000000) {
      return _pick(['이거 너무한 거 아닌가요', '흠... 많이 나갔네요 ㅠ']);
    }
    return _pick([
      '이럴 수가 ㅜㅜ',
      '돈 나갔어요...',
      '아 여기 오면 안 됐는데',
    ]);
  }

  static String tollReceived(int amount) {
    if (amount >= 1000000) {
      return _pick(['대박~!', '이거 많이 받았는데요?']);
    }
    return _pick([
      '나이스~!',
      '들어오셨군요~',
      '고마워요~',
    ]);
  }

  // ─── 영지 ───────────────────────────────────────────────────────────────────

  static String landClaim() => _pick([
    '내 영지 생겼어요~',
    '여기 제 땅이에요 이제',
  ]);

  static String landUpgrade() => _pick([
    '업그레이드~!',
    '더 강해지는 중이에요',
  ]);

  static String landLandmark() => _pick([
    '랜드마크 건설~!',
    '드디어 랜드마크예요',
  ]);

  static String landAcquired() => _pick([
    '인수했어요~',
    '이제 제 영지예요',
  ]);

  static String landLost() => _pick([
    '영지 인수당했어요 ㅠ',
    '빼앗겼네요...',
  ]);

  static String landSkip() => _pick([
    '일단 패스할게요',
    '다음에 살게요',
  ]);

  // ─── 특수 타일 ──────────────────────────────────────────────────────────────

  static String chanceCard() => _pick([
    '찬스카드~!',
    '카드 뽑는 시간이에요',
  ]);

  static String chanceCardGain() => _pick([
    '오~ 좋은 카드네요',
    '이건 이득이에요',
  ]);

  static String chanceCardLoss() => _pick([
    '별로인 카드 ㅠ',
    '이건 좀 아쉽네요',
  ]);

  static String tax() => _pick([
    '세금이에요 ㅠ',
    '운영본부... 좀 아프네요',
  ]);

  static String passedStart() => _pick([
    '임무개시 통과~! 월급이에요',
    '한 바퀴 돌았어요 보너스!',
  ]);

  static String jail() => _pick([
    '블랙사이트 갇혔어요 ㅠ',
    '잠깐 쉬어가야겠네요',
  ]);

  static String gate() => _pick([
    '비밀게이트~! 어디로 갈까요',
    '워프!',
  ]);

  static String tourist() => _pick([
    '관광지 왔어요~',
    '비밀의 섬이에요',
  ]);

  // ─── 게임 흐름 ──────────────────────────────────────────────────────────────

  // round >= 27 (maxRound=30 기준)
  static String endgameWarning() => _pick([
    '이제 얼마 안 남았어요!',
    '막판이에요 집중~',
  ]);

  static String pieceCaptured() => _pick([
    '잡았어요~! 한 번 더!',
    '캐치! 한 번 더 던져요',
  ]);

  static String pieceLost() => _pick([
    '잡혔어요 ㅠ 다시 가야겠네요',
    '억울해요...',
  ]);

  // ─── 게임 종료 ──────────────────────────────────────────────────────────────

  static String win() => _pick([
    '이겼어요~!',
    '제가 이겼네요 감사합니다',
  ]);

  static String lose() => _pick([
    '졌어요 ㅠ 다음엔 이길게요',
    '아쉽네요...',
  ]);

  static String draw() => _pick([
    '비겼어요~ 다시 한 판!',
    '타이예요 아쉽다',
  ]);

  static String bankruptWin() => _pick([
    '파산시켰어요~!',
    '경제전 승리!',
  ]);

  static String bankruptLose() => _pick([
    '파산했어요 ㅠ',
    '이 결과 어떻게 된 거예요...',
  ]);
}
