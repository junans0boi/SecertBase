/// 모던 클래식 시안으로 다시 그린 게임 로비(블랙잭·도둑잡기).
/// 로비 진행(방장·시작·카운트다운)은 `GameLobbyScreen`이 하고, 여기서는 그리기만 한다.
library;

import 'package:flutter/material.dart';

import '../../widgets/play_kit/game_theme.dart';
import '../../widgets/play_kit/modern_kit.dart';
import '../../widgets/play_kit/playing_card.dart';
import 'games/blackjack/blackjack_rules.dart';
import 'games/oldmaid/oldmaid_game_screen.dart' show oldMaidHowTo;

/// 로비 한 판 분량의 그림 정보.
class ThemedLobbySpec {
  final GameTheme theme;
  final ModBackdropKind backdrop;
  final String barTitle;
  final String title;
  final String subtitle;
  final List<(String label, String value)> rules;
  final String howToTitle;
  final List<String> howToLines;

  /// 준비 완료 글자색(밝은 테마에서는 배경에 묻히지 않게 어둡게).
  final Color okColor;

  /// 위쪽 문장(紋章)/일러스트. [compact]이면 작게 그린다.
  final Widget Function(GameTheme theme, bool compact) emblem;

  const ThemedLobbySpec({
    required this.theme,
    required this.backdrop,
    required this.barTitle,
    required this.title,
    required this.subtitle,
    required this.rules,
    required this.howToTitle,
    required this.howToLines,
    required this.okColor,
    required this.emblem,
  });
}

/// 시안이 있는 게임만 돌려준다. 없으면 기본 로비를 쓴다.
ThemedLobbySpec? themedLobbySpecFor(String gameType) => switch (gameType) {
  'blackjack' => _blackjack,
  'oldmaid' => _oldmaid,
  _ => null,
};

final _blackjack = ThemedLobbySpec(
  theme: GameTheme.lounge,
  backdrop: ModBackdropKind.felt,
  barTitle: '블랙잭',
  title: '블랙잭 1:1',
  subtitle: '숨은 카드 한 장으로 겨루는\n1:1 21점 대결',
  rules: const [
    ('승리 조건', '먼저 2승'),
    ('라운드', '최대 5라운드'),
    ('내 차례 제한', '30초'),
    ('시작 카드', '2장 · 1장은 숨김'),
  ],
  howToTitle: '블랙잭 1:1',
  howToLines: blackjackHowTo,
  okColor: GameTheme.lounge.me,
  emblem: (t, compact) {
    final d = compact ? 72.0 : 92.0;
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.accent),
      ),
      child: Container(
        width: d - 12,
        height: d - 12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.gold.withValues(alpha: 0.3)),
        ),
        child: Text(
          '21',
          style: t.display(size: compact ? 30 : 38, color: t.gold),
        ),
      ),
    );
  },
);

final _oldmaid = ThemedLobbySpec(
  theme: GameTheme.storybook,
  backdrop: ModBackdropKind.paper,
  barTitle: '도둑잡기',
  title: '도둑잡기',
  subtitle: '서로의 카드를 한 장씩 뽑아 짝을 버려요.\n마지막 조커를 든 사람이 도둑!',
  rules: const [('카드', '52장 + 조커 1장'), ('짝', '같은 숫자 두 장'), ('내 차례 제한', '25초')],
  howToTitle: '도둑잡기',
  howToLines: oldMaidHowTo,
  okColor: const Color(0xFF597B65),
  emblem: (t, compact) => ThiefHero(size: compact ? 80 : 104),
);

/// 가면 쓴 도둑을 둥근 흰 접시에 올린 일러스트(로비·결과 공통).
class ThiefHero extends StatelessWidget {
  final double size;

