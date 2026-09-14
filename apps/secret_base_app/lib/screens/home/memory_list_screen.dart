import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/main_design.dart';

class MemoryListScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, String> authHeaders;

  const MemoryListScreen({
    super.key,
    required this.baseUrl,
    required this.authHeaders,
  });

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;
  String? _businessDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/retention/memory-card/list'),
        headers: widget.authHeaders,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _posts = (data['posts'] as List? ?? [])
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          _businessDate = data['business_date'] as String?;
        });
      } else {
        setState(() => _error = '기억을 불러오지 못했어요.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '네트워크 연결을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(_businessDate ?? '');
    final dateLabel = date == null
        ? '이 날의 기억들'
        : '${date.month}월 ${date.day}일의 기억들';

    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('추억 되짚기', style: mainBody(size: 16, weight: FontWeight.w900)),
            Text(dateLabel, style: mainBody(size: 11, color: kMainMuted)),
          ],
        ),
        leading: const BackButton(color: kMainInk),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error != null
          ? Center(
              child: MainCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: mainBody(color: kMainSub)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          : _posts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CozyMascot(size: 72),
                    const SizedBox(height: 14),
                    Text(
                      '아직 되짚어볼 기억이 없어요',
                      style: mainBody(weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '오늘의 순간을 남기면 다음 해에 다시 만날 수 있어요',
                      textAlign: TextAlign.center,
                      style: mainBody(size: 12, color: kMainMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: _posts.length,
              separatorBuilder: (_, a) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final post = _posts[i];
                final yearsAgo = post['years_ago'] as int? ?? 0;
                final placeName = post['place_name'] as String?;
                final caption = post['caption'] as String?;
                final mediaUrl = post['media_url'] as String?;
                final fullUrl = mediaUrl != null
                    ? '${widget.baseUrl}$mediaUrl'
                    : null;

                return MainCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fullUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            fullUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, a, b) => Container(
                              width: 80,
                              height: 80,
                              color: kMainPaperSoft,
                              child: const Icon(
                                Icons.image_outlined,
                                color: kMainMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: kMainPaperSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.photo_album_outlined,
                            color: kMainMuted,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$yearsAgo년 전 오늘',
                              style: mainBody(size: 11, color: kMainMuted),
                            ),
                            if (placeName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                placeName,
                                style: mainBody(
                                  size: 13,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (caption != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                caption,
                                style: mainBody(size: 13, color: kMainSub),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
