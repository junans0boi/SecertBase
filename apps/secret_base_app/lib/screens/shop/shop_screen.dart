import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';

// ── Grade helpers ─────────────────────────────────────────────────────────────

const _gradeOrder = ['B', 'A', 'S', 'SS', 'SSS'];

Color _gradeColor(String grade) => switch (grade) {
      'B' => kMainMuted,
      'A' => kMainSage,
      'S' => kMainSky,
      'SS' => kMainLilac,
      'SSS' => kMainHoney,
      _ => kMainMuted,
    };

LinearGradient _gradeGradient(String grade) {
  final c = _gradeColor(grade);
  return LinearGradient(
    colors: [c.withValues(alpha: 0.15), c.withValues(alpha: 0.05)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const _statLabels = {
  'coin_bonus_pct': '🪙 승리 코인 +%',
  'shop_discount_pct': '🏷️ 상점 할인 %',
  'daily_bonus_add': '📅 데일리 추가 코인',
  'lose_refund_pct': '🔁 패배 환급 %',
  'yut_control_pct': '🎯 윷/모 확률 +%',
  'yut_catch_bonus': '⚡ 말 잡기 보너스',
  'gacha_rate_up': '🎰 뽑기 S등급 확률 +%',
  'daily_bonus_cooldown': '⏱️ 데일리 쿨타임 감소',
  'win_streak_bonus': '🔥 연승 추가 코인',
  'onecard_draw_reduce': '🃏 +카드 1장 감소',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _socket = SocketService();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _coupons = [];
  Set<int> _ownedItemIds = {};
  Set<int> _equippedItemIds = {};
  int _balance = 0;
  bool _loading = true;
  String? _error;

  late final TabController _tabCtrl;

  static const _gameTabs = [
    ('전체', null),
    ('원카드', 'onecard'),
    ('윷놀이', 'yut'),
    ('데이트쿠폰', 'coupon'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _gameTabs.length, vsync: this);
    _socket.addListener(_onWallet);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _socket.removeListener(_onWallet);
    super.dispose();
  }

  void _onWallet() {
    final b = _socket.walletBalance;
    if (b != null && b != _balance) setState(() => _balance = b);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = _auth.token;
      final base = _socket.serverUrl ?? '';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final results = await Future.wait([
        http.get(Uri.parse('$base/api/shop/items'), headers: headers),
        http.get(Uri.parse('$base/api/wallet/balance'), headers: headers),
        http.get(Uri.parse('$base/api/shop/coupons'), headers: headers),
        http.get(Uri.parse('$base/api/shop/owned'), headers: headers),
        http.get(Uri.parse('$base/api/shop/equipped'), headers: headers),
      ]);

      final itemsRes = jsonDecode(results[0].body) as Map;
      final walletRes = jsonDecode(results[1].body) as Map;
      final couponsRes = jsonDecode(results[2].body) as Map;
      final ownedRes = jsonDecode(results[3].body) as Map;
      final equippedRes = jsonDecode(results[4].body) as Map;

      final ownedList = (ownedRes['owned'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final equippedSlots = (equippedRes['slots'] as Map? ?? {})
          .values
          .toList();

      setState(() {
        _items = (itemsRes['items'] as List? ?? []).cast<Map<String, dynamic>>();
        _balance = (walletRes['balance'] as num?)?.toInt() ?? _balance;
        _coupons =
            (couponsRes['coupons'] as List? ?? []).cast<Map<String, dynamic>>();
        _ownedItemIds =
            ownedList.map((o) => (o['item_id'] as num).toInt()).toSet();
        _equippedItemIds = equippedSlots
            .map((s) => (s['item_id'] as num).toInt())
            .toSet();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _preview(Map<String, dynamic> item) async {
    final owned = _ownedItemIds.contains((item['id'] as num).toInt());
    final equipped = _equippedItemIds.contains((item['id'] as num).toInt());
    final grade = item['grade'] as String? ?? 'B';
    final isGachaOnly = ['S', 'SS', 'SSS'].contains(grade);
    final stats = (item['stats'] as List? ?? []).cast<Map<String, dynamic>>();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ItemPreviewSheet(
        item: item,
        stats: stats,
        owned: owned,
        equipped: equipped,
        isGachaOnly: isGachaOnly,
        balance: _balance,
        gradeColor: _gradeColor(grade),
        gradeGradient: _gradeGradient(grade),
        onBuy: isGachaOnly || owned ? null : () { Navigator.pop(ctx); _buy(item); },
        onEquip: owned && !equipped ? () { Navigator.pop(ctx); _equip(item); } : null,
        formatCoins: _formatCoins,
      ),
    );
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    try {
      final token = _auth.token;
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/buy'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'item_id': item['id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        setState(() => _balance = (body['new_balance'] as num).toInt());
        _showSnack('${item['name']} 획득! 🎉');
        await _load();
      } else {
        _showSnack(_buyErrorMsg(body['reason'] as String?));
      }
    } catch (e) {
      _showSnack('오류: $e');
    }
  }

  Future<void> _equip(Map<String, dynamic> item) async {
    try {
      final token = _auth.token;
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/equip'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'item_id': item['id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        _showSnack('${item['name']} 장착 완료 ✅');
        await _load();
      } else {
        _showSnack('장착 실패');
      }
    } catch (e) {
      _showSnack('오류: $e');
    }
  }

  Future<void> _issueCoupon() async {
    String title = '';
    String desc = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이트 쿠폰 보내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '제목 (필수)'),
              onChanged: (v) => title = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: '내용 (선택)'),
              maxLines: 2,
              onChanged: (v) => desc = v,
            ),
            const SizedBox(height: 8),
            Text('500코인 차감', style: TextStyle(fontSize: 11, color: kMainMuted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('보내기')),
        ],
      ),
    );
    if (confirmed != true || title.trim().isEmpty || !mounted) return;

    try {
      final token = _auth.token;
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/coupons/issue'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'title': title.trim(), 'description': desc.trim()}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        setState(() => _balance = (body['new_balance'] as num).toInt());
        _showSnack('쿠폰을 보냈어요! 🎟️');
      } else {
        _showSnack(_buyErrorMsg(body['reason'] as String?));
      }
    } catch (e) {
      _showSnack('오류: $e');
    }
  }

  Future<void> _redeemCoupon(Map<String, dynamic> coupon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(coupon['title'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coupon['description'] != null)
              Text(coupon['description'] as String),
            const SizedBox(height: 8),
            Text('사용하면 되돌릴 수 없어요.',
                style: TextStyle(fontSize: 11, color: kMainMuted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: kMainHoney),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('사용하기',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final token = _auth.token;
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/shop/coupons/redeem'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'coupon_id': coupon['id']}),
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        _showSnack('쿠폰 사용 완료! ✅');
        await _load();
      } else {
        _showSnack('사용 실패');
      }
    } catch (e) {
      _showSnack('오류: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _buyErrorMsg(String? reason) => switch (reason) {
        'insufficient_coins' => '코인이 부족해요',
        'item_not_found' => '아이템을 찾을 수 없어요',
        'gacha_only' => 'S등급 이상은 뽑기로만 획득 가능해요',
        _ => '구매 실패',
      };

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _formatCoins(int n) =>
      n >= 1000
          ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K'
          : '$n';

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('상점',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  _formatCoins(_balance),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kMainHoney,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _gameTabs
              .map((t) => Tab(
                    child: Text(t.$1,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ))
              .toList(),
          labelColor: kMainHoney,
          unselectedLabelColor: kMainMuted,
          indicatorColor: kMainHoney,
          indicatorWeight: 3,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('오류: $_error'))
              : TabBarView(
                  controller: _tabCtrl,
                  children: _gameTabs
                      .map((t) => t.$2 == 'coupon'
                          ? _buildCouponsTab()
                          : _buildItemsTab(t.$2))
                      .toList(),
                ),
    );
  }

  Widget _buildItemsTab(String? gameFilter) {
    final filtered = gameFilter == null
        ? _items.where((i) => i['category'] != 'coupon').toList()
        : _items.where((i) => i['game'] == gameFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text('준비 중이에요', style: TextStyle(color: kMainMuted)),
          ],
        ),
      );
    }

    // Group by grade order
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final grade in _gradeOrder) {
      final gradeItems =
          filtered.where((i) => i['grade'] == grade).toList();
      if (gradeItems.isNotEmpty) grouped[grade] = gradeItems;
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in grouped.entries) ...[
            _GradeHeader(grade: entry.key),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemCount: entry.value.length,
              itemBuilder: (_, idx) {
                final item = entry.value[idx];
                final id = (item['id'] as num).toInt();
                return _ShopItemCard(
                  item: item,
                  owned: _ownedItemIds.contains(id),
                  equipped: _equippedItemIds.contains(id),
                  balance: _balance,
                  formatCoins: _formatCoins,
                  onTap: () => _preview(item),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Issue button
          _IssueCouponButton(onTap: _issueCoupon),
          const SizedBox(height: 16),
          if (_coupons.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎟️', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('받은 쿠폰이 없어요',
                        style: TextStyle(color: kMainMuted)),
                    const SizedBox(height: 4),
                    Text('상대방에게 데이트 쿠폰을 받아봐요!',
                        style: TextStyle(fontSize: 11, color: kMainMuted)),
                  ],
                ),
              ),
            )
          else
            for (final c in _coupons) ...[
              _CouponCard(
                  coupon: c, onRedeem: () => _redeemCoupon(c)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

// ── Grade Header ─────────────────────────────────────────────────────────────

class _GradeHeader extends StatelessWidget {
  final String grade;
  const _GradeHeader({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(grade);
    final label = switch (grade) {
      'B' => 'B등급 · 코인 구매',
      'A' => 'A등급 · 코인 구매',
      'S' => 'S등급 · 뽑기 전용',
      'SS' => 'SS등급 · 뽑기 전용',
      'SSS' => 'SSS등급 · 뽑기 전용',
      _ => grade,
    };

    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
      ],
    );
  }
}

// ── Shop Item Card (Grid) ─────────────────────────────────────────────────────

class _ShopItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool owned;
  final bool equipped;
  final int balance;
  final String Function(int) formatCoins;
  final VoidCallback onTap;

  const _ShopItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.balance,
    required this.formatCoins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final color = _gradeColor(grade);
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final isGachaOnly = ['S', 'SS', 'SSS'].contains(grade);
    final canAfford = balance >= price;
    final stats = (item['stats'] as List? ?? []).cast<Map<String, dynamic>>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: _gradeGradient(grade),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: equipped
                ? color
                : color.withValues(alpha: 0.3),
            width: equipped ? 2.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade badge + owned badge
            Row(
              children: [
                _GradeBadge(grade: grade),
                const Spacer(),
                if (equipped)
                  _StatusBadge(label: '장착 중', color: color)
                else if (owned)
                  _StatusBadge(label: '보유', color: kMainSage),
              ],
            ),
            const SizedBox(height: 10),
            // Icon
            Center(
              child: Text(item['icon'] as String? ?? '📦',
                  style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              item['name'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Stats preview (first one)
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _statLabels[stats[0]['key']] ?? stats[0]['key'],
                style: TextStyle(fontSize: 10, color: kMainSub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            // Price / status
            if (owned)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: equipped ? color : kMainSage),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onTap,
                  child: Text(
                    equipped ? '장착 중' : '장착하기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: equipped ? color : kMainSage,
                    ),
                  ),
                ),
              )
            else if (isGachaOnly)
              Center(
                child: Text('🎰 뽑기 전용',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canAfford ? color : kMainMuted.withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: canAfford ? 2 : 0,
                  ),
                  onPressed: canAfford ? onTap : null,
                  child: Text(
                    '🪙 ${formatCoins(price)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Grade Badge ───────────────────────────────────────────────────────────────

class _GradeBadge extends StatelessWidget {
  final String grade;
  const _GradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ── Item Preview Sheet ────────────────────────────────────────────────────────

class _ItemPreviewSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> stats;
  final bool owned;
  final bool equipped;
  final bool isGachaOnly;
  final int balance;
  final Color gradeColor;
  final LinearGradient gradeGradient;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;
  final String Function(int) formatCoins;

  const _ItemPreviewSheet({
    required this.item,
    required this.stats,
    required this.owned,
    required this.equipped,
    required this.isGachaOnly,
    required this.balance,
    required this.gradeColor,
    required this.gradeGradient,
    required this.onBuy,
    required this.onEquip,
    required this.formatCoins,
  });

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final canAfford = balance >= price;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kMainMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: gradeGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: gradeColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              children: [
                _GradeBadge(grade: grade),
                const SizedBox(height: 16),
                Text(item['icon'] as String? ?? '📦',
                    style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                if (item['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item['description'] as String,
                    style: TextStyle(fontSize: 12, color: kMainSub),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stats list
          if (stats.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('능력치',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kMainSub)),
            ),
            const SizedBox(height: 8),
            for (final s in stats)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statLabels[s['key'] as String] ??
                            s['key'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${s['value']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: gradeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
          // Action button
          SizedBox(
            width: double.infinity,
            child: _actionButton(grade, price, canAfford),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String grade, int price, bool canAfford) {
    if (equipped) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: gradeColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: null,
        child: Text('장착 중',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: gradeColor)),
      );
    }
    if (owned) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kMainSage,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onEquip,
        child: const Text('장착하기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
    }
    if (isGachaOnly) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: gradeColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: null,
        child: Text('🎰 뽑기로만 획득 가능',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: gradeColor)),
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? gradeColor : kMainMuted,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: canAfford ? onBuy : null,
      child: Text(
        canAfford ? '🪙 ${formatCoins(price)} 구매' : '코인 부족',
        style:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Issue Coupon Button ───────────────────────────────────────────────────────

class _IssueCouponButton extends StatelessWidget {
  final VoidCallback onTap;
  const _IssueCouponButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kMainHoneySoft, kMainRoseSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kMainHoney.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('데이트 쿠폰 보내기',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('파트너에게 특별한 약속을 보내요 · 500코인',
                      style: TextStyle(fontSize: 11, color: kMainSub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: kMainHoney),
          ],
        ),
      ),
    );
  }
}

// ── Coupon Card ───────────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;
  final VoidCallback onRedeem;

  const _CouponCard({required this.coupon, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    final expires = coupon['expires_at'] as String?;
    final expiresDate = DateTime.tryParse(expires ?? '')?.toLocal();
    final daysLeft = expiresDate?.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kMainHoneySoft, kMainRoseSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: kMainHoney.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎟️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon['title'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                if (coupon['description'] != null &&
                    (coupon['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(coupon['description'] as String,
                      style:
                          TextStyle(fontSize: 12, color: kMainSub)),
                ],
                if (daysLeft != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    daysLeft > 0 ? '$daysLeft일 후 만료' : '오늘 만료',
                    style: TextStyle(
                        fontSize: 10,
                        color: daysLeft <= 3
                            ? kMainRose
                            : kMainMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMainHoney,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onRedeem,
            child: const Text('사용',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
