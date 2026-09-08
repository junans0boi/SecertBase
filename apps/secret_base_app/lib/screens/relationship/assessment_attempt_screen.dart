import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/assessment_attempt_api.dart';
import '../../core/assessment_catalog_api.dart';
import '../../core/main_design.dart';

class AssessmentAttemptScreen extends StatefulWidget {
  final AssessmentCatalogItem assessment;
  final AssessmentAttemptApi api;
  final bool isCouple;

  const AssessmentAttemptScreen({
    super.key,
    required this.assessment,
    required this.api,
    this.isCouple = false,
  });

  @override
  State<AssessmentAttemptScreen> createState() =>
      _AssessmentAttemptScreenState();
}

class _AssessmentAttemptScreenState extends State<AssessmentAttemptScreen> {
  AssessmentAttempt? _attempt;
  AssessmentResult? _result;
  CoupleAssessmentState? _coupleState;
  String? _errorMessage;
  String? _savingQuestion;
  bool _submitting = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _startOrResume();
  }

  @override
  void dispose() {
    widget.api.close();
    super.dispose();
  }

  Future<void> _startOrResume() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final attempt = widget.isCouple
          ? await widget.api.startCoupleOrResume(widget.assessment.code)
          : await widget.api.startOrResume(widget.assessment.code);
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  Future<void> _saveAnswer(String questionKey, int value) async {
    final attempt = _attempt;
    if (attempt == null || _savingQuestion != null) return;
    setState(() {
      _savingQuestion = questionKey;
      _errorMessage = null;
    });
    try {
      final updated = await widget.api.saveAnswer(
        attempt.id,
        questionKey,
        value,
      );
      if (!mounted) return;
      setState(() {
        _attempt = updated;
        _savingQuestion = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingQuestion = null;
        _errorMessage = _messageFor(error);
      });
    }
  }

  Future<void> _submit() async {
    final attempt = _attempt;
    if (attempt == null ||
        attempt.progress.answeredCount < attempt.progress.totalCount ||
        _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      if (widget.isCouple) {
        final state = await widget.api.submitCouple(attempt.id);
        if (!mounted) return;
        setState(() {
          _coupleState = state;
          _submitting = false;
        });
        return;
      }
      final result = await widget.api.submit(attempt.id);
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) => switch (error) {
    AssessmentAttemptApiException(reason: 'network_error') =>
      '네트워크 연결을 확인하고 다시 시도해주세요.',
    AssessmentAttemptApiException(reason: 'invalid_answer_value') =>
      '답변은 1점부터 5점까지 선택해주세요.',
    AssessmentAttemptApiException(reason: 'incomplete_attempt') =>
      '모든 문항에 답변한 뒤 제출할 수 있어요.',
    AssessmentAttemptApiException(reason: 'attempt_not_in_progress') =>
      '이미 제출된 검사예요.',
    AssessmentAttemptApiException(reason: 'active_couple_required') =>
      '활성 커플 연결이 필요해요.',
    AssessmentAttemptApiException() => '검사 시도를 불러오지 못했어요.',
    _ => '검사 시도를 불러오지 못했어요.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text(widget.assessment.title, style: mainTitle(size: 21)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _errorMessage != null && _attempt == null
          ? _errorState()
          : widget.isCouple && _coupleState != null
          ? _coupleStateContent()
          : _result != null
          ? _resultContent()
          : _content(),
    );
  }

  Widget _content() {
    final attempt = _attempt!;
    final selected = attempt.answerByQuestion;
    final progress = attempt.progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text(
          widget.isCouple ? '커플 검사 진행 중' : '검사 진행 중',
          style: mainTitle(size: 25),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isCouple
              ? '각자의 답변은 서로에게 공개되지 않으며, 선택할 때마다 저장돼요.'
              : '답변은 선택할 때마다 저장되며, 나중에 이어서 할 수 있어요.',
          style: mainBody(size: 13, color: kMainSub, height: 1.5),
        ),
        const SizedBox(height: 16),
        MainCard(
          key: const Key('assessment_attempt_progress'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.answeredCount}/${progress.totalCount} 문항 저장됨',
                  ),
                  Text('${progress.percentage}%'),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress.totalCount == 0
                    ? 0
                    : progress.answeredCount / progress.totalCount,
                color: kMainRose,
                backgroundColor: kMainRoseSoft,
              ),
              const SizedBox(height: 8),
              Text(
                _savingQuestion == null ? '마지막 저장 상태를 반영했어요.' : '저장 중이에요…',
                style: mainBody(size: 12, color: kMainMuted),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            key: const Key('assessment_attempt_error'),
            style: mainBody(size: 13, color: kError),
          ),
        ],
        const SizedBox(height: 18),
        ...widget.assessment.questions.asMap().entries.map(
          (entry) =>
              _questionCard(entry.key, entry.value, selected[entry.value.key]),
        ),
        if (progress.answeredCount >= progress.totalCount) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('assessment_submit'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('검사 제출하기'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultContent() {
    final result = _result!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text('검사 결과', style: mainTitle(size: 25)),
        const SizedBox(height: 6),
        Text(
          '지금의 응답을 바탕으로 정리한 자기이해용 결과예요.',
          style: mainBody(size: 13, color: kMainSub, height: 1.5),
        ),
        const SizedBox(height: 16),
        MainCard(
          key: const Key('assessment_result_summary'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전체 경향', style: mainBody(size: 12, color: kMainSub)),
              const SizedBox(height: 5),
              Text(
                result.overallTendency,
                style: mainBody(size: 16, weight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                '전체 점수 ${result.overallScore}점',
                style: mainBody(weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...result.dimensions.map(
          (dimension) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MainCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dimension.title,
                      style: mainBody(weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${dimension.score}점',
                    style: mainBody(color: kMainLilac, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.disclaimer,
          key: const Key('assessment_result_disclaimer'),
          style: mainBody(size: 12, color: kMainMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _coupleStateContent() {
    final state = _coupleState!;
    if (state.result == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Text('파트너 응답을 기다리는 중', style: mainTitle(size: 25)),
          const SizedBox(height: 8),
          Text(
            '${state.completedMemberCount}/${state.requiredMemberCount}명이 완료했어요. 파트너가 같은 검사를 마치면 공유 결과가 열려요.',
            key: const Key('couple_assessment_pending'),
            style: mainBody(size: 14, color: kMainSub, height: 1.55),
          ),
          const SizedBox(height: 16),
          MainCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              '각자의 답변과 개인별 점수는 서로에게 공개되지 않아요. 두 사람의 완료 신호만 공유 결과 생성에 사용돼요.',
              style: mainBody(size: 13, color: kMainSub, height: 1.55),
            ),
          ),
        ],
      );
    }

    final result = state.result!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text('두 사람의 관계 결과', style: mainTitle(size: 25)),
        const SizedBox(height: 6),
        Text(
          '개인별 답변은 공개하지 않고, 두 사람의 조합만 정리했어요.',
          style: mainBody(size: 13, color: kMainSub, height: 1.5),
        ),
        const SizedBox(height: 16),
        MainCard(
          key: const Key('couple_assessment_result_summary'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('관계 조합', style: mainBody(size: 12, color: kMainSub)),
              const SizedBox(height: 5),
              Text(
                result.relationshipPattern,
                style: mainBody(size: 16, weight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                '관계 점수 ${result.overallScore}점 · 조율도 ${result.overallAlignmentScore}점',
                style: mainBody(weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...result.dimensions.map(
          (dimension) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MainCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dimension.title,
                      style: mainBody(weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '조합 ${dimension.pairScore} · 조율 ${dimension.alignmentScore}',
                    style: mainBody(color: kMainLilac, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.disclaimer,
          key: const Key('couple_assessment_result_disclaimer'),
          style: mainBody(size: 12, color: kMainMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _questionCard(int index, AssessmentQuestion question, int? selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MainCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '문항 ${index + 1}',
              style: mainBody(size: 12, color: kMainLilac),
            ),
            const SizedBox(height: 8),
            Text(question.prompt, style: mainBody(size: 15, height: 1.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: question.likertScale
                  .map(
                    (option) => ChoiceChip(
                      label: Text('${option.value}'),
                      selected: selected == option.value,
                      onSelected: _savingQuestion == null
                          ? (_) => _saveAnswer(question.key, option.value)
                          : null,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Text(
              question.likertScale
                  .map((option) => '${option.value} ${option.label}')
                  .join(' · '),
              style: mainBody(size: 11, color: kMainMuted, height: 1.4),
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
        key: const Key('assessment_attempt_load_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('검사를 시작하지 못했어요', style: mainTitle(size: 20)),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: mainBody(size: 13, color: kMainSub),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _startOrResume,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    ),
  );
}
