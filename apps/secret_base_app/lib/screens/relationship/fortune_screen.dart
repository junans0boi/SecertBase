import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/fortune_api.dart';
import '../../core/main_design.dart';

enum FortuneScope { personal, couple }

class RelationshipFortuneScreen extends StatefulWidget {
  final FortuneApi? api;
  final VoidCallback? onOpenCounseling;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenPartner;
  final FortuneScope scope;

  const RelationshipFortuneScreen({
    super.key,
    this.api,
    this.onOpenCounseling,
    this.onEditProfile,
    this.onOpenPartner,
    this.scope = FortuneScope.personal,
  });

  @override
  State<RelationshipFortuneScreen> createState() =>
      _RelationshipFortuneScreenState();
}

class _RelationshipFortuneScreenState extends State<RelationshipFortuneScreen> {
  late final FortuneApi _api;
  late final bool _ownsApi;
  FortuneToday? _today;
  String? _error;
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

  String _messageFor(Object error) => switch (error) {
    FortuneApiException(reason: 'network_error') => '네트워크 연결을 확인해주세요.',
    FortuneApiException(reason: 'active_couple_required') =>
      '파트너를 연결하면 관계 운세를 볼 수 있어요.',
    FortuneApiException(reason: 'profile_incomplete') =>
      '출생 프로필을 저장하면 개인 운세를 볼 수 있어요.',
    FortuneApiException() => '오늘의 운세를 불러오지 못했어요.',
    _ => '오늘의 운세를 불러오지 못했어요.',
  };

  @override
  Widget build(BuildContext context) {
    final isCouple = widget.scope == FortuneScope.couple;
    final current = isCouple ? _today?.relationship : _today?.personal;
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('오늘의 운세', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error != null && _today == null
          ? _errorState(isCouple: isCouple)
          : RefreshIndicator(
              onRefresh: _load,
              color: kMainRose,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _intro(isCouple: isCouple, content: current),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: mainBody(size: 13, color: kMainRose),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _fortuneCard(
                      current,
                      isCouple: isCouple,
                      expectedType: isCouple ? 'relationship' : 'personal',
                      emptyText: isCouple
                          ? '커플을 연결하면 관계 운세가 준비돼요.'
                          : '출생 프로필을 저장하면 개인 운세가 준비돼요.',
                    ),
                    if (!isCouple) ...[
                      const SizedBox(height: 26),
                      _fortuneCard(
                        _today?.emotionalFlow,
                        isCouple: false,
                        expectedType: 'emotional_flow',
                        emptyText: '오늘의 감정 흐름이 아직 없어요.',
                      ),
                      if (_today?.relationship != null) ...[
                        const SizedBox(height: 26),
                        _fortuneCard(
                          _today!.relationship!,
                          isCouple: true,
                          expectedType: 'relationship',
                          emptyText: '커플을 연결하면 관계 운세가 준비돼요.',
                        ),
                      ],
                    ],
                    const SizedBox(height: 26),
                    _howItWorks(isCouple: isCouple),
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
            ),
    );
  }

