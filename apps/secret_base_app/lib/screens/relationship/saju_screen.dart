import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/auth_service.dart';
import '../../core/birth_profile_api.dart';
import '../../core/saju_api.dart';
import 'birth_info_sheet.dart';
import 'share_card.dart';

class SajuScreen extends StatefulWidget {
  final SajuApi? api;
  final VoidCallback? onEditProfile;
  final bool relationshipFirst;

  /// Used by the standalone "정보 추가하기" sheet (tests inject a fake).
  final BirthProfileApi? birthProfileApi;

  const SajuScreen({
    super.key,
    this.api,
    this.onEditProfile,
    this.relationshipFirst = false,
    this.birthProfileApi,
  });

  @override
  State<SajuScreen> createState() => _SajuScreenState();
}

class _SajuScreenState extends State<SajuScreen> {
  late final SajuApi _api;
  late final bool _ownsApi;
  SajuResult? _result;
  SajuApiException? _error;
  bool _loading = true;
  bool _technical = false;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    final auth = AuthService();
    _api =
        widget.api ?? SajuApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    _load();
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    super.dispose();
  }

  Future<void> _run(Future<SajuResult> Function() call) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await call();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is SajuApiException
            ? error
            : const SajuApiException('unknown_error');
        _loading = false;
      });
    }
  }

  Future<void> _load() => _run(_api.fetch);

  Future<void> _confirmLimited() =>
      _run(() => _api.calculate(mode: SajuMode.limited));

  /// "정보 추가하기" / "출생 정보 수정하기": always works, even when the
  /// screen is opened without callbacks.
  Future<void> _editProfile() async {
    final custom = widget.onEditProfile;
    if (custom != null) {
      custom();
      return;
    }
    final auth = AuthService();
    final api =
        widget.birthProfileApi ??
        BirthProfileApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
    BirthProfile? existing;
    try {
      existing = await api.fetch();
    } catch (_) {
      existing = null; // first time: prefill from the signup birthday
    }
    if (!mounted) return;
    final saved = await showBirthInfoSheet(
      context,
      api: api,
      existing: existing,
    );
    if (widget.birthProfileApi == null) api.close();
    if (saved != null && mounted) await _load();
  }

  String _messageFor(SajuApiException error) => switch (error.reason) {
    'network_error' => '네트워크 연결을 확인하고 다시 시도해 주세요.',
    'birth_profile_incomplete' => '출생 정보를 먼저 알려 주세요.',
    _ => '사주 정보를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    return V2Theme(
      child: Scaffold(
        appBar: V2Header(
          title: widget.relationshipFirst ? '우리의 관계 사주' : '나의 사주',
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2SkeletonList(count: 3),
      );
    }
    final reason = _error?.reason;
    if (reason == 'saju_limited_confirmation_required') return _limitedPrompt();
    if (reason == 'unsupported_birth_date_range') return _outOfRange();
    final personal = _result?.personal;
    if (personal == null) return _errorState();
    return _reading(personal);
  }

  Widget _centered(Widget child) => ListView(
    key: const Key('saju_reading_list'),
    padding: const EdgeInsets.fromLTRB(V2Space.page, 24, V2Space.page, 32),
    children: [child],
  );

  Widget _limitedPrompt() => _centered(
    V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const V2Art(icon: V2Icons.info, tone: V2Tone.honey, size: 56),
          const SizedBox(height: 14),
          Text('태어난 시각을 모르면 시각 없이 볼 수 있어요', style: V2Text.head),
          const SizedBox(height: 8),
          Text(
            '시각이 없으면 네 기둥 중 시간 기둥은 빠지고 세 기둥으로 살펴봐요. 나중에 시각을 알게 되면 정보를 추가해서 더 자세히 볼 수 있어요.',
            style: V2Text.body,
          ),
          const SizedBox(height: 18),
          V2Button(
            key: const Key('saju_limited_confirm'),
            label: '시각 없이 보기',
            onPressed: _confirmLimited,
          ),
          const SizedBox(height: 8),
          V2Button(
            key: const Key('saju_edit_profile'),
            label: '정보 추가하기',
            variant: V2ButtonVariant.soft,
            onPressed: _editProfile,
          ),
        ],
      ),
    ),
  );

  Widget _outOfRange() => _centered(
    V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const V2Art(icon: V2Icons.calendar, tone: V2Tone.sky, size: 56),
          const SizedBox(height: 14),
          Text('계산할 수 있는 날짜를 벗어났어요', style: V2Text.head),
          const SizedBox(height: 8),
          Text(
            '1900년부터 2050년 사이에 태어난 날만 계산할 수 있어요. 생년월일이 맞는지 확인해 주세요.',
            style: V2Text.body,
          ),
          const SizedBox(height: 18),
          V2Button(label: '출생 정보 수정하기', onPressed: _editProfile),
        ],
      ),
    ),
  );

  Widget _errorState() {
    final incomplete = _error?.reason == 'birth_profile_incomplete';
    return Column(
      children: [
        Expanded(
          child: _error?.reason == 'network_error'
              ? V2ErrorState.offline(onRetry: _load)
              : V2ErrorState(
                  title: incomplete ? '출생 정보가 필요해요' : '사주를 불러오지 못했어요',
                  body: _messageFor(
                    _error ?? const SajuApiException('unknown_error'),
                  ),
                  onRetry: _load,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(V2Space.page),
          child: V2Button(
            label: incomplete ? '출생 정보 입력하기' : '출생 정보 수정하기',
            variant: incomplete
                ? V2ButtonVariant.primary
                : V2ButtonVariant.soft,
            onPressed: _editProfile,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _maps(Object? v) => (v as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);

  Widget _reading(SajuPersonal personal) {
    final isLimited =
        personal.mode == 'limited' || personal.limitations.isNotEmpty;
    final p = V2Palette.of(context);
    final rel = _result?.relationship;
    final relFirst = widget.relationshipFirst && rel != null;
    return ListView(
      key: const Key('saju_reading_list'),
      padding: const EdgeInsets.fromLTRB(V2Space.page, 4, V2Space.page, 40),
      children: [
        if (isLimited) ...[
          V2Banner(
            message: '태어난 시각 없이 본 결과예요. 시각을 알게 되면 더 자세히 볼 수 있어요.',
            actionLabel: '정보 추가하기',
            onAction: _editProfile,
          ),
          const SizedBox(height: 12),
        ],
        V2Segmented<bool>(
          key: const Key('saju_technical_toggle'),
          segments: const [
            V2Segment(value: false, label: '쉬운 설명'),
            V2Segment(value: true, label: '전문 용어'),
          ],
          selected: _technical,
          onChanged: (v) => setState(() => _technical = v),
        ),
        const SizedBox(height: 14),
        if (relFirst) ...[
          _relationshipReading(rel),
          const SizedBox(height: 12),
        ],
        if (!_technical) ..._plain(personal, p) else ..._pro(personal),
        if (!relFirst && rel != null) ...[
          const SizedBox(height: 12),
          _relationshipReading(rel),
        ],
        const SizedBox(height: 16),
        _details(personal),
        const SizedBox(height: 12),
        Text('해석 참고용이에요. 예측이나 진단으로 쓰지 말아 주세요.', style: V2Text.cap),
      ],
    );
  }

  List<Widget> _plain(SajuPersonal personal, V2Palette p) {
    final pillars = _maps(personal.plain['pillars']);
    final focus = '${personal.plain['focus'] ?? ''}';
    return [
      V2Card(
        gradient: V2Gradients.hero,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.relationshipFirst ? '우리의 사주 이야기' : '오늘의 나를 천천히 살펴봐요',
              style: V2Text.label.copyWith(
                color: V2Colors.onHeroStrong,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              personal.plainTitle,
              style: V2Text.serif(size: 24, color: V2Colors.onHeroStrong),
            ),
            const SizedBox(height: 10),
            Text(
              personal.plainSummary,
              style: V2Text.body.copyWith(color: V2Colors.onHeroStrong),
            ),
            if (focus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                focus,
                style: V2Text.body.copyWith(color: V2Colors.onHeroStrong),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      V2Button(
        label: '카드로 공유',
        icon: V2Icons.share,
        variant: V2ButtonVariant.soft,
        onPressed: () => _share(personal),
      ),
      if (pillars.isNotEmpty) ...[
        const SizedBox(height: 12),
        _pillars(pillars),
      ],
      if (personal.plain['dayMaster'] is Map) ...[
        const SizedBox(height: 12),
        _dayMaster(_map(personal.plain['dayMaster'])),
      ],
      if (personal.plain['elements'] is Map) ...[
        const SizedBox(height: 12),
        _bars(
          key: const Key('saju_elements_card'),
          title: '오행 균형',
          data: _map(personal.plain['elements']),
          colorOf: _elementColor,
          chips: true,
        ),
      ],
      if (personal.plain['sipseong'] is Map) ...[
        const SizedBox(height: 12),
        _bars(
          key: const Key('saju_sipseong_card'),
          title: '십신의 흐름',
          data: _map(personal.plain['sipseong']),
          colorOf: (_) => V2Colors.lilac,
        ),
      ],
      if (personal.plain['ilju'] is Map) ...[
        const SizedBox(height: 12),
        _ilju(_map(personal.plain['ilju'])),
      ],
      if ((personal.plain['reflectionPrompts'] as List? ?? const [])
          .isNotEmpty) ...[
        const SizedBox(height: 12),
        V2Card(
          key: const Key('saju_reflection_card'),
          variant: V2CardVariant.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('오늘 가져갈 질문', style: V2Text.head),
              const SizedBox(height: 4),
              Text('사주를 정답표가 아니라 나를 살펴보는 질문으로 써 보세요.', style: V2Text.cap),
              for (final prompt
                  in personal.plain['reflectionPrompts'] as List) ...[
                const SizedBox(height: 8),
                Text('· $prompt', style: V2Text.body),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _pro(SajuPersonal personal) {
    final chart = _map(personal.technical['chart']);
    final day = chart['day'];
    final dayHanja = day is Map ? '${day['hanja'] ?? ''}' : '';
    final elements = _map(personal.technical['elements']);
    final sipseong = _map(personal.technical['sipseong']);
    final ilju = _map(personal.technical['ilju']);
    return [
      V2Card(
        key: const Key('saju_technical_card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('전문 용어', style: V2Text.head),
            const SizedBox(height: 10),
            Text('일주', style: V2Text.cap),
            Text(
              dayHanja,
              style: V2Text.serif(size: 26, color: V2Palette.of(context).ink),
            ),
            if (chart.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('네 기둥 원문', style: V2Text.cap),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in const {
                    'year': '년주',
                    'month': '월주',
                    'day': '일주',
                    'hour': '시주',
                  }.entries)
                    V2Chip(label: '${e.value} ${_pillarText(chart[e.key])}'),
                ],
              ),
            ],
            if (elements.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('오행 본기: ${elements['counts'] ?? ''}', style: V2Text.body),
              Text('오행 가중치: ${elements['weighted'] ?? ''}', style: V2Text.cap),
            ],
            if (sipseong.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('십신 분포: ${sipseong['counts'] ?? ''}', style: V2Text.body),
            ],
            if (ilju.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '일주 세부: ${ilju['ganji'] ?? ''} · ${ilju['twelveStage'] ?? ''} · ${ilju['branchSipseong'] ?? ''}',
                style: V2Text.body,
              ),
            ],
          ],
        ),
      ),
    ];
  }

  String _pillarText(Object? v) {
    if (v is! Map) return '미계산';
    return '${v['korean'] ?? ''} ${v['hanja'] ?? ''}'.trim();
  }

  Widget _pillars(List<Map<String, dynamic>> pillars) {
    final p = V2Palette.of(context);
    return V2Card(
      key: const Key('saju_pillars_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('나의 네 기둥', style: V2Text.head),
          const SizedBox(height: 4),
          Text('각 기둥이 어떤 이야기를 여는지 살펴봐요.', style: V2Text.cap),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              for (final pillar in pillars)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pillar['available'] == true ? p.primarySoft : p.soft,
                    borderRadius: BorderRadius.circular(V2Radius.ctl),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${pillar['label'] ?? ''}', style: V2Text.cap),
                      const Spacer(),
                      Text(
                        pillar['available'] == true
                            ? '${pillar['korean'] ?? ''}  ${pillar['hanja'] ?? ''}'
                            : '시각 없이 비워 둬요',
                        style: V2Text.bodyStrong.copyWith(color: p.ink),
                      ),
                      Text('${pillar['role'] ?? ''}', style: V2Text.cap),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayMaster(Map<String, dynamic> d) => V2Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('내 중심, 일간', style: V2Text.cap),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                '${d['label'] ?? ''}',
                style: V2Text.serif(size: 24, color: V2Palette.of(context).ink),
              ),
            ),
            const SizedBox(width: 8),
            V2Chip(label: '${d['polarity'] ?? ''}기운', tone: V2Tone.rose),
          ],
        ),
        const SizedBox(height: 8),
        Text('${d['keywords'] ?? ''}', style: V2Text.bodyStrong),
        const SizedBox(height: 4),
        Text('${d['summary'] ?? ''}', style: V2Text.body),
      ],
    ),
  );

  Color _elementColor(String element) => switch (element) {
    '木' => V2Colors.sage,
    '火' => V2Colors.peach,
    '土' => V2Colors.honey,
    '金' => V2Colors.sky,
    '水' => V2Colors.lilac,
    _ => V2Colors.lilac,
  };

  Widget _bars({
    required Key key,
    required String title,
    required Map<String, dynamic> data,
    required Color Function(String) colorOf,
    bool chips = false,
  }) {
    final entries = _maps(data['entries']);
    double count(Map<String, dynamic> e) =>
        double.tryParse('${e['count'] ?? 0}') ?? 0;
    final max = entries.fold<double>(0, (m, e) => count(e) > m ? count(e) : m);
    final dominant = _maps(data['dominant']);
    final lacking = _maps(data['lacking']);
    return V2Card(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: V2Text.head),
          const SizedBox(height: 10),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text('${e['name'] ?? ''}', style: V2Text.cap),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(V2Radius.pill),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : count(e) / max,
                        minHeight: 10,
                        backgroundColor: V2Palette.of(context).soft2,
                        color: colorOf('${e['key'] ?? ''}'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${e['count'] ?? 0}',
                      textAlign: TextAlign.end,
                      style: V2Text.cap,
                    ),
                  ),
                ],
              ),
            ),
          if ('${data['summary'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${data['summary']}', style: V2Text.body),
          ],
          if (chips && (dominant.isNotEmpty || lacking.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in dominant)
                  V2Chip(label: '많이 드러난 ${i['name'] ?? ''}', tone: V2Tone.rose),
                for (final i in lacking)
                  V2Chip(label: '살펴볼 ${i['name'] ?? ''}', tone: V2Tone.sky),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ilju(Map<String, dynamic> d) => V2Card(
    variant: V2CardVariant.soft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('일주 포인트', style: V2Text.cap),
        const SizedBox(height: 4),
        Text(
          '${d['ganji'] ?? ''} · ${d['twelveStage'] ?? ''}',
          style: V2Text.head,
        ),
        const SizedBox(height: 6),
        Text('${d['stageSummary'] ?? ''}', style: V2Text.body),
        const SizedBox(height: 6),
        Text('${d['summary'] ?? ''}', style: V2Text.body),
      ],
    ),
  );

  Widget _relationshipReading(Map<String, dynamic> relationship) {
    final patterns = _maps(relationship['patterns']);
    final questions =
        (relationship['conversationQuestions'] as List? ?? const [])
            .map((q) => '$q')
            .toList(growable: false);
    return V2Card(
      key: const Key('saju_relationship_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('우리의 관계 사주', style: V2Text.head),
          const SizedBox(height: 4),
          Text('점수 대신 서로를 이해할 대화 실마리를 살펴봐요.', style: V2Text.cap),
          for (final pattern in patterns) ...[
            const SizedBox(height: 12),
            Text('${pattern['title'] ?? ''}', style: V2Text.bodyStrong),
            const SizedBox(height: 2),
            Text('${pattern['summary'] ?? ''}', style: V2Text.body),
          ],
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('대화해 볼 질문', style: V2Text.cap),
            const SizedBox(height: 4),
            for (final q in questions) Text('· $q', style: V2Text.body),
          ],
        ],
      ),
    );
  }

  /// Hash / version / input summary live behind "자세히".
  Widget _details(SajuPersonal personal) {
    final version = _result?.calculationVersion ?? '';
    return V2Card(
      variant: V2CardVariant.soft,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('saju_details'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text('자세히', style: V2Text.bodyStrong),
            subtitle: Text('계산 기준과 참고 사항', style: V2Text.cap),
            children: [
              if (personal.basis.isNotEmpty)
                Text(personal.basis.join('\n'), style: V2Text.body),
              if (personal.limitations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '참고: ${personal.limitations.join(', ')}',
                  style: V2Text.cap,
                ),
              ],
              if (personal.inputSummary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '사용한 출생 정보: ${personal.inputSummary.values.where((v) => '$v'.isNotEmpty).join(' · ')}',
                  style: V2Text.cap,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '계산 버전 ${version.isNotEmpty ? version : '확인 중'}',
                style: V2Text.cap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _share(SajuPersonal personal) {
    final line = personal.plainSummary.length > 90
        ? '${personal.plainSummary.substring(0, 90)}…'
        : personal.plainSummary;
    showShareCardSheet(
      context,
      fileName: 'secretbase-saju.png',
      caption: '나의 사주 · ${personal.plainTitle}\n$line\n- 비밀기지',
      card: ShareCard(
        kind: widget.relationshipFirst ? '우리의 사주' : '나의 사주',
        title: personal.plainTitle,
        line: line,
        gradient: V2Gradients.hero,
        art: Icon(V2Icons.sparkle, color: V2Colors.onHeroStrong, size: 64),
      ),
    );
  }
}
