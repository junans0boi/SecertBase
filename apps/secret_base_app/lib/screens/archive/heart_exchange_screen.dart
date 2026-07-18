import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import 'qa_screen.dart';
import 'balance_screen.dart';
import 'wish_ticket_screen.dart';

class HeartExchangeScreen extends StatelessWidget {
  const HeartExchangeScreen({super.key});

  static const _items = [
    _ExchangeItem(
      '❓',
      '10시의 질문',
      '매일 밤 10시에 나누는 서로의 속마음 문답',
      kMainHoney,
      kMainHoneySoft,
    ),
    _ExchangeItem(
      '⚖️',
      '커플 밸런스',
      '오늘 서로의 취향이 얼마나 일치하는지 알아보는 게임',
      kMainPeach,
      kMainPeachSoft,
    ),
    _ExchangeItem(
      '🎟️',
      '소원권',
      '미션 완료 보상과 애정 어린 약속 쿠폰',
      kMainRose,
      kMainRoseSoft,
    ),
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
        title: Text('마음 교감', style: mainTitle(size: 24)),
      ),
      body: CozyPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Text(
                '서로의 가치관을 알아가고, 소소한 소통을 이어가는 공간이에요.',
                style: mainBody(size: 13.5, color: kMainSub),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _ExchangeCard(
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

  void _openDetail(BuildContext ctx, _ExchangeItem item) {
    Widget? screen;
    switch (item.name) {
      case '10시의 질문':
        screen = const QaScreen();
      case '커플 밸런스':
        screen = const BalanceScreen();
      case '소원권':
        screen = const WishTicketScreen();
    }
    if (screen != null) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen!));
    }
  }
}

class _ExchangeItem {
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final Color bgColor;
  const _ExchangeItem(
    this.emoji,
    this.name,
    this.desc,
    this.color,
    this.bgColor,
  );
}

class _ExchangeCard extends StatelessWidget {
  final _ExchangeItem item;
  final VoidCallback onTap;
  const _ExchangeCard({required this.item, required this.onTap});

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
