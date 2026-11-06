import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../lobby_options.dart';
import 'penalty_chrome.dart';

/// 패널티킥 대기방(목업 안 A "야간 방송"): 두 선수 카드, 골대 칸 고르기(방장만), 경기 방식, 시작 버튼.
/// 로비 동작(방장이 3·6칸을 고르고 상대는 읽기만, 방장만 시작)은 [GameLobbyScreen]이 그대로 맡고
/// 이 위젯은 그리기만 한다.
class PenaltyLobbyView extends StatelessWidget {
  /// 로비 옵션 정의(골대 칸 3/6)와 지금 고른 값.
  final LobbyOptionDef cellsDef;
  final Object? cellsValue;

  final String? myId;
  final String? hostId;
  final List<String> players;
  final Map<String, String> nicknames;
  final Map<String, String> emojis;

  final bool isHost;
  final bool canStart;
  final String startLabel;

  final ValueChanged<Object> onSelectCells;
  final VoidCallback? onStart;
  final VoidCallback onBack;
  final VoidCallback? onHelp;

  const PenaltyLobbyView({
    super.key,
    required this.cellsDef,
    required this.cellsValue,
    required this.myId,
    required this.hostId,
    required this.players,
    required this.nicknames,
    required this.emojis,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onSelectCells,
    required this.onStart,
    required this.onBack,
    this.onHelp,
  });

  static const _cellInfo = {
    3: ('왼쪽·가운데·오른쪽\n쉬운 심리전', false),
    6: ('위·아래까지 노리는 승부\n서든데스 최대 10번', true),
  };

