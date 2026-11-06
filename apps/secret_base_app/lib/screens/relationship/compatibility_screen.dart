import 'package:flutter/material.dart';

import '../../core/compatibility_api.dart';
import 'package:secret_base_app/v2/v2.dart';
import '../auth/partner_screen.dart';

Widget _compatibilityRestrictedState(BuildContext context) => Column(
  key: const Key('compatibility_restricted'),
  children: [
    const Expanded(
      child: V2EmptyState(
        icon: V2Icons.lock,
        title: '파트너와 연결하면 궁합을 볼 수 있어요',
        body: '커플 검사와 궁합은 연결된 두 사람에게만 보여요.',
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(V2Space.page),
      child: V2Button(
        label: '파트너 연결하기',
        variant: V2ButtonVariant.soft,
        onPressed: () => Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const PartnerScreen())),
      ),
    ),
  ],
);

class CompatibilityDashboardScreen extends StatefulWidget {
  final CompatibilityApi api;

  const CompatibilityDashboardScreen({super.key, required this.api});

  @override
  State<CompatibilityDashboardScreen> createState() =>
      _CompatibilityDashboardScreenState();
}

class _CompatibilityDashboardScreenState
    extends State<CompatibilityDashboardScreen> {
  CompatibilityDashboard? _dashboard;
  String? _errorMessage;
  bool _restricted = false;
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
      _restricted = false;
    });
    try {
      final dashboard = await widget.api.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _restricted =
            error is CompatibilityApiException &&
            error.reason == 'active_couple_required';
        _errorMessage =
            error is CompatibilityApiException &&
                error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해 주세요.'
            : _restricted
            ? '파트너와 연결하면 궁합을 볼 수 있어요.'
            : '잠시 뒤 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '우리의 궁합'),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 3),
              )
            : _restricted
            ? _restrictedState()
            : _errorMessage != null
            ? _errorState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  Text('검사별 관계 카드', style: V2Text.title),
                  const SizedBox(height: 6),
                  Text('각 분석은 필요한 검사만 준비되면 독립적으로 열려요.', style: V2Text.cap),
                  const SizedBox(height: 16),
                  ...?_dashboard?.cards.map(_card),
                ],
              ),
      ),
    );
  }

  Widget _card(CompatibilityDashboardCard card) {
    final statusLabel = switch (card.state.status) {
      'ready' => '결과 준비됨',
      'pending' => '기다리는 중',
      _ => '아직 이용할 수 없어요',
    };
    final cardContent = V2Card(
      key: Key('compatibility_card_${card.code}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(card.title, style: V2Text.bodyStrong)),
              V2Chip(
                label: statusLabel,
                tone: switch (card.state.status) {
                  'ready' => V2Tone.lilac,
                  'pending' => V2Tone.honey,
                  _ => V2Tone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(card.description, style: V2Text.cap),
          const SizedBox(height: 10),
          if (card.state.status == 'ready' && card.state.result != null)
            Text(card.state.result!.complementaryPattern, style: V2Text.body)
          else if (card.state.status == 'pending')
            Text(
              _pendingDescription(card.state),
              key: Key('compatibility_pending_${card.code}'),
              style: V2Text.cap,
            )
          else
            Text('필요한 결과를 확인한 뒤 다시 준비할 수 있어요.', style: V2Text.cap),
          if (card.state.status == 'ready') ...[
            const SizedBox(height: 8),
            V2Button(
              label: '상세 보기',
              variant: V2ButtonVariant.text,
              size: V2ButtonSize.sm,
              fullWidth: false,
              onPressed: () => _openDetail(card.code),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: cardContent,
    );
  }

  String _pendingDescription(CompatibilityState state) {
    if (state.dependencyStatus.isEmpty) return '필요한 검사가 아직 완료되지 않았어요.';
    return state.dependencyStatus.entries
        .map((entry) => '${_assessmentLabel(entry.key)} ${entry.value}/2명 완료')
        .join(' · ');
  }

  String _assessmentLabel(String code) => switch (code) {
    'attachment' => '애착 검사',
    'conflictRepair' || 'conflict_repair' => '갈등·회복 검사',
    'social_bonding' => '사회적 유대 검사',
    'emotional_regulation' => '감정 해소 검사',
    'relationship_deficiency' => '관계 결핍 인식 검사',
    'togetherness_personal_time' => '함께 있음과 개인 시간 검사',
    'affection_alignment' => '애정 표현과 기대 검사',
    _ => '관계 검사',
  };

  void _openDetail(String code) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CompatibilityScreen(
          analysisCode: code,
          api: CompatibilityApi(
            baseUrl: widget.api.baseUrl,
            token: widget.api.token,
          ),
        ),
      ),
    );
  }

  Widget _errorState() => V2ErrorState(
    title: '궁합 분석을 불러오지 못했어요',
    body: _errorMessage,
    onRetry: _load,
  );

  Widget _restrictedState() => _compatibilityRestrictedState(context);
}

class CompatibilityScreen extends StatefulWidget {
  final CompatibilityApi api;
  final String analysisCode;

  const CompatibilityScreen({
    super.key,
    required this.api,
    this.analysisCode = 'attachment-conflict',
  });

  @override
  State<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends State<CompatibilityScreen> {
  CompatibilityState? _state;
  CompatibilityExplanationState? _explanationState;
  String? _errorMessage;
  bool _restricted = false;
  bool _loading = true;
  bool _loadingExplanation = false;

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
      _restricted = false;
    });
    try {
      final state = widget.analysisCode == 'conflict-repair'
          ? await widget.api.fetchConflictRepair()
          : widget.analysisCode == 'attachment-conflict'
          ? await widget.api.fetchAttachmentConflict()
          : await widget.api.fetchPersonal(widget.analysisCode);
      CompatibilityExplanationState? explanation;
      if (state.result != null) {
        try {
          explanation = await widget.api.fetchExplanation(widget.analysisCode);
        } catch (_) {
          // The deterministic compatibility result remains usable on explanation errors.
        }
      }
      if (!mounted) return;
      setState(() {
        _state = state;
        _explanationState = explanation;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _restricted =
            error is CompatibilityApiException &&
            error.reason == 'active_couple_required';
        _errorMessage =
            error is CompatibilityApiException &&
                error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해 주세요.'
            : _restricted
            ? '파트너와 연결하면 궁합을 볼 수 있어요.'
            : '잠시 뒤 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _requestExplanation() async {
    if (_loadingExplanation) return;
    setState(() => _loadingExplanation = true);
    try {
      final state = await widget.api.requestExplanation(widget.analysisCode);
      if (!mounted) return;
      setState(() {
        _explanationState = state;
        _loadingExplanation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingExplanation = false;
        _errorMessage =
            error is CompatibilityApiException &&
                error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해 주세요.'
            : '궁합 설명을 생성하지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '우리의 궁합'),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 3),
              )
            : _restricted
            ? _restrictedState()
            : _errorMessage != null
            ? _errorState()
            : _state?.result == null
            ? _pendingState()
            : _readyState(_state!.result!),
      ),
    );
  }

  Widget _pendingState() {
    final dependencies = _state?.dependencyStatus ?? const <String, int>{};
    final attachmentCount = dependencies['attachment'] ?? 0;
    final conflictCount = dependencies['conflictRepair'] ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text('분석을 준비하고 있어요', style: V2Text.head),
        const SizedBox(height: 8),
        Text(
          '두 사람의 애착 요약과 갈등·회복 검사가 모두 준비되면 이 공간이 열려요.',
          key: const Key('compatibility_pending'),
          style: V2Text.cap,
        ),
        const SizedBox(height: 16),
        V2Card(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('준비 상태', style: V2Text.bodyStrong),
              const SizedBox(height: 10),
              Text('애착 요약 $attachmentCount/2명'),
              const SizedBox(height: 6),
              Text('갈등·회복 검사 $conflictCount/2명'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _readyState(CompatibilityAnalysis result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text('우리의 관계 패턴', style: V2Text.title),
        const SizedBox(height: 8),
        Text(
          result.complementaryPattern,
          key: const Key('compatibility_ready'),
          style: V2Text.cap,
        ),
        const SizedBox(height: 16),
        ...result.dimensions.map(
          (dimension) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: V2Card(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(dimension.title)),
                  Text(
                    '차이 ${dimension.scoreDifference}점',
                    style: V2Text.bodyStrong.copyWith(
                      color: V2Colors.lilacText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (result.conflictTrigger != null ||
            result.repairApproach != null) ...[
          Text('갈등을 이해하는 단서', style: V2Text.head),
          const SizedBox(height: 8),
          if (result.conflictTrigger != null)
            V2Card(
              padding: const EdgeInsets.all(14),
              child: Text(
                result.conflictTrigger!,
                key: const Key('compatibility_conflict_trigger'),
                style: V2Text.body,
              ),
            ),
          if (result.repairApproach != null) ...[
            const SizedBox(height: 8),
            V2Card(
              padding: const EdgeInsets.all(14),
              child: Text(
                result.repairApproach!,
                key: const Key('compatibility_repair_approach'),
                style: V2Text.body,
              ),
            ),
          ],
        ],
        if (result.conversationStarters.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('대화 시작점', style: V2Text.head),
          const SizedBox(height: 8),
          ...result.conversationStarters.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: V2Card(
                padding: const EdgeInsets.all(14),
                child: Text(item, style: V2Text.body),
              ),
            ),
          ),
        ],
        Text('주의해서 살펴볼 상호작용', style: V2Text.head),
        const SizedBox(height: 8),
        ...result.cautionInteractions.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: V2Card(
              padding: const EdgeInsets.all(14),
              child: Text(item, style: V2Text.body),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('대화 질문', style: V2Text.head),
        const SizedBox(height: 8),
        ...result.conversationPrompts.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: V2Card(
              padding: const EdgeInsets.all(14),
              child: Text(item, style: V2Text.body),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(result.disclaimer, style: V2Text.cap),
        const SizedBox(height: 16),
        V2Card(
          key: const Key('compatibility_explanation_card'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('자연어 설명', style: V2Text.bodyStrong),
              const SizedBox(height: 6),
              Text(
                _explanationState?.generation?.explanation ??
                    '원할 때만 두 사람의 구조화된 패턴을 자연어로 풀어볼 수 있어요.',
                style: V2Text.cap,
              ),
              const SizedBox(height: 10),
              if (_explanationState?.status == 'pending' || _loadingExplanation)
                const Text('설명을 준비하고 있어요…')
              else
                OutlinedButton(
                  key: const Key('request_compatibility_explanation'),
                  onPressed: _requestExplanation,
                  child: Text(
                    _explanationState == null ? '설명 요청하기' : '다시 생성하기',
                  ),
                ),
              if (_explanationState?.status == 'fallback')
                Text(
                  '고정 설명을 표시하고 있어요. 궁합 점수와 핵심 결과는 변하지 않아요.',
                  key: const Key('compatibility_explanation_fallback'),
                  style: V2Text.cap,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorState() => V2ErrorState(
    title: '궁합 분석을 불러오지 못했어요',
    body: _errorMessage,
    onRetry: _load,
  );

  Widget _restrictedState() => _compatibilityRestrictedState(context);
}
