import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';
import 'catch_input.dart';
import 'catch_models.dart';
import 'catch_paint.dart';

/// 그림 맞히기 2.0 상태. 서버 `game:catch:*`만 받아 들고 있고 화면은 이것만 보고 그린다.
/// 그림 자체는 [canvas](획 기록)에 있고, 상태 알림과 따로 움직인다(획마다 화면을 다시 만들지 않으려고).
class CatchController extends GameController {
  CatchController._() {
    on('game:catch:state', applyState);
    on('game:catch:replay', applyReplay);
    on('game:catch:stroke', applyRemoteStroke);
    on('game:catch:undo', applyRemoteUndo);
    on('game:catch:clear', applyRemoteClear);
    on('game:catch:guess', applyGuess);
    on('game:catch:round_result', applyRoundResult);
  }

  static final CatchController instance = CatchController._();

  CatchState? state;

  /// 이번 라운드 마감시각(기기 시계 기준).
  GameDeadline? deadline;

  final CatchCanvasModel canvas = CatchCanvasModel();

  /// 내가 그린 획 번호(최근 [kCatchUndoLimit]개). 되돌리기 순서.
  final List<String> undoStack = [];

  /// 이번 라운드 추측 기록(말풍선·추측 목록).
  List<CatchGuess> guessLog = [];

  /// 사람별 가장 최근 추측 말풍선과 그 번호(바뀔 때마다 말풍선이 새로 튀어나온다).
  final Map<String, CatchGuess> latestGuess = {};
  int guessSeq = 0;

  CatchRoundResult? roundResult;
  int roundResultSeq = 0;

  int _strokeCounter = 0;
  DateTime? _lastGuessAt;

  /// 추측 사이 최소 간격(서버와 같다). 너무 빠른 입력은 서버에 보내지 않는다.
  static const Duration guessGap = Duration(milliseconds: 700);

  void sync() => emit('game:catch:sync', const {});

  bool get iAmDrawer {
    final s = state;
    return s != null && s.drawer == me;
  }

  /// 지금 내가 그릴 수 있는가(그리는 사람이고 라운드 진행 중).
  bool get canDraw => iAmDrawer && (state?.drawing ?? false);

  bool get canUndo => canDraw && undoStack.isNotEmpty;

  /// 표시 이름. 닉네임을 모르면 사용자 코드를 쓰지 않고 '나'/'상대'로 쓴다.
  String displayName(String? id) {
    if (id == null) return '상대';
    final n = nameOf(id);
    if (n.isEmpty || n == id) return id == me ? '나' : '상대';
    return n;
  }

  // ── 서버 → 화면 ────────────────────────────────────────────────────────────

  @visibleForTesting
  void applyState(Map<String, dynamic> data, {DateTime? receivedAt}) {
    final next = CatchState.fromMap(data);
    final prev = state;
    final newGame = prev == null || prev.gameId != next.gameId;
    final newRound = newGame || prev.round != next.round;
    if (newGame) {
      // 새 판이 왔으면 재대결 대기 표시를 끈다.
      socket.restartWaiting = false;
      latestGuess.clear();
    }
    if (newRound) {
      canvas.clear();
      undoStack.clear();
      roundResult = null;
      latestGuess.clear();
      guessLog = [...next.guesses];
    } else if (next.guesses.length >= guessLog.length) {
      guessLog = [...next.guesses];
    }
    final now = receivedAt ?? DateTime.now();
    deadline = next.drawing
        ? GameDeadline.fromServer(
            deadlineMs: next.turnDeadline,
            serverNowMs: next.serverNow,
            total: Duration(milliseconds: next.roundMs),
            receivedAt: now,
          )
        : null;
    state = next;
    notifyListeners();
  }

  @visibleForTesting
  void applyReplay(Map<String, dynamic> data) {
    final s = state;
    final round = (data['round'] as num?)?.toInt();
    if (s != null && round != s.round) return;
    canvas.replaceAll([
      for (final raw in (data['strokes'] as List? ?? const []))
        if (raw is Map) CatchStroke.fromMap(raw),
    ]);
    // 다시 받은 그림에는 내 획이 섞여 있을 수 있어 되돌리기 목록을 맞춘다.
    final ids = canvas.strokes.map((e) => e.id).toSet();
    undoStack.removeWhere((id) => !ids.contains(id));
    notifyListeners();
  }