  const ThiefHero({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) {
    final t = GameTheme.storybook;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surface,
        border: Border.all(color: t.hair),
        boxShadow: [
          BoxShadow(
            color: t.ink.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ThiefIcon(size: size * 0.69),
    );
  }
}

/// 로비 화면 한 장.
class ThemedLobbyView extends StatelessWidget {
  final ThemedLobbySpec spec;
  final String gameType;
  final List<String> players;
  final String? host;
  final String? myId;
  final Map<String, String> nicknames;
  final bool isHost;
  final bool canStart;
  final String startLabel;
  final VoidCallback onStart;
  final VoidCallback onBack;

  const ThemedLobbyView({
    super.key,
    required this.spec,
    required this.gameType,
    required this.players,
    required this.host,
    required this.myId,
    required this.nicknames,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onStart,
    required this.onBack,
  });

  String _nameOf(String? id, {required bool mine}) {
    final n = id == null ? null : nicknames[id];
    if (n != null && n.trim().isNotEmpty) return n;
    return mine ? '나' : '상대';
  }

  @override
  Widget build(BuildContext context) {
    final t = spec.theme;
    // 로비에서는 "나"가 왼쪽, 상대가 오른쪽.
    final others = [
      for (final p in players)
        if (p != myId) p,
    ];
    final String? opp = others.isEmpty ? null : others.first;
    final iAmIn = myId != null && players.contains(myId);
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: ModBackdrop(
        theme: t,
        kind: spec.backdrop,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  ModTopBar(
                    theme: t,
                    title: spec.barTitle,
                    gameType: gameType,
                    onBack: onBack,
                    onHelp: () => showModHowTo(
                      context,
                      theme: t,
                      title: spec.howToTitle,
                      lines: spec.howToLines,
                    ),
                    showSound: false,
                    showMenu: false,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxHeight < 520;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: box.maxHeight - 12,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: compact ? 4 : 22),
                                spec.emblem(t, compact),
                                SizedBox(height: compact ? 12 : 20),
                                Text(
                                  spec.title,
                                  style: t.display(size: compact ? 26 : 30),
                                ),
                                SizedBox(height: compact ? 6 : 8),
                                Text(
                                  spec.subtitle,
                                  textAlign: TextAlign.center,
                                  style: t.body(
                                    size: compact ? 14 : 15,
                                    color: t.subInk,
                                    weight: FontWeight.w400,
                                    height: 1.55,
                                  ),
                                ),
                                SizedBox(height: compact ? 16 : 28),
                                _players(t, compact, iAmIn, opp),
                                SizedBox(height: compact ? 14 : 20),
                                ModRowsCard(
                                  theme: t,
                                  rows: [
                                    for (final r in spec.rules)
                                      SizedBox(
                                        height: compact ? 44 : 48,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                r.$1,
                                                style: t.body(
                                                  size: 14,
                                                  color: t.subInk,
                                                  weight: FontWeight.w400,
                                                ),
                                              ),
                                              Text(
                                                r.$2,
                                                style: t.body(
                                                  size: 14,
                                                  weight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    child: isHost
                        ? ModButton(
                            theme: t,
                            label: startLabel,
                            onPressed: canStart ? onStart : null,
                          )
                        : ModButton(
                            theme: t,
                            label: '방장이 시작하길 기다려요',
                            onPressed: null,
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

  Widget _players(GameTheme t, bool compact, bool iAmIn, String? opp) {
    final h = compact ? 96.0 : 112.0;
    final me = _PlayerCard(
      theme: t,
      height: h,
      name: _nameOf(myId, mine: true),
      status: iAmIn ? (host == myId ? '방장 · 준비 완료' : '준비 완료') : '들어오는 중…',
      mine: true,
      ok: iAmIn,
      okColor: spec.okColor,
    );
    final other = _PlayerCard(
      theme: t,
      height: h,
      name: opp == null ? '기다리는 중' : _nameOf(opp, mine: false),
      status: opp == null ? '상대를 기다려요' : (host == opp ? '방장 · 준비 완료' : '준비 완료'),
      mine: false,
      ok: opp != null,
      okColor: spec.okColor,
      empty: opp == null,
    );
    final vsLabel = t.dark ? 'VS' : 'vs';
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(child: me),
            const SizedBox(width: 12),
            Expanded(child: other),
          ],
        ),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.dark ? const Color(0xFF0A3A31) : t.backdrop.first,
            border: Border.all(color: t.dark ? t.accent : t.hair),
          ),
          child: Text(
            vsLabel,
            style: t.body(
              size: 12,
              color: t.dark ? t.gold : t.subInk,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final GameTheme theme;
  final double height;
  final String name;
  final String status;
  final bool mine;
  final bool ok;
  final Color okColor;
  final bool empty;

  const _PlayerCard({
    required this.theme,
    required this.height,
    required this.name,
    required this.status,
    required this.mine,
    required this.ok,
    required this.okColor,
    this.empty = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.plate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.hair),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          empty
              ? Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.hair),
                  ),
                  child: Text('…', style: t.display(size: 16, color: t.subInk)),
                )
              : ModAvatar(theme: t, name: name, mine: mine, size: 44),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(
              size: 15,
              color: empty ? t.subInk : t.ink,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(
              size: 12.5,
              color: ok ? okColor : t.subInk,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 시작 카운트다운(어두운 막 + 큰 숫자).
class ThemedCountdown extends StatelessWidget {
  final GameTheme theme;
  final int seconds;

  const ThemedCountdown({
    super.key,
    required this.theme,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$seconds',
                  style: t.display(size: 96, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  '게임 시작!',
                  style: t.body(
                    size: 20,
                    color: Colors.white70,
                    weight: FontWeight.w700,
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
