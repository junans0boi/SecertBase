import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/main_design.dart';

class BasePostcardScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;
  final int initialYear;
  final int initialMonth;

  const BasePostcardScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<BasePostcardScreen> createState() => _BasePostcardScreenState();
}

class _BasePostcardScreenState extends State<BasePostcardScreen> {
  late int _year;
  late int _month;
  Map<String, dynamic>? _postcard;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _postcard = null;
        _loadError = null;
      });
    }
    String? reason;
    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/retention/secret-base/postcard/$_year/$_month',
        ),
        headers: widget.authHeaders,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      reason = data['reason'] as String?;
      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
        throw const FormatException();
      }
      final postcard = data['postcard'];
      if (postcard is! Map) throw const FormatException();
      setState(() {
        _postcard = Map<String, dynamic>.from(postcard);
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
    'active_couple_required' => '활성 커플을 연결하면 둘만의 엽서를 볼 수 있어요.',
    _ => '엽서를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
  };

  void _prevMonth() {
    if (_loading) return;
    setState(() {
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_loading ||
        _year > now.year ||
        (_year == now.year && _month >= now.month)) {
      return;
    }
    setState(() {
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
    });
    _load();
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return !_loading && !(_year >= now.year && _month >= now.month);
  }

  bool get _hasRecords {
    final postcard = _postcard;
    if (postcard == null) return false;
    final moments = (postcard['moments_count'] as num?)?.toInt() ?? 0;
    final visited = (postcard['visited_count'] as num?)?.toInt() ?? 0;
    final places = postcard['visited_places'];
    return moments > 0 || visited > 0 || places is List && places.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '우리의 기지 엽서',
          style: mainBody(size: 17, weight: FontWeight.w900),
        ),
        leading: const BackButton(color: kMainInk),
      ),
      body: Column(
        children: [
          _monthNavigator(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kMainRose),
                  )
                : _loadError != null
                ? _errorState()
                : _postcard == null || !_hasRecords
                ? _emptyState()
                : _postcardContent(),
          ),
        ],
      ),
    );
  }

  Widget _monthNavigator() {
    return Container(
      color: kMainPaper,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _loading ? null : _prevMonth,
            icon: const Icon(Icons.chevron_left_rounded, color: kMainInk),
            tooltip: '이전 달',
          ),
          Semantics(
            label: '현재 보고 있는 달 $_year년 $_month월',
            child: Text(
              '$_year년 $_month월',
              style: mainBody(
                size: 16,
                weight: FontWeight.w800,
                color: kMainInk,
              ),
            ),
          ),
          IconButton(
            onPressed: _canGoNext ? _nextMonth : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _canGoNext ? kMainInk : kMainLine,
            ),
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      children: [
        _scopeCard(),
        const SizedBox(height: 20),
        MainCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 48,
                color: kMainLilac,
              ),
              const SizedBox(height: 12),
              Text('이달의 기록이 없어요', style: mainTitle(size: 20)),
              const SizedBox(height: 6),
              Text(
                '이번 달에 남긴 순간과 방문 기록이 모이면\n우리의 엽서가 만들어져요.',
                textAlign: TextAlign.center,
                style: mainBody(size: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('지난달 기록 보기'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 확인'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      children: [
        _scopeCard(),
        const SizedBox(height: 20),
        MainCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44, color: kMainRose),
              const SizedBox(height: 12),
              Text('엽서를 열 수 없어요', style: mainTitle(size: 20)),
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
      ],
    );
  }

  Widget _scopeCard() {
    return Semantics(
      container: true,
      label: '우리의 기지 엽서. 활성 커플만 함께 보는 월간 기록',
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
                    '우리 둘만 보는 월간 기록',
                    style: mainBody(
                      size: 13,
                      color: kMainInk,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '활성 커플의 순간과 방문 기록을 한 장에 모아요.',
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

  Widget _postcardContent() {
    final pc = _postcard!;
    final momentsCount = pc['moments_count'] as int? ?? 0;
    final visitedCount = pc['visited_count'] as int? ?? 0;
    final highlight = pc['highlight_post'] as Map<String, dynamic>?;
    final visitedPlaces = (pc['visited_places'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();

    final highlightUrl = highlight?['media_url'] as String?;
    final fullHighlightUrl = highlightUrl != null
        ? '${widget.baseUrl}$highlightUrl'
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      children: [
        _scopeCard(),
        const SizedBox(height: 18),
        MainCard(
          gradient: kRoseGrad,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_year년 $_month월 · 우리의 기록',
                style: mainBody(size: 13, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '이번 달, 우리가 남긴 장면',
                style: mainTitle(size: 23, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statChip(
                    Icons.photo_library_outlined,
                    '$momentsCount 순간',
                    Colors.white,
                  ),
                  const SizedBox(width: 10),
                  _statChip(
                    Icons.place_outlined,
                    '$visitedCount 장소',
                    Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (fullHighlightUrl != null || highlight != null) ...[
          const SizedBox(height: 18),
          Text('이달의 하이라이트', style: mainTitle(size: 18)),
          const SizedBox(height: 8),
          MainCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fullHighlightUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      fullHighlightUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, a, b) => _placeholderBox(),
                    ),
                  )
                else
                  _placeholderBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (highlight?['place_name'] != null)
                        Text(
                          highlight!['place_name'] as String,
                          style: mainBody(
                            size: 13,
                            weight: FontWeight.w700,
                            color: kMainInk,
                          ),
                        ),
                      if (highlight?['caption'] != null)
                        Text(
                          highlight!['caption'] as String,
                          style: mainBody(size: 13, color: kMainSub),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (visitedPlaces.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('방문한 장소', style: mainTitle(size: 18)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visitedPlaces.map((place) {
              final name = place['place_name'] as String? ?? '알 수 없음';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: kMainSageSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '📍 $name',
                  style: mainBody(
                    size: 12,
                    color: kMainInk,
                    weight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.85), size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: mainBody(size: 13, color: color, weight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _placeholderBox() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.photo_album_outlined, color: kMainMuted),
    );
  }
}
