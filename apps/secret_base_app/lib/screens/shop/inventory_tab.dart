import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';

// ── Shared grade helpers (공개) ───────────────────────────────────────────────

const gradeOrder = ['B', 'A', 'S', 'SS', 'SSS'];

Color gradeColor(String grade) => switch (grade) {
  'B' => kMainMuted,
  'A' => kMainSage,
  'S' => kMainSky,
  'SS' => kMainLilac,
  'SSS' => kMainHoney,
  _ => kMainMuted,
};

const statLabels = {
  // 기존
  'coin_bonus_pct': '🪙 승리 코인 +%',
  'shop_discount_pct': '🏷️ 상점 할인 %',
  'daily_bonus_add': '📅 데일리 추가 코인',
  'lose_refund_pct': '🔁 패배 환급 %',
  'yut_control_pct': '🎯 윷/모 확률 +%',
  'yut_catch_bonus': '⚡ 말 잡기 보너스 코인',
  'gacha_rate_up': '🎰 뽑기 S등급 확률 +%',
  'daily_bonus_cooldown': '⏱️ 데일리 쿨타임 감소',
  'win_streak_bonus': '🔥 연승 추가 코인',
  'onecard_draw_reduce': '🃏 +카드 1장 감소',
  // 윷 전용
  'yut_mo_rate_pct': '🎲 모(5칸) 확률 +%',
  'yut_backdo_shield_pct': '🛡️ 뒤도 → 도 변환 확률 %',
  'yut_win_coin_pct': '💰 윷/모 시 추가 코인',
  'yut_overturn_pct': '🔄 역전 시 윷/모 확률 +%',
  // 말 전용
  'piece_catch_resist_pct': '🛡️ 잡힐 확률 감소 %',
  'piece_catch_coin_bonus': '💥 상대 잡기 추가 코인',
  'piece_safe_zone_pct': '🏠 모서리 착지 확률 +%',
  'piece_group_pct': '🤝 업은 말 분리 방지 %',
  // 원카드 전용
  'card_shield_pct': '🛡️ 공격 카드 무효화 %',
  'card_lucky_draw_pct': '🍀 원하는 카드 뽑기 %',
  'card_uno_protect_pct': '🔒 원카드 선언 보호 %',
  'card_reverse_bonus': '↩️ 리버스/스킵 추가 코인',
};

// ── InventoryTab ──────────────────────────────────────────────────────────────

class InventoryTab extends StatefulWidget {
  final VoidCallback onBalanceChanged;
  const InventoryTab({super.key, required this.onBalanceChanged});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final _auth = AuthService();
  final _socket = SocketService();

  List<Map<String, dynamic>> _owned = [];
  Set<int> _equippedIds = {};
  int _balance = 0;
  bool _loading = true;
  String? _filterGame; // 인벤토리 필터 (null=전체)

  @override
  void initState() {
    super.initState();
    _load();
    _socket.addListener(_onWallet);
  }

  @override
  void dispose() {
    _socket.removeListener(_onWallet);
    super.dispose();
  }

