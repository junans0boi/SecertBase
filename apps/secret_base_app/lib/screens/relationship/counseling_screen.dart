import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/auth_service.dart';
import '../../core/counseling_api.dart';
import '../../core/mindcare_api.dart' show SafetyResources;
import '../../core/safety_location.dart';
import 'care_safety.dart';
import 'care_settings_screen.dart';
import 'relationship_common.dart';

class RelationshipCounselingScreen extends StatefulWidget {
  final CounselingApi? api;
  final bool shared;
  final VoidCallback? onOpenPartner;
  final SafetyLocationProvider? locationProvider;

  const RelationshipCounselingScreen({
    super.key,
    this.api,
    required this.shared,
    this.onOpenPartner,
    this.locationProvider,
  });

  @override
  State<RelationshipCounselingScreen> createState() =>
      _RelationshipCounselingScreenState();
}

class _RelationshipCounselingScreenState
    extends State<RelationshipCounselingScreen> {
  late final CounselingApi _api;
  late final SafetyLocationProvider _locationProvider;
  late final bool _ownsApi;
  final _messageController = TextEditingController();
  CounselingConversation? _conversation;
  List<CounselingSession> _sessions = const [];
  String? _error;
  bool _needsPartner = false;
  bool _loading = true;
  bool _sending = false;
  String? _failedText;
  bool _crisis = false;
  SafetyResources? _crisisResources;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    final auth = AuthService();
    _api =
        widget.api ??
        CounselingApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    _locationProvider =
        widget.locationProvider ??
        const PlatformSafetyLocationProvider(allowPrompt: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    _messageController.dispose();
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
      _needsPartner = false;
    });
    try {
      final sessions = await _api.fetchSessions(shared: widget.shared);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
      if (sessions.isNotEmpty) await _open(sessions.first.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsPartner =
            error is CounselingApiException &&
            error.reason == 'active_couple_required';
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversation = await _api.createSession(shared: widget.shared);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _crisis = false;
        _sessions = [conversation.session, ..._sessions];
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

  Future<void> _open(int id) async {
    try {
      final conversation = await _api.fetchSession(
        shared: widget.shared,
        id: id,
      );
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _crisis = false;
        _failedText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _send([String? retryText]) async {
    final conversation = _conversation;
    final message = (retryText ?? _messageController.text).trim();
    if (conversation == null || message.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _failedText = null;
    });
    try {
      final location = await resolvePreChosenLocation(_locationProvider);
      final updated = await _api.sendMessage(
        shared: widget.shared,
        id: conversation.session.id,
        content: message,
        locationPermissionGranted: location.permissionGranted ? true : null,
        countryCode: location.countryCode,
        adminArea: location.adminArea,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _conversation = updated;
        _sending = false;
        if (updated.isCrisis) {
          _crisis = true;
          _crisisResources = updated.safetyResources;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failedText = message;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _shareHint() async {
    final conversation = _conversation;
    if (conversation == null) return;
    final controller = TextEditingController();
    final text = await showV2Sheet<String>(
      context,
      title: '파트너에게 힌트 한 문장 보내기',
      subtitle: '대화 원문이 아니라 내가 직접 쓴 한 문장만 보낼 수 있어요.',
      builder: (ctx) => V2TextField(
        label: '보낼 문장',
        controller: controller,
        maxLines: 3,
        hint: '예: 혼자 있는 시간을 안전하게 연습하고 싶어요.',
      ),
      actions: [
        Builder(
          builder: (ctx) => V2Button(
            label: '이 문장만 보내기',
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ),
      ],
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final approved = await showV2Confirm(
      context,
      title: '이 문장을 보낼까요?',
      message: '“$text”\n파트너와의 상담 공간에 이 문장만 공유돼요. 보낸 뒤에도 취소할 수 있어요.',
      confirmLabel: '보내기',
    );
    if (!approved || !mounted) return;
    try {
      await _api.approveInsight(sessionId: conversation.session.id, text: text);
      if (!mounted) return;
      showV2Snack(context, '확인한 문장만 커플 상담에 공유했어요');
    } catch (error) {
      if (!mounted) return;
      showV2Snack(context, _messageFor(error), tone: V2Tone.err);
    }
  }

  String _messageFor(Object error) => switch (error) {
    CounselingApiException(reason: 'network_error') =>
      '네트워크 연결을 확인해 주세요. 쓴 내용은 그대로 남아 있어요.',
    CounselingApiException(reason: 'active_couple_required') =>
      '파트너와 연결하면 함께 하는 상담을 쓸 수 있어요.',
    CounselingApiException(
      reason: 'session_not_shareable_with_current_couple',
    ) =>
      '지금 연결된 파트너에게는 공유할 수 없는 개인 상담이에요.',
    _ => '상담 요청을 처리하지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };

  Widget _bubble(CounselingMessage message, V2Palette p, bool last) {
    final mine = message.role == 'user';
    if (!mine && message.generationStatus == 'fallback') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CareFallbackNotice(message: last ? message.content : null),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: mine ? p.primarySoft : p.soft,
          borderRadius: BorderRadius.circular(V2Radius.card),
        ),
        child: Text(
          message.content,
          style: V2Text.body.copyWith(color: mine ? p.onPrimarySoft : p.ink),
        ),
      ),
    );
  }

  Widget _sessionChips() {
    if (_sessions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sessions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => Center(
          child: V2Chip(
            label: _sessions[index].title.isEmpty
                ? '상담 ${_sessions.length - index}'
                : _sessions[index].title,
            selected: _conversation?.session.id == _sessions[index].id,
            onTap: () => _open(_sessions[index].id),
          ),
        ),
      ),
    );
  }

  Widget _scopeCard() => V2Card(
    key: const Key('counseling_scope_card'),
    variant: V2CardVariant.soft,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          widget.shared ? V2Icons.couple : V2Icons.lock,
          size: 20,
          color: V2Palette.of(context).primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.shared
                ? '두 사람이 함께 볼 수 있는 내용만 사용해요. 개인 상담 원문은 이 공간으로 이동하지 않아요.'
                : '이 공간의 원문은 나만 볼 수 있어요. 파트너에게는 내가 확인한 한 문장만 직접 골라 보낼 수 있어요.',
            style: V2Text.cap.copyWith(color: V2Palette.of(context).sub),
          ),
        ),
      ],
    ),
  );

  Widget _body(V2Palette p) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 3),
      );
    }
    final conversation = _conversation;
    final messages = conversation?.messages ?? const <CounselingMessage>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 32),
      children: [
        _scopeCard(),
        const SizedBox(height: 12),
        if (_needsPartner && _conversation == null)
          V2EmptyState.unpaired(
            title: '파트너와 연결해 주세요',
            body: '연결하면 두 사람이 함께 쓰는 상담 공간이 열려요.',
            onAction:
                widget.onOpenPartner ?? () => openPartnerConnection(context),
          )
        else if (_error != null && conversation == null)
          SizedBox(
            height: 320,
            child: V2ErrorState(
              title: '상담을 불러오지 못했어요',
              body: _error,
              onRetry: _load,
            ),
          )
        else ...[
          _sessionChips(),
          if (conversation == null) ...[
            const SizedBox(height: 12),
            V2EmptyState(
              illustration: const V2SceneIllustration(V2Scene.hearts),
              title: '아직 시작한 상담이 없어요',
              body: '지금 마음을 천천히 적어 보세요. AI 가이드가 함께 살펴봐요.',
              actionLabel: '상담 시작하기',
              onAction: _create,
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (var i = 0; i < messages.length; i++)
              _bubble(messages[i], p, i == messages.length - 1),
            if (_sending)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('답변을 준비하고 있어요…', style: V2Text.cap),
                ),
              ),
            if (_crisis) ...[
              Text(
                '지금 도움받을 수 있는 곳이에요. 혼자 감당하지 않아도 괜찮아요.',
                style: V2Text.bodyStrong,
              ),
              const SizedBox(height: 8),
              CrisisContactsCard(resources: _crisisResources),
              const SizedBox(height: 12),
            ],
            if (_failedText != null)
              V2Banner(
                tone: V2BannerTone.err,
                title: '보내지 못했어요',
                message: _error ?? '다시 보내 보세요.',
                actionLabel: '다시 보내기',
                onAction: () => _send(_failedText),
                onDismiss: () => setState(() {
                  _failedText = null;
                  _error = null;
                }),
              )
            else if (_error != null)
              V2Banner(tone: V2BannerTone.err, message: _error!),
            const SizedBox(height: 10),
            V2TextField(
              label: '지금 마음이나 궁금한 점',
              controller: _messageController,
              maxLines: 4,
              hint: '편한 만큼만 적어 주세요.',
            ),
            const SizedBox(height: 10),
            V2Button(
              label: '보내고 답변 받기',
              loading: _sending,
              onPressed: _sending ? null : () => _send(),
            ),
            if (!widget.shared) ...[
              const SizedBox(height: 8),
              V2Button(
                label: '파트너에게 힌트 한 문장 보내기',
                variant: V2ButtonVariant.soft,
                icon: V2Icons.send,
                onPressed: _shareHint,
              ),
            ],
          ],
        ],
        const SizedBox(height: 16),
        const CareAiNotice(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Builder(
        builder: (context) {
          final p = V2Palette.of(context);
          return Scaffold(
            backgroundColor: p.bg,
            appBar: V2Header(
              title: widget.shared ? '커플 상담' : '프라이빗 상담',
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CareHelpChip(resources: _crisisResources),
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
