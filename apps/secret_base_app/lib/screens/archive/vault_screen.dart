import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import 'challenge_screen.dart';
import 'timeline_screen.dart';
import 'jukebox_screen.dart';
import 'monthly_report_screen.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  static const _items = [
    _VaultItem('🏆', '목표 챌린지', '함께 달성해가는 커플 미션', kMainSky, kMainSkySoft),
    _VaultItem('🧾', '우리 타임라인', '차곡차곡 자동 적립되는 기록들', kMainSage, kMainSageSoft),
    _VaultItem('📊', '월간 리포트', '지난 한 달 동안의 요약 보고서', kMainPeach, kMainPeachSoft),
    _VaultItem('🎵', '주크박스', '우리만의 로맨틱 플레이리스트', kMainHoney, kMainHoneySoft),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainPaperSoft,
      appBar: AppBar(
        backgroundColor: kMainPaperSoft,
        foregroundColor: kMainInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('추억 저장고', style: mainTitle(size: 24)),
      ),
      body: CozyPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Text(
                '더욱 단단한 소통을 도와주는 유틸리티 모음집이에요.',
                style: mainBody(size: 13.5, color: kMainSub),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _VaultCard(
                  item: _items[i],
                  onTap: () => _openDetail(ctx, _items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext ctx, _VaultItem item) {
    Widget? screen;
    switch (item.name) {
      case '목표 챌린지':
        screen = const ChallengeScreen();
      case '우리 타임라인':
        screen = const TimelineScreen();
      case '월간 리포트':
        screen = const MonthlyReportScreen();
      case '주크박스':
        screen = const JukeboxScreen();
    }
    if (screen != null) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen!));
    }
  }
}

class _VaultItem {
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final Color bgColor;
  const _VaultItem(this.emoji, this.name, this.desc, this.color, this.bgColor);
}

class _VaultCard extends StatelessWidget {
  final _VaultItem item;
  final VoidCallback onTap;
  const _VaultCard({required this.item, required this.onTap});

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
              child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
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
