import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/socket_service.dart';

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
  int _balance = 0;
  bool _loading = true;
  String? _error;

  late final TabController _tabCtrl;
  final _tabs = const ['아이템', '내 쿠폰'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
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
    setState(() { _loading = true; _error = null; });
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
      ]);

      final itemsRes = jsonDecode(results[0].body) as Map;
      final walletRes = jsonDecode(results[1].body) as Map;
      final couponsRes = jsonDecode(results[2].body) as Map;

      setState(() {
        _items = (itemsRes['items'] as List? ?? []).cast<Map<String, dynamic>>();
        _balance = (walletRes['balance'] as num?)?.toInt() ?? _balance;
        _coupons = (couponsRes['coupons'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item['name']} 구매'),
        content: Text('${_formatCoins(item['price'] as int)}코인을 사용합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('구매'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

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
        _showSnack('구매 완료! ${item['name']} 획득 🎉');
        if (item['category'] == 'coupon') {
          _tabCtrl.animateTo(1);
          await _load();
        }
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
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
            Text('사용하면 되돌릴 수 없어요.',
                style: TextStyle(fontSize: 11, color: kMainMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
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

  String _buyErrorMsg(String? reason) => switch (reason) {
        'insufficient_coins' => '코인이 부족해요',
        'item_not_found' => '아이템을 찾을 수 없어요',
        'no_couple' => '커플 연결이 필요해요',
        _ => '구매 실패',
      };

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _formatCoins(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('상점', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          labelColor: kMainHoney,
          unselectedLabelColor: kMainMuted,
          indicatorColor: kMainHoney,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('오류: $_error'))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildItemsTab(),
                    _buildCouponsTab(),
                  ],
                ),
    );
  }

  Widget _buildItemsTab() {
    final categories = ['coupon', 'booster', 'skin', 'gacha'];
    final categoryLabels = {
      'coupon': '🎟️ 데이트 쿠폰',
      'booster': '⚡ 부스터',
      'skin': '✨ 스킨',
      'gacha': '🎰 뽑기',
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final cat in categories) ...[
            if (_items.any((i) => i['category'] == cat)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  categoryLabels[cat] ?? cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kMainSub,
                  ),
                ),
              ),
              for (final item in _items.where((i) => i['category'] == cat))
                _ShopItemCard(
                  item: item,
                  balance: _balance,
                  onBuy: cat == 'coupon' ? _issueCoupon : () => _buy(item),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCouponsTab() {
    if (_coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text('받은 쿠폰이 없어요', style: TextStyle(color: kMainMuted)),
            const SizedBox(height: 4),
            Text('상대방에게 데이트 쿠폰을 받아봐요!',
                style: TextStyle(fontSize: 11, color: kMainMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _coupons.length,
        separatorBuilder: (_, idx) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _CouponCard(
          coupon: _coupons[i],
          onRedeem: () => _redeemCoupon(_coupons[i]),
        ),
      ),
    );
  }
}

// ── Item Card ────────────────────────────────────────────────────────────────

class _ShopItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int balance;
  final VoidCallback onBuy;

  const _ShopItemCard({
    required this.item,
    required this.balance,
    required this.onBuy,
  });

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    final price = (item['price'] as num).toInt();
    final canAfford = balance >= price;

    return MainCard(
      child: Row(
        children: [
          Text(item['icon'] as String? ?? '📦',
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (item['description'] != null) ...[
                  const SizedBox(height: 2),
                  Text(item['description'] as String,
                      style: TextStyle(fontSize: 11, color: kMainMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canAfford ? kMainHoney : kMainMuted.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: canAfford ? onBuy : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 12)),
                Text(_fmt(price),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
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
        border: Border.all(
          color: kMainHoney.withValues(alpha: 0.35),
        ),
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
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (coupon['description'] != null &&
                    (coupon['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(coupon['description'] as String,
                      style: TextStyle(fontSize: 12, color: kMainSub)),
                ],
                if (daysLeft != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    daysLeft > 0
                        ? '$daysLeft일 후 만료'
                        : '오늘 만료',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onRedeem,
            child: const Text('사용',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
