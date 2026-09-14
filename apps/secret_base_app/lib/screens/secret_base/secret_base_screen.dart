import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/main_design.dart';
import '../archive/moment_loop_screen.dart';
import 'base_postcard_screen.dart';

class SecretBaseScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;
  final http.Client? client;

  const SecretBaseScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
    this.client,
  });

  @override
  State<SecretBaseScreen> createState() => _SecretBaseScreenState();
}

class _SecretBaseScreenState extends State<SecretBaseScreen> {
  List<Map<String, dynamic>> _milestones = [];
  bool _loading = true;
  String? _loadError;
  final Set<String> _claiming = {};
  late final http.Client _client;
  late final bool _ownsClient;

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
    _ownsClient = widget.client == null;
    _client = widget.client ?? http.Client();
    _load();
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    String? reason;
    try {
      final res = await _client.get(
        Uri.parse('${widget.baseUrl}/api/retention/secret-base/milestones'),
        headers: widget.authHeaders,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      reason = data['reason'] as String?;
      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
        throw const FormatException();
      }
      final rawMilestones = data['milestones'];
      if (rawMilestones is! List) throw const FormatException();
      setState(() {
        _milestones = rawMilestones
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = _loadErrorMessage(reason));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _loadErrorMessage(String? reason) => switch (reason) {
    'active_couple_required' => '활성 커플을 연결하면 둘만의 비밀기지를 볼 수 있어요.',
    _ => '비밀기지를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
  };

  Future<void> _claimReward(String type) async {
    if (_claiming.contains(type)) return;
    setState(() => _claiming.add(type));
    try {
      final res = await _client.post(
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
      ).showSnackBar(const SnackBar(content: Text('보상을 받지 못했어요. 다시 시도해 주세요.')));
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

  void _openMomentLoop() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MomentLoopScreen()));
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
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '보상 $claimable개',
                  style: mainBody(
                    size: 12,
                    color: kMainRose,
                    weight: FontWeight.w800,
                  ),
                ),
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
      body: _loading && _milestones.isEmpty
          ? _loadingState()
          : _loadError != null && _milestones.isEmpty
          ? _errorState()
          : RefreshIndicator(
              onRefresh: _load,
              color: kMainRose,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                children: [
                  _scopeCard(),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(color: kMainRose),
                  ],
                  if (_loadError != null) ...[
                    const SizedBox(height: 12),
                    _inlineError(),
                  ],
                  const SizedBox(height: 20),
                  if (_milestones.isEmpty)
                    _emptyState()
                  else ...[
                    _headerCard(achieved, total),
                    const SizedBox(height: 24),
                    Text('함께 쌓은 기록', style: mainTitle(size: 20)),
                    const SizedBox(height: 4),
                    Text(
                      '달성한 기록은 보상으로 바꿀 수 있어요.',
                      style: mainBody(size: 13, color: kMainSub),
                    ),
                    const SizedBox(height: 12),
                    ..._milestones.map((m) => _milestoneRow(m)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _loadingState() {
    return const Center(child: CircularProgressIndicator(color: kMainRose));
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MainCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: kMainRose),
              const SizedBox(height: 14),
              Text('비밀기지를 열 수 없어요', style: mainTitle(size: 20)),
              const SizedBox(height: 6),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: mainBody(size: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inlineError() {
    return MainCard(
      color: kMainPeachSoft,
      borderColor: kMainPeach.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: kMainPeach),
          const SizedBox(width: 10),
          Expanded(child: Text(_loadError!, style: mainBody(size: 12))),
          TextButton(onPressed: _load, child: const Text('재시도')),
        ],
      ),
    );
  }

  Widget _scopeCard() {
    return Semantics(
      container: true,
      label: '우리의 비밀기지. 활성 커플만 함께 보는 공유 공간',
      child: MainCard(
        color: kMainRoseSoft,
        borderColor: kMainRose.withValues(alpha: 0.18),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: kMainRose, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '우리 둘만 보는 공간',
                    style: mainBody(
                      size: 13,
                      color: kMainInk,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '활성 커플의 순간과 기념 기록을 함께 모아요.',
                    style: mainBody(size: 12, color: kMainSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return MainCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.home_work_outlined, size: 44, color: kMainLilac),
          const SizedBox(height: 12),
          Text('아직 쌓인 기록이 없어요', style: mainTitle(size: 20)),
          const SizedBox(height: 6),
          Text(
            'MomentLoop에 둘만의 순간을 남기면\n비밀기지가 하나씩 채워져요.',
            textAlign: TextAlign.center,
            style: mainBody(size: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openMomentLoop,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('순간 남기러 가기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openPostcard,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('기지 엽서 둘러보기'),
          ),
        ],
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
                _statusChip(achieved: achieved, claimed: claimed),
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

  Widget _statusChip({required bool achieved, required bool claimed}) {
    final label = claimed
        ? '수령 완료'
        : achieved
        ? '보상 가능'
        : '진행 중';
    final color = claimed
        ? kMainSage
        : achieved
        ? kMainRose
        : kMainMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: mainBody(size: 10, color: color, weight: FontWeight.w800),
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
