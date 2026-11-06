import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/auth_service.dart';
import '../../core/birth_profile_api.dart';
import '../../core/counseling_api.dart';
import '../../core/fortune_api.dart';
import 'birth_info_sheet.dart';
import 'counseling_screen.dart';
import 'relationship_common.dart';
import 'share_card.dart';

enum FortuneScope { personal, couple }

class RelationshipFortuneScreen extends StatefulWidget {
  final FortuneApi? api;
  final VoidCallback? onOpenCounseling;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenPartner;
  final FortuneScope scope;
  final BirthProfileApi? birthProfileApi;

  const RelationshipFortuneScreen({
    super.key,
    this.api,
    this.onOpenCounseling,
    this.onEditProfile,
    this.onOpenPartner,
    this.scope = FortuneScope.personal,
    this.birthProfileApi,
  });

  @override
  State<RelationshipFortuneScreen> createState() =>
      _RelationshipFortuneScreenState();
}

class _RelationshipFortuneScreenState extends State<RelationshipFortuneScreen> {
  late final FortuneApi _api;
  late final bool _ownsApi;
  FortuneToday? _today;
  FortuneApiException? _error;
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
        _error = error is FortuneApiException
            ? error
            : const FortuneApiException('unknown_error');
      });
    }
  }

  Future<void> _editProfile() async {
    final custom = widget.onEditProfile;
    if (custom != null) {
      custom();
      return;
    }
    if (await editBirthProfile(context, api: widget.birthProfileApi) &&
        mounted) {
      await _load();
    }
  }

  void _openPartner() =>
      (widget.onOpenPartner ?? () => openPartnerConnection(context))();

  void _openCounseling() {
    final custom = widget.onOpenCounseling;
    if (custom != null) {
      custom();
      return;
    }
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RelationshipCounselingScreen(
          api: CounselingApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
          shared: false,
        ),
      ),
    );
  }

  String _messageFor(FortuneApiException? error) => switch (error?.reason) {
    'network_error' => '네트워크 연결을 확인하고 다시 시도해 주세요.',
    'active_couple_required' => '파트너와 연결하면 관계 운세를 볼 수 있어요.',
    'profile_incomplete' => '출생 정보를 알려 주면 개인 운세를 볼 수 있어요.',
    _ => '오늘의 운세를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    final isCouple = widget.scope == FortuneScope.couple;
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '오늘의 운세'),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(V2Space.page),
                child: V2SkeletonList(count: 3),
              )
            : _today == null
            ? _errorState(isCouple)
            : _content(isCouple),
      ),
    );
  }

  Widget _content(bool isCouple) {
    final today = _today!;
    final current = isCouple ? today.relationship : today.personal;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: V2Chip(
                    label: isCouple ? '우리 둘의 흐름' : '나만 보는 흐름',
                    tone: isCouple ? V2Tone.lilac : V2Tone.rose,
                    icon: isCouple ? V2Icons.couple : V2Icons.person,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isCouple ? '오늘 우리 사이에 필요한 건' : '오늘 나에게 필요한 건',
                  style: V2Text.title,
                ),
                const SizedBox(height: 4),
                Text(
                  '예언을 맞히는 시간이 아니라, 오늘을 조금 다르게 바라보는 시간이에요.',
                  style: V2Text.cap,
                ),
                const SizedBox(height: 16),
                _fortuneCard(
                  current,
                  isCouple: isCouple,
                  expectedType: isCouple ? 'relationship' : 'personal',
                  emptyText: isCouple
                      ? '파트너와 연결하면 관계 운세가 준비돼요.'
                      : '출생 정보를 알려 주면 개인 운세가 준비돼요.',
                ),
                if (current != null) ...[
                  const SizedBox(height: 10),
                  V2Button(
                    label: '카드로 공유',
                    icon: V2Icons.share,
                    variant: V2ButtonVariant.soft,
                    onPressed: () => _share(current, isCouple),
                  ),
                ],
                if (!isCouple) ...[
                  const SizedBox(height: 22),
                  _fortuneCard(
                    today.emotionalFlow,
                    isCouple: false,
                    expectedType: 'emotional_flow',
                    emptyText: '오늘의 감정 흐름이 아직 없어요.',
                  ),
                  if (today.relationship != null) ...[
                    const SizedBox(height: 22),
                    _fortuneCard(
                      today.relationship,
                      isCouple: true,
                      expectedType: 'relationship',
                      emptyText: '파트너와 연결하면 관계 운세가 준비돼요.',
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                _howItWorks(isCouple),
                const SizedBox(height: 16),
                V2Button(
                  label: '이 흐름으로 상담 시작하기',
                  icon: V2Icons.chat,
                  onPressed: _openCounseling,
                ),
                const SizedBox(height: 10),
                Text('AI가 쓴 안내예요. 전문 상담이나 의료가 아니에요.', style: V2Text.cap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fortuneCard(
    FortuneContent? content, {
    required bool isCouple,
    required String expectedType,
    required String emptyText,
  }) {
    final type = content?.type.isNotEmpty == true
        ? content!.type
        : expectedType;
    final isEmotional = type == 'emotional_flow';
    final sectionKey = isEmotional
        ? 'fortune_emotional_flow'
        : isCouple
        ? 'fortune_relationship'
        : 'fortune_overview';
    final sectionTitle = isEmotional
        ? '마음의 날씨'
        : isCouple
        ? '우리 사이의 흐름'
        : '오늘의 전체 흐름';
    final sectionDescription = isEmotional
        ? '감정이 올라오는 속도와 잠깐 살펴볼 신호'
        : isCouple
        ? '두 사람의 리듬과 대화를 살펴보는 운세'
        : '오늘 하루의 방향과 나에게 맞는 작은 행동';
    return KeyedSubtree(
      key: Key(sectionKey),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              V2Art(
                icon: isEmotional
                    ? V2Icons.sparkle
                    : isCouple
                    ? V2Icons.heart
                    : V2Icons.star,
                tone: isEmotional ? V2Tone.lilac : V2Tone.rose,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sectionTitle, style: V2Text.head),
                    Text(sectionDescription, style: V2Text.cap),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content == null)
            V2Card(
              variant: V2CardVariant.soft,
              child: _emptyContent(emptyText, isCouple, !isEmotional),
            )
          else
            _contentCard(content, isEmotional),
        ],
      ),
    );
  }

  Widget _contentCard(FortuneContent content, bool isEmotional) {
    final p = V2Palette.of(context);
    return V2Card(
      key: Key('fortune_card_${content.type}'),
      gradient: isEmotional ? null : V2Gradients.heroSoft,
      color: isEmotional ? p.soft : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(content.title, style: V2Text.serif(size: 24, color: p.ink)),
              ),
              if (content.status == 'fallback')
                const V2Chip(label: '기본 안내', tone: V2Tone.neutral),
            ],
          ),
          const SizedBox(height: 12),
          Text('오늘의 한 줄', style: V2Text.label.copyWith(color: p.primary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(content.summary, style: V2Text.body.copyWith(color: p.ink)),
          if (content.signals.isNotEmpty) ...[
            const SizedBox(height: 16),
            _insightRow(V2Icons.visibility, '조심할 흐름', content.signals.join(' '), V2Tone.peach),
          ],
          const SizedBox(height: 12),
          KeyedSubtree(
            key: Key(_actionKey(content)),
            child: _insightRow(V2Icons.check, '힘이 되는 행동', content.suggestion, V2Tone.sage),
          ),
          if (content.generatedText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('오늘의 한 문장', style: V2Text.cap),
            const SizedBox(height: 2),
            Text(content.generatedText, style: V2Text.body.copyWith(color: p.sub)),
          ],
          if (content.disclaimer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(content.disclaimer, style: V2Text.cap),
          ],
        ],
      ),
    );
  }

  String _actionKey(FortuneContent content) => switch (content.type) {
    'emotional_flow' => 'fortune_emotional_action',
    'relationship' => 'fortune_relationship_action',
    _ => 'fortune_action',
  };

  Widget _insightRow(IconData icon, String label, String text, V2Tone tone) {
    final c = V2ToneColors.of(tone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: c.soft, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: c.text),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: V2Text.cap),
              Text(text, style: V2Text.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyContent(String text, bool isCouple, bool actionable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: V2Text.body),
        if (actionable) ...[
          const SizedBox(height: 12),
          if (isCouple)
            V2Button(
              label: '파트너 연결하기',
              icon: V2Icons.couple,
              variant: V2ButtonVariant.soft,
              onPressed: _openPartner,
            )
          else
            V2Button(
              label: '출생 정보 입력하기',
              icon: V2Icons.edit,
              variant: V2ButtonVariant.soft,
              onPressed: _editProfile,
            ),
        ],
      ],
    );
  }

  Widget _howItWorks(bool isCouple) {
    return V2Card(
      key: const Key('fortune_logic'),
      variant: V2CardVariant.soft,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('fortune_technical'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text('이 운세는 어떻게 나왔나요?', style: V2Text.bodyStrong),
            subtitle: Text(
              isCouple ? '두 사람의 출생 정보 + 오늘 날짜' : '생년월일·출생 정보 + 오늘 날짜',
              style: V2Text.cap,
            ),
            children: [
              if (_today?.date.isNotEmpty == true)
                Text('날짜 ${_today!.date}', style: V2Text.body),
              const SizedBox(height: 6),
              Text(
                '매일 조건이 같으면 같은 흐름이 나오도록 계산하고, 결과는 날짜별로 저장해요. 무작위 문구를 매번 바꾸는 방식이 아니라 오늘의 마음을 살피는 자기성찰용 힌트예요.',
                style: V2Text.body,
              ),
              const SizedBox(height: 8),
              Text(
                '입력값과 날짜를 암호화 해시로 바꾸어 정해진 테마를 골라요. 콘텐츠 버전 ${_today?.contentVersion ?? ''}',
                style: V2Text.cap,
              ),
              const SizedBox(height: 4),
              Text('결과는 예언·진단·치료가 아닌 자기성찰용 안내예요.', style: V2Text.cap),
            ],
          ),
        ),
      ),
    );
  }

  void _share(FortuneContent c, bool isCouple) {
    final line = c.summary.length > 100 ? '${c.summary.substring(0, 100)}…' : c.summary;
    showShareCardSheet(
      context,
      fileName: 'secretbase-fortune.png',
      caption: '${isCouple ? '우리의' : '오늘의'} 운세 · ${c.title}\n$line\n- 비밀기지',
      card: ShareCard(
        kind: isCouple ? '오늘 우리의 운세' : '오늘의 운세',
        title: c.title,
        line: line,
        art: const Icon(V2Icons.sparkle, color: Colors.white, size: 56),
      ),
    );
  }

  Widget _errorState(bool isCouple) {
    final reason = _error?.reason;
    final needsPartner = reason == 'active_couple_required';
    final needsProfile = reason == 'profile_incomplete';
    return Column(
      children: [
        Expanded(
          child: reason == 'network_error'
              ? V2ErrorState.offline(onRetry: _load)
              : V2ErrorState(
                  title: needsPartner
                      ? '파트너와 연결해 주세요'
                      : needsProfile
                      ? '출생 정보가 필요해요'
                      : '오늘의 운세를 불러오지 못했어요',
                  body: _messageFor(_error),
                  onRetry: _load,
                ),
        ),
        if (needsPartner || needsProfile)
          Padding(
            padding: const EdgeInsets.all(V2Space.page),
            child: V2Button(
              label: needsPartner ? '파트너 연결하기' : '출생 정보 입력하기',
              variant: V2ButtonVariant.soft,
              onPressed: needsPartner ? _openPartner : _editProfile,
            ),
          ),
      ],
    );
  }
}
