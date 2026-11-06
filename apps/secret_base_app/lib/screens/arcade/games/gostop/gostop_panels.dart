import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'gostop_card.dart';
import 'gostop_models.dart';
import 'gostop_score.dart';

/// 규칙 요약(도움말). 서버 엔진과 같은 규칙이다.
const gostopHowToLines = [
  '2명이 하는 맞고예요. 손패를 한 장 내고 더미를 한 장 뒤집어, 같은 월 패를 가져와요. 내 차례는 25초!',
  '광·열끗·띠·피를 모아 7점이 되면 "고" 또는 "스톱". 스톱하면 그 점수로 이기고, 고 하면 계속해요.',
  '고 점수: 1고 +1점, 2고 +2점, 3고부터는 +3점에 ×2, 그 뒤로 고마다 ×2. 고한 뒤 상대가 이기면 고박(×2)!',
  '박: 피박(내가 피로 났고 상대 피 7장 이하), 광박(내가 광으로 났고 상대 광 0장) 각각 ×2.',
  '흔들기(같은 월 3장을 보이고 내기)와 폭탄(3장+바닥 1장)은 이겼을 때만 ×2. 폭탄 뒤엔 "도탄" 두 번 더미만 뒤집어요.',
  '쪽·따닥·쓸·뻑 가져오기·폭탄은 상대 피를 1장 뺏어요. 쓸은 턴이 끝났을 때 바닥이 비어야 해요(마지막 턴 제외).',
  '낸 패가 바닥 두 장과 맞으면 직접 골라요. 바닥에 같은 월 4장이면 다시 나누고, 같은 월 4장을 쥔 총통은 10점으로 바로 이겨요.',
  '마지막 패까지 마지막에 점수를 낸 사람만 이겨요. 고만 하고 더 못 나면 나가리! 국진(9월 열끗)은 열끗이에요.',
  '25초가 지나면 자동으로 코치 추천 패를 내고, 고/스톱은 스톱으로 이겨요. 3번 연속 자동이면 기권패예요.',
];

/// 고/스톱 전체 패널: 지금 스톱 vs 고 했을 때 금액, 상대 위협.
class GostopDecisionPanel extends StatelessWidget {
  final GameTheme theme;
  final GostopView view;
  final String? me;
  final String oppName;
  final GameDeadline? deadline;
  final VoidCallback onGo;
  final VoidCallback onStop;