  void _onWallet() {
    final b = _socket.walletBalance;
    if (b != null && b != _balance) setState(() => _balance = b);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final base = _socket.serverUrl ?? '';
      final headers = {'Authorization': 'Bearer ${_auth.token}'};
      final results = await Future.wait([
        http.get(Uri.parse('$base/api/shop/owned'), headers: headers),
        http.get(Uri.parse('$base/api/shop/equipped'), headers: headers),
        http.get(Uri.parse('$base/api/wallet/balance'), headers: headers),
      ]);
      if (!mounted) return;
      final ownedData = jsonDecode(results[0].body) as Map;
      final equippedData = jsonDecode(results[1].body) as Map;
      final walletData = jsonDecode(results[2].body) as Map;

      final slots = (equippedData['slots'] as Map? ?? {})
          .cast<String, dynamic>();

      setState(() {
        _owned = (ownedData['owned'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _equippedIds = slots.values
            .map((v) => ((v as Map)['item_id'] as num).toInt())
            .toSet();
        _balance = (walletData['balance'] as num?)?.toInt() ?? _balance;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _equip(Map<String, dynamic> item) async {
    try {
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/equip'),
        headers: {
          'Authorization': 'Bearer ${_auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'item_id': item['item_id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true && mounted) {
        _showSnack('${item['name']} 장착 완료 ✅');
        await _load();
      } else {
        _showSnack('장착 실패');
      }
    } catch (_) {
      _showSnack('오류가 발생했어요');
    }
  }

  Future<void> _gacha(String game, String tier) async {
    final cost = switch (tier) {
      'normal' => 3000,
      'advanced' => 45000,
      'rare' => 100000,
      _ => 0,
    };
    final tierName = switch (tier) {
      'normal' => '랜덤 뽑기',
      'advanced' => '고급 뽑기',
      'rare' => '레어 뽑기',
      _ => '뽑기',
    };
    final gameName = game == 'yut' ? '윷놀이' : '원카드';

    if (_balance < cost) {
      _showSnack('코인이 부족해요 (필요: ${_formatCoins(cost)}금)');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(
          '$gameName $tierName',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '${_formatCoins(cost)}금을 소모해 $gameName 아이템을 뽑습니다.',
          style: TextStyle(color: kMainMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _tierColor(tier)),
            child: Text('뽑기!', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/gacha'),
        headers: {
          'Authorization': 'Bearer ${_auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'game': game, 'tier': tier}),
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        final item = body['item'] as Map<String, dynamic>;
        final grade = item['grade'] as String? ?? 'B';
        final isNew = body['is_new'] as bool? ?? true;
        final newBalance = (body['new_balance'] as num?)?.toInt() ?? _balance;
        setState(() => _balance = newBalance);
        widget.onBalanceChanged();

        if (['S', 'SS', 'SSS'].contains(grade)) {
          await _showGachaAnimation(item, isNew);
        } else {
          await _showGachaResult(item, isNew);
        }
        await _load();
      } else {
        final reason = body['reason'] as String? ?? '';
        _showSnack(
          reason == 'insufficient_coins' ? '코인이 부족해요' : '뽑기 실패: $reason',
        );
      }
    } catch (_) {
      _showSnack('오류가 발생했어요');
    }
  }

  Future<void> _showGachaResult(Map<String, dynamic> item, bool isNew) async {
    if (!mounted) return;
    final grade = item['grade'] as String? ?? 'B';
    await showDialog(
      context: context,
      builder: (ctx) =>
          _GachaResultDialog(item: item, grade: grade, isNew: isNew),
    );
  }

  Future<void> _showGachaAnimation(
    Map<String, dynamic> item,
    bool isNew,
  ) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, a, b) => _GachaAnimOverlay(item: item, isNew: isNew),
      ),
    );
  }

  Future<void> _showCompendium() async {
    final base = _socket.serverUrl ?? '';
    final gameParam = _filterGame != null ? '?game=$_filterGame' : '';
    try {
      final res = await http.get(
        Uri.parse('$base/api/shop/catalog$gameParam'),
        headers: {'Authorization': 'Bearer ${_auth.token}'},
      );
      final body = jsonDecode(res.body) as Map;
      if (!mounted) return;
      if (body['ok'] == true) {
        final items = (body['items'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _CompendiumSheet(items: items),
        );
      }
    } catch (_) {
      _showSnack('도감을 불러오지 못했어요');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _formatCoins(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K'
      : '$n';

  Color _tierColor(String tier) => switch (tier) {
    'normal' => kMainSage,
    'advanced' => kMainSky,
    'rare' => kMainLilac,
    _ => kMainMuted,
  };

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filterGame == null
        ? _owned
        : _owned.where((i) => i['game'] == _filterGame).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 잔액 + 도감 버튼
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kMainHoney.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      _formatCoins(_balance),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kMainHoney,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showCompendium,
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('도감', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: kMainLilac),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 게임 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, game) in [
                  ('전체', null),
                  ('윷놀이', 'yut'),
                  ('원카드', 'onecard'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filterGame == game,
                      onSelected: (_) => setState(() {
                        _filterGame = game;
                      }),
                      selectedColor: kMainHoney.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _filterGame == game ? kMainHoney : kMainMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 보유 아이템
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Text('🎒', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('보유한 아이템이 없어요', style: TextStyle(color: kMainMuted)),
                  const SizedBox(height: 4),
                  Text(
                    '상점에서 구매하거나 뽑기로 획득해보세요',
                    style: TextStyle(fontSize: 12, color: kMainMuted),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              '보유 아이템 (${filtered.length}개)',
              style: mainBody(size: 13, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                final id = (item['item_id'] as num).toInt();
                final equipped = _equippedIds.contains(id);
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                return _InventoryItemCard(
                  item: item,
                  equipped: equipped,
                  quantity: qty,
                  onEquip: equipped ? null : () => _equip(item),
                );
              },
            ),
          ],

          const SizedBox(height: 28),

          // 가챠 섹션
          if (_filterGame != null) ...[
            _GachaSection(
              game: _filterGame!,
              balance: _balance,
              onPull: _gacha,
              formatCoins: _formatCoins,
              tierColor: _tierColor,
            ),
          ] else ...[
            Text(
              '카테고리를 선택하면 뽑기를 할 수 있어요',
              style: mainBody(size: 13, color: kMainMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CategoryGachaButton(
                    label: '윷놀이 뽑기',
                    icon: '🎲',
                    color: kMainSage,
                    onTap: () => setState(() {
                      _filterGame = 'yut';
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CategoryGachaButton(
                    label: '원카드 뽑기',
                    icon: '🃏',
                    color: kMainSky,
                    onTap: () => setState(() {
                      _filterGame = 'onecard';
                    }),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── _InventoryItemCard ────────────────────────────────────────────────────────

class _InventoryItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool equipped;
  final int quantity;
  final VoidCallback? onEquip;

  const _InventoryItemCard({
    required this.item,
    required this.equipped,
    required this.quantity,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final gc = gradeColor(grade);

    return MainCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item['icon'] as String? ?? '🎁',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const Spacer(),
              if (quantity > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kMainMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'x$quantity',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: gc,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item['name'] as String? ?? '',
            style: mainBody(size: 12, weight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (equipped)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: kMainSage.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '장착 중 ✓',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kMainSage,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 30,
              child: ElevatedButton(
                onPressed: onEquip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMainHoney,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '장착',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _GachaSection ─────────────────────────────────────────────────────────────

class _GachaSection extends StatelessWidget {
  final String game;
  final int balance;
  final Future<void> Function(String, String) onPull;
  final String Function(int) formatCoins;
  final Color Function(String) tierColor;

  const _GachaSection({
    required this.game,
    required this.balance,
    required this.onPull,
    required this.formatCoins,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final gameName = game == 'yut' ? '윷놀이' : '원카드';
    final tiers = [
      ('normal', '랜덤 뽑기', 'B ~ S', 3000),
      ('advanced', '고급 뽑기', 'S ~ SS', 45000),
      ('rare', '레어 뽑기', 'SS ~ SSS', 100000),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$gameName 뽑기', style: mainTitle(size: 16)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: kMainHoney.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🪙 ${formatCoins(balance)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (tier, label, range, cost) in tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GachaTierButton(
              label: label,
              range: range,
              cost: cost,
              color: tierColor(tier),
              canAfford: balance >= cost,
              formatCoins: formatCoins,
              onTap: () => onPull(game, tier),
            ),
          ),
      ],
    );
  }
}

class _GachaTierButton extends StatelessWidget {
  final String label;
  final String range;
  final int cost;
  final Color color;
  final bool canAfford;
  final String Function(int) formatCoins;
  final VoidCallback onTap;

  const _GachaTierButton({
    required this.label,
    required this.range,
    required this.cost,
    required this.color,
    required this.canAfford,
    required this.formatCoins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: canAfford ? 0.18 : 0.07),
              color.withValues(alpha: canAfford ? 0.06 : 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: canAfford ? 0.35 : 0.15),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: canAfford ? color : kMainMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    range,
                    style: TextStyle(fontSize: 11, color: kMainMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '🪙 ${formatCoins(cost)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: canAfford ? kMainHoney : kMainMuted,
                  ),
                ),
                if (!canAfford)
                  Text(
                    '잔액 부족',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGachaButton extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryGachaButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GachaResultDialog (B/A grade) ────────────────────────────────────────────

class _GachaResultDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final String grade;
  final bool isNew;

  const _GachaResultDialog({
    required this.item,
    required this.grade,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final gc = gradeColor(grade);
    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item['icon'] as String? ?? '🎁',
              style: const TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: gc.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                grade,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: gc,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(item['name'] as String? ?? '', style: mainTitle(size: 18)),
            if (!isNew) ...[
              const SizedBox(height: 6),
              Text(
                '이미 보유 중 (x1 추가)',
                style: TextStyle(fontSize: 12, color: kMainMuted),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: gc),
                child: const Text('확인', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GachaAnimOverlay (S/SS/SSS grade) ───────────────────────────────────────

class _GachaAnimOverlay extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isNew;
  const _GachaAnimOverlay({required this.item, required this.isNew});

  @override
  State<_GachaAnimOverlay> createState() => _GachaAnimOverlayState();
}

class _GachaAnimOverlayState extends State<_GachaAnimOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    final grade = widget.item['grade'] as String? ?? 'S';
    final duration = switch (grade) {
      'SSS' => const Duration(milliseconds: 3500),
      'SS' => const Duration(milliseconds: 2500),
      _ => const Duration(milliseconds: 1500),
    };
    _ctrl = AnimationController(vsync: this, duration: duration);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _ctrl.forward().then((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.item['grade'] as String? ?? 'S';
    final gc = gradeColor(grade);
    final bgColor = switch (grade) {
      'SSS' => const Color(0xFF1A0A00),
      'SS' => const Color(0xFF0D0020),
      _ => const Color(0xFF000A1A),
    };

    return Scaffold(
      backgroundColor: bgColor.withValues(alpha: 0.95),
      body: GestureDetector(
        onTap: _revealed ? () => Navigator.pop(context) : null,
        child: Stack(
          children: [
            // 파티클 배경
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, x) => CustomPaint(
                painter: _GachaBurstPainter(
                  progress: _ctrl.value,
                  gradeColor: gc,
                  grade: grade,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            // 카드 reveal
            Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Transform.scale(
                  scale: 0.5 + _scale.value * 0.5,
                  child: Opacity(opacity: _opacity.value, child: child),
                ),
                child: _ResultCard(
                  item: widget.item,
                  grade: grade,
                  gc: gc,
                  isNew: widget.isNew,
                  revealed: _revealed,
                ),
              ),
            ),
            if (_revealed)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '탭하여 닫기',
                    style: TextStyle(
                      color: gc.withValues(alpha: 0.7),
                      fontSize: 13,
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

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String grade;
  final Color gc;
  final bool isNew;
  final bool revealed;

  const _ResultCard({
    required this.item,
    required this.grade,
    required this.gc,
    required this.isNew,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gc, width: 2),
        boxShadow: [
          BoxShadow(
            color: gc.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item['icon'] as String? ?? '🎁',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: gc,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item['name'] as String? ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isNew) ...[
            const SizedBox(height: 6),
            Text(
              '이미 보유 중 (x1 추가)',
              style: TextStyle(fontSize: 11, color: kMainMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _GachaBurstPainter extends CustomPainter {
  final double progress;
  final Color gradeColor;
  final String grade;

  _GachaBurstPainter({
    required this.progress,
    required this.gradeColor,
    required this.grade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.1) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    final particleCount = grade == 'SSS'
        ? 20
        : grade == 'SS'
        ? 14
        : 8;
    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 3.14159 * 2;
      final radius = size.width * 0.4 * progress;
      final px = cx + radius * 0.8 * (1 + 0.3 * ((i % 3) - 1));
      final py = cy + radius * 0.6 * (1 - 0.3 * ((i % 2)));
      final dx = px * (angle.abs() % 1.0);
      final dy = py * ((angle + 1) % 1.0);
      paint.color = gradeColor.withValues(alpha: (1 - progress) * 0.7);
      canvas.drawCircle(
        Offset(cx + dx - cx * 0.5, cy + dy - cy * 0.5),
        4 + (i % 3) * 2.0,
        paint,
      );
    }

    // 글로우 원
    final glowPaint = Paint()
      ..color = gradeColor.withValues(alpha: (1 - progress) * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.3 * progress, glowPaint);
  }

  @override
  bool shouldRepaint(_GachaBurstPainter old) => old.progress != progress;
}

// ── _CompendiumSheet (도감) ────────────────────────────────────────────────────

class _CompendiumSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _CompendiumSheet({required this.items});

  @override
  State<_CompendiumSheet> createState() => _CompendiumSheetState();
}

class _CompendiumSheetState extends State<_CompendiumSheet> {
  String? _filterGrade;
  String? _filterGame;

  @override
  Widget build(BuildContext context) {
    var filtered = widget.items.where((i) {
      if (_filterGrade != null && i['grade'] != _filterGrade) return false;
      if (_filterGame != null && i['game'] != _filterGame) return false;
      return true;
    }).toList();

    final total = widget.items.length;
    final owned = widget.items
        .where((i) => (i['owned'] as bool? ?? false))
        .length;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들 + 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kMainLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('도감', style: mainTitle(size: 18)),
                      const SizedBox(width: 8),
                      Text(
                        '$owned / $total 수집',
                        style: mainBody(size: 12, color: kMainMuted),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total > 0 ? owned / total : 0,
                            minHeight: 6,
                            backgroundColor: kMainLine,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              kMainHoney,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 필터 행
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (g, label) in [
                          (null, '전체'),
                          ('yut', '윷놀이'),
                          ('onecard', '원카드'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _filterGame == g,
                              onSelected: (_) =>
                                  setState(() => _filterGame = g),
                              selectedColor: kMainSky.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: _filterGame == g ? kMainSky : kMainMuted,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        for (final grade in ['B', 'A', 'S', 'SS', 'SSS'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                grade,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: _filterGrade == grade,
                              onSelected: (_) => setState(
                                () => _filterGrade = _filterGrade == grade
                                    ? null
                                    : grade,
                              ),
                              selectedColor: gradeColor(
                                grade,
                              ).withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: _filterGrade == grade
                                    ? gradeColor(grade)
                                    : kMainMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                ],
              ),
            ),
            // 아이템 그리드
            Expanded(
              child: GridView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _CompendiumCard(item: filtered[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompendiumCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CompendiumCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final active = item['active'] as bool? ?? false;
    final owned = item['owned'] as bool? ?? false;
    final grade = item['grade'] as String? ?? 'B';
    final gc = gradeColor(grade);
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;

    if (!active) {
      // 미공개: 실루엣
      return Container(
        decoration: BoxDecoration(
          color: kMainLine.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                0.5,
                0,
              ]),
              child: const Text('❓', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 4),
            Text('???', style: TextStyle(fontSize: 10, color: kMainMuted)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: gc.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                grade,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: gc.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showItemDetail(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: owned
              ? gc.withValues(alpha: 0.08)
              : kMainLine.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: owned ? gc.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Text(
                  item['icon'] as String? ?? '🎁',
                  style: TextStyle(
                    fontSize: 28,
                    color: owned ? null : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                if (owned && qty > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: kMainHoney,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'x$qty',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item['name'] as String? ?? '',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: owned ? null : kMainMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: gc.withValues(alpha: owned ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                grade,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: gc.withValues(alpha: owned ? 1.0 : 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDetail(BuildContext context, Map<String, dynamic> item) {
    final grade = item['grade'] as String? ?? 'B';
    final gc = gradeColor(grade);
    final stats = item['stats'] as Map? ?? {};
    final owned = item['owned'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item['icon'] as String? ?? '🎁',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String? ?? '',
                        style: mainTitle(size: 17),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gc.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          grade,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: gc,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (owned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kMainSage.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '보유 중',
                      style: TextStyle(
                        fontSize: 11,
                        color: kMainSage,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (item['description'] != null) ...[
              const SizedBox(height: 10),
              Text(
                item['description'] as String,
                style: mainBody(size: 12, color: kMainMuted),
              ),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '스탯',
                style: mainBody(
                  size: 12,
                  weight: FontWeight.w700,
                  color: kMainMuted,
                ),
              ),
              const SizedBox(height: 6),
              for (final entry in stats.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        statLabels[entry.key] ?? entry.key,
                        style: mainBody(size: 12),
                      ),
                      const Spacer(),
                      Text(
                        '+${entry.value}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: gc,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (owned == false) ...[
              const SizedBox(height: 12),
              Text(
                '보유 시 스탯이 공개됩니다',
                style: mainBody(size: 12, color: kMainMuted),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
