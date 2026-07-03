import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth_service.dart';
import '../../core/main_design.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Premium 구독 화면
// ──────────────────────────────────────────────────────────────────────────────

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with TickerProviderStateMixin {
  final _auth = AuthService();
  bool _loading = true;
  bool _activating = false;
  bool _isPremium = false;
  String? _premiumSince;
  String? _premiumExpiresAt;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _limits;

  // 선택된 플랜: 'monthly' or 'yearly'
  String _selectedPlan = 'monthly';

  late AnimationController _shimmerCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _loadStatus();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  int? get _userId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Future<void> _loadStatus() async {
    final uid = _userId;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final response = await http.get(Uri.parse('${_auth.baseUrl}/api/premium/status?user_id=$uid'));
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['ok'] == true) {
        setState(() {
          _isPremium = data['is_premium'] == true;
          _premiumSince = data['premium_since'];
          _premiumExpiresAt = data['premium_expires_at'];
          _subscription = data['subscription'];
          _limits = data['limits'];
        });
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _activatePremium() async {
    final uid = _userId;
    if (uid == null || _activating) return;

    // 결제 데모 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('결제 확인', style: mainTitle(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택한 플랜:', style: mainBody(size: 12, color: kMainMuted)),
            const SizedBox(height: 6),
            Text(
              _selectedPlan == 'yearly' ? '연간 플랜 — ₩19,000 / 년' : '월간 플랜 — ₩1,900 / 월',
              style: mainBody(size: 16, color: kMainInk, weight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                '⚠️ 현재 데모 모드입니다.\n실제 결제가 이루어지지 않으며\n테스트 목적으로 즉시 활성화됩니다.',
                style: mainBody(size: 12, color: Colors.orange.shade800),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: mainBody(color: kMainMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kMainRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('구독 시작 👑', style: mainBody(color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _activating = true);
    try {
      final response = await http.post(
        Uri.parse('${_auth.baseUrl}/api/premium/activate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': uid,
          'plan': _selectedPlan,
          'payment_key': 'demo_${DateTime.now().millisecondsSinceEpoch}',
          'payment_method': 'card',
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['ok'] == true) {
        await _loadStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Premium 구독이 활성화되었어요! 🎉'),
            backgroundColor: kMainRose,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('구독 활성화에 실패했습니다')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _cancelPremium() async {
    final uid = _userId;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kMainPaper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('구독 취소', style: mainTitle(size: 18)),
        content: Text(
          '구독을 취소해도 현재 구독 기간이 끝날 때까지 Premium 혜택이 유지됩니다.',
          style: mainBody(size: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('유지', style: mainBody(color: kMainMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse('${_auth.baseUrl}/api/premium/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': uid}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? '구독이 취소되었어요')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainPaper,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        title: Text('비밀기지 Premium', style: mainTitle(size: 20)),
        iconTheme: IconThemeData(color: kMainInk),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 상단 히어로 배너
                  AnimatedBuilder(
                    animation: _glowCtrl,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(const Color(0xFFFF6B9D), const Color(0xFFFF8E53), _glowCtrl.value)!,
                            Color.lerp(const Color(0xFFFF8E53), const Color(0xFFFFD700), _glowCtrl.value)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B9D).withValues(alpha: 0.3 + _glowCtrl.value * 0.2),
                            blurRadius: 20 + _glowCtrl.value * 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('👑', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 10),
                          Text(
                            _isPremium ? 'Premium 구독 중' : '더 많은 추억을\n비밀기지에 담아보세요',
                            style: mainTitle(size: 22, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (_isPremium && _premiumExpiresAt != null)
                            Text(
                              '만료일: ${_premiumExpiresAt!.substring(0, 10)}',
                              style: mainBody(size: 13, color: Colors.white.withValues(alpha: 0.85)),
                            )
                          else
                            Text(
                              '소중한 추억을 더 많이, 더 선명하게',
                              style: mainBody(size: 14, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 혜택 비교표
                  Text('무료 vs Premium 혜택 비교', style: mainTitle(size: 17, color: kMainInk)),
                  const SizedBox(height: 12),
                  _BenefitTable(limits: _limits),

                  const SizedBox(height: 28),

                  if (!_isPremium) ...[
                    // ── 플랜 선택
                    Text('플랜 선택', style: mainTitle(size: 17, color: kMainInk)),
                    const SizedBox(height: 12),
                    _PlanCard(
                      title: '월간 플랜',
                      price: '₩1,900',
                      period: '/ 월',
                      badge: null,
                      isSelected: _selectedPlan == 'monthly',
                      onTap: () => setState(() => _selectedPlan = 'monthly'),
                    ),
                    const SizedBox(height: 10),
                    _PlanCard(
                      title: '연간 플랜',
                      price: '₩19,000',
                      period: '/ 년',
                      badge: '17% 할인',
                      isSelected: _selectedPlan == 'yearly',
                      onTap: () => setState(() => _selectedPlan = 'yearly'),
                    ),
                    const SizedBox(height: 24),

                    // ── 구독하기 버튼
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, child) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: kMainRose.withValues(alpha: 0.3 + _glowCtrl.value * 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: FilledButton(
                        onPressed: _activating ? null : _activatePremium,
                        style: FilledButton.styleFrom(
                          backgroundColor: kMainRose,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _activating
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                '👑 구독 시작하기 — ${_selectedPlan == 'yearly' ? '₩19,000/년' : '₩1,900/월'}',
                                style: mainBody(size: 16, color: Colors.white, weight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '언제든지 취소할 수 있으며, 취소해도 기간 내 혜택은 유지됩니다.',
                        style: mainBody(size: 11, color: kMainMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    // ── 구독 중 상태 카드
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('✅', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text('구독 중', style: mainBody(size: 14, color: const Color(0xFFB8860B), weight: FontWeight.bold)),
                          ]),
                          if (_subscription != null) ...[
                            const SizedBox(height: 10),
                            _InfoRow('플랜', _subscription!['plan'] == 'yearly' ? '연간 플랜' : '월간 플랜'),
                            _InfoRow('금액', '₩${_subscription!['amount_krw']}'),
                            if (_premiumSince != null) _InfoRow('시작일', _premiumSince!.substring(0, 10)),
                            if (_premiumExpiresAt != null) _InfoRow('만료일', _premiumExpiresAt!.substring(0, 10)),
                          ],
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: _cancelPremium,
                            child: Text('구독 취소하기', style: mainBody(size: 13, color: Colors.red.shade400)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 혜택 비교 테이블
// ──────────────────────────────────────────────────────────────────────────────

class _BenefitTable extends StatelessWidget {
  final Map<String, dynamic>? limits;
  const _BenefitTable({this.limits});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('앨범 폴더 수', '최대 15개', '최대 100개'),
      ('폴더당 사진 (각자)', '10장', '50장'),
      ('사진 화질', '1080px 압축', '2K 고화질 원본'),
      ('사진 캡션', '✅', '✅'),
      ('마음 대피소', '✅', '✅'),
      ('광고 표시', '있음 (예정)', '없음'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMainRoseSoft),
        boxShadow: [BoxShadow(color: kMainRose.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: kMainRoseSoft,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('기능', style: mainBody(size: 12, color: kMainRose, weight: FontWeight.bold))),
                Expanded(flex: 2, child: Center(child: Text('무료', style: mainBody(size: 12, color: kMainInk)))),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text('👑 Premium', style: mainBody(size: 12, color: kMainRose, weight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              decoration: BoxDecoration(
                color: i.isEven ? Colors.white : kMainPaper.withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(row.$1, style: mainBody(size: 12, color: kMainInk))),
                  Expanded(flex: 2, child: Center(child: Text(row.$2, style: mainBody(size: 12, color: kMainSub), textAlign: TextAlign.center))),
                  Expanded(flex: 2, child: Center(child: Text(row.$3, style: mainBody(size: 12, color: kMainRose, weight: FontWeight.bold), textAlign: TextAlign.center))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 플랜 선택 카드
// ──────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kMainRoseSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kMainRose : kMainRoseSoft,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: kMainRose.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? kMainRose : Colors.transparent,
                border: Border.all(color: isSelected ? kMainRose : kMainMuted, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: mainBody(size: 14, color: kMainInk, weight: FontWeight.bold)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge!, style: mainBody(size: 10, color: Colors.white, weight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: mainBody(size: 18, color: kMainInk, weight: FontWeight.bold).copyWith(color: kMainInk),
                  ),
                  TextSpan(
                    text: period,
                    style: mainBody(size: 12, color: kMainSub).copyWith(color: kMainSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 정보 행 위젯
// ──────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ', style: mainBody(size: 13, color: kMainSub)),
          Text(value, style: mainBody(size: 13, color: kMainInk, weight: FontWeight.bold)),
        ],
      ),
    );
  }
}
