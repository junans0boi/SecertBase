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
      }
    } catch (_) {
      // Resilient — show empty state on error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _businessDate != null
        ? '${_businessDate!.substring(5, 7)}월 ${_businessDate!.substring(8, 10)}일의 기억들'
        : '이 날의 기억들';

    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainPaper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(dateLabel, style: mainBody(size: 17, weight: FontWeight.w900)),
        leading: const BackButton(color: kMainInk),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _posts.isEmpty
              ? Center(child: Text('아직 기억이 없어요', style: mainBody(color: kMainMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final post = _posts[i];
                    final yearsAgo = post['years_ago'] as int? ?? 0;
                    final placeName = post['place_name'] as String?;
                    final caption = post['caption'] as String?;
                    final mediaUrl = post['media_url'] as String?;
                    final fullUrl =
                        mediaUrl != null ? '${widget.baseUrl}$mediaUrl' : null;

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
                                errorBuilder: (_, __, ___) => Container(
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
                                  '$yearsAgo년 전',
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
