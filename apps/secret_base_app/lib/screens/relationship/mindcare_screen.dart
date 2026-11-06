import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/auth_service.dart';
import '../../core/mindcare_api.dart';
import '../../core/safety_location.dart';
import 'care_safety.dart';
import 'care_settings_screen.dart';

class MindcareScreen extends StatefulWidget {
  final MindcareApi? api;
  final SafetyLocationProvider? locationProvider;

  const MindcareScreen({super.key, this.api, this.locationProvider});

  @override
  State<MindcareScreen> createState() => _MindcareScreenState();
}

class _MindcareScreenState extends State<MindcareScreen> {
  late final MindcareApi _api;
  late final SafetyLocationProvider _locationProvider;
  late final bool _ownsApi;
  final _textController = TextEditingController();
  final _scroll = ScrollController();
  MindcareConversation? _conversation;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  SafetyResources? _safetyResources;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    final auth = AuthService();
    _api =
        widget.api ??
        MindcareApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    // Crisis moments never trigger an OS location prompt.
    _locationProvider =
        widget.locationProvider ??
        const PlatformSafetyLocationProvider(allowPrompt: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    _textController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await ensureCareConsent(context);
    if (!mounted) return;
    if (!ok) {
      Navigator.of(context).maybePop();
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversation = await _api.createOrResume();
      SafetyResources? resources = conversation.safetyResources;
      if (conversation.session.status == 'safety_support' &&
          resources == null) {
        resources = await _fetchSafetyResources();
      }
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _safetyResources = resources;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _choose(MindcareChoice choice) async {
    final conversation = _conversation;
    if (conversation == null || _sending) return;
    if (conversation.session.currentState == 'safety') {
      await _confirmSafety(choice.key == 'safe_now');
      return;
    }
    await _run(
      () =>
          _api.sendMessage(id: conversation.session.id, choiceKey: choice.key),
    );
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    final conversation = _conversation;
    if (conversation == null || text.isEmpty || _sending) return;
    final ok = await _run(
      () => _api.sendMessage(id: conversation.session.id, text: text),
    );
    if (ok) _textController.clear();
  }

  Future<bool> _run(Future<MindcareConversation> Function() call) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await call();
      if (!mounted) return false;
      setState(() {
        _conversation = updated;
        _sending = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _sending = false;
        _error = _messageFor(error);
      });
      return false;
    }
  }

