import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import 'moment_loop_screen.dart';
import 'map_screen.dart';
import 'album_screen.dart';
import 'shelter_screen.dart';
import 'capsule_screen.dart';
import 'vault_screen.dart';
import 'heart_exchange_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  static const _items = [
    _ArchiveItem(
      '📸',
      'MomentLoop',
      '하루의 조각과 소소한 안부 나누기',
      kMainRose,
      kMainRoseSoft,
    ),
    _ArchiveItem('🗺️', '비밀 지도', '우리가 간 곳 모음', kMainSage, kMainSageSoft),
    _ArchiveItem('🖼️', '우리 앨범', '벽에 걸린 사진처럼 간직하는 추억', kMainPeach, kMainPeachSoft),
    _ArchiveItem('🕯️', '타임캡슐', '미래의 우리에게 보내는 러브레터', kMainHoney, kMainHoneySoft),
    _ArchiveItem('🍃', '마음 대피소', '말 못 할 고민과 나를 위한 이야기', kMainSky, kMainSkySoft),
    _ArchiveItem('💬', '마음 교감', '질문과 답변, 취향 매칭, 소원권 교환', kMainPeach, kMainPeachSoft),
    _ArchiveItem('📦', '추억 저장고', '챌린지, 타임라인 및 추가 도구', kMainSage, kMainSageSoft),
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
      case '우리 앨범':
        screen = const AlbumScreen();
      case '타임캡슐':
        screen = const CapsuleScreen();
      case '마음 대피소':
        screen = const ShelterScreen();
      case '마음 교감':
        screen = const HeartExchangeScreen();
      case '추억 저장고':
        screen = const VaultScreen();
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
