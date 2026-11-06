import 'package:flutter/material.dart';

import '../../core/assessment_attempt_api.dart';
import 'package:secret_base_app/v2/v2.dart';

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
  AssessmentComparison? _comparison;
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
      AssessmentComparison? comparison;
      try {
        comparison = await widget.api.fetchComparison(widget.assessmentCode);
      } on Object {
        comparison = null;
      }
      if (!mounted) return;
      setState(() {
        _history = history;
        _comparison = comparison;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            error is AssessmentAttemptApiException &&
                error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해 주세요.'
            : '잠시 뒤 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(title: '${widget.title} 이력'),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 3),
              )
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
                      Text('검사 기록', style: V2Text.title),
                      const SizedBox(width: 8),
                      Text('${_history!.length}회', style: V2Text.cap),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '가장 최근 결과가 현재 결과로 사용돼요. 이전 결과도 수정되지 않고 그대로 보관돼요.',
                    style: V2Text.cap,
                  ),
                  const SizedBox(height: 16),
                  ..._history!.asMap().entries.map(
                    (entry) => _historyCard(entry.key, entry.value),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _comparisonCard(AssessmentComparison comparison) {
    if (!comparison.available || comparison.overall == null) {
      return Semantics(
        container: true,
        excludeSemantics: true,
        label: '최근 변화 비교',
        child: Container(
          key: const Key('assessment_comparison_card'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: V2Colors.soft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('최근 변화', style: V2Text.bodyStrong),
              const SizedBox(height: 6),
              Text(comparison.message, style: V2Text.cap),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '최근 변화 비교',
      child: Container(
        key: const Key('assessment_comparison_card'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: V2Colors.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph_rounded, color: V2Colors.lilac),
                const SizedBox(width: 8),
                Text('최근 변화', style: V2Text.bodyStrong),
              ],
            ),
            const SizedBox(height: 6),
            Text(comparison.accessibleMessage, style: V2Text.cap),
            const SizedBox(height: 12),
            ...comparison.dimensions.map(
              (dimension) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(dimension.title, style: V2Text.cap)),
                    Text(
                      '${dimension.previous} → ${dimension.current} (${dimension.delta >= 0 ? '+' : ''}${dimension.delta})',
                      style: V2Text.cap.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            Text(comparison.disclaimer, style: V2Text.cap),
          ],
        ),
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
          borderRadius: BorderRadius.circular(26),
          onTap: () => _openDetail(index, item),
          child: V2Card(
            key: index == 0
                ? const Key('assessment_history_current_meta')
                : Key('assessment_history_${item.id}'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        index == 0 ? '현재 결과' : '이전 결과 $index',
                        style: V2Text.bodyStrong,
                      ),
                    ),
                    Text(item.version, style: V2Text.cap),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: V2Colors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.result.overallTendency, style: V2Text.body),
                const SizedBox(height: 8),
                Text(
                  '전체 점수 ${item.result.overallScore}점$dateLabel · 전체 ${_history?.length ?? 0}회 기록',
                  style: V2Text.cap,
                ),
                if (index == 0 && _comparison != null) ...[
                  const SizedBox(height: 12),
                  _comparisonCard(_comparison!),
                ],
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
                            color: V2Colors.soft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${dimension.title} ${dimension.score}점',
                            style: V2Text.cap,
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
                      color: V2Colors.rose600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.answers.isEmpty
                          ? '선택 답변 상세 보기'
                          : '${item.answers.length}개 문항의 선택 답변 보기',
                      style: V2Text.cap.copyWith(
                        color: V2Colors.rose600,
                        fontWeight: FontWeight.w700,
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

  Widget _emptyState() => const V2EmptyState(
    title: '아직 완료한 기록이 없어요',
    body: '검사를 마치면 결과가 이곳에 보관돼요. 다시 검사해도 이전 기록은 사라지지 않아요.',
  );

  Widget _errorState() => KeyedSubtree(
    key: const Key('assessment_history_error'),
    child: V2ErrorState(
      title: '과거 결과를 불러오지 못했어요',
      body: _errorMessage,
      onRetry: _load,
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
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(title: '$resultLabel 상세'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Text(title, style: V2Text.title),
            const SizedBox(height: 6),
            Text('이 기록은 읽기 전용이에요. 당시 선택한 답변은 바꿀 수 없어요.', style: V2Text.cap),
            const SizedBox(height: 16),
            V2Card(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resultLabel, style: V2Text.bodyStrong),
                  const SizedBox(height: 8),
                  Text(item.result.overallTendency, style: V2Text.body),
                  const SizedBox(height: 8),
                  Text(
                    '전체 점수 ${item.result.overallScore}점 · ${item.version}',
                    style: V2Text.cap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('당시 선택한 답변', style: V2Text.head),
            const SizedBox(height: 8),
            if (item.answers.isEmpty)
              V2Card(
                padding: const EdgeInsets.all(18),
                color: V2Colors.soft,
                child: Text(
                  '이 기록에는 문항별 선택 정보가 아직 포함되어 있지 않아요.',
                  style: V2Text.cap,
                ),
              )
            else
              for (final answer in item.answers) _answerDetailCard(answer),
          ],
        ),
      ),
    );
  }
}

Widget _answerDetailCard(AssessmentHistoryAnswer answer) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: V2Card(
      padding: const EdgeInsets.all(14),
      color: V2Colors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (answer.dimensionTitle != null &&
                  answer.dimensionTitle!.isNotEmpty) ...[
                Text(
                  answer.dimensionTitle!,
                  style: V2Text.cap.copyWith(
                    color: V2Colors.rose600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(' · ', style: V2Text.cap),
              ],
              Text('문항 ${answer.order}', style: V2Text.cap),
            ],
          ),
          const SizedBox(height: 4),
          Text(answer.prompt, style: V2Text.body),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('선택한 답변', style: V2Text.cap),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: V2Colors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${answer.value} · ${answer.label}',
                  style: V2Text.cap.copyWith(
                    color: V2Colors.rose600,
                    fontWeight: FontWeight.w700,
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
