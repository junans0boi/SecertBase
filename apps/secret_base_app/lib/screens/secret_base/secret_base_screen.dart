import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/main_design.dart';
import 'base_postcard_screen.dart';

class SecretBaseScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;

  const SecretBaseScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
  });

  @override
  State<SecretBaseScreen> createState() => _SecretBaseScreenState();
}

class _SecretBaseScreenState extends State<SecretBaseScreen> {
  List<Map<String, dynamic>> _milestones = [];
  bool _loading = true;
  final Set<String> _claiming = {};

  static const _milestoneIcons = <String, IconData>{
    'first_moment': Icons.photo_camera_outlined,
    'moments_10': Icons.collections_outlined,
    'moments_50': Icons.auto_awesome_outlined,
    'moments_100': Icons.star_outline_rounded,
    'moments_200': Icons.diamond_outlined,
    'moments_500': Icons.local_fire_department_outlined,
    'moments_1000': Icons.workspace_premium_outlined,
    'first_pin': Icons.place_outlined,
    'pins_5': Icons.map_outlined,
    'first_visit': Icons.travel_explore_outlined,
    'visited_5': Icons.map_outlined,
    'visited_10': Icons.tour_outlined,
    'visited_20': Icons.explore_outlined,
    'first_memory_card': Icons.history_outlined,
    'd100': Icons.favorite_border_rounded,
    'd200': Icons.favorite_rounded,
    'd365': Icons.cake_outlined,
    'd500': Icons.stars_outlined,
    'd730': Icons.celebration_outlined,
    'd1000': Icons.emoji_events_outlined,
    'd1461': Icons.military_tech_outlined,
  };

  static const _milestoneColors = <String, Color>{
    'first_moment': kMainRose,
    'moments_10': kMainRose,
    'moments_50': kMainHoney,
    'moments_100': kMainHoney,
    'moments_200': kMainLilac,
    'moments_500': kMainLilac,
    'moments_1000': kMainLilac,
    'first_pin': kMainSage,
    'pins_5': kMainSage,
    'first_visit': kMainSage,
    'visited_5': kMainSage,
    'visited_10': kMainSage,
    'visited_20': kMainSage,
    'first_memory_card': kMainLilac,
    'd100': kMainRose,
    'd200': kMainRose,
    'd365': kMainRose,
    'd500': kMainRose,
    'd730': kMainRose,
    'd1000': kMainRose,
    'd1461': kMainRose,
  };

