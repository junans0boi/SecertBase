import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/socket_service.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import '../../lobby_options.dart';
import 'yut_figures.dart';
import 'yut_models.dart';
import 'yut_palette.dart';
import 'yut_ui.dart';

/// 윷놀이 로비: 두 사람 알약, 큰 캐릭터 + 능력치 레이더, 캐릭터 고르기, 말 개수·판돈 선택,
/// 두툼한 시작/준비 버튼. 방장이 옵션·판돈을 고르고 상대는 같은 값을 읽기 전용으로 본다.
/// 로비에서는 아직 낮/밤이 정해지지 않았으므로 낮 팔레트를 쓴다.
class YutLobbyView extends StatelessWidget {
  final SocketService socket;
  final bool isHost;
  final bool canStart;
  final String startLabel;
  final VoidCallback onStart;
  final VoidCallback onBack;
  final YutPalette palette;

  const YutLobbyView({
    super.key,
    required this.socket,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onStart,
    required this.onBack,
    this.palette = YutPalette.daylight,
  });

  static const _stakes = [0, 500, 1000, 3000];

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final me = socket.userId;
    final picks = socket.lobbyCharacterSelections;
    final opponent = socket.lobbyPlayers.firstWhere(
      (u) => u != me,
      orElse: () => '',
    );
    final myPick = picks[me];
    final shown = myPick ?? SocketService.yutCharacterIds.first;
    final pieceDef = lobbyOptionsFor('yut').first;
    final pieces = pieceDef.choiceFor(socket.lobbyOptions[pieceDef.key]).value;
    final hasTwo = socket.lobbyPlayers.length >= 2;
    final stakeNeedsReady = socket.lobbyStake > 0;
    return YutPaletteScope(
      palette: p,
      child: Scaffold(
        backgroundColor: p.theme.backdrop.last,
        body: GameBackdrop(
          theme: p.theme,
          frame: false,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                      child: SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text('윷놀이', style: p.display(size: 24)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: YutRoundButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                label: '로비에서 나가기',
                                onTap: onBack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _PlayerPill(
                                    p: p,
                                    mine: true,
                                    name: socket.presenceNicknames[me] ?? '나',
                                    host: socket.lobbyHost == me,
                                    ready: true,
                                    character: myPick,
                                    emoji: socket.profileEmojis[me],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    'vs',
                                    style: p.display(size: 22, color: p.sub),
                                  ),
                                ),
                                Expanded(
                                  child: _PlayerPill(
                                    p: p,
                                    mine: false,
                                    name: opponent.isEmpty
                                        ? '기다리는 중'
                                        : (socket.presenceNicknames[opponent] ??
                                              '상대'),
                                    host:
                                        opponent.isNotEmpty &&
                                        socket.lobbyHost == opponent,
                                    ready:
                                        hasTwo &&
                                        (socket.lobbyHost == opponent ||
                                            socket.lobbyReady[opponent] ==
                                                true ||
                                            !stakeNeedsReady),
                                    character: picks[opponent],
                                    emoji: socket.profileEmojis[opponent],
                                    empty: opponent.isEmpty,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _Hero(p: p, character: shown),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (final id
                                    in SocketService.yutCharacterIds) ...[
                                  Expanded(
                                    child: _CharacterCard(
                                      p: p,
                                      id: id,
                                      state: picks[me] == id
                                          ? _Pick.mine
                                          : picks.entries.any(
                                              (e) =>
                                                  e.key != me && e.value == id,
                                            )
                                          ? _Pick.taken
                                          : _Pick.free,
                                      onTap: () =>
                                          socket.selectYutLobbyCharacter(id),
                                    ),
                                  ),
                                  if (id != SocketService.yutCharacterIds.last)
                                    const SizedBox(width: 8),
                                ],
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                myPick == null
                                    ? '고르지 않으면 자동으로 정해져요'
                                    : '상대와 겹치지 않아요',
                                style: p.body(
                                  size: 12,
                                  color: p.sub,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionTitle(
                              p: p,
                              title: '말 개수',
                              hint: isHost ? '방장이 골라요' : '방장이 고른 설정',
                            ),
                            _Segmented<Object>(
                              p: p,
                              enabled: isHost,
                              value: pieces,
                              items: [
                                for (final choice in pieceDef.choices.reversed)
                                  (
                                    choice.value,
                                    '${choice.value}개',
                                    switch (choice.value) {
                                      4 => '정석',
                                      3 => '조금 짧게',
                                      _ => '빠른 판',
                                    },
                                  ),
                              ],
                              onChanged: (v) =>
                                  socket.setLobbyOption('yut', pieceDef.key, v),
                            ),
                            const SizedBox(height: 12),
                            _SectionTitle(
                              p: p,
                              title: '판돈',
                              hint: isHost ? '방장이 골라요' : '방장이 선택한 금액',
                            ),
                            _Segmented<int>(
                              p: p,
                              enabled: isHost,
                              value: socket.lobbyStake,
                              items: [
                                for (final s in _stakes)
                                  (
                                    s,
                                    s == 0 ? '무료' : '$s',
                                    s == 0 ? null : '코인',
                                  ),
                              ],
                              onChanged: (v) => socket.setLobbyStake('yut', v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isHost && stakeNeedsReady)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                socket.lobbyReady[me ?? ''] == true
                                    ? '${socket.lobbyStake}코인 판돈에 동의했어요'
                                    : '이 판에는 ${socket.lobbyStake}코인이 걸려 있어요',
                                textAlign: TextAlign.center,
                                style: p.body(size: 13, color: p.sub),
                              ),
                            ),
                          if (isHost)
                            YutChunkyButton(
                              label: startLabel,
                              onPressed: canStart ? onStart : null,
                            )
                          else if (stakeNeedsReady)
                            YutChunkyButton(
                              label: socket.lobbyReady[me ?? ''] == true
                                  ? '준비 취소'
                                  : '준비 완료',
                              icon: socket.lobbyReady[me ?? ''] == true
                                  ? null
                                  : Icons.check_rounded,
                              onPressed: () => socket.setLobbyReady(
                                'yut',
                                socket.lobbyReady[me ?? ''] != true,
                              ),
                            )
                          else
                            YutChunkyButton(
                              label: '방장이 시작할 때까지 기다려요',
                              onPressed: null,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '먼저 들어온 사람이 방장이 됩니다',
                            style: p.body(
                              size: 12,
                              color: p.sub,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final YutPalette p;
  final String title;
  final String hint;

  const _SectionTitle({
    required this.p,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        children: [
          Text(title, style: p.display(size: 19)),
          const SizedBox(width: 8),
          Text(
            hint,
            style: p.body(size: 12, color: p.sub, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 두 사람 알약: 얼굴(고른 캐릭터), 이름, 방장 표시, 준비 상태.
class _PlayerPill extends StatelessWidget {
  final YutPalette p;
  final bool mine;
  final String name;
  final bool host;
  final bool ready;
  final String? character;
  final String? emoji;
  final bool empty;

  const _PlayerPill({
    required this.p,
    required this.mine,
    required this.name,
    required this.host,
    required this.ready,
    required this.character,
    required this.emoji,
    this.empty = false,
  });

  @override
  Widget build(BuildContext context) {
    final ring = mine ? p.me : p.opp;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      decoration: BoxDecoration(
        color: p.night ? p.panel : Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: p.panelEdge, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ring, width: 3),
            ),
            child: empty
                ? Text('…', style: p.display(size: 22, color: p.sub))
                : character != null
                ? YutCharacterAvatar(character: character!, size: 42)
                : Text(
                    (emoji == null || emoji!.isEmpty) ? '🙂' : emoji!,
                    style: const TextStyle(fontSize: 24),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: p.display(size: 18),
                      ),
                    ),
                    if (host) ...[
                      const SizedBox(width: 5),
                      const YutPill('방장', filled: true),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: empty
                            ? p.sub
                            : (ready ? const Color(0xFF2FBF71) : p.yellow),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        empty ? '입장 대기' : (ready ? '준비 완료' : '준비 중'),
                        style: p.body(size: 12, color: p.sub),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 큰 캐릭터(받침 위) + 능력치 레이더.
class _Hero extends StatelessWidget {
  final YutPalette p;
  final String character;

  const _Hero({required this.p, required this.character});

  @override
  Widget build(BuildContext context) {
    final stats = yutCharacterStatsFor(character);
    return SizedBox(
      height: 214,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 140,
                    height: 34,
                    decoration: BoxDecoration(
                      color: p.plateSide,
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(140, 34),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 140,
                    height: 34,
                    decoration: BoxDecoration(
                      color: p.plate,
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(140, 34),
                      ),
                      boxShadow: [BoxShadow(color: p.shadow, blurRadius: 14)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  child: YutFigure(
                    key: const ValueKey('yut_lobby_hero'),
                    height: 190,
                    team: p.me,
                    spec: YutFigureSpec(character: character),
                    badge: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.glassEdge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          yutCharacterNames[character] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: p.display(size: 22),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            for (final t
                                in (kYutCharacterBlurb[character] ?? '').split(
                                  '·',
                                ))
                              YutPill(t, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: _Radar(p: p, stats: stats),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 능력치 5가지 레이더(칸마다 1~5). 글자와 숫자도 함께 적어 읽기 쉽게 한다.
class _Radar extends StatelessWidget {
  final YutPalette p;
  final Map<String, int> stats;

  const _Radar({required this.p, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final c = Offset(box.maxWidth / 2, box.maxHeight / 2 + 4);
        final r = math.min(box.maxWidth * 0.27, box.maxHeight * 0.36);
        Offset at(int i, double k) {
          final a = -math.pi / 2 + i * math.pi * 2 / 5;
          return c + Offset(math.cos(a), math.sin(a)) * r * k;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: const ValueKey('yut_radar'),
                painter: _RadarPainter(p, stats, c, r),
              ),
            ),
            for (var i = 0; i < kYutStatDefs.length; i++)
              () {
                final def = kYutStatDefs[i];
                final pos = at(i, 1.42);
                return Positioned(
                  left: pos.dx - 40,
                  top: pos.dy - 10,
                  width: 80,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${def.label} '),
                        TextSpan(
                          text: '${stats[def.key] ?? 3}',
                          style: TextStyle(color: p.accText),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: p.body(
                      size: 13,
                      weight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final YutPalette p;
  final Map<String, int> stats;
  final Offset c;
  final double r;

  _RadarPainter(this.p, this.stats, this.c, this.r);

  Offset _at(int i, double k) {
    final a = -math.pi / 2 + i * math.pi * 2 / 5;
    return c + Offset(math.cos(a), math.sin(a)) * r * k;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = p.sub.withValues(alpha: 0.35);
    for (int ring = 1; ring <= 5; ring++) {
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final o = _at(i, ring / 5);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path..close(), grid);
    }
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(c, _at(i, 1), grid);
    }
    final poly = Path();
    for (int i = 0; i < 5; i++) {
      final v = ((stats[kYutStatDefs[i].key] ?? 3) / 5).clamp(0.2, 1.0);
      final o = _at(i, v);
      i == 0 ? poly.moveTo(o.dx, o.dy) : poly.lineTo(o.dx, o.dy);
    }
    poly.close();
    canvas.drawPath(poly, Paint()..color = p.acc.withValues(alpha: 0.3));
    canvas.drawPath(
      poly,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = p.acc,
    );
    for (int i = 0; i < 5; i++) {
      final v = ((stats[kYutStatDefs[i].key] ?? 3) / 5).clamp(0.2, 1.0);
      final o = _at(i, v);
      canvas.drawCircle(o, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        o,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.acc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.stats != stats || old.p != p;
}

enum _Pick { free, mine, taken }

class _CharacterCard extends StatelessWidget {
  final YutPalette p;
  final String id;
  final _Pick state;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.p,
    required this.id,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = yutCharacterNames[id] ?? id;
    final taken = state == _Pick.taken;
    final mine = state == _Pick.mine;
    return Semantics(
      button: !taken,
      enabled: !taken,
      selected: mine,
      label:
          '$name, ${mine
              ? '내 선택'
              : taken
              ? '상대 선택'
              : '고르기'}',
      child: GestureDetector(
        key: ValueKey('yut_pick_$id'),
        behavior: HitTestBehavior.opaque,
        onTap: taken ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 112,
          decoration: BoxDecoration(
            color: p.night ? p.panel : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: mine ? Border.all(color: p.acc, width: 3) : null,
            boxShadow: [
              BoxShadow(
                color: mine ? p.acc2 : p.panelEdge,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: taken ? 0.4 : 1,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: YutBust(character: id, height: 66),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    color: mine
                        ? p.acc
                        : p.glass.withValues(alpha: p.night ? 0.2 : 0.7),
                    child: Text(
                      name,
                      style: p.display(size: 17, color: mine ? p.onAcc : p.ink),
                    ),
                  ),
                ),
                if (mine)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: const YutPill('선택', filled: true),
                  ),
                if (taken)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: p.ink.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '상대 선택',
                          style: p.body(
                            size: 12,
                            color: p.night ? p.panel : Colors.white,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
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

/// 분할 선택(말 개수·판돈). 선택된 칸은 포인트색 알약. 방장만 바꿀 수 있다.
class _Segmented<T extends Object> extends StatelessWidget {
  final YutPalette p;
  final bool enabled;
  final T value;
  final List<(T, String, String?)> items;
  final ValueChanged<T> onChanged;

  const _Segmented({
    required this.p,
    required this.enabled,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.glassEdge),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Semantics(
                button: enabled,
                selected: it.$1 == value,
                label: '${it.$2}${it.$3 == null ? '' : ' ${it.$3}'}',
                child: GestureDetector(
                  key: ValueKey('yut_seg_${it.$1}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? () => onChanged(it.$1) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: it.$1 == value ? p.acc : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: it.$1 == value
                          ? [
                              BoxShadow(
                                color: p.acc2,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          it.$2,
                          style: p.display(
                            size: 18,
                            color: it.$1 == value
                                ? p.onAcc
                                : p.ink.withValues(alpha: enabled ? 1 : 0.6),
                            height: 1.1,
                          ),
                        ),
                        if (it.$3 != null)
                          Text(
                            it.$3!,
                            style: p.body(
                              size: 12,
                              color: it.$1 == value
                                  ? p.onAcc.withValues(alpha: 0.85)
                                  : p.sub,
                              weight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
