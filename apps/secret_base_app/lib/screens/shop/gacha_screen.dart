import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth_service.dart';
import '../../v2/v2.dart';
import 'gacha_overlay.dart';
import 'shop_common.dart';

/// 뽑기: 3단계 뽑기 카드, 확률 시트, 확인 → 연출 → 결과.
///
/// 가격과 확률은 [kGachaTiers](서버 시드와 같은 값)를 써요. 서버가 값을
/// 내려주는 API가 생기면 이 한 곳만 바꾸면 돼요.
class GachaScreen extends StatefulWidget {
  const GachaScreen({
    super.key,
    required this.client,
    required this.baseUrl,
    required this.balance,
    required this.onOpenCoinGuide,
  });

  final http.Client client;
  final String baseUrl;
  final int balance;
  final VoidCallback onOpenCoinGuide;

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> {
  String _game = 'yut';
  late int _balance = widget.balance;
  bool _pulling = false;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${AuthService().token}',
    'Content-Type': 'application/json',
  };

  String get _gameName => _game == 'yut' ? '윷놀이' : '원카드';

  Future<void> _pull(GachaTier tier) async {
    if (_pulling) return;
    if (_balance < tier.cost) {
      await _showInsufficient(tier);
      return;
    }
    final ok = await showV2Confirm(
      context,
      title: '$_gameName ${tier.name}를 할까요?',
      message:
          '${coinText(tier.cost)} 코인을 써요. 뽑은 뒤에는 되돌릴 수 없어요.\n'
          '지금 코인 ${coinText(_balance)} → ${coinText(_balance - tier.cost)}',
      confirmLabel: '뽑기하기',
      cancelLabel: '취소',
    );
    if (!ok || !mounted) return;
    setState(() => _pulling = true);
    try {
      final res = await widget.client.post(
        Uri.parse('${widget.baseUrl}/api/shop/gacha'),
        headers: _headers,
        body: jsonEncode({'game': _game, 'tier': tier.id}),
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        final item = Map<String, dynamic>.from(body['item'] as Map);
        final isNew = body['is_new'] as bool? ?? true;
        setState(() {
          _balance = (body['new_balance'] as num?)?.toInt() ?? _balance;
          _pulling = false;
        });
        await Navigator.of(context).push(
          PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, _, _) =>
                GachaResultOverlay(item: item, isNew: isNew),
          ),
        );
        if (mounted) await _showResult(tier, item, isNew);
      } else {
        setState(() => _pulling = false);
        if (body['reason'] == 'insufficient_coins') {
          await _showInsufficient(tier);
        } else {
          showV2Snack(
            context,
            '뽑지 못했어요. 코인은 그대로예요. 잠시 후 다시 시도해 주세요.',
            tone: V2Tone.err,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _pulling = false);
      showV2Snack(context, '뽑지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.', tone: V2Tone.err);
    }
  }