  static const _gradeColors = <String, Color>{
    'B': Color(0xFF9E9E9E),
    'A': Color(0xFF66BB6A),
    'S': Color(0xFF42A5F5),
    'SS': Color(0xFFAB47BC),
    'SSS': Color(0xFFFF7043),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/retention/secret-base/milestones'),
        headers: widget.authHeaders,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _milestones = (data['milestones'] as List? ?? [])
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimReward(String type) async {
    if (_claiming.contains(type)) return;
    setState(() => _claiming.add(type));
    try {
      final res = await http.post(
        Uri.parse(
          '${widget.baseUrl}/api/retention/secret-base/milestones/$type/claim',
        ),
        headers: widget.authHeaders,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        final itemName = data['item_name'] as String? ?? '아이템';
        final itemIcon = data['item_icon'] as String? ?? '🎁';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$itemIcon $itemName 획득!'),
            backgroundColor: kMainSage,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _load();
      } else {
        final reason = data['reason'] as String? ?? 'error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_claimErrorMsg(reason)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('네트워크 오류')));
    } finally {
      if (mounted) setState(() => _claiming.remove(type));
    }
  }

  String _claimErrorMsg(String reason) => switch (reason) {
    'already_claimed' => '이미 수령한 보상입니다',
    'not_achieved' => '아직 달성하지 않은 마일스톤입니다',
    _ => '보상 수령에 실패했습니다',
  };

  void _openPostcard() {
    final now = DateTime.now();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BasePostcardScreen(
          baseUrl: widget.baseUrl,
          authHeaders: widget.authHeaders,
          initialYear: now.year,
          initialMonth: now.month,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final achieved = _milestones.where((m) => m['achieved'] == true).length;
    final total = _milestones.length;
    final claimable = _milestones
        .where(
          (m) =>
              m['achieved'] == true &&
              m['claimed'] == false &&
              m['reward'] != null,
        )
        .length;

    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '우리의 비밀기지',
          style: mainBody(size: 17, weight: FontWeight.w900),
        ),
        leading: const BackButton(color: kMainInk),
        actions: [
          if (claimable > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.card_giftcard, color: kMainRose),
                    onPressed: null,
                    tooltip: '받을 보상이 있어요',
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: kMainRose,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$claimable',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: _openPostcard,
            icon: const Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: kMainRose,
            ),
            label: Text(
              '기지 엽서',
              style: mainBody(
                size: 13,
                color: kMainRose,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : RefreshIndicator(
              onRefresh: _load,
              color: kMainRose,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                children: [
                  _headerCard(achieved, total),
                  const SizedBox(height: 24),
                  Text('마일스톤', style: mainTitle(size: 20)),
                  const SizedBox(height: 12),
                  ..._milestones.map((m) => _milestoneRow(m)),
                ],
              ),
            ),
    );
  }

  Widget _headerCard(int achieved, int total) {
    final progress = total == 0 ? 0.0 : achieved / total;
    return MainCard(
      gradient: kRoseGrad,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('비밀기지 달성도', style: mainBody(size: 13, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            '$achieved / $total',
            style: mainTitle(size: 36, color: Colors.white),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}% 달성',
            style: mainBody(size: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _milestoneRow(Map<String, dynamic> m) {
    final type = m['type'] as String? ?? '';
    final label = m['label'] as String? ?? type;
    final achieved = m['achieved'] as bool? ?? false;
    final claimed = m['claimed'] as bool? ?? false;
    final achievedAt = m['achieved_at'] as String?;
    final reward = m['reward'] as Map<String, dynamic>?;
    final icon = _milestoneIcons[type] ?? Icons.emoji_events_outlined;
    final color = _milestoneColors[type] ?? kMainRose;
    final isClaiming = _claiming.contains(type);

    String? dateLabel;
    if (achievedAt != null && achievedAt.length >= 10) {
      final parts = achievedAt.substring(0, 10).split('-');
      if (parts.length == 3) {
        dateLabel = '${parts[0]}년 ${parts[1]}월 ${parts[2]}일';
      }
    }

    final canClaim = achieved && !claimed && reward != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MainCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: achieved
                        ? color.withValues(alpha: 0.12)
                        : kMainPaperSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: achieved ? color : kMainMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: mainBody(
                          size: 14,
                          weight: FontWeight.w700,
                          color: achieved ? kMainInk : kMainMuted,
                        ),
                      ),
                      if (achieved && dateLabel != null)
                        Text(
                          dateLabel,
                          style: mainBody(size: 11, color: kMainMuted),
                        ),
                    ],
                  ),
                ),
                if (claimed)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: kMainSage,
                    size: 22,
                  )
                else if (!achieved)
                  const Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: kMainLine,
                    size: 22,
                  ),
              ],
            ),
            if (reward != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _rewardBadge(reward, achieved, claimed),
                  const Spacer(),
                  if (canClaim)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: isClaiming ? null : () => _claimReward(type),
                        icon: isClaiming
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.card_giftcard, size: 14),
                        label: Text(
                          isClaiming ? '수령 중...' : '받기',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kMainRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    )
                  else if (claimed)
                    Text(
                      '수령 완료',
                      style: mainBody(
                        size: 11,
                        color: kMainSage,
                        weight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rewardBadge(
    Map<String, dynamic> reward,
    bool achieved,
    bool claimed,
  ) {
    final grade = reward['grade'] as String? ?? 'B';
    final icon = reward['icon'] as String? ?? '🎁';
    final name = reward['name'] as String? ?? '보상';
    final gradeColor = _gradeColors[grade] ?? const Color(0xFF9E9E9E);

    return Opacity(
      opacity: achieved ? 1.0 : 0.4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      grade,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: gradeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(name, style: mainBody(size: 11, color: kMainInk)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
