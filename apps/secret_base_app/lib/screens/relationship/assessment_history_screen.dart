import 'package:flutter/material.dart';

import '../../core/assessment_attempt_api.dart';
import '../../core/main_design.dart';

class AssessmentHistoryScreen extends StatefulWidget {
  final String title;
  final AssessmentAttemptApi api;
  final String assessmentCode;

  const AssessmentHistoryScreen({
    super.key,
    required this.title,
    required this.api,
    required this.assessmentCode,
  });

  @override
  State<AssessmentHistoryScreen> createState() =>
      _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  List<AssessmentHistoryItem>? _history;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.api.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final history = await widget.api.fetchHistory(widget.assessmentCode);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            error is AssessmentAttemptApiException &&
                error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해주세요.'
            : '과거 결과를 불러오지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('${widget.title} 이력', style: mainTitle(size: 21)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _errorMessage != null
          ? _errorState()
          : _history == null || _history!.isEmpty
          ? const Center(child: Text('완료된 결과가 아직 없어요'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                Text('과거 결과', style: mainTitle(size: 24)),
                const SizedBox(height: 6),
                Text(
                  '가장 최근 결과가 현재 결과로 사용돼요. 이전 결과도 그대로 보관됩니다.',
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 16),
                ..._history!.asMap().entries.map(
                  (entry) => _historyCard(entry.key, entry.value),
                ),
              ],
            ),
    );
  }

  Widget _historyCard(int index, AssessmentHistoryItem item) {
    final dateLabel = item.createdAt == null ? '' : ' · ${item.createdAt}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MainCard(
        key: Key('assessment_history_${item.id}'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  index == 0 ? '현재 결과' : '이전 결과 $index',
                  style: mainBody(weight: FontWeight.w800),
                ),
                Text(
                  item.version,
                  style: mainBody(size: 12, color: kMainMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.result.overallTendency,
              style: mainBody(size: 14, height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              '전체 점수 ${item.result.overallScore}점$dateLabel',
              style: mainBody(size: 12, color: kMainSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: MainCard(
        key: const Key('assessment_history_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('과거 결과를 불러오지 못했어요', style: mainTitle(size: 20)),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: mainBody(size: 13, color: kMainSub),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      ),
    ),
  );
}