  Future<void> _showInsufficient(GachaTier tier) {
    final lack = tier.cost - _balance;
    return showV2Sheet<void>(
      context,
      title: '코인이 ${coinText(lack)} 모자라요',
      subtitle: '${tier.name}는 ${coinText(tier.cost)} 코인이 필요해요',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2ProgressBar(
            value: tier.cost == 0 ? 0 : _balance / tier.cost,
            semanticLabel: '필요한 코인 중 ${coinText(_balance)} 보유',
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('내 코인 ${coinText(_balance)}', style: V2Text.cap),
              Text('필요 ${coinText(tier.cost)}', style: V2Text.cap),
            ],
          ),
          const SizedBox(height: 20),
          V2Button(
            label: '코인 얻는 법 보기',
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onOpenCoinGuide();
            },
          ),
          const SizedBox(height: 8),
          V2Button(
            label: '닫기',
            variant: V2ButtonVariant.text,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _showResult(
    GachaTier tier,
    Map<String, dynamic> item,
    bool isNew,
  ) {
    final grade = '${item['grade'] ?? 'B'}';
    final canAgain = _balance >= tier.cost;
    return showV2Sheet<void>(
      context,
      title: item['name'] as String? ?? '새 아이템',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ItemArt(game: _game, grade: grade, size: 88),
          ),
          const SizedBox(height: 12),
          Center(child: GradeChip(grade: grade)),
          const SizedBox(height: 12),
          Text(
            isNew ? '처음 만난 아이템이에요. 도감에 추가됐어요.' : '이미 가지고 있는 아이템이에요.',
            textAlign: TextAlign.center,
            style: V2Text.body,
          ),
          const SizedBox(height: 4),
          Text(
            '남은 코인 ${coinText(_balance)}',
            textAlign: TextAlign.center,
            style: V2Text.cap,
          ),
          const SizedBox(height: 20),
          V2Button(
            label: '한 번 더 뽑기 · ${coinText(tier.cost)}',
            variant: V2ButtonVariant.soft,
            onPressed: canAgain
                ? () {
                    Navigator.of(ctx).pop();
                    _pull(tier);
                  }
                : null,
          ),
          const SizedBox(height: 8),
          V2Button(label: '닫기', onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  Future<void> _showOdds() {
    return showV2Sheet<void>(
      context,
      title: '뽑기 확률',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tier in kGachaTiers) ...[
            Text(
              '${tier.name} · ${coinText(tier.cost)} 코인',
              style: V2Text.bodyStrong,
            ),
            const SizedBox(height: 6),
            for (final g in gradeOrder)
              if (tier.odds.containsKey(g))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      GradeChip(grade: g),
                      const Spacer(),
                      Text(
                        oddsPercent(tier.odds[g]!),
                        style: V2Text.bodyStrong,
                      ),
                    ],
                  ),
                ),
            const Divider(height: 24),
          ],
          Text(
            '같은 등급 안에서는 모든 아이템이 같은 확률이에요. 장착한 아이템의 ‘뽑기 높은 등급 확률’ 효과가 있으면 높은 등급이 조금 더 잘 나와요.',
            style: V2Text.cap,
          ),
        ],
      ),
      actions: [
        V2Button(label: '닫기', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(
          title: '뽑기',
          actions: [
            CoinPill(balance: _balance, onTap: widget.onOpenCoinGuide),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                V2Segmented<String>(
                  segments: const [
                    V2Segment(value: 'yut', label: '윷놀이'),
                    V2Segment(value: 'onecard', label: '원카드'),
                  ],
                  selected: _game,
                  onChanged: (v) => setState(() => _game = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: V2Button(
                    label: '뽑기 확률 보기',
                    icon: V2Icons.info,
                    variant: V2ButtonVariant.text,
                    size: V2ButtonSize.sm,
                    fullWidth: false,
                    onPressed: _showOdds,
                  ),
                ),
                for (final tier in kGachaTiers) ...[
                  _TierCard(
                    tier: tier,
                    canAfford: _balance >= tier.cost,
                    onPull: () => _pull(tier),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('가격은 바뀔 수 있어요. 뽑기 전에 한 번 더 알려드려요.', style: V2Text.cap),
              ],
            ),
            if (_pulling)
              Positioned.fill(
                child: ColoredBox(
                  color: V2Colors.scrim,
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: '뽑는 중이에요',
                      child: V2Card(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text('두근두근, 뽑는 중이에요', style: V2Text.bodyStrong),
                            Text('잠시만 기다려 주세요', style: V2Text.cap),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.canAfford,
    required this.onPull,
  });

  final GachaTier tier;
  final bool canAfford;
  final VoidCallback onPull;

  @override
  Widget build(BuildContext context) {
    return V2Card(
      key: ValueKey('gacha_tier_${tier.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tier.name, style: V2Text.head),
          const SizedBox(height: 2),
          Text(tier.blurb, style: V2Text.cap),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in gradeOrder)
                if (tier.odds.containsKey(g)) GradeChip(grade: g),
            ],
          ),
          const SizedBox(height: 14),
          V2Button(
            label: canAfford
                ? '${coinText(tier.cost)} 코인으로 뽑기'
                : '${coinText(tier.cost)} 코인 · 코인이 모자라요',
            variant: canAfford ? V2ButtonVariant.primary : V2ButtonVariant.soft,
            onPressed: onPull,
          ),
        ],
      ),
    );
  }
}
