import 'package:flutter/material.dart';

import '../../core/assessment_attempt_api.dart';
import '../../core/assessment_catalog_api.dart';
import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import 'assessment_attempt_screen.dart';
import 'assessment_history_screen.dart';

class AssessmentCatalogScreen extends StatefulWidget {
  final AssessmentCatalogApi api;
  final bool hasActiveCouple;

  const AssessmentCatalogScreen({
    super.key,
    required this.api,
    this.hasActiveCouple = false,
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
      '네트워크 연결을 확인하고 다시 시도해주세요.',
    AssessmentCatalogApiException() => '검사 목록을 불러오지 못했어요.',
    _ => '검사 목록을 불러오지 못했어요.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('검사 목록', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _errorMessage != null
          ? _errorState()
          : _assessments == null || _assessments!.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                Text('나를 이해하는 검사', style: mainTitle(size: 24)),
                const SizedBox(height: 6),
                Text(
                  '고정된 문항과 버전으로 진행 상태를 확인할 수 있어요.',
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 18),
                _section(
                  '개인 검사',
                  _assessments!
                      .where(
                        (assessment) =>
                            assessment.audience ==
                            AssessmentAudience.individual,
                      )
                      .toList(),
                  enabled: true,
                ),
                const SizedBox(height: 18),
                _section(
                  '커플 검사',
                  _assessments!
                      .where(
                        (assessment) =>
                            assessment.audience == AssessmentAudience.couple,
                      )
                      .toList(),
                  enabled: widget.hasActiveCouple,
                ),
              ],
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
            Text(title, style: mainTitle(size: 20)),
            if (!enabled) ...[
              const SizedBox(width: 8),
              Text('파트너 연결 후', style: mainBody(size: 12, color: kMainMuted)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...assessments.map(
          (assessment) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _assessmentCard(assessment, enabled: enabled),
          ),
        ),
      ],
    );
  }

  Widget _assessmentCard(
    AssessmentCatalogItem assessment, {
    required bool enabled,
  }) {
    final status = switch (assessment.completionStatus) {
      AssessmentCompletionStatus.notStarted => '아직 시작하지 않았어요',
      AssessmentCompletionStatus.inProgress => '진행 중이에요',
      AssessmentCompletionStatus.completed => '완료했어요',
    };
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: GestureDetector(
        onTap: enabled && assessment.audience == AssessmentAudience.individual
            ? () => _openAssessment(assessment)
            : null,
        child: MainCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      assessment.title,
                      style: mainBody(weight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    assessment.version,
                    style: mainBody(size: 12, color: kMainMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                assessment.description,
                style: mainBody(size: 13, color: kMainSub, height: 1.45),
              ),
              const SizedBox(height: 10),
              Text(
                '후보 ${assessment.candidateQuestionCount}문항 · 실제 ${assessment.activeQuestionCount}문항',
                style: mainBody(
                  size: 12,
                  color: kMainLilac,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                assessment.dimensions
                    .map((dimension) => dimension.title)
                    .join(' · '),
                style: mainBody(size: 12, color: kMainSub),
              ),
              const SizedBox(height: 8),
              Text(
                enabled ? status : '파트너 연결 후 이용할 수 있어요',
                style: mainBody(size: 12, color: kMainMuted),
              ),
              if (enabled &&
                  assessment.audience == AssessmentAudience.individual &&
                  assessment.completionStatus ==
                      AssessmentCompletionStatus.completed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _openHistory(assessment),
                    child: const Text('과거 결과 보기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAssessment(AssessmentCatalogItem assessment) {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssessmentAttemptScreen(
          assessment: assessment,
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

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: MainCard(
        key: const Key('assessment_catalog_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('검사 목록을 불러오지 못했어요', style: mainTitle(size: 20)),
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

  Widget _emptyState() => const Center(child: Text('현재 준비된 검사가 없어요'));
}