  @visibleForTesting
  void applyRemoteStroke(Map<String, dynamic> data) {
    final s = state;
    if (s == null || (data['round'] as num?)?.toInt() != s.round) return;
    final id = '${data['id'] ?? ''}';
    if (id.isEmpty) return;
    final pts = CatchStroke.parsePoints(data['pts']);
    final existing = canvas.byId(id);
    if (existing == null) {
      // 시작 묶음을 놓쳤다면 그리지 않고 다음 sync(replay)를 기다린다.
      if (((data['seq'] as num?)?.toInt() ?? 0) != 0) return;
      canvas.begin(
        CatchStroke(
          id: id,
          tool: CatchTool.fromWire(data['tool']),
          color: ((data['color'] as num?)?.toInt() ?? 0).clamp(0, 11),
          w: (data['w'] as num?)?.toDouble() ?? kCatchBrushWidths[1],
        )..addAll(pts),
      );
    } else {
      canvas.append(id, pts);
    }
    if (data['end'] == true) canvas.finish(id);
  }

  @visibleForTesting
  void applyRemoteUndo(Map<String, dynamic> data) {
    final s = state;
    if (s == null || (data['round'] as num?)?.toInt() != s.round) return;
    canvas.remove('${data['id'] ?? ''}');
  }

  @visibleForTesting
  void applyRemoteClear(Map<String, dynamic> data) {
    final s = state;
    if (s == null || (data['round'] as num?)?.toInt() != s.round) return;
    canvas.clear();
  }

  @visibleForTesting
  void applyGuess(Map<String, dynamic> data) {
    final g = CatchGuess.fromMap(data);
    final s = state;
    if (s != null && g.round != s.round) return;
    if (guessLog.any((e) => e.id == g.id)) return;
    guessLog = [...guessLog, g];
    if (guessLog.length > 12) guessLog = guessLog.sublist(guessLog.length - 12);
    latestGuess[g.userId] = g;
    guessSeq++;
    notifyListeners();
  }

  @visibleForTesting
  void applyRoundResult(Map<String, dynamic> data) {
    roundResult = CatchRoundResult.fromMap(data);
    roundResultSeq++;
    notifyListeners();
  }

  // ── 화면 → 서버 ────────────────────────────────────────────────────────────

  /// 새 획 번호(영문·숫자 24자 이하).
  String newStrokeId() {
    _strokeCounter++;
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 's$t${_strokeCounter.toRadixString(36)}';
  }

  void sendBatch(StrokeBatch batch) {
    final s = state;
    if (s == null || !s.drawing) return;
    emit('game:catch:stroke', batch.toPayload(s.round));
  }

  /// 획 하나가 끝났다(되돌리기 목록에 쌓는다).
  void strokeDone(String id) {
    undoStack.add(id);
    while (undoStack.length > kCatchUndoLimit) {
      undoStack.removeAt(0);
    }
    notifyListeners();
  }

  void undo() {
    final s = state;
    if (!canUndo || s == null) return;
    final id = undoStack.removeLast();
    canvas.remove(id);
    emit('game:catch:undo', {'round': s.round, 'id': id});
    notifyListeners();
  }

  void clearBoard() {
    final s = state;
    if (!canDraw || s == null) return;
    canvas.clear();
    undoStack.clear();
    emit('game:catch:clear', {'round': s.round});
    notifyListeners();
  }

  /// 추측을 보낸다. 너무 빠르거나 보낼 수 없으면 false.
  bool guess(String text, {DateTime? now}) {
    final s = state;
    final t = text.trim();
    if (s == null || t.isEmpty || !s.drawing || iAmDrawer) return false;
    final at = now ?? DateTime.now();
    final last = _lastGuessAt;
    if (last != null && at.difference(last) < guessGap) return false;
    _lastGuessAt = at;
    emit('game:catch:guess', {'round': s.round, 'text': t});
    return true;
  }

  void requestHint() {
    final s = state;
    if (s == null || !s.canHint || iAmDrawer) return;
    emit('game:catch:hint', {'round': s.round});
  }

  /// 테스트용: 상태를 비우고 알린다.
  @visibleForTesting
  void clearForTest() {
    reset();
    notifyListeners();
  }

  @override
  void reset() {
    state = null;
    deadline = null;
    canvas.clear();
    undoStack.clear();
    guessLog = [];
    latestGuess.clear();
    roundResult = null;
    _lastGuessAt = null;
  }
}
