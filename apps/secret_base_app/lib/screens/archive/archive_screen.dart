import 'package:flutter/material.dart';
import '../../core/main_design.dart';
import 'moment_loop_screen.dart';
import 'map_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  // 비활성 REST에 의존하는 항목(앨범/캡슐/대피소/교감/저장고)은 복구 전까지
  // 노출하지 않는다 (#32). 복원은 git 히스토리 참고.
  static const _items = [
    _ArchiveItem(
      Icons.auto_stories_outlined,
      'MomentLoop',
      '오늘 기록',
      '방금 있었던 일, 사진, 짧은 안부를 한 번에 남겨요.',
      '오늘',
      kMainRose,
      kMainRoseSoft,
    ),
    _ArchiveItem(
      Icons.map_outlined,
      '비밀 지도',
      '장소 저장',
      '둘이 다녀온 장소와 다시 가고 싶은 곳을 지도 위에 모아요.',
      '장소',
      kMainSage,
      kMainSageSoft,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CozyPage(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            sliver: SliverToBoxAdapter(child: _buildHeader()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            sliver: SliverToBoxAdapter(
              child: _FeaturedMemoryCard(
                item: _items.first,
                onTap: () => _openDetail(context, _items.first),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '더 꺼내보기',
                style: mainBody(
                  size: 13,
                  color: kMainSub,
                  weight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 34),
            sliver: SliverList.separated(
              itemCount: _items.length - 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = _items[i + 1];
                return _ArchiveListTile(
                  item: item,
                  onTap: () => _openDetail(ctx, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('우리의 기록', style: mainTitle(size: 34)),
              const SizedBox(height: 2),
              Text(
                '쌓아두는 곳보다 꺼내보기 쉬운 곳으로',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mainBody(size: 13, color: kMainSub),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: kMainRoseSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kMainLine),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: kMainRose),
        ),
      ],
    );
  }

  void _openDetail(BuildContext ctx, _ArchiveItem item) {
    Widget? screen;
    switch (item.name) {
      case 'MomentLoop':
        screen = const MomentLoopScreen();
      case '비밀 지도':
        screen = const MapScreen();
    }
    if (screen != null) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen!));
    }
  }
}

class _ArchiveItem {
  final IconData icon;
  final String name;
  final String desc;
  final String detail;
  final String badge;
  final Color color;
  final Color bgColor;
  const _ArchiveItem(
    this.icon,
    this.name,
    this.desc,
    this.detail,
    this.badge,
    this.color,
    this.bgColor,
  );
}

class _FeaturedMemoryCard extends StatelessWidget {
  final _ArchiveItem item;
  final VoidCallback onTap;
  const _FeaturedMemoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MainCard(
        padding: EdgeInsets.zero,
        gradient: kRoseGrad,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -24,
              child: Icon(
                Icons.favorite_rounded,
                size: 128,
                color: Colors.white.withAlpha(38),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ArchiveBadge(label: '오늘 남길 것', color: Colors.white),
                  const SizedBox(height: 18),
                  Icon(item.icon, color: Colors.white, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    style: mainTitle(size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: mainBody(
                      size: 14,
                      color: Colors.white.withAlpha(225),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '바로 기록하기',
                          style: mainBody(
                            size: 14,
                            color: item.color,
                            weight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: item.color),
                      ],
                    ),
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

class _ArchiveListTile extends StatelessWidget {
  final _ArchiveItem item;
  final VoidCallback onTap;

  const _ArchiveListTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kMainPaper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kMainLine),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: item.color, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mainBody(
                              size: 16,
                              color: kMainInk,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ArchiveBadge(label: item.badge, color: item.color),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mainBody(size: 12, color: kMainMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: item.color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ArchiveBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final white = color == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: white ? Colors.white.withAlpha(42) : color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: white ? Colors.white.withAlpha(90) : color.withAlpha(80),
        ),
      ),
      child: Text(
        label,
        style: mainBody(
          size: 11,
          color: white ? Colors.white : color,
          weight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
