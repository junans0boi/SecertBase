import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/counseling_api.dart';
import '../../core/main_design.dart';

class RelationshipCounselingScreen extends StatefulWidget {
  final CounselingApi? api;
  final bool shared;

  const RelationshipCounselingScreen({
    super.key,
    this.api,
    required this.shared,
  });

  @override
  State<RelationshipCounselingScreen> createState() =>
      _RelationshipCounselingScreenState();
}

class _RelationshipCounselingScreenState
    extends State<RelationshipCounselingScreen> {
  late final CounselingApi _api;
  late final bool _ownsApi;
  final _messageController = TextEditingController();
  final _insightController = TextEditingController();
  CounselingConversation? _conversation;
  List<CounselingSession> _sessions = const [];
  String? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    final auth = AuthService();
    _api =
        widget.api ??
        CounselingApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    _load();
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    _messageController.dispose();
    _insightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
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
      setState(() => _conversation = conversation);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _send() async {
    final conversation = _conversation;
    final message = _messageController.text.trim();
    if (conversation == null || message.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await _api.sendMessage(
        shared: widget.shared,
        id: conversation.session.id,
        content: message,
      );
      if (!mounted) return;
      _messageController.clear();
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

  Future<void> _approveInsight() async {
    final conversation = _conversation;
    final text = _insightController.text.trim();
    if (conversation == null || text.isEmpty) return;
    try {
      await _api.approveInsight(sessionId: conversation.session.id, text: text);
      if (!mounted) return;
      _insightController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('확인한 힌트만 커플 상담에 공유했어요.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    }
  }

  String _messageFor(Object error) => switch (error) {
    CounselingApiException(reason: 'network_error') => '네트워크 연결을 확인해주세요.',
    CounselingApiException(reason: 'active_couple_required') =>
      '파트너를 연결하면 커플 상담을 사용할 수 있어요.',
    CounselingApiException(
      reason: 'session_not_shareable_with_current_couple',
    ) =>
      '현재 커플에 공유할 수 없는 개인 상담이에요.',
    CounselingApiException() => '상담 요청을 처리하지 못했어요.',
    _ => '상담 요청을 처리하지 못했어요.',
  };

  Widget _messageBubble(CounselingMessage message) {
    final mine = message.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? kMainLilacSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content, style: mainBody(size: 13, height: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text(
          widget.shared ? '커플 상담' : '프라이빗 상담',
          style: mainTitle(size: 22),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                MainCard(
                  child: Text(
                    widget.shared
                        ? '두 사람이 함께 볼 수 있는 내용만 사용해요. 개인 상담 원문은 이 공간으로 이동하지 않아요.'
                        : '이 공간의 원문은 나만 볼 수 있어요. 커플 공간에 공유할 내용은 내가 확인한 힌트만 직접 선택해요.',
                    style: mainBody(size: 13, color: kMainSub, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: mainBody(size: 13, color: kMainRose),
                    ),
                  ),
                if (_sessions.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => OutlinedButton(
                        onPressed: () => _open(_sessions[index].id),
                        child: Text(_sessions[index].title),
                      ),
                    ),
                  ),
                if (conversation == null) ...[
                  const SizedBox(height: 24),
                  Text('아직 시작한 상담이 없어요.', style: mainTitle(size: 20)),
                  const SizedBox(height: 8),
                  Text(
                    '지금 마음을 안전한 속도로 적어보세요.',
                    style: mainBody(size: 13, color: kMainSub),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: const Text('상담 시작하기'),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ...conversation.messages.map(_messageBubble),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '지금 마음이나 궁금한 점을 적어보세요.',
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
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('보내고 답변 받기'),
                  ),
                  if (!widget.shared) ...[
                    const SizedBox(height: 20),
                    Text(
                      '커플 상담에 공유할 힌트',
                      style: mainBody(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '원문이 아니라 내가 확인한 추상화된 문장만 직접 승인해요.',
                      style: mainBody(size: 12, color: kMainSub),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _insightController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '예: 혼자 있는 시간을 안전하게 연습하고 싶다.',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _approveInsight,
                      child: const Text('이 힌트만 커플 상담에 공유'),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
