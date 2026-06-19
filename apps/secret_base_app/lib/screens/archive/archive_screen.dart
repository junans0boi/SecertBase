import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/main_design.dart';
import 'moment_loop_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  static const _items = [
    _ArchiveItem(
      '📸',
      'MomentLoop',
      '우리 둘의 날것 같은 하루 조각',
      kMainRose,
      kMainRoseSoft,
    ),
    _ArchiveItem('🗺️', '비밀 지도', '우리가 간 곳 모음', kMainSage, kMainSageSoft),
    _ArchiveItem('❓', '10시의 질문', '매일 밤 10시 Q&A', kMainHoney, kMainHoneySoft),
    _ArchiveItem('🏆', '목표 챌린지', '함께하는 도전', kMainSky, kMainSkySoft),
    _ArchiveItem('🎵', '주크박스', '우리의 플레이리스트', kMainPeach, kMainPeachSoft),
  ];

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _ArchiveCard(
                item: _items[i],
                onTap: () => _openDetail(ctx, _items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: MainCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            DoodleBadge(
              color: kMainHoney,
              backgroundColor: kMainHoneySoft,
              size: 54,
              child: const Text('📦', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('우리의 기록', style: mainTitle(size: 28)),
                  const SizedBox(height: 2),
                  Text('모든 순간을 천천히 모아둘게요', style: mainBody(size: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext ctx, _ArchiveItem item) {
    if (item.name == 'MomentLoop') {
      Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const MomentLoopScreen()),
      );
      return;
    }

    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => _ArchiveDetailPage(item: item)),
    );
  }
}

class _ArchiveItem {
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final Color bgColor;
  const _ArchiveItem(
    this.emoji,
    this.name,
    this.desc,
    this.color,
    this.bgColor,
  );
}

class _ArchiveCard extends StatelessWidget {
  final _ArchiveItem item;
  final VoidCallback onTap;
  const _ArchiveCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MainCard(
        padding: const EdgeInsets.all(15),
        radius: 18,
        borderColor: item.color.withAlpha(90),
        child: Row(
          children: [
            DoodleBadge(
              color: item.color,
              backgroundColor: item.bgColor,
              size: 52,
              child: Text(item.emoji, style: const TextStyle(fontSize: 25)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: mainBody(
                      size: 16,
                      color: kMainInk,
                      weight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.desc,
                    style: mainBody(size: 12, color: kMainMuted, height: 1.2),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: kMainMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ArchiveDetailPage extends StatelessWidget {
  final _ArchiveItem item;
  const _ArchiveDetailPage({required this.item});

  String get _endpoint {
    switch (item.name) {
      case 'MomentLoop':
        return 'GET/POST /api/setlog';
      case '비밀 지도':
        return 'GET/POST /api/map';
      case '10시의 질문':
        return 'GET /api/qa/today';
      case '목표 챌린지':
        return 'GET/POST /api/challenges';
      default:
        return 'GET/POST /api/jukebox';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        foregroundColor: kMainInk,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${item.emoji} ${item.name}'),
      ),
      body: SafeArea(
        child: CozyPage(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: MainCard(
                    padding: const EdgeInsets.all(28),
                    color: item.bgColor,
                    borderColor: item.color.withAlpha(80),
                    child: Column(
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 60)),
                        const SizedBox(height: 10),
                        Text(item.name, style: mainTitle(size: 28)),
                        const SizedBox(height: 4),
                        Text(
                          item.desc,
                          style: mainBody(size: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                MainCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.construction_rounded,
                        color: kGold,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text('개발 중', style: mainTitle(size: 24, color: kGold)),
                      const SizedBox(height: 6),
                      Text(
                        'Phase 4에서 완성 예정\n백엔드 API는 이미 준비됐어요!',
                        style: mainBody(size: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kSuccess.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kSuccess.withAlpha(80)),
                        ),
                        child: Text(
                          _endpoint,
                          style: mainBody(
                            size: 12,
                            color: kSuccess,
                            weight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
