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
  'yut_backdo_bonus_pct': '🎲 유리한 백도 추가 던지기 %',
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
  Map<String, dynamic> _equippedBySlot =
      {}; // slot → {item_id, name, icon, grade, stats:{}}
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
        _equippedBySlot = Map<String, dynamic>.from(slots);
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

  Future<void> _unequip(String slot) async {
    try {
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/unequip'),
        headers: {
          'Authorization': 'Bearer ${_auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'slot': slot}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true && mounted) {
        _showSnack('기본 아이템으로 변경됨');
        await _load();
      }
    } catch (_) {
      _showSnack('오류가 발생했어요');
    }
  }

  static const _defaultItems = <Map<String, dynamic>>[
    {
      'item_id': 0,
      'name': '기본 윷',
      'slot': 'yut_yut',
      'game': 'yut',
      'grade': 'B',
      'icon': '🎲',
      'stats': <String, dynamic>{},
    },
    {
      'item_id': 0,
      'name': '기본 말',
      'slot': 'yut_piece',
      'game': 'yut',
      'grade': 'B',
      'icon': '⬛',
      'stats': <String, dynamic>{},
    },
    {
      'item_id': 0,
      'name': '기본 카드',
      'slot': 'onecard_cardback',
      'game': 'onecard',
      'grade': 'B',
      'icon': '🃏',
      'stats': <String, dynamic>{},
    },
  ];

  static const _statMaxValues = {
    'coin_bonus_pct': 20,
    'shop_discount_pct': 20,
    'daily_bonus_add': 500,
    'lose_refund_pct': 20,
    'yut_control_pct': 25,
    'yut_catch_bonus': 300,
    'gacha_rate_up': 20,
    'win_streak_bonus': 400,
    'yut_mo_rate_pct': 22,
    'yut_backdo_bonus_pct': 25,
    'yut_win_coin_pct': 18,
    'yut_overturn_pct': 20,
    'piece_catch_resist_pct': 25,
    'piece_catch_coin_bonus': 25,
    'piece_safe_zone_pct': 25,
    'piece_group_pct': 22,
    'card_shield_pct': 25,
    'card_lucky_draw_pct': 25,
    'card_uno_protect_pct': 22,
    'card_reverse_bonus': 22,
    'onecard_draw_reduce': 2,
  };

  void _showItemDetail(Map<String, dynamic> item) {
    final grade = item['grade'] as String? ?? 'B';
    final gc = gradeColor(grade);
    final slot = item['slot'] as String? ?? '';
    final id = (item['item_id'] as num).toInt();
    final equipped = _equippedIds.contains(id);

    // 이 아이템의 스탯
    Map<String, dynamic> itemStats = {};
    final rawStats = item['stats'];
    if (rawStats is String && rawStats.isNotEmpty && rawStats != 'null') {
      try {
        itemStats = Map<String, dynamic>.from(jsonDecode(rawStats) as Map);
      } catch (_) {}
    } else if (rawStats is Map) {
      itemStats = Map<String, dynamic>.from(rawStats);
    }

    // 같은 슬롯에 장착된 다른 아이템의 스탯
    Map<String, dynamic> equippedStats = {};
    final equippedInSlot = _equippedBySlot[slot] as Map?;
    if (equippedInSlot != null &&
        (equippedInSlot['item_id'] as num?)?.toInt() != id) {
      final es = equippedInSlot['stats'] as Map?;
      if (es != null) equippedStats = Map<String, dynamic>.from(es);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kMainLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 헤더
              Row(
                children: [
                  Text(
                    item['icon'] as String? ?? '🎁',
                    style: const TextStyle(fontSize: 44),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
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
                            if (equipped) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: kMainSage.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '장착 중',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kMainSage,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!equipped)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _equip(item);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMainHoney,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        '장착',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (itemStats.isNotEmpty) ...[
                const SizedBox(height: 20),
                if (equippedStats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 6,
                          decoration: BoxDecoration(
                            color: gc,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '이 아이템',
                          style: TextStyle(
                            fontSize: 10,
                            color: gc,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 10,
                          height: 6,
                          decoration: BoxDecoration(
                            color: kMainMuted.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '장착 중',
                          style: TextStyle(
                            fontSize: 10,
                            color: kMainMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final entry in itemStats.entries) ...[
                  _buildStatBar(
                    key: entry.key,
                    value: (entry.value as num).toDouble(),
                    compareValue: equippedStats[entry.key] != null
                        ? (equippedStats[entry.key] as num).toDouble()
                        : null,
                    gc: gc,
                  ),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                const SizedBox(height: 12),
                Text('스탯 정보 없음', style: mainBody(size: 12, color: kMainMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBar({
    required String key,
    required double value,
    double? compareValue,
    required Color gc,
  }) {
    final maxV = (_statMaxValues[key] ?? value).toDouble();
    final fraction = maxV > 0 ? (value / maxV).clamp(0.0, 1.0) : 0.0;
    final cFraction = compareValue != null && maxV > 0
        ? (compareValue / maxV).clamp(0.0, 1.0)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                statLabels[key] ?? key,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            Text(
              '+${value.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: gc,
              ),
            ),
            if (compareValue != null) ...[
              Text(
                ' vs +${compareValue.toInt()}',
                style: TextStyle(fontSize: 10, color: kMainMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (_, constraints) {
            final w = constraints.maxWidth;
            return Stack(
              children: [
                Container(
                  height: 8,
                  width: w,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (cFraction != null)
                  Container(
                    height: 8,
                    width: w * cFraction,
                    decoration: BoxDecoration(
                      color: kMainMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                Container(
                  height: 8,
                  width: w * fraction,
                  decoration: BoxDecoration(
                    color: gc,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            );
          },
        ),
      ],
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filteredOwned = _filterGame == null
        ? _owned
        : _owned.where((i) => i['game'] == _filterGame).toList();

    // 기본 아이템: 필터 일치 + 맨 앞에 배치
    final filteredDefaults = _defaultItems
        .where((d) {
          if (_filterGame == null) return true;
          return d['game'] == _filterGame;
        })
        .map((d) {
          final slot = d['slot'] as String;
          final slotEquipped = _equippedBySlot[slot];
          // 해당 슬롯에 다른 아이템이 장착돼 있지 않으면 기본이 장착 중
          final isDefaultEquipped = slotEquipped == null;
          return <String, dynamic>{
            ...d,
            '_isDefault': true,
            '_defaultEquipped': isDefaultEquipped,
          };
        })
        .toList();

    final allItems = [...filteredDefaults, ...filteredOwned];

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
                  ('마블 작전', 'marble'),
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

          // 보유 아이템 (기본 포함)
          Text(
            '아이템 (${filteredOwned.length}개 보유)',
            style: mainBody(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: allItems.length,
            itemBuilder: (_, i) {
              final item = allItems[i];
              final isDefault = item['_isDefault'] == true;
              final id = (item['item_id'] as num).toInt();
              if (isDefault) {
                final defaultEquipped = item['_defaultEquipped'] == true;
                final slot = item['slot'] as String;
                return _InventoryItemCard(
                  item: item,
                  equipped: defaultEquipped,
                  quantity: 1,
                  onEquip: defaultEquipped ? null : () => _unequip(slot),
                  onTap: null,
                );
              }
              final equipped = _equippedIds.contains(id);
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              return _InventoryItemCard(
                item: item,
                equipped: equipped,
                quantity: qty,
                onEquip: equipped ? null : () => _equip(item),
                onTap: () => _showItemDetail(item),
              );
            },
          ),
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
  final VoidCallback? onTap;

  const _InventoryItemCard({
    required this.item,
    required this.equipped,
    required this.quantity,
    required this.onEquip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final gc = gradeColor(grade);

    return GestureDetector(
      onTap: onTap,
      child: MainCard(
        padding: const EdgeInsets.all(8),
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
      ),
    );
  }
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
