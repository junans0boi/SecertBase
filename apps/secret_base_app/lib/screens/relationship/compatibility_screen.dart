import 'package:flutter/material.dart';

import '../../core/compatibility_api.dart';
import '../../core/main_design.dart';

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
      final state = widget.analysisCode == 'conflict-repair'
          ? await widget.api.fetchConflictRepair()
          : await widget.api.fetchAttachmentConflict();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            error is CompatibilityApiException &&
                error.reason == 'network_error'
            ? '네트워크 연결을 확인하고 다시 시도해주세요.'
            : '궁합 분석을 불러오지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('우리의 궁합 분석', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _errorMessage != null
          ? _errorState()
          : _state?.result == null
          ? _pendingState()
          : _readyState(_state!.result!),
    );
  }

  Widget _pendingState() {
    final dependencies = _state?.dependencyStatus ?? const <String, int>{};
    final attachmentCount = dependencies['attachment'] ?? 0;
    final conflictCount = dependencies['conflictRepair'] ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text('분석을 준비하고 있어요', style: mainTitle(size: 25)),
        const SizedBox(height: 8),
        Text(
          '두 사람의 애착 요약과 갈등·회복 검사가 모두 준비되면 이 공간이 열려요.',
          key: const Key('compatibility_pending'),
          style: mainBody(size: 14, color: kMainSub, height: 1.55),
        ),
        const SizedBox(height: 16),
        MainCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('준비 상태', style: mainBody(weight: FontWeight.w800)),
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

  Widget _readyState(CompatibilityAnalysis result) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
    children: [
      Text('우리의 관계 패턴', style: mainTitle(size: 25)),
      const SizedBox(height: 8),
      Text(
        result.complementaryPattern,
        key: const Key('compatibility_ready'),
        style: mainBody(size: 15, color: kMainSub, height: 1.55),
      ),
      const SizedBox(height: 16),
      ...result.dimensions.map(
        (dimension) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MainCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text(dimension.title)),
                Text(
                  '차이 ${dimension.scoreDifference}점',
                  style: mainBody(color: kMainLilac, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      if (result.conflictTrigger != null || result.repairApproach != null) ...[
        Text('갈등을 이해하는 단서', style: mainTitle(size: 19)),
        const SizedBox(height: 8),
        if (result.conflictTrigger != null)
          MainCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              result.conflictTrigger!,
              key: const Key('compatibility_conflict_trigger'),
              style: mainBody(size: 13, height: 1.45),
            ),
          ),
        if (result.repairApproach != null) ...[
          const SizedBox(height: 8),
          MainCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              result.repairApproach!,
              key: const Key('compatibility_repair_approach'),
              style: mainBody(size: 13, height: 1.45),
            ),
          ),
        ],
      ],
      if (result.conversationStarters.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('대화 시작점', style: mainTitle(size: 19)),
        const SizedBox(height: 8),
        ...result.conversationStarters.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MainCard(
              padding: const EdgeInsets.all(14),
              child: Text(item, style: mainBody(size: 13, height: 1.45)),
            ),
          ),
        ),
      ],
      Text('주의해서 살펴볼 상호작용', style: mainTitle(size: 19)),
      const SizedBox(height: 8),
      ...result.cautionInteractions.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MainCard(
            padding: const EdgeInsets.all(14),
            child: Text(item, style: mainBody(size: 13, height: 1.45)),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text('대화 질문', style: mainTitle(size: 19)),
      const SizedBox(height: 8),
      ...result.conversationPrompts.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MainCard(
            padding: const EdgeInsets.all(14),
            child: Text(item, style: mainBody(size: 13, height: 1.45)),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        result.disclaimer,
        style: mainBody(size: 12, color: kMainMuted, height: 1.5),
      ),
    ],
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: MainCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('궁합 분석을 불러오지 못했어요', style: mainTitle(size: 20)),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      ),
    ),
  );
}
