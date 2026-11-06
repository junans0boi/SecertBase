/// 그림 맞히기 2.0: 서버 상태(`game:catch:state`)와 획(stroke)을 읽기 쉬운 모양으로 옮긴 것.
/// 계약: docs/socket-events/catch.md
library;

import 'dart:ui';

/// 그리기 도구. 서버 문자열(`pen`/`marker`/`eraser`)과 같다.
enum CatchTool {
  pen('pen', '연필'),
  marker('marker', '마커'),
  eraser('eraser', '지우개');

  final String wire;
  final String label;

  const CatchTool(this.wire, this.label);

  static CatchTool fromWire(Object? v) => CatchTool.values.firstWhere(
    (t) => t.wire == v,
    orElse: () => CatchTool.pen,
  );
}

/// 보드는 항상 4:3. 좌표는 0~1로 정규화하고, 굵기는 보드 너비 대비 비율이다.
const double kCatchBoardAspect = 4 / 3;

/// 획을 기록·그리는 가상 보드 크기. 화면 크기와 상관없이 이 크기로 그린 뒤 확대·축소한다.
const double kCatchVirtualW = 1000;
const double kCatchVirtualH = 750;

/// 팔레트 12색(서버는 번호 0~11만 받는다).
class CatchInk {
  final String name;
  final Color color;

  const CatchInk(this.name, this.color);
}

const List<CatchInk> kCatchPalette = [
  CatchInk('검정', Color(0xFF23242C)),
  CatchInk('회색', Color(0xFF8C8F9A)),
  CatchInk('갈색', Color(0xFF8A5A3C)),
  CatchInk('빨강', Color(0xFFE5483F)),
  CatchInk('주황', Color(0xFFF58A2E)),
  CatchInk('노랑', Color(0xFFF7C934)),
  CatchInk('초록', Color(0xFF3BA55D)),
  CatchInk('하늘', Color(0xFF4CC3F0)),
  CatchInk('파랑', Color(0xFF2F62E0)),
  CatchInk('보라', Color(0xFF8A56D6)),
  CatchInk('분홍', Color(0xFFF27AB0)),
  CatchInk('살구', Color(0xFFF8C9A0)),
];

/// 굵기 3단계(보드 너비 대비). 연필 기준이고 마커·지우개는 [catchWidthFactor]만큼 더 굵게 그린다.
const List<double> kCatchBrushWidths = [0.008, 0.016, 0.030];
const List<String> kCatchBrushLabels = ['가늘게', '보통', '굵게'];

/// 도구별 실제 선 굵기 배율. 그리는 쪽과 받는 쪽이 같은 값을 쓴다(지우개 크기가 달랐던 옛 버그 방지).
double catchWidthFactor(CatchTool tool) => switch (tool) {
  CatchTool.pen => 1.0,
  CatchTool.marker => 1.7,
  CatchTool.eraser => 2.4,
};

/// 실행 취소로 되돌릴 수 있는 최근 획 수.
const int kCatchUndoLimit = 20;