  Future<void> _confirmSafety(bool safeNow) async {
    final conversation = _conversation;
    if (conversation == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final location = safeNow
          ? const SafetyLocation.denied()
          : await resolvePreChosenLocation(_locationProvider);
      final updated = await _api.confirmSafety(
        id: conversation.session.id,
        safeNow: safeNow,
        permissionGranted: safeNow ? null : location.permissionGranted,
        countryCode: safeNow ? null : location.countryCode,
        adminArea: safeNow ? null : location.adminArea,
      );
      final resources =
          updated.safetyResources ??
          (safeNow ? null : await _fetchSafetyResources(location: location));
      if (!mounted) return;
      setState(() {
        _conversation = updated;
        _safetyResources = resources;
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<SafetyResources?> _fetchSafetyResources({
    SafetyLocation? location,
  }) async {
    final resolved =
        location ?? await resolvePreChosenLocation(_locationProvider);
    try {
      return await _api.fetchSafetyResources(
        permissionGranted: resolved.permissionGranted,
        countryCode: resolved.countryCode,
        adminArea: resolved.adminArea,
      );
    } catch (_) {
      // The built-in contacts are shown either way.
      return null;
    }
  }

  String _messageFor(Object error) => switch (error) {
    MindcareApiException(reason: 'network_error') =>
      '네트워크 연결을 확인해 주세요. 방금 고른 답은 다시 눌러서 보낼 수 있어요.',
    MindcareApiException(reason: 'mindcare_safety_confirmation_required') =>
      '먼저 지금 안전한지 알려 주세요.',
    _ => '마음관리 요청을 처리하지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };

  String _stateLabel(String state) => switch (state) {
    'emotion' || 'emotion_detail' => '감정 알아차리기',
    'situation' || 'situation_detail' => '상황 바라보기',
    'need' || 'need_detail' => '필요한 것 찾기',
    'action' || 'action_detail' => '작은 행동 고르기',
    'safety' || 'safety_support' => '안전 먼저 확인하기',
    _ => '천천히 마음 살펴보기',
  };

  int _stepOf(String state) => switch (state) {
    'emotion' || 'emotion_detail' => 1,
    'situation' || 'situation_detail' => 2,
    'need' || 'need_detail' => 3,
    'action' || 'action_detail' => 4,
    _ => 0,
  };

  Widget _bubble(MindcareMessage message, V2Palette p) {
    final mine = message.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: mine ? p.primarySoft : p.surface,
          borderRadius: BorderRadius.circular(V2Radius.card),
        ),
        child: Text(
          message.content,
          style: V2Text.body.copyWith(color: mine ? p.onPrimarySoft : p.ink),
        ),
      ),
    );
  }

  Widget _flowHeader(MindcareConversation c, V2Palette p) {
    final state = c.session.currentState;
    final step = _stepOf(state);
    final safety = state == 'safety';
    return V2Card(
      key: const Key('mindcare_flow_header'),
      variant: V2CardVariant.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                safety ? V2Icons.shield : V2Icons.care,
                color: safety ? p.err : p.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_stateLabel(state), style: V2Text.bodyStrong),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            safety
                ? '이야기를 이어가기 전에 지금 안전한지 먼저 확인할게요.'
                : '감정, 상황, 필요한 것, 작은 행동 순서로 천천히 살펴봐요.',
            style: V2Text.cap.copyWith(color: p.sub),
          ),
          if (step > 0) ...[
            const SizedBox(height: 10),
            V2ProgressBar(value: step / 4, semanticLabel: '4단계 중 $step단계'),
          ],
        ],
      ),
    );
  }

  Widget _choiceButtons(MindcareConversation c) {
    final safety = c.session.currentState == 'safety';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in c.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: V2Button(
              label: choice.label,
              // Same weight for every answer, including on the safety check.
              variant: V2ButtonVariant.soft,
              onPressed: _sending ? null : () => _choose(choice),
              semanticLabel: safety ? '안전 확인: ${choice.label}' : null,
            ),
          ),
      ],
    );
  }

  Widget _body(V2Palette p) {
    final conversation = _conversation;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 3),
      );
    }
    if (conversation == null) {
      return V2ErrorState(
        title: '마음관리를 열지 못했어요',
        body: _error ?? '잠시 뒤 다시 시도해 주세요. 급하면 위의 도움이 필요하면을 눌러 주세요.',
        onRetry: _load,
      );
    }
    final question = conversation.nextQuestion;
    final canType = question?.allowFreeText == true;
    final supporting = conversation.session.status == 'safety_support';
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 32),
      children: [
        _flowHeader(conversation, p),
        const SizedBox(height: 14),
        if (supporting) ...[
          Text(
            '지금은 안전이 먼저예요. 가까운 사람이나 아래 도움받을 곳에 연락해 주세요.',
            style: V2Text.bodyStrong.copyWith(color: p.ink),
          ),
          const SizedBox(height: 10),
          CrisisContactsCard(resources: _safetyResources),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: V2Button(
              label: '가까운 기관도 보고 싶어요',
              variant: V2ButtonVariant.text,
              size: V2ButtonSize.sm,
              fullWidth: false,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CareSettingsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final m in conversation.messages) _bubble(m, p),
        if (conversation.session.status == 'completed')
          V2Card(
            variant: V2CardVariant.soft,
            child: Text(
              '오늘의 마음관리를 마쳤어요. 작은 행동 하나만 기억해 두세요. 다음에 또 와도 괜찮아요.',
              style: V2Text.body.copyWith(color: p.ink),
            ),
          ),
        if (_error != null) ...[
          V2Banner(tone: V2BannerTone.err, message: _error!),
          const SizedBox(height: 10),
        ],
        if (conversation.choices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            question?.text ?? '마음에 가까운 답을 골라 주세요.',
            style: V2Text.head.copyWith(color: p.ink),
          ),
          const SizedBox(height: 10),
          _choiceButtons(conversation),
        ],
        if (canType) ...[
          const SizedBox(height: 12),
          V2TextField(
            label: '편한 말로 적어 주세요',
            controller: _textController,
            maxLines: 4,
            hint: '짧게 적어도 괜찮아요.',
          ),
          const SizedBox(height: 10),
          V2Button(
            label: '다음으로',
            loading: _sending,
            onPressed: _sending ? null : _sendText,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      dark: true,
      child: Builder(
        builder: (context) {
          final p = V2Palette.of(context);
          return Scaffold(
            backgroundColor: p.bg,
            appBar: V2Header(
              title: '마음관리',
              actions: [
                V2IconButton(
                  icon: V2Icons.settings,
                  tooltip: '돌봄 설정',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CareSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.page,
                    0,
                    V2Space.page,
                    8,
                  ),
                  child: Row(
                    children: [
                      CareHelpChip(resources: _safetyResources),
                      const SizedBox(width: 10),
                      const Expanded(child: CareAiNotice()),
                    ],
                  ),
                ),
                Expanded(child: _body(p)),
              ],
            ),
          );
        },
      ),
    );
  }
}
