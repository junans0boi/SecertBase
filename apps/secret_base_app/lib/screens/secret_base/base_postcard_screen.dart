import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../v2/v2.dart';
import '../home/home_format.dart';
import 'base_api.dart';
import 'base_common.dart';
import 'couple_store.dart';

/// Stand-alone 엽서 page (kept for callers that open it directly). The hub
/// shows the same content as its 엽서 tab.
class BasePostcardScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;
  final int initialYear;
  final int initialMonth;
  final http.Client? client;

  const BasePostcardScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
    required this.initialYear,
    required this.initialMonth,
    this.client,
  });

  @override
  State<BasePostcardScreen> createState() => _BasePostcardScreenState();
}

class _BasePostcardScreenState extends State<BasePostcardScreen> {
  late final BaseApi _api = BaseApi(
    baseUrl: widget.baseUrl,
    headers: widget.authHeaders,
    client: widget.client,
  );
  late final CoupleStore _couple = CoupleStore(_api)..load();

  @override
  void dispose() {
    _couple.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        appBar: const V2Header(title: '엽서'),
        body: BasePostcardTab(
          hub: BaseHub(api: _api, couple: _couple),
          initialYear: widget.initialYear,
          initialMonth: widget.initialMonth,
        ),
      ),
    );
  }
}

/// 엽서 탭: one card per month; the previous month stays (dimmed) while the
/// next one loads so the card never flashes empty.
class BasePostcardTab extends StatefulWidget {
  const BasePostcardTab({
    super.key,
    required this.hub,
    this.initialYear,
    this.initialMonth,
  });

  final BaseHub hub;
  final int? initialYear;
  final int? initialMonth;

  @override
  State<BasePostcardTab> createState() => _BasePostcardTabState();
}