Map<String, int> _intMap(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', (val as num?)?.toInt() ?? 0))
    : <String, int>{};

/// 추측 말풍선.
class CatchGuess {
  final String id;
  final int round;
  final String userId;
  final String text;
  final String verdict; // wrong | close | correct

  const CatchGuess({
    required this.id,
    required this.round,
    required this.userId,
    required this.text,
    required this.verdict,
  });

  static CatchGuess fromMap(Map<String, dynamic> m) => CatchGuess(
    id: '${m['id'] ?? ''}',
    round: (m['round'] as num?)?.toInt() ?? 0,
    userId: '${m['userId'] ?? ''}',
    text: '${m['text'] ?? ''}',
    verdict: '${m['verdict'] ?? 'wrong'}',
  );

  bool get close => verdict == 'close';
  bool get correct => verdict == 'correct';
}

/// 끝난 한 라운드의 기록(결과 화면·정답 공개 연출).
class CatchRoundRecord {
  final int round;
  final String drawer;
  final String word;
  final String category;
  final String outcome; // correct | timeout
  final String? guesser;
  final Map<String, int> points;
  final int timeLeftMs;
  final bool usedHint;
  final Map<String, int> scores;

  const CatchRoundRecord({
    required this.round,
    required this.drawer,
    required this.word,
    required this.category,
    required this.outcome,
    required this.guesser,
    required this.points,
    required this.timeLeftMs,
    required this.usedHint,
    required this.scores,
  });

  static CatchRoundRecord fromMap(Map<dynamic, dynamic> m) => CatchRoundRecord(
    round: (m['round'] as num?)?.toInt() ?? 0,
    drawer: '${m['drawer'] ?? ''}',
    word: '${m['word'] ?? ''}',
    category: '${m['category'] ?? ''}',
    outcome: '${m['outcome'] ?? 'timeout'}',
    guesser: m['guesser'] as String?,
    points: _intMap(m['points']),
    timeLeftMs: (m['timeLeftMs'] as num?)?.toInt() ?? 0,
    usedHint: m['usedHint'] == true,
    scores: _intMap(m['scores']),
  );

  bool get correct => outcome == 'correct';
}

/// 서버가 라운드 끝에 보내는 `round_result`. 기록에 연출 시각이 붙은 것.
class CatchRoundResult {
  final CatchRoundRecord record;
  final bool last;
  final int? revealUntil;
  final int? serverNow;

  const CatchRoundResult({
    required this.record,
    required this.last,
    this.revealUntil,
    this.serverNow,
  });

  static CatchRoundResult fromMap(Map<String, dynamic> m) => CatchRoundResult(
    record: CatchRoundRecord.fromMap(m),
    last: m['last'] == true,
    revealUntil: (m['revealUntil'] as num?)?.toInt(),
    serverNow: (m['serverNow'] as num?)?.toInt(),
  );
}

/// 결과 화면 갤러리의 한 칸: 라운드별 최종 그림.
class CatchGalleryItem {
  final CatchRoundRecord info;
  final List<CatchStroke> strokes;

  const CatchGalleryItem(this.info, this.strokes);

  static CatchGalleryItem fromMap(Map<dynamic, dynamic> m) =>
      CatchGalleryItem(CatchRoundRecord.fromMap(m), [
        for (final s in (m['strokes'] as List? ?? const []))
          if (s is Map) CatchStroke.fromMap(s),
      ]);
}

class CatchResult {
  final String? winner;
  final String? loser;
  final bool draw;
  final String reason; // score | forfeit | both_away
  final Map<String, int> scores;

  const CatchResult({
    required this.winner,
    required this.loser,
    required this.draw,
    required this.reason,
    required this.scores,
  });

  static CatchResult? fromMap(Object? v) {
    if (v is! Map) return null;
    return CatchResult(
      winner: v['winner'] as String?,
      loser: v['loser'] as String?,
      draw: v['draw'] == true,
      reason: '${v['reason'] ?? 'score'}',
      scores: _intMap(v['scores']),
    );
  }
}

class CatchState {
  final String gameId;
  final String status; // playing | finished
  final String phase; // drawing | reveal | over
  final List<String> players;
  final int round;
  final int maxRounds;
  final String drawer;
  final String category;
  final int wordLen;
  final List<String> hint; // 열린 칸은 글자, 닫힌 칸은 ''
  final bool canHint;
  final bool directHint;
  final String? word; // 그리는 사람 또는 정답 공개 뒤에만
  final int? roundStartsAt;
  final int? turnDeadline;
  final int roundMs;
  final int? revealUntil;
  final int revealMs;
  final Map<String, int> scores;
  final List<CatchGuess> guesses;
  final List<CatchRoundRecord> history;
  final CatchResult? result;
  final Map<String, dynamic>? series;
  final int? serverNow;
  final List<CatchGalleryItem> gallery;

  const CatchState({
    required this.gameId,
    required this.status,
    required this.phase,
    required this.players,
    required this.round,
    required this.maxRounds,
    required this.drawer,
    required this.category,
    required this.wordLen,
    required this.hint,
    required this.canHint,
    required this.directHint,
    required this.word,
    required this.roundStartsAt,
    required this.turnDeadline,
    required this.roundMs,
    required this.revealUntil,
    required this.revealMs,
    required this.scores,
    required this.guesses,
    required this.history,
    required this.result,
    required this.series,
    required this.serverNow,
    required this.gallery,
  });

  static CatchState fromMap(Map<String, dynamic> m) => CatchState(
    gameId: '${m['gameId'] ?? ''}',
    status: '${m['status'] ?? 'playing'}',
    phase: '${m['phase'] ?? 'drawing'}',
    players: [for (final p in (m['players'] as List? ?? const [])) '$p'],
    round: (m['round'] as num?)?.toInt() ?? 1,
    maxRounds: (m['maxRounds'] as num?)?.toInt() ?? 6,
    drawer: '${m['drawer'] ?? ''}',
    category: '${m['category'] ?? ''}',
    wordLen: (m['wordLen'] as num?)?.toInt() ?? 0,
    hint: [for (final h in (m['hint'] as List? ?? const [])) '$h'],
    canHint: m['canHint'] == true,
    directHint: m['directHint'] == true,
    word: m['word'] as String?,
    roundStartsAt: (m['roundStartsAt'] as num?)?.toInt(),
    turnDeadline: (m['turnDeadline'] as num?)?.toInt(),
    roundMs: (m['roundMs'] as num?)?.toInt() ?? 60000,
    revealUntil: (m['revealUntil'] as num?)?.toInt(),
    revealMs: (m['revealMs'] as num?)?.toInt() ?? 6000,
    scores: _intMap(m['scores']),
    guesses: [
      for (final g in (m['guesses'] as List? ?? const []))
        if (g is Map) CatchGuess.fromMap(Map<String, dynamic>.from(g)),
    ],
    history: [
      for (final h in (m['history'] as List? ?? const []))
        if (h is Map) CatchRoundRecord.fromMap(h),
    ],
    result: CatchResult.fromMap(m['result']),
    series: m['series'] is Map
        ? Map<String, dynamic>.from(m['series'] as Map)
        : null,
    serverNow: (m['serverNow'] as num?)?.toInt(),
    gallery: [
      for (final g in (m['gallery'] as List? ?? const []))
        if (g is Map) CatchGalleryItem.fromMap(g),
    ],
  );

  bool get playing => status == 'playing';
  bool get finished => status == 'finished';
  bool get drawing => playing && phase == 'drawing';
  bool get revealing => playing && phase == 'reveal';

  String? opponentOf(String? me) {
    for (final p in players) {
      if (p != me) return p;
    }
    return null;
  }

  CatchRoundRecord? get lastRecord => history.isEmpty ? null : history.last;
}

// ── 획 ────────────────────────────────────────────────────────────────────

/// 한 획. 점은 0~1로 정규화된 보드 좌표. 가상 보드(1000×750) 위의 경로를 점을 받을 때마다 이어 붙인다.
class CatchStroke {
  final String id;
  final CatchTool tool;
  final int color;
  final double w;

  /// 아직 점이 더 들어올 수 있으면 true(손가락이 닿아 있거나 상대 묶음을 받는 중).
  bool open = true;

  final List<Offset> pts = [];
  final Path _path = Path();
  Offset? _last;
  Path? _closed;

  CatchStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.w,
  });

  static CatchStroke fromMap(Map<dynamic, dynamic> m) {
    final s = CatchStroke(
      id: '${m['id'] ?? ''}',
      tool: CatchTool.fromWire(m['tool']),
      color: ((m['color'] as num?)?.toInt() ?? 0).clamp(0, 11),
      w: (m['w'] as num?)?.toDouble() ?? kCatchBrushWidths[1],
    );
    s.addAll(_points(m['pts']));
    s.finish();
    return s;
  }

  static List<Offset> _points(Object? raw) => [
    for (final p in (raw as List? ?? const []))
      if (p is List && p.length >= 2)
        Offset(
          ((p[0] as num).toDouble()).clamp(0.0, 1.0),
          ((p[1] as num).toDouble()).clamp(0.0, 1.0),
        ),
  ];

  /// 서버가 보낸 `pts`를 정리한 목록.
  static List<Offset> parsePoints(Object? raw) => _points(raw);

  Offset _virtual(Offset n) =>
      Offset(n.dx * kCatchVirtualW, n.dy * kCatchVirtualH);

  /// 점 하나를 이어 붙인다(중점 이차곡선으로 부드럽게).
  void add(Offset n) {
    final v = _virtual(n);
    pts.add(n);
    _closed = null;
    final last = _last;
    if (last == null) {
      _path.moveTo(v.dx, v.dy);
    } else {
      final mid = Offset((last.dx + v.dx) / 2, (last.dy + v.dy) / 2);
      _path.quadraticBezierTo(last.dx, last.dy, mid.dx, mid.dy);
    }
    _last = v;
  }

  void addAll(Iterable<Offset> points) {
    for (final p in points) {
      add(p);
    }
  }

  void finish() {
    open = false;
  }

  /// 점이 하나뿐인 획(탭)은 점으로 그린다.
  bool get isDot => pts.length == 1;

  /// 그릴 경로. 마지막 반 마디까지 이어서 돌려준다.
  Path get path {
    final last = _last;
    if (last == null) return _path;
    final cached = _closed;
    if (!open && cached != null) return cached;
    final full = Path.from(_path)..lineTo(last.dx, last.dy);
    if (!open) _closed = full;
    return full;
  }

  Offset? get lastVirtual => _last;

  /// 보드 위 실제 선 굵기(가상 보드 단위).
  double get strokeWidth => w * kCatchVirtualW * catchWidthFactor(tool);

  Map<String, dynamic> toMap() => {
    'id': id,
    'tool': tool.wire,
    'color': color,
    'w': w,
    'pts': [
      for (final p in pts) [p.dx, p.dy],
    ],
  };
}