  const GostopDecisionPanel({
    super.key,
    required this.theme,
    required this.view,
    required this.me,
    required this.oppName,
    required this.deadline,
    required this.onGo,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final stop = view.stopNow ?? view.projectionOf(me);
    final go = view.afterGo ?? stop;
    final staked = view.perPointBet > 0;
    final opp = view.opponentOf(me);
    final oppScore = view.scoreOf(opp);
    final myGo = view.goOf(me);
    String money(HProjection p) =>
        staked ? '${gostopCoins(p.amount)}코인' : '${p.total}점';
    return Stack(
      fit: StackFit.expand,
      key: const ValueKey('go-stop-panel'),
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: 0.78)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GamePanel(
                  theme: t,
                  radius: 28,
                  opaque: true,
                  glow: t.gold,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${view.scoreOf(me).total}점!',
                            style: t.display(size: 38, color: t.gold),
                          ),
                          const SizedBox(width: 10),
                          TurnTimerRing(theme: t, deadline: deadline, size: 40),
                        ],
                      ),
                      Text('고 할까요, 스톱 할까요?', style: t.display(size: 21)),
                      const SizedBox(height: 4),
                      Text(
                        '시간이 지나면 자동으로 스톱해서 이겨요.',
                        style: t.body(size: 12, color: t.subInk),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Option(
                              theme: t,
                              title: '지금 스톱',
                              amount: money(stop),
                              lines: [
                                '${stop.base}점${stop.goPoints > 0 ? ' + 고 ${stop.goPoints}점' : ''}',
                                for (final m in stop.multipliers)
                                  '${m.label} ×${m.factor}',
                              ],
                              total: '= ${stop.total}점 ×${stop.multiplier}',
                              color: t.me,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Option(
                              theme: t,
                              title: '${myGo + 1}고 하면',
                              amount: '${money(go)} ↑',
                              lines: [
                                '1점 더 나서 스톱하면',
                                '${go.base}점 + 고 ${go.goPoints}점',
                                for (final m in go.multipliers)
                                  '${m.label} ×${m.factor}',
                              ],
                              total: '= ${go.total}점 ×${go.multiplier}',
                              color: const Color(0xFFFF8A5B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: t.opponent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: t.opponent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '$oppName: ${oppScore.total}점 · 광 ${oppScore.gwangCount}장 · '
                          '열끗 ${oppScore.animCount}장 · 띠 ${oppScore.ribCount}장 · 피 ${oppScore.piTotal}장\n'
                          '고 하고 상대가 먼저 7점을 내면 고박(×2)으로 내야 해요.',
                          style: t.body(size: 12, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GamePrimaryButton(
                              theme: t,
                              label: '스톱',
                              icon: Icons.flag_rounded,
                              height: 54,
                              color: const Color(0xFF2F9E62),
                              onPressed: onStop,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GamePrimaryButton(
                              theme: t,
                              label: '고!',
                              icon: Icons.local_fire_department_rounded,
                              height: 54,
                              color: const Color(0xFFE2623A),
                              onPressed: onGo,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final GameTheme theme;
  final String title;
  final String amount;
  final List<String> lines;
  final String total;
  final Color color;

  const _Option({
    required this.theme,
    required this.title,
    required this.amount,
    required this.lines,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.body(size: 12.5, color: color, weight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: t.display(size: 24, weight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          for (final l in lines)
            Text(l, style: t.body(size: 11, color: t.subInk, height: 1.35)),
          const SizedBox(height: 2),
          Text(total, style: t.body(size: 11.5, weight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// 손패/뒤집은 패가 바닥 두 장과 맞을 때: 가져올 패를 고르는 시트.
class GostopChoicePanel extends StatelessWidget {
  final GameTheme theme;
  final HPending pending;
  final GameDeadline? deadline;
  final ValueChanged<HCard> onChoose;

  const GostopChoicePanel({
    super.key,
    required this.theme,
    required this.pending,
    required this.deadline,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GamePanel(
      key: const ValueKey('choice-panel'),
      theme: t,
      radius: 24,
      opaque: true,
      glow: t.gold,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text('가져올 패를 고르세요', style: t.display(size: 19))),
              TurnTimerRing(theme: t, deadline: deadline, size: 34),
            ],
          ),
          Text(
            pending.kind == 'deck'
                ? '뒤집은 패와 같은 월이 바닥에 두 장 있어요.'
                : '낸 패와 같은 월이 바닥에 두 장 있어요.',
            style: t.body(size: 12, color: t.subInk),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  GostopCard(card: pending.card, width: 52),
                  const SizedBox(height: 3),
                  Text(
                    pending.kind == 'deck' ? '뒤집은 패' : '내는 패',
                    style: t.body(size: 10.5, color: t.subInk),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.add_rounded, color: t.gold),
              ),
              for (final o in pending.options) ...[
                Column(
                  children: [
                    GostopCard(
                      card: o,
                      width: 64,
                      highlighted: true,
                      onTap: () => onChoose(o),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _caption(o),
                      style: t.body(
                        size: 11,
                        weight: FontWeight.w900,
                        color: t.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _caption(HCard c) =>
      '${gostopTypeLabelLong(c.type)}${c.isDoubleJunk ? '(쌍피)' : ''}';
}

String gostopTypeLabelLong(String type) => switch (type) {
  'bright' => '광',
  'animal' => '열끗',
  'ribbon' => '띠',
  _ => '피',
};

/// 총통 선언 패널.
class GostopChongtongPanel extends StatelessWidget {
  final GameTheme theme;
  final List<HCard> cards;
  final int perPointBet;
  final GameDeadline? deadline;
  final VoidCallback onDeclare;
  final VoidCallback onDecline;

  const GostopChongtongPanel({
    super.key,
    required this.theme,
    required this.cards,
    required this.perPointBet,
    required this.deadline,
    required this.onDeclare,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Stack(
      fit: StackFit.expand,
      key: const ValueKey('chongtong-panel'),
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: 0.78)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: GamePanel(
                  theme: t,
                  radius: 28,
                  opaque: true,
                  glow: t.gold,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('총통!', style: t.display(size: 40, color: t.gold)),
                      Text('같은 월 네 장을 쥐고 있어요', style: t.display(size: 18)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final c in cards) GostopCard(card: c, width: 56),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '선언하면 10점으로 바로 이겨요'
                        '${perPointBet > 0 ? ' (+${gostopCoins(10 * perPointBet)}코인)' : ''}.\n'
                        '받지 않고 그냥 칠 수도 있어요.',
                        textAlign: TextAlign.center,
                        style: t.body(size: 13, color: t.subInk, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      GamePrimaryButton(
                        theme: t,
                        label: '총통 선언! (10점)',
                        icon: Icons.emoji_events_rounded,
                        height: 54,
                        onPressed: onDeclare,
                      ),
                      const SizedBox(height: 8),
                      GameSecondaryButton(
                        theme: t,
                        label: '그냥 치기',
                        height: 46,
                        onPressed: onDecline,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TurnTimerRing(theme: t, deadline: deadline, size: 28),
                          const SizedBox(width: 6),
                          Text(
                            '시간이 지나면 자동으로 선언해요',
                            style: t.body(size: 11, color: t.subInk),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 점수 내역 한 줄씩(광 3장 +3 …).
List<String> gostopScoreLines(HScore s) => [
  if (s.gwangScore > 0) '광 ${s.gwangCount}장 +${s.gwangScore}점',
  if (s.animScore > 0) '열끗 ${s.animCount}장 +${s.animScore}점',
  if (s.godoriScore > 0) '고도리 +${s.godoriScore}점',
  if (s.ribScore > 0) '띠 ${s.ribCount}장 +${s.ribScore}점',
  if (s.hongdanBonus > 0) '홍단 +${s.hongdanBonus}점',
  if (s.cheongdanBonus > 0) '청단 +${s.cheongdanBonus}점',
  if (s.chodanBonus > 0) '초단 +${s.chodanBonus}점',
  if (s.piTotal >= 10) '피 ${s.piTotal}장 +${s.piTotal - 9}점',
];

/// 정산 영수증. 합계는 서버가 실제로 옮긴 코인(transferred)과 같다.
class GostopReceipt extends StatelessWidget {
  final GameTheme theme;
  final HReceipt receipt;
  final String? me;
  final String winnerName;

  const GostopReceipt({
    super.key,
    required this.theme,
    required this.receipt,
    required this.me,
    required this.winnerName,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = receipt;
    final won = r.winner == me;
    final staked = r.perPointBet > 0;
    if (r.reason == 'nagari') {
      return _box(
        t,
        Text(
          '나가리! 점수를 낸 사람이 없어서 코인은 오가지 않았어요.',
          textAlign: TextAlign.center,
          style: t.body(size: 13, height: 1.45),
        ),
      );
    }
    final lines = r.reason == 'chongtong'
        ? const <String>['총통 10점']
        : gostopScoreLines(r.winnerScore);
    Widget row(String l, String v, {bool strong = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l,
                  style: t.body(
                    size: strong ? 13 : 12,
                    color: color ?? (strong ? t.ink : t.subInk),
                  ),
                ),
              ),
              Text(
                v,
                style: t.body(
                  size: strong ? 14 : 12.5,
                  weight: FontWeight.w900,
                  color: color ?? t.ink,
                ),
              ),
            ],
          ),
        );
    final sign = won ? '+' : '-';
    return _box(
      t,
      Column(
        key: const ValueKey('receipt'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in lines) row(l, ''),
          row('점수', '${r.base}점'),
          if (r.goPoints > 0) row('고 ${r.goPoints}번', '+${r.goPoints}점'),
          row('합계', '${r.total}점', strong: true),
          const Divider(height: 10, color: Colors.white24),
          if (r.multipliers.isEmpty)
            row('배수', '×1')
          else ...[
            for (final m in r.multipliers) row(m.label, '×${m.factor}'),
            row('배수 합계', '×${r.multiplier}', strong: true),
          ],
          const Divider(height: 10, color: Colors.white24),
          if (staked) ...[
            row('1점당 판돈', '${gostopCoins(r.perPointBet)}코인'),
            row(
              '${r.total}점 × ${r.multiplier} × ${gostopCoins(r.perPointBet)}',
              '${gostopCoins(r.amount)}코인',
            ),
            const SizedBox(height: 2),
            row(
              won ? '받은 코인' : '낸 코인',
              '$sign${gostopCoins(r.transferred)}코인',
              strong: true,
              color: won ? t.gold : t.opponent,
            ),
            if (r.capped)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '진 쪽 코인이 모자라 ${gostopCoins(r.transferred)}코인만 옮겨졌어요.',
                  style: t.body(size: 11, color: t.subInk),
                ),
              ),
            if (r.settlement == 'failed')
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '코인 정산이 지연되고 있어요. 잠시 후 잔액을 확인해 주세요.',
                  style: t.body(size: 11, color: t.opponent),
                ),
              ),
          ] else
            row(
              '최종',
              '${r.total * r.multiplier}점',
              strong: true,
              color: t.gold,
            ),
        ],
      ),
    );
  }

  Widget _box(GameTheme t, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: t.gold.withValues(alpha: 0.4)),
    ),
    child: child,
  );
}
