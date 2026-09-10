import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/mindcare_api.dart';
import '../../core/safety_location.dart';

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
    _locationProvider =
        widget.locationProvider ?? const PlatformSafetyLocationProvider();
    _load();
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await _api.sendMessage(
        id: conversation.session.id,
        choiceKey: choice.key,
      );
      if (!mounted) return;
      setState(() {
        _conversation = updated;
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

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    final conversation = _conversation;
    if (conversation == null || text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await _api.sendMessage(
        id: conversation.session.id,
        text: text,
      );
      if (!mounted) return;
      _textController.clear();
      setState(() {
        _conversation = updated;
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
          : await _resolveSafetyLocation();
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

  Future<SafetyLocation> _resolveSafetyLocation() async {
    try {
      return await _locationProvider.resolve();
    } catch (_) {
      return const SafetyLocation.denied();
    }
  }

  Future<SafetyResources?> _fetchSafetyResources({
    SafetyLocation? location,
  }) async {
    final resolved = location ?? await _resolveSafetyLocation();
    try {
      return await _api.fetchSafetyResources(
        permissionGranted: resolved.permissionGranted,
        countryCode: resolved.countryCode,
        adminArea: resolved.adminArea,
      );
    } catch (_) {
      return null;
    }
  }

  String _messageFor(Object error) => switch (error) {
    MindcareApiException(reason: 'network_error') => '네트워크 연결을 확인해주세요.',
    MindcareApiException(reason: 'mindcare_safety_confirmation_required') =>
      '먼저 지금 안전한지 알려주세요.',
    MindcareApiException() => '마음관리 요청을 처리하지 못했어요.',
    _ => '마음관리 요청을 처리하지 못했어요.',
  };

  Widget _bubble(MindcareMessage message) {
    final mine = message.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: mine ? kMainLilacSoft : Colors.white,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(message.content, style: mainBody(size: 13, height: 1.5)),
      ),
    );
  }

  Widget _safetyResourceCard(SafetyResources resources) {
    final heading =
        resources.locationMode == 'region' && resources.adminArea != null
        ? '${resources.adminArea} 기준 안내'
        : '일반 안전 안내';
    return Semantics(
      container: true,
      label: '$heading. 위치 정보는 저장하지 않아요.',
      child: MainCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: mainTitle(size: 17)),
            const SizedBox(height: 6),
            Text(
              resources.locationMode == 'region'
                  ? '현재 지역에 맞춘 도움 정보를 잠시 보여드려요.'
                  : '위치 권한 없이도 바로 확인할 수 있는 도움 정보예요.',
              style: mainBody(size: 12, color: kMainSub, height: 1.45),
            ),
            const SizedBox(height: 10),
            ...resources.resources.map(
              (resource) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: mainBody(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resource.description,
                      style: mainBody(size: 12, color: kMainSub, height: 1.4),
                    ),
                    if (resource.contact != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        resource.contact!,
                        style: mainBody(size: 14, weight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Text(
              '리소스 ${resources.resourceVersion} · ${resources.validUntil}까지 확인된 안내',
              style: mainBody(size: 10, color: kMainSub),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final question = conversation?.nextQuestion;
    final canType = question?.allowFreeText == true;
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('마음관리', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                MainCard(
                  child: Text(
                    '따뜻한 질문을 따라 내 마음과 작은 행동을 정리해봐요. 파트너와 자동으로 공유되지 않아요.',
                    style: mainBody(size: 13, color: kMainSub, height: 1.5),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: mainBody(size: 13, color: kMainRose)),
                ],
                if (conversation == null) ...[
                  const SizedBox(height: 28),
                  Text('마음관리 세션을 열 수 없어요.', style: mainTitle(size: 20)),
                ] else ...[
                  const SizedBox(height: 16),
                  ...conversation.messages.map(_bubble),
                  if (conversation.session.status == 'completed')
                    Text(
                      '오늘의 마음관리를 마쳤어요. 작은 행동 하나만 기억해두세요.',
                      style: mainBody(size: 13, color: kMainSub, height: 1.5),
                    ),
                  if (conversation.session.status == 'safety_support') ...[
                    Text(
                      '지금은 안전을 먼저 챙겨주세요. 가까운 사람이나 즉시 도움을 받을 곳에 연락해 주세요.',
                      style: mainBody(size: 13, color: kMainRose, height: 1.5),
                    ),
                    if (_safetyResources != null) ...[
                      const SizedBox(height: 12),
                      _safetyResourceCard(_safetyResources!),
                    ],
                  ],
                  if (conversation.choices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      question?.text ?? '마음에 가까운 답을 골라주세요.',
                      style: mainBody(weight: FontWeight.w800, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: conversation.choices
                          .map(
                            (choice) => OutlinedButton(
                              onPressed: _sending
                                  ? null
                                  : () => _choose(choice),
                              child: Text(choice.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (canType) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: '편한 말로 적어주셔도 괜찮아요.',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _sending ? null : _sendText,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('다음으로'),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
