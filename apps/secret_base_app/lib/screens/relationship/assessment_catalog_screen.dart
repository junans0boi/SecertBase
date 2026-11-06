import 'package:flutter/material.dart';

import '../../core/assessment_attempt_api.dart';
import '../../core/assessment_catalog_api.dart';
import '../../core/auth_service.dart';
import 'package:secret_base_app/v2/v2.dart';
import '../auth/partner_screen.dart';
import 'assessment_attempt_screen.dart';
import 'assessment_history_screen.dart';
import 'assessment_ui.dart';

class AssessmentCatalogScreen extends StatefulWidget {
  final AssessmentCatalogApi api;
  final bool hasActiveCouple;
  final AssessmentAudience? audienceFilter;

  const AssessmentCatalogScreen({
    super.key,
    required this.api,
    this.hasActiveCouple = false,
    this.audienceFilter,
  });

  @override
  State<AssessmentCatalogScreen> createState() =>
      _AssessmentCatalogScreenState();
}

class _AssessmentCatalogScreenState extends State<AssessmentCatalogScreen> {
  List<AssessmentCatalogItem>? _assessments;
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
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final assessments = await widget.api.fetch();
      if (!mounted) return;
      setState(() {
        _assessments = assessments;
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

  String _messageFor(Object error) => switch (error) {
    AssessmentCatalogApiException(reason: 'network_error') =>
      '네트워크 연결을 확인하고 다시 시도해 주세요.',
    AssessmentCatalogApiException() => '잠시 뒤 다시 시도해 주세요.',
    _ => '잠시 뒤 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '심리검사'),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 3),
              )
            : _errorMessage != null
            ? KeyedSubtree(
                key: const Key('assessment_catalog_error'),
                child: V2ErrorState(
                  title: '검사 목록을 불러오지 못했어요',
                  body: _errorMessage,
                  onRetry: _load,
                ),
              )
            : _assessments == null || _assessments!.isEmpty
            ? const V2EmptyState(
                title: '현재 준비된 검사가 없어요',
                body: '새 검사가 생기면 여기에서 만날 수 있어요.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  V2Space.page,
                  4,
                  V2Space.page,
                  32,
                ),
                children: [
                  Text(
                    widget.audienceFilter == AssessmentAudience.couple
                        ? '우리의 관계를 이해하는 검사'
                        : '나를 이해하는 검사',
                    style: V2Text.title,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '답변은 저장되고, 제출하면 결과가 기록돼요. 다시 검사해도 이전 기록은 남아 있어요. 출생 정보는 필요 없어요.',
                    style: V2Text.cap,
                  ),
                  const SizedBox(height: 18),
                  if (widget.audienceFilter == null) ...[
                    _section(
                      '개인 검사',
                      _assessments!
                          .where(
                            (a) => a.audience == AssessmentAudience.individual,
                          )
                          .toList(),
                      enabled: true,
                    ),
                    const SizedBox(height: 18),
                    _section(
                      '커플 검사',
                      _assessments!
                          .where((a) => a.audience == AssessmentAudience.couple)
                          .toList(),
                      enabled: widget.hasActiveCouple,
                    ),
                  ] else
                    _section(
                      widget.audienceFilter == AssessmentAudience.couple
                          ? '커플 검사'
                          : '개인 검사',
                      _assessments!
                          .where((a) => a.audience == widget.audienceFilter)
                          .toList(),
                      enabled:
                          widget.audienceFilter ==
                              AssessmentAudience.individual ||
                          widget.hasActiveCouple,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _section(
    String title,
    List<AssessmentCatalogItem> assessments, {
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: V2Text.head),
            if (!enabled) ...[
              const SizedBox(width: 8),
              const V2Chip(
                label: '파트너 연결 후',
                tone: V2Tone.neutral,
                icon: V2Icons.lock,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ...assessments.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _assessmentCard(a, enabled: enabled),
          ),
        ),
      ],
    );
  }

  Widget _assessmentCard(
    AssessmentCatalogItem assessment, {
    required bool enabled,
  }) {
    final (statusText, statusTone) = switch (assessment.completionStatus) {
      AssessmentCompletionStatus.notStarted => ('시작 전', V2Tone.neutral),
      AssessmentCompletionStatus.inProgress => ('진행 중', V2Tone.honey),
      AssessmentCompletionStatus.completed => ('완료', V2Tone.ok),
    };
    final count = assessment.activeQuestionCount;
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: V2Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(assessment.title, style: V2Text.head)),
                if (enabled) V2Chip(label: statusText, tone: statusTone),
              ],
            ),
            const SizedBox(height: 6),
            Text(assessment.description, style: V2Text.body),
            const SizedBox(height: 10),
            Text(
              assessmentSizeLabel(count),
              style: V2Text.bodyStrong.copyWith(
                color: V2Palette.of(context).primary,
              ),
            ),
            if (assessment.dimensions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                assessment.dimensions.map((d) => d.title).join(' · '),
                style: V2Text.cap,
              ),
            ],
            const SizedBox(height: 14),
            if (!enabled)
              V2Button(
                label: '파트너 연결하기',
                variant: V2ButtonVariant.soft,
                onPressed: _openPartnerConnection,
              )
            else
              V2Button(
                key: Key('assessment_action_${assessment.code}'),
                label: _actionLabel(assessment),
                icon:
                    assessment.completionStatus ==
                        AssessmentCompletionStatus.completed
                    ? V2Icons.sparkle
                    : V2Icons.chevron,
                onPressed: () => _openPrimaryAction(assessment),
              ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(AssessmentCatalogItem assessment) =>
      switch (assessment.completionStatus) {
        AssessmentCompletionStatus.notStarted => '검사 시작하기',
        AssessmentCompletionStatus.inProgress => '검사 이어하기',
        AssessmentCompletionStatus.completed => '결과 보기',
      };

  void _openPrimaryAction(AssessmentCatalogItem assessment) {
    if (assessment.completionStatus == AssessmentCompletionStatus.completed) {
      _openHistory(assessment);
      return;
    }
    _openAssessment(assessment);
  }

  void _openPartnerConnection() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const PartnerScreen()));
  }

  void _openAssessment(AssessmentCatalogItem assessment) {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssessmentAttemptScreen(
          assessment: assessment,
          isCouple: assessment.audience == AssessmentAudience.couple,
          api: AssessmentAttemptApi(
            baseUrl: auth.baseUrl,
            token: auth.token ?? '',
          ),
        ),
      ),
    );
  }

  void _openHistory(AssessmentCatalogItem assessment) {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssessmentHistoryScreen(
          title: assessment.title,
          assessmentCode: assessment.code,
          api: AssessmentAttemptApi(
            baseUrl: auth.baseUrl,
            token: auth.token ?? '',
          ),
        ),
      ),
    );
  }
}
