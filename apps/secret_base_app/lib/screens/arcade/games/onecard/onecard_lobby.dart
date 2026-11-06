import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import 'onecard_cards.dart';
import 'onecard_models.dart';
import 'onecard_ui.dart';

/// 원카드 대기실(목업 "로비"): 두 사람 카드, 판돈 4칸, 규칙 두 카드, 하단 주 버튼.
/// 서버·소켓 상태는 [GameLobbyScreen]이 들고 있고, 이 화면은 값을 받아 그리기만 한다.
class OneCardLobby extends StatefulWidget {
  /// 로비 참가자(들어온 순서)와 방장.
  final List<String> players;
  final String? host;
  final String? me;
  final Map<String, String> nicknames;
  final Map<String, bool> ready;
  final int stake;
  final String mode;
  final bool isHost;
  final bool canStart;
  final String startLabel;
  final List<int> stakeOptions;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final ValueChanged<int> onStake;
  final ValueChanged<String> onMode;
  final ValueChanged<bool> onReady;

  const OneCardLobby({
    super.key,
    required this.players,
    required this.host,
    required this.me,
    required this.nicknames,
    required this.ready,
    required this.stake,
    required this.mode,
    required this.isHost,
    required this.canStart,
    required this.startLabel,
    required this.onBack,
    required this.onStart,
    required this.onStake,
    required this.onMode,
    required this.onReady,
    this.stakeOptions = const [0, 500, 1000, 3000],
  });

  @override
  State<OneCardLobby> createState() => _OneCardLobbyState();
}

