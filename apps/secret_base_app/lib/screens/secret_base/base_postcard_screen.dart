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
  bool _loading = false;

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
      });
    }
    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/retention/secret-base/postcard/$_year/$_month',
        ),
        headers: widget.authHeaders,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true && data['postcard'] != null) {
        setState(
          () => _postcard = Map<String, dynamic>.from(data['postcard'] as Map),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
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
    if (_year > now.year || (_year == now.year && _month >= now.month)) return;
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
    return !(_year >= now.year && _month >= now.month);
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
          '기지 엽서',
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
                : _postcard == null
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
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left_rounded, color: kMainInk),
          ),
          Text(
            '$_year년 $_month월',
            style: mainBody(size: 16, weight: FontWeight.w800, color: kMainInk),
          ),
          IconButton(
            onPressed: _canGoNext ? _nextMonth : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _canGoNext ? kMainInk : kMainLine,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mail_outline_rounded, size: 48, color: kMainLine),
          const SizedBox(height: 12),
          Text('이달의 기록이 없어요', style: mainBody(color: kMainMuted, size: 15)),
          const SizedBox(height: 4),
          Text(
            '순간을 남기면 엽서가 만들어져요',
            style: mainBody(color: kMainMuted, size: 13),
          ),
        ],
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
        MainCard(
          gradient: kRoseGrad,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_year년 $_month월 엽서',
                style: mainBody(size: 13, color: Colors.white70),
              ),
              const SizedBox(height: 8),
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