class _BasePostcardTabState extends State<BasePostcardTab> {
  late int _year = widget.initialYear ?? DateTime.now().year;
  late int _month = widget.initialMonth ?? DateTime.now().month;
  Map<String, dynamic>? _postcard;
  bool _loading = true;
  BaseLoad _failure = BaseLoad.ready;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _failure = BaseLoad.ready;
    });
    try {
      final body = await widget.hub.api.get(
        '/retention/secret-base/postcard/$_year/$_month',
      );
      final card = body['postcard'];
      if (card is! Map) throw const BaseApiException('invalid_response');
      if (!mounted || id != _request) return;
      setState(() {
        _postcard = Map<String, dynamic>.from(card);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _loading = false;
        _failure = loadStateFor(e);
      });
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _year < now.year || (_year == now.year && _month < now.month);
  }

  void _step(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _year = y;
      _month = m;
    });
    _fetch();
  }

  int _count(String key) => (_postcard?[key] as num?)?.toInt() ?? 0;

  bool get _hasRecords =>
      _count('moments_count') > 0 ||
      _count('visited_count') > 0 ||
      _postcard?['highlight_post'] != null;

  String get _shareText {
    final partner = widget.hub.couple.partnerName;
    return '$_month월의 우리 엽서 · 순간 ${_count('moments_count')}개 · 방문 ${_count('visited_count')}곳 (${josa(partner, '와', '과')} 함께)';
  }

  Future<void> _share() async {
    await showV2Sheet<void>(
      context,
      title: '$_month월의 우리 엽서',
      subtitle: '문구를 복사해 공유해요',
      builder: (_) => Column(
        children: [
          V2List(
            children: [
              Builder(
                builder: (c) => V2ListTile(
                  icon: V2Icons.copy,
                  title: '엽서 문구 복사',
                  subtitle: '메신저나 SNS에 붙여 넣어요',
                  onTap: () async {
                    final messenger = Navigator.of(c);
                    await Clipboard.setData(ClipboardData(text: _shareText));
                    messenger.pop();
                    if (mounted) showV2Snack(context, '엽서 문구를 복사했어요');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partner = widget.hub.couple.partnerName;
    return ListView(
      padding: baseListPadding,
      children: [
        _MonthBar(
          year: _year,
          month: _month,
          canGoNext: _canGoNext && !_loading,
          canGoPrev: !_loading,
          onPrev: () => _step(-1),
          onNext: () => _step(1),
        ),
        const SizedBox(height: V2Space.x3),
        if (_failure == BaseLoad.unpaired)
          V2EmptyState.unpaired(onAction: () => openPartnerScreen(context))
        else if (_failure == BaseLoad.error && _postcard == null)
          V2ErrorState(
            title: '엽서를 불러오지 못했어요',
            body: '다른 달은 그대로 볼 수 있어요',
            retryLabel: '다시 불러오기',
            onRetry: _fetch,
          )
        else if (_postcard == null)
          const V2SkeletonCard()
        else ...[
          if (_failure == BaseLoad.error)
            Padding(
              padding: const EdgeInsets.only(bottom: V2Space.x3),
              child: V2Banner(
                tone: V2BannerTone.err,
                message: '$_month월 엽서를 불러오지 못했어요',
                actionLabel: '다시 불러오기',
                onAction: _fetch,
              ),
            ),
          AnimatedOpacity(
            opacity: _loading || _failure == BaseLoad.error ? .45 : 1,
            duration: V2Motion.of(context, V2Motion.fast),
            child: _hasRecords
                ? _PostcardCard(
                    month: _postcard!['month'] is num
                        ? (_postcard!['month'] as num).toInt()
                        : _month,
                    postcard: _postcard!,
                    me: widget.hub.couple.myName,
                    partner: partner,
                    baseUrl: widget.hub.api.baseUrl,
                  )
                : V2Card(
                    child: V2EmptyState(
                      illustration: const V2SceneIllustration(V2Scene.letter),
                      title: _isCurrentMonth
                          ? '이번 달 엽서는 아직 비어 있어요'
                          : '$_month월에는 남긴 기록이 없어요',
                      body: V2Text.keepAll(
                        '순간이나 장소를 남기면\n한 달의 이야기가 엽서 한 장으로 모여요.',
                      ),
                      actionLabel: _isCurrentMonth ? '오늘의 순간 남기기' : null,
                      onAction: _isCurrentMonth
                          ? () => openMomentComposer(context)
                          : null,
                    ),
                  ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: V2Space.x3),
              child: Text(
                '$_month월 엽서를 불러오는 중이에요',
                textAlign: TextAlign.center,
                style: V2Text.cap,
              ),
            ),
          if (_hasRecords && !_loading) ...[
            const SizedBox(height: V2Space.x4),
            V2Button(
              label: '공유하기',
              icon: V2Icons.share,
              variant: V2ButtonVariant.soft,
              onPressed: _share,
            ),
          ],
        ],
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.year,
    required this.month,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        V2IconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: '지난달',
          onPressed: canGoPrev ? onPrev : null,
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              '$year년 $month월',
              textAlign: TextAlign.center,
              style: V2Text.head,
            ),
          ),
        ),
        V2IconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: '다음 달',
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}

class _PostcardCard extends StatelessWidget {
  const _PostcardCard({
    required this.month,
    required this.postcard,
    required this.me,
    required this.partner,
    required this.baseUrl,
  });

  final int month;
  final Map<String, dynamic> postcard;
  final String me;
  final String partner;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final moments = (postcard['moments_count'] as num?)?.toInt() ?? 0;
    final visited = (postcard['visited_count'] as num?)?.toInt() ?? 0;
    final highlight = postcard['highlight_post'] is Map
        ? Map<String, dynamic>.from(postcard['highlight_post'] as Map)
        : null;
    final places = [
      for (final v in (postcard['visited_places'] as List? ?? const []))
        if (v is Map && v['place_name'] != null) '${v['place_name']}',
    ];
    final when = DateTime.tryParse('${highlight?['captured_at'] ?? ''}');
    final day = when == null
        ? null
        : '$month월 ${(when.isUtc ? when.toLocal() : when).day}일';
    final media = highlight?['media_url'] as String?;
    final caption = highlight?['caption'] as String?;

    return V2Card(
      padding: EdgeInsets.zero,
      semanticLabel: '$month월의 엽서, 순간 $moments개, 방문 $visited곳',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(V2Space.x5),
            decoration: BoxDecoration(
              gradient: V2Gradients.heroSoft,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(V2Radius.card),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('비밀기지에서 보낸 $month월의 엽서', style: V2Text.cap),
                const SizedBox(height: V2Space.x1),
                Text('$month월의 우리', style: V2Text.serif(size: 30)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(V2Space.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Stat(value: moments, label: '순간'),
                    _Stat(value: places.length, label: '장소'),
                    _Stat(value: visited, label: '방문'),
                  ],
                ),
                if (highlight != null) ...[
                  const Divider(height: V2Space.x8),
                  Text(
                    day == null ? '가장 기억에 남는 날' : '가장 기억에 남는 날 · $day',
                    style: V2Text.label.copyWith(color: p.sub),
                  ),
                  const SizedBox(height: V2Space.x2),
                  if (media != null && media.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: V2Radius.ctlAll,
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          media.startsWith('http') ? media : '$baseUrl$media',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const V2PhotoPlaceholder(seed: 'postcard'),
                        ),
                      ),
                    ),
                    const SizedBox(height: V2Space.x3),
                  ],
                  if (caption != null && caption.trim().isNotEmpty)
                    Text(caption, style: V2Text.serif(size: 18)),
                ],
                if (places.isNotEmpty) ...[
                  const SizedBox(height: V2Space.x3),
                  Text(places.join(' · '), style: V2Text.cap),
                ],
                const SizedBox(height: V2Space.x4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('$me & $partner', style: V2Text.cap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: V2Text.serif(size: 28, color: V2Colors.rose700),
          ),
          Text(label, style: V2Text.cap),
        ],
      ),
    );
  }
}