class _OneCardLobbyState extends State<OneCardLobby> {
  @override
  void initState() {
    super.initState();
    // 저장된 소리 설정을 읽어 둔다(상단 소리 버튼 표시용).
    GameSfx.instance.init(const []).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _nameOf(String? player) {
    if (player == null) return '비어 있음';
    if (player == widget.me) return '나';
    return widget.nicknames[player] ?? player;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // 왼쪽은 항상 나, 오른쪽은 상대.
    final me = w.me != null && w.players.contains(w.me)
        ? w.me
        : (w.players.isNotEmpty ? w.players.first : null);
    final other = w.players.where((p) => p != me).firstOrNull;
    final guestReady = other == null ? false : (w.ready[other] ?? false);
    final myReady = me == null ? false : (w.ready[me] ?? false);
    final needsAgree = w.stake > 0;

    String statusOf(String? player) {
      if (player == null) return '기다리는 중';
      if (player == w.host || !needsAgree) return '준비 완료';
      return (w.ready[player] ?? false) ? '준비 완료' : '동의 기다리는 중';
    }

    final stakeHint = w.stake == 0
        ? '판돈 없이 가볍게 즐겨요.'
        : w.isHost
        ? '이긴 사람이 ${oneCardMoney(w.stake)}코인을 가져가요. ${guestReady ? '두 사람 모두 동의했어요.' : '상대가 동의하면 시작할 수 있어요.'}'
        : '이긴 사람이 ${oneCardMoney(w.stake)}코인을 가져가요. ${myReady ? '동의했어요. 방장이 시작하면 바로 시작돼요.' : '동의하면 준비 완료를 눌러 주세요.'}';

    // 하단 주 버튼: 방장은 게임 시작, 판돈이 걸린 판의 상대는 준비 완료, 그 밖엔 기다림.
    final Widget bottom;
    if (w.isHost) {
      bottom = OneCardMainButton(
        label: w.startLabel,
        style: w.canStart ? OneCardButtonStyle.primary : OneCardButtonStyle.off,
        onPressed: w.canStart ? w.onStart : null,
      );
    } else if (needsAgree) {
      bottom = OneCardMainButton(
        label: myReady ? '준비 완료 취소' : '준비 완료',
        style: myReady ? OneCardButtonStyle.ghost : OneCardButtonStyle.primary,
        onPressed: () => w.onReady(!myReady),
      );
    } else {
      bottom = const OneCardMainButton(
        label: '방장이 시작할 때까지 기다려 주세요',
        style: OneCardButtonStyle.off,
      );
    }

    return Scaffold(
      backgroundColor: OneCardUi.bg,
      body: OneCardBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              OneCardTopBar(
                tag: '대기실',
                onBack: w.onBack,
                onHelp: () => showOneCardHowTo(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Versus(
                        meName: _nameOf(me),
                        otherName: _nameOf(other),
                        meIsHost: me != null && me == w.host,
                        otherIsHost: other != null && other == w.host,
                        meStatus: statusOf(me),
                        otherStatus: statusOf(other),
                        hasOther: other != null,
                      ),
                      const SizedBox(height: 20),
                      _SectionHead(
                        title: '판돈',
                        hint: w.isHost ? '방장이 선택' : '방장이 고른 금액',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final option in w.stakeOptions) ...[
                            if (option != w.stakeOptions.first)
                              const SizedBox(width: 8),
                            Expanded(
                              child: _StakeChip(
                                label: option == 0
                                    ? '무료'
                                    : oneCardMoney(option),
                                selected: w.stake == option,
                                enabled: w.isHost,
                                onTap: () => w.onStake(option),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(stakeHint, style: _hint),
                      const SizedBox(height: 26),
                      _SectionHead(
                        title: '규칙',
                        hint: w.isHost ? '방장이 선택' : '방장이 고른 설정',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ModeCard(
                              title: '고와일드',
                              badge: '추천',
                              body: '+2·+4를 쌓아 넘기고, 같은 색은 모두 내요',
                              selected: w.mode != 'classic',
                              enabled: w.isHost,
                              onTap: () => w.onMode('go_wild'),
                              cards: const [
                                OneCard(id: 'l1', color: 'red', value: 'draw2'),
                                OneCard(
                                  id: 'l2',
                                  color: null,
                                  value: 'wild_draw4',
                                ),
                                OneCard(
                                  id: 'l3',
                                  color: 'blue',
                                  value: 'discard_all',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModeCard(
                              title: '클래식',
                              body: '쌓기 없이 벌칙은 바로 받는 기본 규칙',
                              selected: w.mode == 'classic',
                              enabled: w.isHost,
                              onTap: () => w.onMode('classic'),
                              cards: const [
                                OneCard(id: 'c1', color: 'red', value: '7'),
                                OneCard(
                                  id: 'c2',
                                  color: 'yellow',
                                  value: 'skip',
                                ),
                                OneCard(
                                  id: 'c3',
                                  color: 'green',
                                  value: 'reverse',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '손패 7장으로 시작해 지금 색이나 같은 숫자·기호를 내요. 먼저 손패를 비우면 승리! 마지막 한 장엔 원카드를 외쳐요.',
                        style: _hint,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _hint = OneCardUi.sans(
    size: 12,
    color: OneCardUi.sub,
    height: 1.55,
  );
}

class _SectionHead extends StatelessWidget {
  final String title;
  final String hint;

  const _SectionHead({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: OneCardUi.sans(size: 14, weight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text(hint, style: OneCardUi.sans(size: 12, color: OneCardUi.sub)),
      ],
    );
  }
}

class _Versus extends StatelessWidget {
  final String meName;
  final String otherName;
  final bool meIsHost;
  final bool otherIsHost;
  final String meStatus;
  final String otherStatus;
  final bool hasOther;

  const _Versus({
    required this.meName,
    required this.otherName,
    required this.meIsHost,
    required this.otherIsHost,
    required this.meStatus,
    required this.otherStatus,
    required this.hasOther,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OneCardUi.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Seat(
              name: meName,
              host: meIsHost,
              status: meStatus,
              color: OneCardUi.meAvatar,
              filled: true,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              'VS',
              textAlign: TextAlign.center,
              style: OneCardUi.sans(
                size: 12,
                color: OneCardUi.mut,
                weight: FontWeight.w800,
                spacing: 0.14,
              ),
            ),
          ),
          Expanded(
            child: _Seat(
              name: otherName,
              host: otherIsHost,
              status: otherStatus,
              color: OneCardUi.oppAvatar,
              filled: hasOther,
            ),
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  final String name;
  final bool host;
  final String status;
  final Color color;
  final bool filled;

  const _Seat({
    required this.name,
    required this.host,
    required this.status,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = filled && status == '준비 완료'
        ? OneCardUi.vio2
        : OneCardUi.mut;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : const Color(0x14FFFFFF),
          ),
          child: Text(
            filled ? oneCardInitial(name) : '…',
            style: OneCardUi.sans(
              size: 20,
              color: filled ? Colors.white : OneCardUi.mut,
              weight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OneCardUi.sans(
                  size: 15,
                  color: filled ? OneCardUi.ink : OneCardUi.mut,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            if (host)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: OneCardUi.line),
                ),
                child: Text(
                  '방장',
                  style: OneCardUi.sans(
                    size: 11,
                    color: OneCardUi.sub,
                    weight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OneCardUi.sans(
                  size: 12,
                  color: statusColor,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StakeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _StakeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: enabled,
      selected: selected,
      label: label == '무료' ? '판돈 없음' : '판돈 $label코인',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled && !selected ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: !enabled && !selected ? 0.6 : 1,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0x2E8E6CF2)
                  : const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? OneCardUi.vio2 : OneCardUi.line,
              ),
            ),
            child: Text(
              label,
              style: OneCardUi.sans(
                size: 14,
                color: selected ? Colors.white : OneCardUi.sub,
                weight: FontWeight.w700,
                features: OneCardUi.tabular,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String? badge;
  final String body;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final List<OneCard> cards;

  const _ModeCard({
    required this.title,
    this.badge,
    required this.body,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: enabled,
      selected: selected,
      label: '$title, $body',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled && !selected ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: !enabled && !selected ? 0.6 : 1,
          child: Container(
            height: 176,
            padding: const EdgeInsets.all(14),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0x298E6CF2)
                  : const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? OneCardUi.vio2 : OneCardUi.line,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OneCardUi.sans(
                              size: 15,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: OneCardUi.vio2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: OneCardUi.sans(
                                size: 11,
                                color: const Color(0xFF1B0F36),
                                weight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: OneCardUi.sans(
                        size: 12,
                        color: OneCardUi.sub,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  bottom: -4,
                  child: SizedBox(
                    width: 40 + 26.0 * (cards.length - 1),
                    height: 40 * kOneCardAspect,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          Positioned(
                            left: i * 26.0,
                            child: OneCardFace(
                              card: cards[i],
                              width: 40,
                              shadows: OneCardShadows.mini,
                            ),
                          ),
                      ],
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