  static const _rules = [
    ('5번씩', '번갈아 차서 골이 많으면 승리'),
    ('동점', '서든데스로 한 번씩 더 차요'),
    ('선공', '첫 키커는 무작위, 재대결에서 교대'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = cellsDef.choiceFor(cellsValue);
    // 나를 왼쪽에, 상대를 오른쪽에 둔다.
    final me = players.contains(myId) ? myId : null;
    final others = players.where((p) => p != me).toList();
    final left = me ?? (players.isNotEmpty ? players.first : null);
    final right = me != null
        ? (others.isNotEmpty ? others.first : null)
        : (players.length > 1 ? players[1] : null);

    return Scaffold(
      backgroundColor: PenaltyNight.bg,
      body: PenaltyNightBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  PenaltyTopBar(
                    chip: current.label,
                    onBack: onBack,
                    onHelp: onHelp,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Versus(
                            left: _slot(left, isMe: left == myId),
                            right: _slot(right, isMe: right == myId),
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(
                            title: cellsDef.title,
                            hint: isHost ? '방장이 선택' : '방장이 고른 설정',
                          ),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final choice in cellsDef.choices) ...[
                                  if (choice != cellsDef.choices.first)
                                    const SizedBox(width: 10),
                                  Expanded(
                                    child: _CellsOption(
                                      choice: choice,
                                      selected: choice.value == current.value,
                                      enabled: isHost,
                                      onTap: () => onSelectCells(choice.value),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          const _SectionHeader(title: '경기 방식'),
                          for (final (label, text) in _rules)
                            _RuleRow(label: label, text: text),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      math.max(
                        30,
                        MediaQuery.viewPaddingOf(context).bottom + 12,
                      ),
                    ),
                    child: PenaltyMainButton(
                      label: isHost ? startLabel : '방장이 시작할 때까지 기다려요',
                      onPressed: isHost && canStart ? onStart : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _SlotData _slot(String? id, {required bool isMe}) {
    if (id == null) return const _SlotData.empty();
    final nick = nicknames[id];
    return _SlotData(
      name: isMe ? '나' : (nick == null || nick.isEmpty ? '상대' : nick),
      emoji: emojis[id] ?? '🙂',
      isMe: isMe,
      isHost: id == hostId,
    );
  }

  static (String, bool) infoFor(Object value) =>
      _cellInfo[value] ?? ('', false);
}

class _SlotData {
  final String name;
  final String emoji;
  final bool isMe;
  final bool isHost;
  final bool present;

  const _SlotData({
    required this.name,
    required this.emoji,
    required this.isMe,
    required this.isHost,
  }) : present = true;

  const _SlotData.empty()
    : name = '비어 있음',
      emoji = '',
      isMe = false,
      isHost = false,
      present = false;
}

class _Versus extends StatelessWidget {
  final _SlotData left;
  final _SlotData right;

  const _Versus({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: PenaltyNight.card(radius: 20),
      child: Row(
        children: [
          Expanded(child: _Player(data: left)),
          SizedBox(
            width: 36,
            child: Text(
              'VS',
              textAlign: TextAlign.center,
              style: PenaltyNight.ui(
                12,
                weight: FontWeight.w800,
                color: PenaltyNight.sub,
                spacing: 0.14,
              ),
            ),
          ),
          Expanded(child: _Player(data: right)),
        ],
      ),
    );
  }
}

class _Player extends StatelessWidget {
  final _SlotData data;

  const _Player({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isMe ? PenaltyNight.me : PenaltyNight.opponent;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: data.present
              ? BoxDecoration(shape: BoxShape.circle, color: color)
              : BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PenaltyNight.line, width: 1.5),
                ),
          child: Text(
            data.present ? data.emoji : '…',
            style: data.present
                ? const TextStyle(fontSize: 26, height: 1.1)
                : PenaltyNight.ui(20, color: PenaltyNight.sub),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                data.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PenaltyNight.ui(
                  15,
                  color: data.present ? PenaltyNight.ink : PenaltyNight.sub,
                ),
              ),
            ),
            if (data.isHost) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: PenaltyNight.line),
                ),
                child: Text(
                  '방장',
                  style: PenaltyNight.ui(
                    11,
                    color: PenaltyNight.sub,
                    height: 16 / 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          data.present ? '준비 완료' : '기다리는 중',
          style: PenaltyNight.ui(
            12,
            color: data.present ? PenaltyNight.accent : PenaltyNight.sub,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? hint;

  const _SectionHeader({required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: PenaltyNight.ui(14)),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Text(
              hint!,
              style: PenaltyNight.ui(
                12,
                color: PenaltyNight.sub,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 골대 칸 한 장. 비방장에게는 방장이 고른 쪽만 켜지고 나머지는 흐리다.
class _CellsOption extends StatelessWidget {
  final LobbyChoice choice;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CellsOption({
    required this.choice,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cells = choice.value as int;
    final (text, precise) = PenaltyLobbyView.infoFor(cells);
    final color = selected ? PenaltyNight.accent : PenaltyNight.sub;
    final dimmed = !enabled && !selected;
    return Semantics(
      button: enabled,
      selected: selected,
      label: '${choice.label}, ${text.replaceAll('\n', ' ')}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !selected ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: dimmed ? 0.5 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 176),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: PenaltyNight.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? PenaltyNight.accent : PenaltyNight.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomPaint(
                  size: const Size(84, 48),
                  painter: _GoalPainter(color: color, rows: cells == 6 ? 2 : 1),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      choice.label,
                      style: PenaltyNight.ui(18, weight: FontWeight.w800),
                    ),
                    if (precise) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: PenaltyNight.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '정밀',
                          style: PenaltyNight.ui(
                            11,
                            color: PenaltyNight.accentInk,
                            height: 18 / 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: PenaltyNight.ui(
                    12,
                    color: PenaltyNight.sub,
                    weight: FontWeight.w400,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 84x48 골대 그림: 3개 기둥/크로스바 + 칸 구분선(6칸이면 가운데 가로선도).
class _GoalPainter extends CustomPainter {
  final Color color;
  final int rows;

  const _GoalPainter({required this.color, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(
      Path()
        ..moveTo(4, 46)
        ..lineTo(4, 4)
        ..lineTo(80, 4)
        ..lineTo(80, 46),
      frame,
    );
    final thin = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(28, 4), const Offset(28, 46), thin);
    canvas.drawLine(const Offset(56, 4), const Offset(56, 46), thin);
    if (rows == 2) {
      canvas.drawLine(const Offset(4, 25), const Offset(80, 25), thin);
    }
  }

  @override
  bool shouldRepaint(covariant _GoalPainter old) =>
      old.color != color || old.rows != rows;
}

class _RuleRow extends StatelessWidget {
  final String label;
  final String text;

  const _RuleRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PenaltyNight.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: PenaltyNight.ui(
                12,
                weight: FontWeight.w800,
                color: PenaltyNight.sub,
                spacing: 0.06,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: PenaltyNight.ui(13, weight: FontWeight.w400, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
