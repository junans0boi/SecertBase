import 'package:flutter/material.dart';

import '../../core/assessment_attempt_api.dart';
import '../../core/assessment_catalog_api.dart';
import 'package:secret_base_app/v2/v2.dart';
import '../auth/partner_screen.dart';
import 'assessment_ui.dart';

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
  ExplanationState? _explanationState;
  String? _errorMessage;
  String? _savingQuestion;
  bool _submitting = false;
  bool _loadingExplanation = false;
  bool _loading = true;
  bool _requiresCoupleConnection = false;
  int _questionIndex = 0;

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
      _requiresCoupleConnection = false;
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
        _requiresCoupleConnection =
            error is AssessmentAttemptApiException &&
            error.reason == 'active_couple_required';
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
      ExplanationState? explanation;
      try {
        explanation = await widget.api.fetchPersonalExplanation(
          widget.assessment.code,
        );
      } catch (_) {
        // The deterministic result remains usable when explanation status cannot load.
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _explanationState = explanation;
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

  Future<void> _requestExplanation() async {
    if (widget.isCouple || _loadingExplanation) return;
    setState(() => _loadingExplanation = true);
    try {
      final state = await widget.api.requestPersonalExplanation(
        widget.assessment.code,
      );
      if (!mounted) return;
      setState(() {
        _explanationState = state;
        _loadingExplanation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingExplanation = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) => switch (error) {
    AssessmentAttemptApiException(reason: 'network_error') =>
      '네트워크 연결을 확인하고 다시 시도해 주세요. 답변은 저장돼 있어요.',
    AssessmentAttemptApiException(reason: 'invalid_answer_value') =>
      '답변은 1점부터 5점까지 골라 주세요.',
    AssessmentAttemptApiException(reason: 'incomplete_attempt') =>
      '모든 문항에 답변한 뒤 제출할 수 있어요.',
    AssessmentAttemptApiException(reason: 'attempt_not_in_progress') =>
      '이미 제출된 검사예요.',
    AssessmentAttemptApiException(reason: 'active_couple_required') =>
      '파트너와 연결하면 함께 하는 검사를 할 수 있어요.',
    AssessmentAttemptApiException() => '검사를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
    _ => '검사를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(title: widget.assessment.title),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 2),
              )
            : _errorMessage != null && _attempt == null
            ? _errorState()
            : widget.isCouple && _coupleState != null
            ? _coupleStateContent()
            : _result != null
            ? _resultContent()
            : _content(),
        bottomNavigationBar:
            !_loading &&
                _attempt != null &&
                _result == null &&
                _coupleState == null
            ? _questionNavigation()
            : null,
      ),
    );
  }

  Widget _content() {
    final attempt = _attempt!;
    final selected = attempt.answerByQuestion;
    final progress = attempt.progress;
    final total = widget.assessment.questions.length;
    final q = widget.assessment.questions[_questionIndex];
    return ListView(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 32),
      children: [
        Text(
          widget.isCouple ? '함께 하는 검사' : '지금 나와 가까운 쪽을 골라 주세요',
          style: V2Text.title,
        ),
        const SizedBox(height: 6),
        Text(
          '${assessmentSizeLabel(total)} · 정답은 없어요. '
          '${widget.isCouple ? '각자의 답변은 서로에게 공개되지 않고, ' : ''}선택할 때마다 저장돼서 나중에 이어서 할 수 있어요.',
          style: V2Text.cap,
        ),
        const SizedBox(height: 14),
        V2Card(
          key: const Key('assessment_attempt_progress'),
          variant: V2CardVariant.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.answeredCount}/${progress.totalCount} 문항 저장됨',
                    style: V2Text.bodyStrong,
                  ),
                  Text('${progress.percentage}%', style: V2Text.bodyStrong),
                ],
              ),
              const SizedBox(height: 10),
              V2ProgressBar(
                value: progress.totalCount == 0
                    ? 0
                    : progress.answeredCount / progress.totalCount,
                semanticLabel:
                    '${progress.totalCount}문항 중 ${progress.answeredCount}문항 답변',
              ),
              const SizedBox(height: 6),
              Text(
                _savingQuestion == null ? '마지막 저장 상태를 반영했어요.' : '저장 중이에요…',
                style: V2Text.cap,
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          KeyedSubtree(
            key: const Key('assessment_attempt_error'),
            child: V2Banner(tone: V2BannerTone.err, message: _errorMessage!),
          ),
        ],
        const SizedBox(height: 14),
        _questionCard(_questionIndex, q, selected[q.key]),
      ],
    );
  }

  Widget _questionNavigation() {
    final isLast = _questionIndex == widget.assessment.questions.length - 1;
    final progress = _attempt!.progress;
    final canSubmit = progress.answeredCount >= progress.totalCount;
    final p = V2Palette.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: p.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.page,
            10,
            V2Space.page,
            14,
          ),
          child: Row(
            children: [
              Expanded(
                child: V2Button(
                  key: const Key('assessment_previous'),
                  label: '이전',
                  variant: V2ButtonVariant.ghost,
                  onPressed: _questionIndex == 0
                      ? null
                      : () => setState(() => _questionIndex--),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: V2Button(
                  key: isLast
                      ? const Key('assessment_submit')
                      : const Key('assessment_next'),
                  label: isLast ? '검사 제출하기' : '다음',
                  loading: _submitting,
                  onPressed: _submitting
                      ? null
                      : isLast
                      ? (canSubmit ? _submit : null)
                      : () => setState(() => _questionIndex++),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRow(String title, String score, double? ratio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: V2Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: V2Text.bodyStrong)),
                Text(
                  score,
                  style: V2Text.bodyStrong.copyWith(
                    color: V2Palette.of(context).primary,
                  ),
                ),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 8),
              V2ProgressBar(
                value: ratio.clamp(0, 1).toDouble(),
                semanticLabel: '$title $score',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scaleNote(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      key: const Key('assessment_score_note'),
      style: V2Text.cap,
    ),
  );

  Widget _resultContent() {
    final result = _result!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 32),
      children: [
        Text('검사 결과', style: V2Text.title),
        const SizedBox(height: 6),
        Text('지금의 응답을 바탕으로 정리한 자기이해용 결과예요.', style: V2Text.cap),
        const SizedBox(height: 16),
        V2Card(
          key: const Key('assessment_result_summary'),
          gradient: V2Gradients.heroSoft,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전체 경향', style: V2Text.cap),
              const SizedBox(height: 4),
              Text(result.overallTendency, style: V2Text.head),
              const SizedBox(height: 10),
              Text('전체 점수 ${result.overallScore}점', style: V2Text.bodyStrong),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _scaleNote(
          '점수는 100점 만점이고, 높을수록 그 영역의 경향이 뚜렷하다는 뜻이에요. 좋고 나쁨을 가리는 점수가 아니에요.',
        ),
        ...result.dimensions.map(
          (d) => _scoreRow(d.title, '${d.score}점', d.score / 100),
        ),
        const SizedBox(height: 4),
        Text(
          result.disclaimer,
          key: const Key('assessment_result_disclaimer'),
          style: V2Text.cap,
        ),
        const SizedBox(height: 16),
        V2Card(
          key: const Key('personal_explanation_card'),
          variant: V2CardVariant.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('쉬운 말로 풀어 보기', style: V2Text.head),
              const SizedBox(height: 6),
              Text(
                _explanationState?.generation?.explanation ??
                    '원할 때만 결과를 쉬운 말로 풀어 볼 수 있어요. AI가 쓴 설명이에요.',
                style: V2Text.body,
              ),
              const SizedBox(height: 10),
              if (_explanationState?.status == 'pending' || _loadingExplanation)
                Text('설명을 준비하고 있어요…', style: V2Text.cap)
              else
                V2Button(
                  key: const Key('request_personal_explanation'),
                  label: _explanationState == null ? '설명 요청하기' : '다시 생성하기',
                  variant: V2ButtonVariant.soft,
                  size: V2ButtonSize.sm,
                  fullWidth: false,
                  onPressed: _requestExplanation,
                ),
              if (_explanationState?.status == 'fallback')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '기본 설명을 보여 드리고 있어요. 핵심 점수와 판정은 바뀌지 않아요.',
                    key: const Key('personal_explanation_fallback'),
                    style: V2Text.cap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coupleStateContent() {
    final state = _coupleState!;
    if (state.result == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 32),
        children: [
          Text('파트너 응답을 기다리고 있어요', style: V2Text.title),
          const SizedBox(height: 8),
          Text(
            '${state.completedMemberCount}/${state.requiredMemberCount}명이 완료했어요. 파트너가 같은 검사를 마치면 함께 보는 결과가 열려요.',
            key: const Key('couple_assessment_pending'),
            style: V2Text.body,
          ),
          const SizedBox(height: 16),
          V2Card(
            variant: V2CardVariant.soft,
            child: Text(
              '각자의 답변과 개인별 점수는 서로에게 공개되지 않아요. 두 사람이 모두 마쳤다는 신호만 결과를 만드는 데 써요.',
              style: V2Text.body,
            ),
          ),
        ],
      );
    }
    final result = state.result!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 32),
      children: [
        Text('두 사람의 관계 결과', style: V2Text.title),
        const SizedBox(height: 6),
        Text('개인별 답변은 공개하지 않고, 두 사람의 조합만 정리했어요.', style: V2Text.cap),
        const SizedBox(height: 16),
        V2Card(
          key: const Key('couple_assessment_result_summary'),
          gradient: V2Gradients.heroSoft,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('관계 조합', style: V2Text.cap),
              const SizedBox(height: 4),
              Text(result.relationshipPattern, style: V2Text.head),
              const SizedBox(height: 10),
              Text(
                '관계 점수 ${result.overallScore}점 · 조율도 ${result.overallAlignmentScore}점',
                style: V2Text.bodyStrong,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _scaleNote(
          '조합은 두 사람의 답이 어우러지는 정도, 조율도는 서로의 답이 가까운 정도예요. 높다고 더 좋은 사이라는 뜻은 아니에요.',
        ),
        ...result.dimensions.map(
          (d) => _scoreRow(
            d.title,
            '조합 ${d.pairScore} · 조율 ${d.alignmentScore}',
            null,
          ),
        ),
        if (result.conversationPrompts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('대화 질문', style: V2Text.head),
          const SizedBox(height: 8),
          ...result.conversationPrompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: V2Card(
                variant: V2CardVariant.soft,
                child: Text(prompt, style: V2Text.body),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          result.disclaimer,
          key: const Key('couple_assessment_result_disclaimer'),
          style: V2Text.cap,
        ),
      ],
    );
  }

  Widget _questionCard(int index, AssessmentQuestion question, int? selected) {
    final p = V2Palette.of(context);
    final scale = question.likertScale;
    final first = scale.isEmpty ? null : scale.first;
    final last = scale.isEmpty ? null : scale.last;
    final current = scale.where((o) => o.value == selected).firstOrNull;
    return V2Card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '문항 ${index + 1} / ${widget.assessment.questions.length}',
            style: V2Text.label.copyWith(color: p.primary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(question.prompt, style: V2Text.head),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final option in scale)
                _likertButton(option, selected == option.value, question.key),
            ],
          ),
          const SizedBox(height: 8),
          if (first != null && last != null)
            Row(
              key: const Key('assessment_likert_labels'),
              children: [
                Expanded(
                  child: Text(
                    '${first.value} ${first.label}',
                    style: V2Text.cap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${last.value} ${last.label}',
                    textAlign: TextAlign.end,
                    style: V2Text.cap,
                  ),
                ),
              ],
            ),
          if (current != null) ...[
            const SizedBox(height: 10),
            Text(
              '고른 답: ${current.value} ${current.label}',
              style: V2Text.bodyStrong.copyWith(color: p.ink),
            ),
          ],
          if (scale.length > 2)
            Material(
              type: MaterialType.transparency,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('assessment_scale_help'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    '점수가 무슨 뜻인가요?',
                    style: V2Text.cap.copyWith(color: p.primary),
                  ),
                  children: [
                    for (final o in scale)
                      Text('${o.value}점 · ${o.label}', style: V2Text.cap),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _likertButton(LikertOption option, bool selected, String questionKey) {
    final p = V2Palette.of(context);
    final enabled = _savingQuestion == null;
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.value}점, ${option.label}',
      onTap: enabled ? () => _saveAnswer(questionKey, option.value) : null,
      child: ExcludeSemantics(
        child: InkWell(
          key: Key('likert_${option.value}'),
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _saveAnswer(questionKey, option.value) : null,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? p.primary : p.surface,
              border: Border.all(
                color: selected ? p.primary : p.control,
                width: 1.5,
              ),
            ),
            child: Text(
              '${option.value}',
              style: V2Text.bodyStrong.copyWith(
                color: selected ? p.onPrimary : p.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    final partner = _requiresCoupleConnection;
    return Column(
      key: Key(
        partner
            ? 'assessment_attempt_couple_restricted'
            : 'assessment_attempt_load_error',
      ),
      children: [
        Expanded(
          child: V2ErrorState(
            title: partner ? '파트너와 연결해 주세요' : '검사를 시작하지 못했어요',
            body: _errorMessage,
            onRetry: partner ? null : _startOrResume,
          ),
        ),
        if (partner)
          Padding(
            padding: const EdgeInsets.all(V2Space.page),
            child: V2Button(
              label: '파트너 연결하기',
              variant: V2ButtonVariant.soft,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const PartnerScreen()),
              ),
            ),
          ),
      ],
    );
  }
}
