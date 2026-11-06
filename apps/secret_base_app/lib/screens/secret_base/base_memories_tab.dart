import 'package:flutter/material.dart';

import '../../v2/v2.dart';
import '../archive/moment_loop_screen.dart';
import '../home/home_format.dart';
import 'base_common.dart';

/// 추억 탭: "n년 전 오늘", grouped by year, pull to refresh, tap to open.
class BaseMemoriesTab extends StatefulWidget {
  const BaseMemoriesTab({super.key, required this.hub});

  final BaseHub hub;

  @override
  State<BaseMemoriesTab> createState() => _BaseMemoriesTabState();
}

class _BaseMemoriesTabState extends State<BaseMemoriesTab> {
  BaseLoad _load = BaseLoad.loading;
  List<Map<String, dynamic>> _posts = [];
  DateTime? _businessDate;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _load = BaseLoad.loading);
    try {
      final body = await widget.hub.api.get('/retention/memory-card/list');
      if (!mounted) return;
      setState(() {
        _posts = [
          for (final p in (body['posts'] as List? ?? const []).whereType<Map>())
            Map<String, dynamic>.from(p),
        ];
        _businessDate = parseDay('${body['business_date'] ?? ''}');
        _load = BaseLoad.ready;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _load == BaseLoad.ready) return;
      setState(() => _load = loadStateFor(e));
    }
  }

  void _open(Map<String, dynamic> post) {
    final id = post['id'] is int ? post['id'] as int : int.tryParse('${post['id']}');
    if (id == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MomentLoopScreen(initialPostId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return baseTabBody(
      context: context,
      load: _load,
      onRetry: _fetch,
      errorTitle: '추억을 불러오지 못했어요',
      errorBody: '당겨서 새로고침하거나 다시 시도해 주세요.',
      ready: _content,
    );
  }

  Widget _content() {
    final date = _businessDate ?? today();
    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetch(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 460,
              child: V2EmptyState(
                illustration: const V2SceneIllustration(V2Scene.photo),
                title: '이날의 기록은 아직 없어요',
                body: V2Text.keepAll('오늘 남긴 순간은 1년 뒤 오늘\n이곳에서 다시 만날 수 있어요.'),
                actionLabel: '오늘의 순간 남기기',
                onAction: () => openMomentComposer(context),
              ),
            ),
          ],
        ),
      );
    }
    final byYears = <int, List<Map<String, dynamic>>>{};
    for (final p in _posts) {
      final y = (p['years_ago'] as num?)?.toInt() ?? 0;
      byYears.putIfAbsent(y, () => []).add(p);
    }
    final years = byYears.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: () => _fetch(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: baseListPadding,
        children: [
          Text('n년 전 오늘', style: V2Text.title),
          const SizedBox(height: V2Space.x1),
          Text(
            '${date.month}월 ${date.day}일 · 이날의 기록 ${_posts.length}개',
            style: V2Text.cap,
          ),
          for (final y in years)
            V2Section(
              title: '$y년 전',
              padding: EdgeInsets.zero,
              child: V2List(
                children: [
                  for (final post in byYears[y]!)
                    _MemoryRow(
                      post: post,
                      baseUrl: widget.hub.api.baseUrl,
                      onTap: () => _open(post),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({
    required this.post,
    required this.baseUrl,
    required this.onTap,
  });

  final Map<String, dynamic> post;
  final String baseUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = (post['caption'] as String?)?.trim() ?? '';
    final place = post['place_name'] as String?;
    final media = post['media_url'] as String?;
    final at = DateTime.tryParse('${post['captured_at'] ?? ''}');
    final clock = clockLabel(post['captured_at'] as String?);
    final subtitle = [
      ?clock,
      ?place,
    ].join(' · ');
    final title = caption.isNotEmpty ? caption : (place ?? '사진 기록');
    final thumb = media == null || media.isEmpty
        ? null
        : ClipRRect(
            borderRadius: V2Radius.ctlAll,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Image.network(
                media.startsWith('http') ? media : '$baseUrl$media',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    V2PhotoPlaceholder(seed: '${post['id']}'),
              ),
            ),
          );
    return V2ListTile(
      icon: thumb == null ? V2Icons.image : null,
      leading: thumb,
      title: title,
      subtitle: at == null ? subtitle : '${dotDate(at)} · $subtitle',
      onTap: onTap,
    );
  }
}
