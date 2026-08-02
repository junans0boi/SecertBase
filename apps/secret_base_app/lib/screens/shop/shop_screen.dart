import 'dart:convert';
import 'dart:math' show pi, cos, sin;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';
import 'inventory_tab.dart';

// ── Grade helpers ─────────────────────────────────────────────────────────────

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

const _statLabels = statLabels;

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
  List<Map<String, dynamic>> _missions = [];
  Set<int> _ownedItemIds = {};
  Set<int> _equippedItemIds = {};
  int _balance = 0;
  int _tickets = 0;
  int _userLevel = 1;
  int _userXp = 0;
  int _xpNeeded = 100;
  bool _loading = true;
  String? _error;

  late final TabController _tabCtrl;

  static const _mainTabs = [
    ('상점', 'shop'),
    ('인벤토리', 'inventory'),
    ('미션', 'mission'),
    ('데이트쿠폰', 'coupon'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: _mainTabs.length,
      vsync: this,
      initialIndex: 0,
    );

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
        http.get(Uri.parse('$base/api/user/level'), headers: headers),
        http.get(Uri.parse('$base/api/missions'), headers: headers),
      ]);

      final itemsRes = jsonDecode(results[0].body) as Map;
      final walletRes = jsonDecode(results[1].body) as Map;
      final couponsRes = jsonDecode(results[2].body) as Map;
      final ownedRes = jsonDecode(results[3].body) as Map;
      final equippedRes = jsonDecode(results[4].body) as Map;
      final levelRes = jsonDecode(results[5].body) as Map;
      final missionsRes = jsonDecode(results[6].body) as Map;

      final ownedList = (ownedRes['owned'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final equippedSlots = (equippedRes['slots'] as Map? ?? {}).values
          .toList();

      setState(() {
        _items = (itemsRes['items'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _balance = (walletRes['balance'] as num?)?.toInt() ?? _balance;
        _coupons = (couponsRes['coupons'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _ownedItemIds = ownedList
            .map((o) => (o['item_id'] as num).toInt())
            .toSet();
        _equippedItemIds = equippedSlots
            .map((s) => (s['item_id'] as num).toInt())
            .toSet();
        if (levelRes['ok'] == true) {
          _userLevel = (levelRes['level'] as num?)?.toInt() ?? 1;
          _userXp = (levelRes['xp'] as num?)?.toInt() ?? 0;
          _xpNeeded = (levelRes['xpNeeded'] as num?)?.toInt() ?? 100;
          _tickets = (levelRes['tickets'] as num?)?.toInt() ?? 0;
        }
        _missions = (missionsRes['missions'] as List? ?? [])
            .cast<Map<String, dynamic>>();
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
        onBuy: isGachaOnly || owned
            ? null
            : () {
                Navigator.pop(ctx);
                _buy(item);
              },
        onEquip: null,
        onGacha: null,
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
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('보내기'),
          ),
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
            Text(
              '사용하면 되돌릴 수 없어요.',
              style: TextStyle(fontSize: 11, color: kMainMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kMainHoney),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('사용하기', style: TextStyle(color: Colors.white)),
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

  // ── Gacha ────────────────────────────────────────────────────────────────────

  Color _tierColor(String tier) => switch (tier) {
    'advanced' => kMainSky,
    'rare' => kMainLilac,
    _ => kMainSage,
  };

  Future<void> _gacha(String game, String tier) async {
    final cost = switch (tier) {
      'advanced' => 45000,
      'rare' => 100000,
      _ => 3000,
    };
    if (_balance < cost) {
      _showSnack('코인이 부족해요 (필요: ${_formatCoins(cost)})');
      return;
    }
    final tierName = switch (tier) {
      'advanced' => '고급 뽑기',
      'rare' => '레어 뽑기',
      _ => '일반 뽑기',
    };
    final gameName = game == 'yut' ? '윷놀이' : '원카드';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(
          '$gameName $tierName',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '🪙 ${_formatCoins(cost)} 코인을 소모합니다.',
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
            child: const Text('뽑기!', style: TextStyle(color: Colors.white)),
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
        final isNew = body['is_new'] as bool? ?? true;
        setState(
          () => _balance = (body['new_balance'] as num?)?.toInt() ?? _balance,
        );
        await Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, a, b) =>
                _GachaResultOverlay(item: item, isNew: isNew),
          ),
        );
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

  String _formatCoins(int n) => n >= 1000
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
        title: const Text(
          '상점',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                if (_tickets > 0) ...[
                  Text('🎫', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 2),
                  Text(
                    'x$_tickets',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kMainLilac,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kMainSky.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv.$_userLevel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kMainSky,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _xpNeeded > 0 ? _userXp / _xpNeeded : 0,
                          minHeight: 6,
                          backgroundColor: kMainMuted.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(kMainSky),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_userXp / $_xpNeeded XP',
                      style: TextStyle(
                        fontSize: 10,
                        color: kMainMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                tabs: _mainTabs
                    .map(
                      (t) => Tab(
                        child: Text(
                          t.$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                labelColor: kMainHoney,
                unselectedLabelColor: kMainMuted,
                indicatorColor: kMainHoney,
                indicatorWeight: 3,
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('오류: $_error'))
          : TabBarView(
              controller: _tabCtrl,
              children: _mainTabs.map((t) {
                if (t.$2 == 'coupon') return _buildCouponsTab();
                if (t.$2 == 'mission') return _buildMissionsTab();
                if (t.$2 == 'inventory') {
                  return InventoryTab(onBalanceChanged: _load);
                }
                return _buildShopTab(); // 상점 탭
              }).toList(),
            ),
    );
  }

  Widget _buildShopTab() {
    final yutItems = _items.where((i) => i['game'] == 'yut').toList();
    final onecardItems = _items.where((i) => i['game'] == 'onecard').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
        children: [
          _GameSection(
            title: '윷놀이',
            icon: '🎲',
            game: 'yut',
            items: yutItems,
            ownedIds: _ownedItemIds,
            equippedIds: _equippedItemIds,
            balance: _balance,
            formatCoins: _formatCoins,
            onItemTap: _preview,
            onGacha: _gacha,
            tierColor: _tierColor,
          ),
          const SizedBox(height: 8),
          _GameSection(
            title: '원카드',
            icon: '🃏',
            game: 'onecard',
            items: onecardItems,
            ownedIds: _ownedItemIds,
            equippedIds: _equippedItemIds,
            balance: _balance,
            formatCoins: _formatCoins,
            onItemTap: _preview,
            onGacha: _gacha,
            tierColor: _tierColor,
          ),
        ],
      ),
    );
  }

  Future<void> _claimMission(int missionId) async {
    try {
      final token = _auth.token;
      final base = _socket.serverUrl ?? '';
      final res = await http.post(
        Uri.parse('$base/api/missions/$missionId/claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        final coins = (body['coins'] as num?)?.toInt() ?? 0;
        final tickets = (body['tickets'] as num?)?.toInt() ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '수령 완료! 🪙 +$coins${tickets > 0 ? '  🎫 +$tickets' : ''}',
              ),
              backgroundColor: kMainSage,
            ),
          );
        }
        _load();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류: ${body['reason'] ?? '알 수 없음'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Widget _buildMissionsTab() {
    final weekly = _missions.where((m) => m['type'] == 'weekly').toList();
    final achievements = _missions
        .where((m) => m['type'] == 'achievement')
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (weekly.isNotEmpty) ...[
            _MissionSectionHeader(title: '주간 미션', icon: '📅'),
            const SizedBox(height: 8),
            ...weekly.map(
              (m) => _MissionCard(
                mission: m,
                onClaim: () => _claimMission(m['id'] as int),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (achievements.isNotEmpty) ...[
            _MissionSectionHeader(title: '달성 미션', icon: '🏆'),
            const SizedBox(height: 8),
            ...achievements.map(
              (m) => _MissionCard(
                mission: m,
                onClaim: () => _claimMission(m['id'] as int),
              ),
            ),
          ],
          if (_missions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  '미션을 불러오는 중...',
                  style: TextStyle(color: kMainMuted),
                ),
              ),
            ),
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
                    Text('받은 쿠폰이 없어요', style: TextStyle(color: kMainMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '상대방에게 데이트 쿠폰을 받아봐요!',
                      style: TextStyle(fontSize: 11, color: kMainMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final c in _coupons) ...[
              _CouponCard(coupon: c, onRedeem: () => _redeemCoupon(c)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

// ── Mission Widgets ───────────────────────────────────────────────────────────

class _MissionSectionHeader extends StatelessWidget {
  final String title;
  final String icon;
  const _MissionSectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: kMainHoney,
          ),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Map<String, dynamic> mission;
  final VoidCallback onClaim;
  const _MissionCard({required this.mission, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final progress = (mission['progress'] as num?)?.toInt() ?? 0;
    final target = (mission['targetCount'] as num?)?.toInt() ?? 1;
    final completed = mission['completed'] == true;
    final claimed = mission['claimed'] == true;
    final coins = (mission['rewardCoins'] as num?)?.toInt() ?? 0;
    final tickets = (mission['rewardTickets'] as num?)?.toInt() ?? 0;
    final xp = (mission['rewardXp'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: claimed
              ? kMainMuted.withValues(alpha: 0.2)
              : completed
              ? kMainSage.withValues(alpha: 0.6)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission['title'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: claimed ? kMainMuted : Colors.white,
                  ),
                ),
              ),
              if (!claimed)
                _MissionClaimButton(completed: completed, onClaim: onClaim),
              if (claimed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kMainMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '수령 완료',
                    style: TextStyle(fontSize: 11, color: kMainMuted),
                  ),
                ),
            ],
          ),
          if (mission['description'] != null &&
              (mission['description'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              mission['description'] as String,
              style: TextStyle(fontSize: 11, color: kMainMuted),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: target > 0 ? (progress / target).clamp(0.0, 1.0) : 0,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                completed ? kMainSage : kMainSky,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$progress / $target',
                style: TextStyle(
                  fontSize: 11,
                  color: kMainMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (coins > 0) _RewardTag(label: '🪙 +$coins'),
              if (tickets > 0) ...[
                const SizedBox(width: 4),
                _RewardTag(label: '🎫 +$tickets', color: kMainLilac),
              ],
              if (xp > 0) ...[
                const SizedBox(width: 4),
                _RewardTag(label: '⭐ +$xp XP', color: kMainSky),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MissionClaimButton extends StatelessWidget {
  final bool completed;
  final VoidCallback onClaim;
  const _MissionClaimButton({required this.completed, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: completed ? onClaim : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: completed
              ? kMainSage.withValues(alpha: 0.9)
              : kMainMuted.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '수령',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: completed ? Colors.black87 : kMainMuted,
          ),
        ),
      ),
    );
  }
}

class _RewardTag extends StatelessWidget {
  final String label;
  final Color? color;
  const _RewardTag({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? kMainHoney).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color ?? kMainHoney,
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
          letterSpacing: 0.5,
        ),
      ),
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
  final VoidCallback? onGacha;
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
    this.onGacha,
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
                color: gradeColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                _GradeBadge(grade: grade),
                const SizedBox(height: 16),
                Text(
                  item['icon'] as String? ?? '📦',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 12),
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
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
              child: Text(
                '능력치',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kMainSub,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final s in stats)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statLabels[s['key'] as String] ?? s['key'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
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
        child: Text(
          '장착 중',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: gradeColor,
          ),
        ),
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
        child: const Text(
          '장착하기',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (isGachaOnly) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: gradeColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onGacha,
        child: const Text(
          '🎰 가챠 뽑기!',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
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
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                  const Text(
                    '데이트 쿠폰 보내기',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    '파트너에게 특별한 약속을 보내요 · 500코인',
                    style: TextStyle(fontSize: 11, color: kMainSub),
                  ),
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
        border: Border.all(color: kMainHoney.withValues(alpha: 0.35)),
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
                Text(
                  coupon['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (coupon['description'] != null &&
                    (coupon['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    coupon['description'] as String,
                    style: TextStyle(fontSize: 12, color: kMainSub),
                  ),
                ],
                if (daysLeft != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    daysLeft > 0 ? '$daysLeft일 후 만료' : '오늘 만료',
                    style: TextStyle(
                      fontSize: 10,
                      color: daysLeft <= 3 ? kMainRose : kMainMuted,
                    ),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onRedeem,
            child: const Text(
              '사용',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Game Section (상점 섹션: 가로 스크롤 아이템 + 뽑기) ───────────────────────

class _GameSection extends StatelessWidget {
  final String title, icon, game;
  final List<Map<String, dynamic>> items;
  final Set<int> ownedIds, equippedIds;
  final int balance;
  final String Function(int) formatCoins;
  final void Function(Map<String, dynamic>) onItemTap;
  final Future<void> Function(String, String) onGacha;
  final Color Function(String) tierColor;

  const _GameSection({
    required this.title,
    required this.icon,
    required this.game,
    required this.items,
    required this.ownedIds,
    required this.equippedIds,
    required this.balance,
    required this.formatCoins,
    required this.onItemTap,
    required this.onGacha,
    required this.tierColor,
  });

  static const _slotOrder = {
    'yut_yut': 0,
    'yut_piece': 1,
    'onecard_cardback': 2,
  };
  static const _slotLabels = {
    'yut_yut': '🎲 윷',
    'yut_piece': '♟️ 말',
    'onecard_cardback': '🃏 카드백',
  };

  @override
  Widget build(BuildContext context) {
    final tiers = [
      ('normal', '일반', 'B~S', 3000),
      ('advanced', '고급', 'S~SS', 45000),
      ('rare', '레어', 'SS~SSS', 100000),
    ];

    // 슬롯별로 그루핑
    final slotMap = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final slot = item['slot'] as String? ?? '';
      (slotMap[slot] ??= []).add(item);
    }
    final slots = slotMap.keys.toList()
      ..sort((a, b) => (_slotOrder[a] ?? 99).compareTo(_slotOrder[b] ?? 99));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length}종',
                style: TextStyle(fontSize: 11, color: kMainMuted),
              ),
            ],
          ),
        ),
        // 슬롯별 가로 스크롤
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '준비 중',
                style: TextStyle(color: kMainMuted, fontSize: 12),
              ),
            ),
          )
        else
          for (final slot in slots) ...[
            if (slots.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  _slotLabels[slot] ?? slot,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kMainMuted,
                  ),
                ),
              ),
            SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: slotMap[slot]!.length,
                itemBuilder: (_, i) {
                  final item = slotMap[slot]![i];
                  final id = (item['id'] as num).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _HorizItemCard(
                      item: item,
                      owned: ownedIds.contains(id),
                      equipped: equippedIds.contains(id),
                      onTap: () => onItemTap(item),
                    ),
                  );
                },
              ),
            ),
            if (slot != slots.last) const SizedBox(height: 10),
          ],
        const SizedBox(height: 12),
        // 뽑기 서브섹션
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '$title 뽑기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kMainMuted,
                ),
              ),
              const SizedBox(width: 4),
              const Text('🎰', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              for (final (tier, label, range, cost) in tiers) ...[
                Expanded(
                  child: _GachaTierCard(
                    label: label,
                    range: range,
                    cost: cost,
                    tier: tier,
                    canAfford: balance >= cost,
                    formatCoins: formatCoins,
                    tierColor: tierColor,
                    onTap: () => onGacha(game, tier),
                  ),
                ),
                if (tier != 'rare') const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 24),
        ),
      ],
    );
  }
}

// ── Horizontal Item Card ──────────────────────────────────────────────────────

class _HorizItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool owned, equipped;
  final VoidCallback onTap;

  const _HorizItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grade = item['grade'] as String? ?? 'B';
    final gc = _gradeColor(grade);
    final isGachaOnly = ['S', 'SS', 'SSS'].contains(grade);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: equipped ? gc : gc.withValues(alpha: 0.3),
            width: equipped ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GradeBadge(grade: grade),
                const Spacer(),
                if (equipped)
                  Icon(Icons.check_circle, size: 11, color: gc)
                else if (owned)
                  Icon(Icons.inventory_2_outlined, size: 11, color: kMainSage),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                item['icon'] as String? ?? '📦',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['name'] as String? ?? '',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isGachaOnly) ...[
              const SizedBox(height: 2),
              Text('🎰 뽑기전용', style: TextStyle(fontSize: 8, color: gc)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Gacha Tier Card ───────────────────────────────────────────────────────────

class _GachaTierCard extends StatelessWidget {
  final String label, range, tier;
  final int cost;
  final bool canAfford;
  final String Function(int) formatCoins;
  final Color Function(String) tierColor;
  final VoidCallback onTap;

  const _GachaTierCard({
    required this.label,
    required this.range,
    required this.cost,
    required this.tier,
    required this.canAfford,
    required this.formatCoins,
    required this.tierColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gc = tierColor(tier);
    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: canAfford
              ? gc.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: canAfford ? gc.withValues(alpha: 0.4) : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: canAfford ? gc : kMainMuted,
              ),
            ),
            const SizedBox(height: 1),
            Text(range, style: TextStyle(fontSize: 9, color: kMainMuted)),
            const SizedBox(height: 4),
            Text(
              '🪙${formatCoins(cost)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: canAfford ? kMainHoney : kMainMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gacha Result Overlay (플립 카드 애니메이션) ───────────────────────────────

class _GachaResultOverlay extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isNew;
  const _GachaResultOverlay({required this.item, required this.isNew});

  @override
  State<_GachaResultOverlay> createState() => _GachaResultOverlayState();
}

class _GachaResultOverlayState extends State<_GachaResultOverlay>
    with TickerProviderStateMixin {
  // Phase 1: accelerating spin (easeIn – slow start, fast end)
  late final AnimationController _spinCtrl;
  late final Animation<double> _spinAnim;
  // Phase 2: snap reveal (easeOut – fast start, decelerates to stop)
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  late final Animation<double> _scaleAnim;
  // Effects
  late final AnimationController _flashCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _idleCtrl;
  late final int _spinRotations;
  bool _flashTriggered = false;

  @override
  void initState() {
    super.initState();
    final grade = widget.item['grade'] as String? ?? 'B';

    _spinRotations = switch (grade) {
      'SSS' => 6,
      'SS' => 5,
      'S' => 4,
      _ => 3,
    };
    final spinMs = switch (grade) {
      'SSS' => 2000,
      'SS' => 1700,
      'S' => 1450,
      _ => 1200,
    };
    final flipMs = switch (grade) {
      'SSS' => 480,
      'SS' => 420,
      'S' => 370,
      _ => 330,
    };

    _spinCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: spinMs),
    );
    _flipCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: flipMs),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // easeIn: card slowly starts spinning, accelerates to peak velocity
    _spinAnim = CurvedAnimation(parent: _spinCtrl, curve: Curves.easeIn);
    // easeOut: snaps in fast (matching spin exit speed), decelerates to stop
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeOut);
    // elasticOut scale pop starting from the reveal midpoint
    _scaleAnim = CurvedAnimation(
      parent: _flipCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
    );

    // Flash + burst trigger exactly at reveal midpoint
    _flipCtrl.addListener(() {
      if (!_flashTriggered && _flipCtrl.value >= 0.5) {
        _flashTriggered = true;
        _flashCtrl.forward();
        _burstCtrl.forward();
      }
    });

    // Chain: spin → snap flip → idle glow
    _spinCtrl.forward().then((_) {
      _flipCtrl.forward().then((_) {
        if (['A', 'S', 'SS', 'SSS'].contains(grade)) {
          _idleCtrl.repeat(reverse: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _flipCtrl.dispose();
    _flashCtrl.dispose();
    _burstCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.item['grade'] as String? ?? 'B';
    final gc = _gradeColor(grade);
    final icon = widget.item['icon'] as String? ?? '✨';
    final name = widget.item['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _spinCtrl,
          _flipCtrl,
          _flashCtrl,
          _burstCtrl,
          _idleCtrl,
        ]),
        builder: (ctx, _) {
          final flash = _flashCtrl.value;
          final burst = _burstCtrl.value;
          final idle = _idleCtrl.value;
          final spinDone = _spinCtrl.status == AnimationStatus.completed;
          // Phase 1: spin angle (0 → rotations×2π, easeIn)
          final spinAngle = _spinAnim.value * _spinRotations * 2 * pi;
          // Phase 2: reveal angle (0 → π, easeOut)
          final flipAngle = _flipAnim.value * pi;
          final isRevealed = spinDone && _flipCtrl.value >= 0.5;

          // Flash: peaks at t=0.3, gone by t=0.85
          final rawFlash = flash < 0.3 ? flash / 0.3 : (1.0 - flash) / 0.7;
          final flashPeak = switch (grade) {
            'SSS' => 0.92,
            'SS' => 0.80,
            'S' => 0.65,
            'A' => 0.40,
            _ => 0.18,
          };

          return Stack(
            children: [
              // Effect layer
              CustomPaint(
                painter: _EffectPainter(
                  grade: grade,
                  color: gc,
                  burstT: burst,
                  idleT: idle,
                ),
                child: const SizedBox.expand(),
              ),

              // Card (spin phase → flip phase)
              Center(
                child: GestureDetector(
                  onTap: isRevealed ? () => Navigator.of(context).pop() : null,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(spinDone ? flipAngle : spinAngle),
                    child: spinDone
                        // Flip phase: switch face at midpoint
                        ? (isRevealed
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(pi),
                                  child: ScaleTransition(
                                    scale: _scaleAnim,
                                    child: _buildRevealCard(
                                      grade,
                                      gc,
                                      icon,
                                      name,
                                      idle,
                                    ),
                                  ),
                                )
                              : _buildHiddenCard(gc, _flipCtrl.value))
                        // Spin phase: always show hidden card (full glow)
                        : _buildHiddenCard(gc, 1.0),
                  ),
                ),
              ),

              // White flash
              if (isRevealed && flash > 0)
                IgnorePointer(
                  child: Container(
                    color: Colors.white.withValues(
                      alpha: (rawFlash.clamp(0.0, 1.0) * flashPeak),
                    ),
                  ),
                ),

              // Tap hint
              if (isRevealed && burst > 0.65)
                Positioned(
                  bottom: 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: ((burst - 0.65) / 0.2).clamp(0.0, 0.6),
                      child: const Text(
                        '탭하여 닫기',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHiddenCard(Color gc, double flipProgress) {
    return Container(
      width: 220,
      height: 300,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12121E), Color(0xFF1A1A30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gc.withValues(alpha: 0.3 + flipProgress * 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gc.withValues(alpha: flipProgress * 0.45),
            blurRadius: 20 + flipProgress * 24,
            spreadRadius: flipProgress * 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 80,
            color: Colors.white.withValues(alpha: 0.15 + flipProgress * 0.25),
          ),
        ),
      ),
    );
  }

  Widget _buildRevealCard(
    String grade,
    Color gc,
    String icon,
    String name,
    double idle,
  ) {
    final glowRadius = switch (grade) {
      'SSS' => 42.0 + idle * 22,
      'SS' => 30.0 + idle * 16,
      'S' => 22.0 + idle * 10,
      'A' => 16.0 + idle * 6,
      _ => 16.0,
    };
    final spread = switch (grade) {
      'SSS' => 5.0 + idle * 5,
      'SS' => 3.0 + idle * 3,
      'S' => 2.0 + idle * 2,
      _ => 2.0,
    };
    // SSS: rainbow border color
    final borderColor = (grade == 'SSS')
        ? HSVColor.fromAHSV(1.0, idle * 360, 0.85, 1.0).toColor()
        : gc;

    return Container(
      width: 220,
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gc.withValues(alpha: 0.65),
            gc.withValues(alpha: 0.28),
            const Color(0xFF12121E),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.85),
          width: grade == 'SSS' ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gc.withValues(alpha: 0.55 + idle * 0.15),
            blurRadius: glowRadius,
            spreadRadius: spread,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gc.withValues(alpha: 0.6)),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: grade == 'SSS' ? 22 : 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: ['S', 'SS', 'SSS'].contains(grade)
                    ? [Shadow(color: gc, blurRadius: 10)]
                    : null,
              ),
            ),
          ),
          if (!widget.isNew) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '코인으로 교환 +500',
                style: TextStyle(fontSize: 11, color: Colors.amber),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _EffectPainter ────────────────────────────────────────────────────────────

class _EffectPainter extends CustomPainter {
  final String grade;
  final Color color;
  final double burstT; // 0→1 one-shot
  final double idleT; // 0→1 repeating

  const _EffectPainter({
    required this.grade,
    required this.color,
    required this.burstT,
    required this.idleT,
  });

  static int _pCount(String g) => switch (g) {
    'SSS' => 48,
    'SS' => 32,
    'S' => 24,
    'A' => 16,
    _ => 10,
  };
  static int _beamCount(String g) => switch (g) {
    'SSS' => 16,
    'SS' => 12,
    'S' => 8,
    _ => 0,
  };
  static int _ringCount(String g) => switch (g) {
    'SSS' => 3,
    'SS' => 2,
    'S' => 1,
    'A' => 1,
    _ => 0,
  };
  static double _speed(String g) => switch (g) {
    'SSS' => 330,
    'SS' => 280,
    'S' => 240,
    'A' => 190,
    _ => 150,
  };

  Color _hueColor(double hue, double alpha) =>
      HSVColor.fromAHSV(alpha.clamp(0.0, 1.0), hue % 360, 0.85, 1.0).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    if (burstT <= 0 && idleT <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint();

    // 1. Background radial glow (A+, idle-driven)
    if (['A', 'S', 'SS', 'SSS'].contains(grade) && idleT > 0) {
      final a = (0.12 + idleT * 0.14).clamp(0.0, 1.0);
      paint
        ..style = PaintingStyle.fill
        ..shader =
            RadialGradient(
              colors: [
                color.withValues(alpha: a),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx, cy),
                radius: size.width * 0.75,
              ),
            );
      canvas.drawCircle(Offset(cx, cy), size.width * 0.75, paint);
      paint.shader = null;
    }

    // 2. Rotating light beams (S+, idle-driven)
    final beams = _beamCount(grade);
    if (beams > 0 && idleT > 0) {
      final beamLen = size.width * 0.62;
      final rot = idleT * pi * 0.5; // 90° over cycle
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = grade == 'SSS' ? 2.5 : 1.8;
      for (int i = 0; i < beams; i++) {
        final a = (2 * pi * i / beams) + rot;
        final beamAlpha = (0.28 + idleT * 0.32).clamp(0.0, 1.0);
        paint.color = (grade == 'SSS')
            ? _hueColor((i / beams * 360 + idleT * 200) % 360, beamAlpha)
            : color.withValues(alpha: beamAlpha);
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(a) * beamLen, cy + sin(a) * beamLen),
          paint,
        );
      }
    }

    // 3. Burst particles (all, burstT-driven)
    if (burstT > 0) {
      final pCount = _pCount(grade);
      final spd = _speed(grade);
      paint.style = PaintingStyle.fill;

      for (int i = 0; i < pCount; i++) {
        final a = 2 * pi * i / pCount;
        final speedMult = 0.7 + (i % 3) * 0.3;
        final t = burstT;
        final dx = cx + cos(a) * spd * speedMult * t * (1 - t * 0.35);
        final dy = cy + sin(a) * spd * speedMult * t * (1 - t * 0.35);
        final alpha = (1.0 - t * 1.05).clamp(0.0, 1.0);
        final radius = (9 * (1 + (i % 4) * 0.15) - t * 6).clamp(1.5, 12.0);

        paint.color = (grade == 'SSS')
            ? _hueColor((i / pCount * 360 + burstT * 80) % 360, alpha)
            : color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(dx, dy), radius, paint);
      }

      // Secondary white sparkles (S+)
      if (['S', 'SS', 'SSS'].contains(grade)) {
        final sCount = 38;
        final t2 = (burstT * 1.15).clamp(0.0, 1.0);
        for (int i = 0; i < sCount; i++) {
          final a = 2 * pi * i / sCount + 0.08;
          final dx = cx + cos(a) * spd * 1.5 * t2 * (1 - t2 * 0.5);
          final dy = cy + sin(a) * spd * 1.5 * t2 * (1 - t2 * 0.5);
          final alpha = (1.0 - t2 * 1.2).clamp(0.0, 1.0);
          paint.color = Colors.white.withValues(alpha: alpha * 0.7);
          canvas.drawCircle(Offset(dx, dy), 3, paint);
        }
      }
    }

    // 4. Expanding rings (A+, burstT-driven)
    final rings = _ringCount(grade);
    if (rings > 0 && burstT > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      for (int r = 0; r < rings; r++) {
        final delay = r * 0.18;
        final t = (burstT - delay).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final ringR = size.width * 0.28 * t + r * 35;
        final ringA = (1.0 - t).clamp(0.0, 1.0) * 0.85;
        paint.color = (grade == 'SSS')
            ? _hueColor((r * 120.0 + idleT * 360) % 360, ringA)
            : color.withValues(alpha: ringA);
        canvas.drawCircle(Offset(cx, cy), ringR, paint);
      }
    }

    // 5. Orbiting sparkles (S+, idle-driven)
    if (['S', 'SS', 'SSS'].contains(grade) && idleT > 0) {
      final sparkCount = switch (grade) {
        'SSS' => 12,
        'SS' => 8,
        _ => 5,
      };
      final orbitR = 165.0;
      paint.style = PaintingStyle.fill;
      for (int i = 0; i < sparkCount; i++) {
        final a = 2 * pi * i / sparkCount + idleT * pi;
        final dx = cx + cos(a) * orbitR;
        final dy = cy + sin(a) * orbitR;
        final sparkAlpha = (0.35 + idleT * 0.45).clamp(0.0, 1.0);
        paint.color = (grade == 'SSS')
            ? _hueColor((i / sparkCount * 360 + idleT * 270) % 360, sparkAlpha)
            : Colors.white.withValues(alpha: sparkAlpha);
        canvas.drawCircle(Offset(dx, dy), 4.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EffectPainter old) =>
      old.burstT != burstT || old.idleT != idleT || old.color != color;
}