  Widget _intro({required bool isCouple, FortuneContent? content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _scopeBadge(isCouple: isCouple),
        const SizedBox(height: 12),
        const SizedBox(height: 5),
        Text(
          isCouple ? '오늘 우리 사이에 필요한 건' : '오늘 나에게 필요한 건',
          style: mainTitle(size: 30),
        ),
        const SizedBox(height: 5),
        Text(
          content?.title.isNotEmpty == true ? content!.title : '마음을 살피는 작은 힌트',
          style: mainBody(size: 15, color: kMainRose, weight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '예언을 맞히는 시간이 아니라, 오늘을 조금 다르게 바라보는 시간이에요.',
          style: mainBody(size: 13, color: kMainSub, height: 1.55),
        ),
      ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: isEmotional
                ? Icons.cloud_outlined
                : isCouple
                ? Icons.favorite_border_rounded
                : Icons.wb_sunny_outlined,
            title: sectionTitle,
            description: sectionDescription,
            color: isEmotional ? kMainLilac : kMainRose,
          ),
          const SizedBox(height: 10),
          if (content == null)
            MainCard(
              child: _emptyContent(
                emptyText,
                isCouple: isCouple,
                actionable: !isEmotional,
              ),
            )
          else
            _contentCard(content, isEmotional: isEmotional),
        ],
      ),
    );
  }

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(
          size: 38,
          color: color,
          backgroundColor: color.withAlpha(28),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: mainTitle(size: 22)),
              Text(
                description,
                style: mainBody(size: 12, color: kMainSub, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contentCard(FortuneContent content, {required bool isEmotional}) {
    final accent = isEmotional ? kMainLilac : kMainRose;
    return MainCard(
      key: Key('fortune_card_${content.type}'),
      color: isEmotional ? kMainLilacSoft : kMainPaper,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(content.title, style: mainTitle(size: 25))),
              if (content.status == 'fallback')
                Tooltip(
                  message: '고정 안내문으로 표시 중이에요',
                  child: Icon(Icons.info_outline, size: 18, color: accent),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '오늘의 한 줄',
            style: mainBody(size: 12, color: accent, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            content.summary,
            style: mainBody(size: 15, color: kMainInk, height: 1.65),
          ),
          const SizedBox(height: 16),
          if (content.signals.isNotEmpty)
            _insightRow(
              icon: Icons.visibility_outlined,
              label: '조심할 흐름',
              text: content.signals.join(' '),
              color: kMainPeach,
            ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: Key(_actionKey(content)),
            child: _insightRow(
              icon: Icons.touch_app_outlined,
              label: '힘이 되는 행동',
              text: content.suggestion,
              color: kMainSage,
            ),
          ),
          if (content.generatedText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('오늘의 한 문장', style: mainBody(size: 12, color: kMainSub)),
            const SizedBox(height: 3),
            Text(
              content.generatedText,
              style: mainBody(size: 13, color: kMainSub, height: 1.55),
            ),
          ],
          Text(
            content.disclaimer,
            style: mainBody(size: 11, color: kMainMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _actionKey(FortuneContent content) => switch (content.type) {
    'emotional_flow' => 'fortune_emotional_action',
    'relationship' => 'fortune_relationship_action',
    _ => 'fortune_action',
  };

  Widget _insightRow({
    required IconData icon,
    required String label,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: mainBody(
                  size: 12,
                  color: color,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: mainBody(size: 13, color: kMainInk, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _howItWorks({required bool isCouple}) {
    return MainCard(
      key: const Key('fortune_logic'),
      color: kMainPaperSoft,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: kMainHoney,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text('이 운세는 어떻게 나왔나요?', style: mainBody(weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: kMainHoneySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: kMainPeach,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isCouple ? '두 사람의 출생 정보 + 오늘 날짜' : '생년월일·출생 정보 + 오늘 날짜',
                    style: mainBody(
                      size: 13,
                      color: kMainInk,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          if (_today?.date.isNotEmpty == true) ...[
            _technicalRow('날짜', _today!.date),
            const SizedBox(height: 3),
          ],
          Text(
            '매일 조건이 같으면 같은 흐름이 나오도록 계산하고, 결과는 날짜별로 저장해요. 무작위 문구를 매번 바꾸는 방식이 아니라 오늘의 마음을 살피는 자기성찰용 힌트예요.',
            style: mainBody(size: 12, color: kMainSub, height: 1.55),
          ),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const Key('fortune_technical'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text(
                '계산 기준 자세히 보기',
                style: mainBody(
                  size: 13,
                  color: kMainInk,
                  weight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '같은 날짜·버전이면 같은 결과',
                style: mainBody(size: 11, color: kMainMuted),
              ),
              children: [
                _technicalRow(
                  '입력 정보',
                  isCouple
                      ? '두 사람의 달력 유형·생년월일·출생시간·출생지·시간대와 오늘 날짜'
                      : '달력 유형·생년월일·출생시간·출생지·시간대와 오늘 날짜',
                ),
                _technicalRow(
                  '결정 방식',
                  '입력값과 날짜를 SHA-256 해시로 바꾸어 정해진 테마를 선택해요.',
                ),
                _technicalRow('저장 방식', '콘텐츠 버전과 날짜별로 저장해 다시 방문해도 흐름이 바뀌지 않아요.'),
              ],
            ),
          ),
          if (_today?.contentVersion.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              '콘텐츠 버전 ${_today!.contentVersion} · 결과는 예언·진단·치료가 아닌 자기성찰용 안내예요.',
              style: mainBody(size: 11, color: kMainMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _technicalRow(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(label, style: mainBody(size: 11, color: kMainSub)),
          ),
          Expanded(
            child: Text(
              text,
              style: mainBody(size: 11, color: kMainInk, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeBadge({required bool isCouple}) => Semantics(
    container: true,
    label: isCouple ? '범위: 우리 둘의 관계 운세' : '범위: 나만 보는 개인 운세',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCouple ? kMainLilacSoft : kMainRoseSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCouple ? Icons.favorite_border_rounded : Icons.person_outline,
            size: 15,
            color: isCouple ? kMainLilac : kMainRose,
          ),
          const SizedBox(width: 5),
          Text(
            isCouple ? '우리 둘의 흐름' : '나만 보는 흐름',
            style: mainBody(
              size: 12,
              color: isCouple ? kMainLilac : kMainRose,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyContent(
    String text, {
    required bool isCouple,
    required bool actionable,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(text, style: mainBody(size: 13, color: kMainSub, height: 1.5)),
      if (actionable &&
          (widget.onEditProfile != null || widget.onOpenPartner != null)) ...[
        const SizedBox(height: 12),
        if (isCouple && widget.onOpenPartner != null)
          FilledButton.icon(
            onPressed: widget.onOpenPartner,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('파트너 연결하기'),
          )
        else if (!isCouple && widget.onEditProfile != null)
          OutlinedButton.icon(
            onPressed: widget.onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('출생 프로필 수정하기'),
          ),
      ],
    ],
  );

  Widget _errorState({required bool isCouple}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: MainCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: kMainSub, size: 34),
            const SizedBox(height: 10),
            Text(
              _error ?? '오늘의 운세를 불러오지 못했어요.',
              textAlign: TextAlign.center,
              style: mainBody(size: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
                if (isCouple &&
                    _error?.contains('파트너') == true &&
                    widget.onOpenPartner != null)
                  FilledButton(
                    onPressed: widget.onOpenPartner,
                    child: const Text('파트너 연결하기'),
                  ),
                if (!isCouple &&
                    _error?.contains('출생 프로필') == true &&
                    widget.onEditProfile != null)
                  FilledButton(
                    onPressed: widget.onEditProfile,
                    child: const Text('출생 프로필 수정하기'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
