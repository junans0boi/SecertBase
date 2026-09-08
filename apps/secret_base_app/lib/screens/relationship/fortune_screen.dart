import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/fortune_api.dart';
import '../../core/main_design.dart';

class RelationshipFortuneScreen extends StatefulWidget {
  final FortuneApi? api;
  final VoidCallback? onOpenCounseling;

  const RelationshipFortuneScreen({super.key, this.api, this.onOpenCounseling});

  @override
  State<RelationshipFortuneScreen> createState() =>
      _RelationshipFortuneScreenState();
}

class _RelationshipFortuneScreenState extends State<RelationshipFortuneScreen> {
  late final FortuneApi _api;
  late final bool _ownsApi;
  FortuneToday? _today;
  String? _error;
  String? _regenerating;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    final auth = AuthService();
    _api =
        widget.api ??
        FortuneApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    _load();
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = await _api.fetchToday();
      if (!mounted) return;
      setState(() {
        _today = today;
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

  Future<void> _regenerate(String type) async {
    if (_regenerating != null) return;
    setState(() {
      _regenerating = type;
      _error = null;
    });
    try {
      final today = await _api.regenerate(type: type);
      if (!mounted) return;
      setState(() {
        _today = today;
        _regenerating = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _regenerating = null;
        _error = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) => switch (error) {
    FortuneApiException(reason: 'network_error') => '네트워크 연결을 확인해주세요.',
    FortuneApiException(reason: 'active_couple_required') =>
      '파트너를 연결하면 관계 운세를 볼 수 있어요.',
    FortuneApiException() => '오늘의 운세를 불러오지 못했어요.',
    _ => '오늘의 운세를 불러오지 못했어요.',
  };

  Widget _fortuneCard(FortuneContent? content, {required String emptyText}) {
    if (content == null) {
      return MainCard(
        child: Text(emptyText, style: mainBody(size: 13, color: kMainSub)),
      );
    }
    final busy = _regenerating == content.type;
    return MainCard(
      key: Key('fortune_card_${content.type}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(content.title, style: mainTitle(size: 20))),
              if (content.status == 'fallback')
                const Tooltip(
                  message: '고정 안내문으로 표시 중이에요',
                  child: Icon(Icons.info_outline, size: 18, color: kMainMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content.summary, style: mainBody(size: 14, height: 1.5)),
          if (content.signals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('오늘의 신호', style: mainBody(size: 12, color: kMainSub)),
            const SizedBox(height: 4),
            Text(
              content.signals.join('\n'),
              style: mainBody(size: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          Text('해볼 만한 것', style: mainBody(size: 12, color: kMainSub)),
          const SizedBox(height: 4),
          Text(content.suggestion, style: mainBody(size: 13, height: 1.5)),
          if (content.generatedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content.generatedText,
              style: mainBody(size: 13, color: kMainSub, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: busy ? null : () => _regenerate(content.type),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('명시적으로 다시 생성'),
            ),
          ),
          Text(
            content.disclaimer,
            style: mainBody(size: 11, color: kMainMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('오늘의 운세', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error != null && _today == null
          ? Center(
              child: Text(_error!, style: mainBody(color: kMainSub)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: kMainRose,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  Text(
                    '${_today?.date ?? ''} · ${_today?.contentVersion ?? ''}',
                    style: mainBody(size: 12, color: kMainSub),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: mainBody(size: 13, color: kMainRose)),
                  ],
                  const SizedBox(height: 12),
                  _fortuneCard(
                    _today?.personal,
                    emptyText: '출생 프로필을 저장하면 개인 운세가 준비돼요.',
                  ),
                  const SizedBox(height: 12),
                  _fortuneCard(
                    _today?.emotionalFlow,
                    emptyText: '오늘의 감정 흐름이 아직 없어요.',
                  ),
                  if (_today?.relationship != null) ...[
                    const SizedBox(height: 12),
                    _fortuneCard(
                      _today?.relationship,
                      emptyText: '커플을 연결하면 관계 운세가 준비돼요.',
                    ),
                  ],
                  if (widget.onOpenCounseling != null) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: widget.onOpenCounseling,
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('이 흐름으로 상담 시작하기'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
