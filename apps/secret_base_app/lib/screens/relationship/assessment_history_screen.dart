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
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('검사 기록', style: mainTitle(size: 24)),
                    const SizedBox(width: 8),
                    Text(
                      '${_history!.length}회',
                      style: mainBody(size: 12, color: kMainMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '가장 최근 결과가 현재 결과로 사용돼요. 이전 결과도 수정되지 않고 그대로 보관됩니다.',
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
    final dateLabel = item.createdAt == null
        ? ''
        : ' · ${_formatDate(item.createdAt!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('assessment_history_open_${item.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetail(index, item),
          child: MainCard(
            key: Key('assessment_history_${item.id}'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        index == 0 ? '현재 결과' : '이전 결과 $index',
                        style: mainBody(weight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      item.version,
                      style: mainBody(size: 12, color: kMainMuted),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: kMainMuted,
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
                if (item.result.dimensions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final dimension in item.result.dimensions)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kMainPaperSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${dimension.title} ${dimension.score}점',
                            style: mainBody(size: 11, color: kMainSub),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      item.answers.isEmpty
                          ? Icons.info_outline_rounded
                          : Icons.checklist_rounded,
                      size: 16,
                      color: kMainRose,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.answers.isEmpty
                          ? '선택 답변 상세 보기'
                          : '${item.answers.length}개 문항의 선택 답변 보기',
                      style: mainBody(
                        size: 12,
                        color: kMainRose,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(int index, AssessmentHistoryItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssessmentHistoryDetailScreen(
          title: widget.title,
          index: index,
          item: item,
        ),
      ),
    );
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$year.$month.$day $hour:$minute';
  }

  Widget _emptyState() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
    children: [
      Text('검사 기록', style: mainTitle(size: 24)),
      const SizedBox(height: 6),
      Text(
        '완료한 검사는 결과가 자동으로 보관돼요. 다시 검사해도 이전 기록은 사라지지 않아요.',
        style: mainBody(size: 13, color: kMainSub, height: 1.5),
      ),
      const SizedBox(height: 18),
      MainCard(
        padding: const EdgeInsets.all(22),
        color: kMainPaperSoft,
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 34, color: kMainLilac),
            const SizedBox(height: 12),
            Text('아직 완료한 기록이 없어요', style: mainBody(weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '검사를 완료하면 결과가 이곳에 보관돼요.',
              textAlign: TextAlign.center,
              style: mainBody(size: 13, color: kMainSub),
            ),
          ],
        ),
      ),
    ],
  );

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

class AssessmentHistoryDetailScreen extends StatelessWidget {
  final String title;
  final int index;
  final AssessmentHistoryItem item;

  const AssessmentHistoryDetailScreen({
    super.key,
    required this.title,
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final resultLabel = index == 0 ? '현재 결과' : '이전 결과 $index';
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('$resultLabel 상세', style: mainTitle(size: 21)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Text(title, style: mainTitle(size: 24)),
          const SizedBox(height: 6),
          Text(
            '이 기록은 읽기 전용이에요. 당시 선택한 답변은 변경할 수 없습니다.',
            style: mainBody(size: 13, color: kMainSub, height: 1.5),
          ),
          const SizedBox(height: 16),
          MainCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resultLabel, style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  item.result.overallTendency,
                  style: mainBody(size: 14, height: 1.45),
                ),
                const SizedBox(height: 8),
                Text(
                  '전체 점수 ${item.result.overallScore}점 · ${item.version}',
                  style: mainBody(size: 12, color: kMainSub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('당시 선택한 답변', style: mainTitle(size: 19)),
          const SizedBox(height: 8),
          if (item.answers.isEmpty)
            MainCard(
              padding: const EdgeInsets.all(18),
              color: kMainPaperSoft,
              child: Text(
                '이 기록에는 문항별 선택 정보가 아직 포함되어 있지 않아요.',
                style: mainBody(size: 13, color: kMainSub, height: 1.5),
              ),
            )
          else
            for (final answer in item.answers) _answerDetailCard(answer),
        ],
      ),
    );
  }
}

Widget _answerDetailCard(AssessmentHistoryAnswer answer) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: MainCard(
      padding: const EdgeInsets.all(14),
      color: kMainPaperSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (answer.dimensionTitle != null &&
                  answer.dimensionTitle!.isNotEmpty) ...[
                Text(
                  answer.dimensionTitle!,
                  style: mainBody(
                    size: 11,
                    color: kMainRose,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(' · ', style: mainBody(size: 11, color: kMainMuted)),
              ],
              Text(
                '문항 ${answer.order}',
                style: mainBody(
                  size: 11,
                  color: kMainMuted,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            answer.prompt,
            style: mainBody(size: 13, color: kMainInk, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('선택한 답변', style: mainBody(size: 11, color: kMainSub)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: kMainPaper,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${answer.value} · ${answer.label}',
                  style: mainBody(
                    size: 11,
                    color: kMainRose,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
