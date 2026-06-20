import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import 'moment_loop_screen.dart';
import 'qa_screen.dart';
import 'challenge_screen.dart';
import 'map_screen.dart';
import 'jukebox_screen.dart';
import 'capsule_screen.dart';

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
    _ArchiveItem('🕯️', '타임캡슐', '미래의 우리에게 편지', kMainHoney, kMainHoneySoft),
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
    Widget? screen;
    switch (item.name) {
      case 'MomentLoop':
        screen = const MomentLoopScreen();
      case '비밀 지도':
        screen = const MapScreen();
      case '10시의 질문':
        screen = const QaScreen();
      case '목표 챌린지':
        screen = const ChallengeScreen();
      case '주크박스':
        screen = const JukeboxScreen();
      case '타임캡슐':
        screen = const CapsuleScreen();
    }
    if (screen != null) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen!));
    }
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
