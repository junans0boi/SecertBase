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

  static const _milestoneIcons = <String, IconData>{
    'first_moment': Icons.photo_camera_outlined,
    'moments_10': Icons.collections_outlined,
    'moments_50': Icons.auto_awesome_outlined,
    'moments_100': Icons.star_outline_rounded,
    'first_pin': Icons.place_outlined,
    'first_visit': Icons.travel_explore_outlined,
    'visited_5': Icons.map_outlined,
    'first_memory_card': Icons.history_outlined,
    'd100': Icons.favorite_border_rounded,
    'd200': Icons.favorite_border_rounded,
    'd365': Icons.cake_outlined,
  };

  static const _milestoneColors = <String, Color>{
    'first_moment': kMainRose,
    'moments_10': kMainRose,
    'moments_50': kMainHoney,
    'moments_100': kMainHoney,
    'first_pin': kMainSage,
    'first_visit': kMainSage,
    'visited_5': kMainSage,
    'first_memory_card': kMainLilac,
    'd100': kMainRose,
    'd200': kMainRose,
    'd365': kMainRose,
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
    final achievedAt = m['achieved_at'] as String?;
    final value = m['value'];
    final icon = _milestoneIcons[type] ?? Icons.emoji_events_outlined;
    final color = _milestoneColors[type] ?? kMainRose;

    String? dateLabel;
    if (achievedAt != null && achievedAt.length >= 10) {
      final parts = achievedAt.substring(0, 10).split('-');
      if (parts.length == 3) {
        dateLabel = '${parts[0]}년 ${parts[1]}월 ${parts[2]}일';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MainCard(
        padding: const EdgeInsets.all(14),
        child: Row(
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
              child: Icon(icon, color: achieved ? color : kMainMuted, size: 22),
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
                  if (achieved && value != null)
                    Text(
                      '$value',
                      style: mainBody(size: 11, color: kMainMuted),
                    ),
                ],
              ),
            ),
            if (achieved)
              const Icon(Icons.check_circle_rounded, color: kMainSage, size: 22)
            else
              const Icon(
                Icons.radio_button_unchecked_rounded,
                color: kMainLine,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
