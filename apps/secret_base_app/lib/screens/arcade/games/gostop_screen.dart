import 'package:flutter/material.dart';
import '../../../core/socket_service.dart';
import '../../../ui/hwatu_card.dart';
import '../../../widgets/game_scaffold.dart';

// 고스톱 (2인 맞고) — 서버 권위 상태, 클라이언트는 렌더+입력만.
// 초보자 지원: 획득 가능 카드 하이라이트, 실시간 점수, 정산 풀이, 도움말 시트.

class GostopScreen extends StatefulWidget {
  const GostopScreen({super.key});
  @override
  State<GostopScreen> createState() => _GostopScreenState();
}

class _GostopScreenState extends State<GostopScreen> {
  final _socket = SocketService();
  bool _settlementShown = false;

  static const _eventLabels = {
    'ssok': '쪽!',
    'ppeok': '뻑!',
    'ddadak': '따닥!',
    'pansseuri': '판쓸이!',
    'chongtong': '총통!',
  };

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    if (!mounted) return;

    // 나가리 알림
    final nageori = _socket.gostopNageoriMultiplier;
    if (nageori != null) {
      _socket.clearGostopNageori();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('나가리! 다음 판 ×$nageori 이월 — 새로 배분합니다'),
          duration: const Duration(seconds: 3),
        ),
      );
      _settlementShown = false;
    }

    // 이벤트 토스트 (쪽/뻑/따닥/판쓸이)
    final events = (_socket.gostopState?['lastEvents'] as List?) ?? const [];
    for (final e in events) {
      final label = _eventLabels[e];
      if (label != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label, textAlign: TextAlign.center),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    }

    // 정산 다이얼로그 (1회만)
    if (_socket.gostopSettlement != null && !_settlementShown) {
      _settlementShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSettlementDialog();
      });
    }

    setState(() {});
  }

  String get _me => _socket.userId ?? '';
  String? get _opponent {
    final players = (_socket.gostopState?['players'] as List?)?.cast<String>();
    if (players == null) return null;
    return players.firstWhere((p) => p != _me, orElse: () => '');
  }

  bool get _isMyTurn {
    final st = _socket.gostopState;
    if (st == null) return false;
    final players = (st['players'] as List).cast<String>();
    final idx = (st['currentPlayerIdx'] as num?)?.toInt() ?? 0;
    return players[idx] == _me;
  }

  List<Map<String, dynamic>> _cards(dynamic raw) => ((raw as List?) ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  @override
  Widget build(BuildContext context) {
    final st = _socket.gostopState;

    return GameScaffold(
      title: '고스톱',
      fullBleed: true,
      child: st == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFF14421F), // 화투판 초록
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _buildOpponentRow(st),
                    Expanded(child: _buildFieldArea(st)),
                    _buildMyArea(st),
                  ],
                ),
              ),
            ),
    );
  }

  // ── 상대 영역 ──────────────────────────────────────────────────────────────

  Widget _buildOpponentRow(Map<String, dynamic> st) {
    final opp = _opponent ?? '';
    final oppHand = _cards(st['hands']?[opp]);
    final oppCaptures = _cards(st['captures']?[opp]);
    final oppScore = (st['scores']?[opp]?['total'] as num?)?.toInt() ?? 0;
    final oppGo = (st['goCount']?[opp] as num?)?.toInt() ?? 0;
    final nickname = presence(opp);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$nickname  ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              _ScoreChip(score: oppScore, go: oppGo, active: !_isMyTurn),
              const Spacer(),
              // 상대 손패 (뒷면)
              SizedBox(
                height: 34,
                child: Stack(
                  children: [
                    for (int i = 0; i < oppHand.length; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i * 9.0),
                        child: const HwatuCard(card: null, width: 22),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _CaptureShelf(captures: oppCaptures, compact: true),
        ],
      ),
    );
  }

  String presence(String code) => _socket.presenceNicknames[code] ?? code;

  // ── 바닥/덱 영역 ───────────────────────────────────────────────────────────

  Widget _buildFieldArea(Map<String, dynamic> st) {
    final field = _cards(st['field']);
    final deckCount = ((st['deck'] as List?) ?? const []).length;
    final phase = st['phase'] as String? ?? 'playing';
    final pending = st['pending'] == null
        ? null
        : Map<String, dynamic>.from(st['pending'] as Map);
    final myHand = _cards(st['hands']?[_me]);
    final myMonths = myHand.map((c) => c['month']).toSet();
    final perPoint = (st['perPointBet'] as num?)?.toInt() ?? 100;
    final baseMul = (st['baseMultiplier'] as num?)?.toInt() ?? 1;
    final shakeMul = (st['shakeMultiplier'] as num?)?.toInt() ?? 1;
    final totalMul = baseMul * shakeMul;

    final isDeckChoice = phase == 'deck_choice' && _isMyTurn && pending != null;
    final choiceIds = isDeckChoice
        ? _cards(pending['fieldOptions']).map((c) => c['id']).toSet()
        : const <dynamic>{};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '점당 $perPoint · 배수 ×$totalMul',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
              Row(
                children: [
                  const HwatuCard(card: null, width: 26),
                  const SizedBox(width: 4),
                  Text(
                    '$deckCount장',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isDeckChoice)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '따닥! 가져올 카드를 선택하세요',
                style: TextStyle(
                  color: kHwatuGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final c in field)
                HwatuCard(
                  card: c,
                  width: 42,
                  // 초보자 지원: 내 손패로 먹을 수 있는 바닥 카드 하이라이트
                  highlighted: isDeckChoice
                      ? choiceIds.contains(c['id'])
                      : _isMyTurn &&
                            phase == 'playing' &&
                            myMonths.contains(c['month']),
                  onTap: isDeckChoice && choiceIds.contains(c['id'])
                      ? () => _socket.pickGostopField(c['id'] as String)
                      : null,
                ),
            ],
          ),
          if (phase == 'go_stop_choice' && _isMyTurn)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _buildGoStopButtons(st),
            ),
          if (phase == 'go_stop_choice' && !_isMyTurn)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '상대가 고/스톱 선택 중...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoStopButtons(Map<String, dynamic> st) {
    final myScore = (st['scores']?[_me]?['total'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Text(
          '$myScore점! 계속할까요?',
          style: const TextStyle(
            color: kHwatuGold,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kHwatuRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _socket.declareGostop('go'),
              child: const Text(
                '고!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kHwatuBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _socket.declareGostop('stop'),
              child: const Text(
                '스톱',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        Text(
          '고: 점수를 더 쌓지만 역전당할 수 있어요 (×2씩)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ── 내 영역 ────────────────────────────────────────────────────────────────

  Widget _buildMyArea(Map<String, dynamic> st) {
    final myHand = _cards(st['hands']?[_me]);
    final myCaptures = _cards(st['captures']?[_me]);
    final myScore = (st['scores']?[_me]?['total'] as num?)?.toInt() ?? 0;
    final myGo = (st['goCount']?[_me] as num?)?.toInt() ?? 0;
    final field = _cards(st['field']);
    final fieldMonths = field.map((c) => c['month']).toSet();
    final phase = st['phase'] as String? ?? 'playing';
    final canPlay = _isMyTurn && phase == 'playing';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CaptureShelf(captures: myCaptures, compact: false),
          const SizedBox(height: 6),
          Row(
            children: [
              _ScoreChip(score: myScore, go: myGo, active: _isMyTurn),
              const SizedBox(width: 8),
              Text(
                canPlay
                    ? '낼 카드를 선택하세요 (빛나는 카드 = 먹을 수 있음)'
                    : phase == 'deck_choice' && _isMyTurn
                    ? '바닥에서 가져올 카드를 고르세요'
                    : '상대 턴',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.help_outline,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
                onPressed: _showHelpSheet,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: myHand.length,
              separatorBuilder: (_, idx) => const SizedBox(width: 5),
              itemBuilder: (_, i) {
                final c = myHand[i];
                return HwatuCard(
                  card: c,
                  width: 48,
                  highlighted: canPlay && fieldMonths.contains(c['month']),
                  onTap: canPlay
                      ? () => _socket.playGostopCard(c['id'] as String)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 정산 다이얼로그 (점수 풀이 포함 — 초보자 지원) ──────────────────────────

  void _showSettlementDialog() {
    final st = _socket.gostopSettlement;
    if (st == null) return;
    final isWin = st['winnerId'] == _me;
    final points = (st['points'] as num?)?.toInt() ?? 0;
    final mul = (st['multiplier'] as num?)?.toInt() ?? 1;
    final perPoint = (st['perPointBet'] as num?)?.toInt() ?? 100;
    final amount = (st['amount'] as num?)?.toInt() ?? 0;
    final ws = Map<String, dynamic>.from((st['winnerScore'] as Map?) ?? {});
    final pibak = st['pibak'] == true;
    final gwangbak = st['gwangbak'] == true;
    final goWin = (st['goBonusWinner'] as num?)?.toInt() ?? 0;

    final lines = <String>[
      if ((ws['gwangScore'] as num? ?? 0) > 0)
        '광 ${ws['gwangCount']}장 → ${ws['gwangScore']}점',
      if ((ws['animScore'] as num? ?? 0) > 0)
        '열끗 ${ws['animCount']}장 → ${ws['animScore']}점',
      if ((ws['ribScore'] as num? ?? 0) > 0)
        '단 ${ws['ribCount']}장 → ${ws['ribScore']}점',
      if ((ws['hongdanBonus'] as num? ?? 0) > 0) '홍단 세트 +3점',
      if ((ws['cheongdanBonus'] as num? ?? 0) > 0) '청단 세트 +3점',
      if ((ws['piScore'] as num? ?? 0) > 0)
        '피 ${ws['piTotal']}장 → ${ws['piScore']}점',
      if (goWin > 0) '고 $goWin회 → ×${1 << goWin}',
      if (pibak) '피박 ×2',
      if (gwangbak) '광박 ×2',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isWin ? '승리! 🎉' : '패배...',
          style: TextStyle(
            color: isWin ? kHwatuGold : kHwatuBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(l, style: const TextStyle(fontSize: 13)),
              ),
            const Divider(),
            Text(
              '$points점 × $perPoint × ×$mul = $amount코인',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  // ── 도움말 시트 ────────────────────────────────────────────────────────────

  void _showHelpSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ListView(
          children: const [
            Text(
              '고스톱 기본 규칙',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10),
            Text('''
1. 내 턴에 손패 1장을 냅니다. 바닥에 같은 월(月) 카드가 있으면 함께 가져와요.
2. 이어서 덱에서 1장이 자동으로 뒤집힙니다. 이것도 월이 맞으면 가져옵니다.
3. 카드를 모아 점수를 만듭니다:
   · 광(光) 3장 = 3점 (비광 포함 시 2점), 4장 = 4점, 5장 = 15점
   · 열끗 5장부터 1점씩
   · 단(띠) 5장부터 1점씩 / 홍단·청단 세트 = +3점
   · 피 10장부터 1점씩 (쌍피는 2장 취급)
4. 7점이 되면 "고" 또는 "스톱"을 선택합니다.
   · 고: 판을 이어가고 이기면 ×2 (단, 역전당하면 상대에게 배수가!)
   · 스톱: 지금 점수로 정산
5. 특수 상황: 쪽/뻑/따닥/판쓸이, 흔들기(같은 월 2장 이상 = ×2), 총통(같은 월 4장 = 즉시 승리)
6. 정산 = 점수 × 점당 금액 × 배수 (피박·광박·고박 시 ×2씩 추가)
''', style: TextStyle(fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

// ── 보조 위젯 ──────────────────────────────────────────────────────────────

class _ScoreChip extends StatelessWidget {
  final int score;
  final int go;
  final bool active;
  const _ScoreChip({
    required this.score,
    required this.go,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? kHwatuGold : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        go > 0 ? '$score점 · $go고' : '$score점',
        style: TextStyle(
          color: active ? kHwatuBlack : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// 획득 카드 진열대 — 광/열끗/단/피 그룹별로 정리해 표시
class _CaptureShelf extends StatelessWidget {
  final List<Map<String, dynamic>> captures;
  final bool compact;
  const _CaptureShelf({required this.captures, required this.compact});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{
      'bright': [],
      'animal': [],
      'ribbon': [],
      'junk': [],
    };
    for (final c in captures) {
      groups[c['type']]?.add(c);
    }
    final cardW = compact ? 20.0 : 26.0;

    return SizedBox(
      height: cardW * kHwatuCardHeightRatio + 4,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(
                  children: [
                    for (int i = 0; i < entry.value.length; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i * (cardW * 0.45)),
                        child: HwatuCard(card: entry.value[i], width: cardW),
                      ),
                  ],
                ),
              ),
          if (captures.isEmpty)
            Center(
              child: Text(
                '획득한 카드 없음',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
