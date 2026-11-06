import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'catch_board.dart';
import 'catch_controller.dart';
import 'catch_input.dart';
import 'catch_models.dart';
import 'catch_result.dart';
import 'catch_tools.dart';
import 'catch_widgets.dart';

const _kGameType = 'catch';

const kCatchHowToLines = [
  '한 사람이 제시어를 그림으로 그리고, 다른 사람이 글자로 맞혀요. 라운드마다 번갈아 그려요.',
  '한 라운드는 60초! 맞히면 맞힌 사람 3점(남은 시간 20초마다 +1점), 그린 사람 2점이에요.',
  '30초와 15초가 남으면 글자가 하나씩 저절로 열려요. 💡를 누르면 바로 한 글자를 볼 수 있지만 1점이 깎여요.',
  '글자 하나만 달라도 “아까워요!”가 떠요. 비슷한 말(티비↔텔레비전)도 정답이에요.',
  '글자나 숫자로 알려 주면 안 돼요. 그림으로만!',
  '내 차례에 그림을 한 획도 안 그린 채 두 번 넘기면 기권이에요.',
];

/// 그림 맞히기 2.0: 아틀리에 스케치북. 서버가 로비 시작과 함께 판을 만든다(시작 버튼 없음).
class CatchScreen extends StatefulWidget {
  const CatchScreen({super.key});

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen> {
  static const GameTheme theme = GameTheme.atelier;

  final _c = CatchController.instance;
  final _socket = SocketService();

  // 그리기 도구(화면이 열려 있는 동안 유지).
  CatchTool _tool = CatchTool.pen;
  int _color = 0;
  int _size = 1;

  String? _gameId;
  int _round = 0;
  int _resultSeq = 0;
  int _guessSeq = 0;
  int _openLetters = 0;
  bool _firstState = true;

  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  int _toastSeq = 0;
  String? _toast;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.tap,
      GameSound.select,
      GameSound.confirm,
      GameSound.pop,
      GameSound.sparkle,
      GameSound.start,
      GameSound.whoosh,
      GameSound.cheer,
      GameSound.aww,
      GameSound.tick,
      GameSound.warn,
      GameSound.win,
      GameSound.lose,
      GameSound.draw,
    ]);
    _resultSeq = _c.roundResultSeq;
    _guessSeq = _c.guessSeq;
    _c.addListener(_onState);
    _absorb(initial: true);
    _c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'howto_catch_v2',
        theme: theme,
        title: '그림 맞히기 규칙',
        emoji: '🎨',
        lines: kCatchHowToLines,
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    super.dispose();
  }

  // ── 상태 변화 ────────────────────────────────────────────────────────────

  void _onState() {
    if (!mounted) return;
    setState(_absorb);
  }

  void _absorb({bool initial = false}) {
    final s = _c.state;
    if (s == null) return;
    final sfx = GameSfx.instance;
    if (s.gameId != _gameId) {
      _gameId = s.gameId;
      _round = 0;
      _openLetters = 0;
    }
    if (s.drawing && s.round != _round) {
      final firstSight = _round == 0;
      _round = s.round;
      _openLetters = s.hint.where((h) => h.isNotEmpty).length;
      if (!(initial || (firstSight && _firstState))) {
        _banner(
          _c.iAmDrawer ? '내가 그려요!' : '맞혀 보세요!',
          '${s.round}라운드 · ${_c.iAmDrawer ? '제시어를 그림으로' : '그림을 보고 글자로'}',
        );
        sfx.play(GameSound.start);
        HapticFeedback.mediumImpact();
      }
      _firstState = false;
    } else if (s.drawing) {
      final open = s.hint.where((h) => h.isNotEmpty).length;
      if (open > _openLetters && !_c.iAmDrawer) {
        _toastMsg('글자가 하나 열렸어요!');
        sfx.play(GameSound.sparkle);
      }
      _openLetters = open;
    }
    if (_c.guessSeq != _guessSeq) {
      _guessSeq = _c.guessSeq;
      final g = _c.latestGuess.values.isEmpty ? null : _lastGuess();
      if (g != null) {
        sfx.play(g.close ? GameSound.sparkle : GameSound.pop);
      }
    }
    if (_c.roundResultSeq != _resultSeq) {
      _resultSeq = _c.roundResultSeq;
      final r = _c.roundResult?.record;
      if (r != null) {
        sfx.play(r.correct ? GameSound.cheer : GameSound.aww);
        HapticFeedback.heavyImpact();
      }
    }
  }

  CatchGuess? _lastGuess() {
    final log = _c.guessLog;
    return log.isEmpty ? null : log.last;
  }

  void _banner(String text, String? sub) {
    _bannerText = text;
    _bannerSub = sub;
    _bannerId = Object();
  }

  void _toastMsg(String message) {
    _toast = message;
    _toastSeq++;
  }

  // ── 조작 ─────────────────────────────────────────────────────────────────

  void _pickTool(CatchTool tool) {
    GameSfx.instance.play(GameSound.select);
    HapticFeedback.selectionClick();
    setState(() => _tool = tool);
  }

  void _pickColor(int index) {
    GameSfx.instance.play(GameSound.tap);
    HapticFeedback.selectionClick();
    setState(() {
      _color = index;
      // 지우개를 쓰다가 색을 누르면 다시 연필로.
      if (_tool == CatchTool.eraser) _tool = CatchTool.pen;
    });
  }

  void _pickSize(int index) {
    GameSfx.instance.play(GameSound.tap);
    HapticFeedback.selectionClick();
    setState(() => _size = index);
  }

  Future<void> _confirmClear() async {
    if (_c.canvas.isEmpty) return;
    final t = theme;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('그림을 모두 지울까요?', style: t.display(size: 21)),
        content: Text(
          '지운 그림은 되돌릴 수 없어요.',
          style: t.body(size: 14, color: t.subInk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: t.body(size: 15, color: t.subInk)),
          ),
          TextButton(
            key: const ValueKey('catch-clear-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '지우기',
              style: t.body(
                size: 15,
                color: t.opponent,
                weight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      GameSfx.instance.play(GameSound.whoosh);
      _c.clearBoard();
    }
  }

  bool _submitGuess(String text) {
    final sent = _c.guess(text);
    if (sent) GameSfx.instance.play(GameSound.confirm);
    return sent;
  }

  void _useHint() {
    GameSfx.instance.play(GameSound.select);
    _c.requestHint();
  }

  void _help() => showGameHowTo(
    context,
    theme: theme,
    title: '그림 맞히기 규칙',
    emoji: '🎨',
    lines: kCatchHowToLines,
  );

  // ── 그리기 ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 키보드가 올라와도 보드가 줄지 않도록 본문 크기를 키보드와 무관하게 둔다.
      // 입력창만 키보드 위로 떠오른다(_body의 Positioned).
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.backdrop.last,
      body: GameMenuListener(
        gameType: _kGameType,
        child: GameBackdrop(
          theme: theme,
          frame: false,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([_c, _socket]),
              builder: (context, _) => _body(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = _c.state;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final guesser = s != null && s.playing && !_c.iAmDrawer;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  GameTopBar(
                    theme: theme,
                    title: '그림 맞히기',
                    gameType: _kGameType,
                    canRestart: true,
                    restartWaiting: _socket.restartWaiting,
                    onRequestRestart: () => _socket.requestRestart(_kGameType),
                    onHelp: _help,
                  ),
                  if (s == null)
                    Expanded(child: CatchPreparing(theme: theme))
                  else ...[
                    CatchScoreRow(theme: theme, controller: _c, state: s),
                    const SizedBox(height: 6),
                    _hintRow(s),
                    const SizedBox(height: 8),
                    Expanded(child: _boardArea(s)),
                    const SizedBox(height: 8),
                    _bottomPanel(s),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 58,
          left: 0,
          right: 0,
          child: Center(
            child: GameToast(theme: theme, id: _toastSeq, message: _toast),
          ),
        ),
        Positioned.fill(
          child: GameTurnBanner(
            theme: theme,
            id: _bannerId,
            text: _bannerText,
            sub: _bannerSub,
            color: theme.accent,
            hold: const Duration(milliseconds: 750),
          ),
        ),
        // 입력창은 키보드 바로 위에 떠서 보드를 가린다(보드 크기는 그대로).
        if (guesser)
          Positioned(
            left: 12,
            right: 12,
            bottom: keyboard + 6,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 496),
                child: CatchGuessInput(
                  theme: theme,
                  enabled: s.drawing,
                  placeholder: s.drawing ? '정답을 입력해 보세요' : '다음 그림을 기다려요',
                  canHint: s.canHint,
                  onSubmit: _submitGuess,
                  onHint: _useHint,
                ),
              ),
            ),
          ),
        if (s != null && s.finished)
          Positioned.fill(
            child: CatchResultOverlay(
              theme: theme,
              controller: _c,
              state: s,
              rematchWaiting: _socket.restartWaiting,
              onRematch: () => _socket.requestRestart(_kGameType),
              onExit: () => Navigator.of(context).maybePop(),
            ),
          ),
      ],
    );
  }

  Widget _hintRow(CatchState s) {
    final t = theme;
    final iDraw = _c.iAmDrawer;
    final showAll = iDraw || !s.drawing;
    final helper = s.revealing
        ? '다음 그림이 곧 시작돼요'
        : iDraw
        ? '글자 없이 그림으로만 알려 주세요!'
        : '그림을 보고 제시어를 맞혀 보세요!';
    return Column(
      children: [
        Row(
          children: [
            GameChip(
              theme: t,
              label: iDraw && s.drawing
                  ? '제시어 · ${s.category}'
                  : '분야 · ${s.category}',
              leading: iDraw && s.drawing ? '✏️' : '🔎',
              color: t.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: t.body(
                  size: 12.5,
                  color: t.subInk,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        CatchLetterTiles(
          theme: t,
          length: s.wordLen,
          hint: s.hint,
          word: s.word,
          showAll: showAll,
          mine: iDraw,
        ),
      ],
    );
  }

  Widget _boardArea(CatchState s) {
    return LayoutBuilder(
      builder: (context, box) {
        final paper = paperWidthFor(box.maxWidth, box.maxHeight);
        final opp = s.opponentOf(_c.me);
        final result = _c.roundResult;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SketchbookBoard(
              theme: theme,
              paperWidth: paper,
              model: _c.canvas,
              overlays: [
                CatchDrawingSurface(
                  model: _c.canvas,
                  enabled: _c.canDraw,
                  tool: _tool,
                  color: _color,
                  sizeIndex: _size,
                  nextId: _c.newStrokeId,
                  onBatch: _c.sendBatch,
                  onStrokeDone: _c.strokeDone,
                ),
                if (!_c.iAmDrawer && s.drawing)
                  ListenableBuilder(
                    listenable: _c.canvas,
                    builder: (context, _) => _c.canvas.isEmpty
                        ? Center(
                            child: Text(
                              '${_c.displayName(s.drawer)}님이 그리는 중…',
                              style: theme.body(
                                size: 14,
                                color: theme.subInk.withValues(alpha: 0.8),
                                weight: FontWeight.w700,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                CatchGuessBubbles(
                  theme: theme,
                  controller: _c,
                  leftId: _c.me,
                  rightId: opp,
                ),
                if (s.revealing &&
                    result != null &&
                    result.record.round == s.round)
                  CatchRevealOverlay(
                    theme: theme,
                    result: result,
                    controller: _c,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomPanel(CatchState s) {
    if (_c.iAmDrawer) {
      return CatchToolbar(
        theme: theme,
        tool: _tool,
        colorIndex: _color,
        sizeIndex: _size,
        canUndo: _c.canUndo,
        enabled: _c.canDraw,
        onTool: _pickTool,
        onColor: _pickColor,
        onSize: _pickSize,
        onUndo: _c.undo,
        onClear: _confirmClear,
      );
    }
    // 맞히는 사람: 최근 추측 목록 + (입력창 자리). 입력창은 Stack에서 따로 뜬다.
    return SizedBox(
      key: const ValueKey('catch-guess-panel'),
      height: kCatchGuessPanelHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, kCatchHintSize + 18),
        child: CatchGuessLog(theme: theme, controller: _c),
      ),
    );
  }
}

/// 맞히는 사람 아래 영역 높이: 추측 목록 3줄 + 입력창.
const double kCatchGuessPanelHeight = 150;
