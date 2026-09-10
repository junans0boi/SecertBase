import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';
import '../../core/saju_api.dart';

class SajuScreen extends StatefulWidget {
  final SajuApi? api;
  final VoidCallback? onEditProfile;

  const SajuScreen({super.key, this.api, this.onEditProfile});

  @override
  State<SajuScreen> createState() => _SajuScreenState();
}

class _SajuScreenState extends State<SajuScreen> {
  late final SajuApi _api;
  late final bool _ownsApi;
  SajuResult? _result;
  SajuApiException? _error;
  bool _loading = true;
  bool _technicalVisible = false;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final exception = error is SajuApiException
          ? error
          : const SajuApiException('unknown_error');
      setState(() {
        _error = exception;
        _loading = false;
      });
    }
  }

  Future<void> _confirmLimited() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.calculate(mode: SajuMode.limited);
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

  String _messageFor(SajuApiException error) => switch (error.reason) {
    'network_error' => '네트워크 연결을 확인하고 다시 시도해주세요.',
    'birth_profile_incomplete' => '출생 프로필을 먼저 저장해주세요.',
    'unsupported_birth_date_range' => '1900년부터 2050년까지의 출생 정보만 계산할 수 있어요.',
    _ => '사주 정보를 불러오지 못했어요.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('나의 사주', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : _error?.reason == 'saju_limited_confirmation_required'
          ? _limitedPrompt()
          : _result?.personal == null
          ? _errorState()
          : _reading(_result!.personal!),
    );
  }

  Widget _limitedPrompt() {
    return ListView(
      key: const Key('saju_reading_list'),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
      children: [
        MainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: kMainRose,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text('출생 정보가 조금 부족해요', style: mainTitle(size: 23)),
              const SizedBox(height: 8),
              Text(
                '출생 시각과 출생지가 없어 기본 명식으로 볼까요?',
                style: mainBody(size: 14, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '출생정보를 수정하면 더 자세한 시간 기둥까지 확인할 수 있어요.',
                style: mainBody(size: 12, color: kMainSub, height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: widget.onEditProfile,
                    child: const Text('출생정보 수정하기'),
                  ),
                  FilledButton(
                    key: const Key('saju_limited_confirm'),
                    onPressed: _confirmLimited,
                    style: FilledButton.styleFrom(backgroundColor: kMainRose),
                    child: const Text('네'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reading(SajuPersonal personal) {
    final day = personal.technical['chart'] is Map
        ? (personal.technical['chart'] as Map)['day']
        : null;
    final dayHanja = day is Map ? '${day['hanja'] ?? ''}' : '';
    final chart = personal.technical['chart'] is Map
        ? Map<String, dynamic>.from(personal.technical['chart'] as Map)
        : <String, dynamic>{};
    final technicalElements = personal.technical['elements'] is Map
        ? Map<String, dynamic>.from(personal.technical['elements'] as Map)
        : <String, dynamic>{};
    final technicalSipseong = personal.technical['sipseong'] is Map
        ? Map<String, dynamic>.from(personal.technical['sipseong'] as Map)
        : <String, dynamic>{};
    final technicalIlju = personal.technical['ilju'] is Map
        ? Map<String, dynamic>.from(personal.technical['ilju'] as Map)
        : <String, dynamic>{};
    final isLimited =
        personal.mode == 'limited' || personal.limitations.isNotEmpty;
    return ListView(
      key: const Key('saju_reading_list'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: [
        Text(
          isLimited ? '기본 명식으로 살펴봐요' : '오늘의 나를 천천히 살펴봐요',
          style: mainTitle(size: 27),
        ),
        const SizedBox(height: 6),
        Text(
          isLimited
              ? '출생 정보가 모두 채워지면 더 자세히 볼 수 있어요.'
              : '사주는 자기 성찰을 돕는 참고 콘텐츠예요.',
          style: mainBody(size: 13, color: kMainSub),
        ),
        const SizedBox(height: 18),
        MainCard(
          key: const Key('saju_plain_card'),
          padding: const EdgeInsets.all(20),
          gradient: kRoseGrad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                personal.plainTitle,
                style: mainTitle(size: 25, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                personal.plainSummary,
                style: mainBody(size: 14, color: Colors.white, height: 1.5),
              ),
              if ((personal.plain['focus'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  personal.plain['focus'].toString(),
                  style: mainBody(size: 13, color: Colors.white, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        if (_plainMaps(personal.plain['pillars']).isNotEmpty) ...[
          const SizedBox(height: 14),
          _pillarOverview(personal.plain['pillars']),
        ],
        if (personal.plain['dayMaster'] is Map) ...[
          const SizedBox(height: 12),
          _dayMasterCard(
            Map<String, dynamic>.from(personal.plain['dayMaster'] as Map),
          ),
        ],
        if (personal.plain['elements'] is Map) ...[
          const SizedBox(height: 12),
          _elementsCard(
            Map<String, dynamic>.from(personal.plain['elements'] as Map),
          ),
        ],
        if (personal.plain['sipseong'] is Map) ...[
          const SizedBox(height: 12),
          _sipseongCard(
            Map<String, dynamic>.from(personal.plain['sipseong'] as Map),
          ),
        ],
        if (personal.plain['ilju'] is Map) ...[
          const SizedBox(height: 12),
          _iljuCard(Map<String, dynamic>.from(personal.plain['ilju'] as Map)),
        ],
        if ((personal.plain['reflectionPrompts'] as List? ?? const [])
            .isNotEmpty) ...[
          const SizedBox(height: 12),
          _reflectionCard(personal.plain['reflectionPrompts'] as List),
        ],
        if (_result?.relationship != null) ...[
          const SizedBox(height: 12),
          _relationshipReading(_result!.relationship!),
        ],
        const SizedBox(height: 12),
        MainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계산 기준', style: mainBody(size: 12, color: kMainSub)),
              const SizedBox(height: 8),
              Text(
                personal.basis.join('\n'),
                style: mainBody(size: 12, height: 1.5),
              ),
              if (personal.limitations.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '참고: ${personal.limitations.join(', ')}',
                  style: mainBody(size: 12, color: kMainSub),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('saju_technical_toggle'),
          onPressed: () =>
              setState(() => _technicalVisible = !_technicalVisible),
          icon: Icon(
            _technicalVisible ? Icons.visibility_off : Icons.menu_book_outlined,
          ),
          label: Text(_technicalVisible ? '쉬운 설명으로 보기' : '더 전문적으로 읽어보기'),
        ),
        if (_technicalVisible) ...[
          const SizedBox(height: 12),
          MainCard(
            key: const Key('saju_technical_card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('전문 용어', style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('일주', style: mainBody(size: 12, color: kMainSub)),
                const SizedBox(height: 2),
                Text(
                  dayHanja,
                  style: mainBody(size: 20, weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '계산된 명식은 해석 참고용이며 예측·진단으로 사용하지 않아요.',
                  style: mainBody(size: 12, color: kMainSub, height: 1.5),
                ),
                if (chart.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('네 기둥 원문', style: mainBody(size: 12, color: kMainSub)),
                  const SizedBox(height: 6),
                  _technicalPillars(chart),
                ],
                if (technicalElements.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    '오행 본기: ${technicalElements['counts'] ?? ''}',
                    style: mainBody(size: 12, height: 1.5),
                  ),
                  Text(
                    '오행 가중치: ${technicalElements['weighted'] ?? ''}',
                    style: mainBody(size: 12, color: kMainSub, height: 1.5),
                  ),
                ],
                if (technicalSipseong.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '십신 분포: ${technicalSipseong['counts'] ?? ''}',
                    style: mainBody(size: 12, height: 1.5),
                  ),
                ],
                if (technicalIlju.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '일주 세부: ${technicalIlju['ganji'] ?? ''} · ${technicalIlju['twelveStage'] ?? ''} · ${technicalIlju['branchSipseong'] ?? ''}',
                    style: mainBody(size: 12, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _technicalPillars(Map<String, dynamic> chart) {
    const labels = <String, String>{
      'year': '년주',
      'month': '월주',
      'day': '일주',
      'hour': '시주',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          Builder(
            builder: (context) {
              final value = chart[entry.key];
              final pillar = value is Map
                  ? Map<String, dynamic>.from(value)
                  : const <String, dynamic>{};
              return Chip(
                label: Text(
                  '${entry.value} ${pillar['korean'] ?? '미계산'} ${pillar['hanja'] ?? ''}',
                ),
              );
            },
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _plainMaps(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);

  Widget _sectionHeader(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: mainBody(size: 17, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: mainBody(size: 12, color: kMainSub, height: 1.45)),
    ],
  );

  Widget _pillarOverview(Object? rawPillars) {
    final pillars = _plainMaps(rawPillars);
    return MainCard(
      key: const Key('saju_pillars_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('나의 네 기둥', '사주팔자를 한눈에 보고, 각 기둥이 어떤 이야기를 여는지 살펴봐요.'),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pillars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1.7,
            ),
            itemBuilder: (context, index) {
              final pillar = pillars[index];
              final available = pillar['available'] == true;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: available
                      ? kMainRoseSoft.withValues(alpha: .72)
                      : kMainBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMainLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pillar['label'] ?? ''}',
                      style: mainBody(size: 11, color: kMainSub),
                    ),
                    const Spacer(),
                    Text(
                      available
                          ? '${pillar['korean'] ?? ''}  ${pillar['hanja'] ?? ''}'
                          : '미계산',
                      style: mainTitle(
                        size: 17,
                        color: available ? kMainInk : kMainMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${pillar['role'] ?? ''}',
                      style: mainBody(size: 10, color: kMainSub),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dayMasterCard(Map<String, dynamic> dayMaster) => MainCard(
    key: const Key('saju_day_master_card'),
    color: kMainLilacSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('내 중심, 일간', '나를 하나의 성격으로 단정하기보다 반응을 관찰하는 중심축이에요.'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${dayMaster['label'] ?? ''}', style: mainTitle(size: 26)),
            const SizedBox(width: 8),
            Text(
              '${dayMaster['polarity'] ?? ''}기운',
              style: mainBody(size: 12, color: kMainSub),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${dayMaster['keywords'] ?? ''}',
          style: mainBody(size: 13, color: kMainRose, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${dayMaster['summary'] ?? ''}',
          style: mainBody(size: 13, height: 1.55),
        ),
      ],
    ),
  );

  Widget _elementsCard(Map<String, dynamic> elements) {
    final entries = _plainMaps(elements['entries']);
    final max = entries.fold<double>(0, (value, entry) {
      final count = double.tryParse('${entry['count'] ?? 0}') ?? 0;
      return count > value ? count : value;
    });
    final dominant = _plainMaps(elements['dominant']);
    final lacking = _plainMaps(elements['lacking']);
    return MainCard(
      key: const Key('saju_elements_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('오행 균형', '다섯 기운의 분포를 보고, 나에게 필요한 균형을 귀엽게 체크해봐요.'),
          const SizedBox(height: 12),
          for (final entry in entries) ...[
            Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${entry['name'] ?? ''}',
                    style: mainBody(size: 12, weight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 9,
                      value: max == 0
                          ? 0
                          : (double.tryParse('${entry['count'] ?? 0}') ?? 0) /
                                max,
                      backgroundColor: kMainBg,
                      color: _elementColor('${entry['key'] ?? ''}'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${entry['count'] ?? 0}',
                    textAlign: TextAlign.end,
                    style: mainBody(size: 12, color: kMainSub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 3),
          Text(
            '${elements['summary'] ?? ''}',
            style: mainBody(size: 13, height: 1.5),
          ),
          if (dominant.isNotEmpty || lacking.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in dominant)
                  Chip(label: Text('많이 드러난 ${item['name'] ?? ''}')),
                for (final item in lacking)
                  Chip(label: Text('살펴볼 ${item['name'] ?? ''}')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _elementColor(String element) => switch (element) {
    '木' => const Color(0xff5bbf91),
    '火' => const Color(0xffef8585),
    '土' => const Color(0xffd4a45d),
    '金' => const Color(0xff9da9bd),
    '水' => const Color(0xff7698da),
    _ => kMainLilac,
  };

  Widget _sipseongCard(Map<String, dynamic> sipseong) {
    final entries = _plainMaps(sipseong['entries']);
    final max = entries.fold<double>(0, (value, entry) {
      final count = double.tryParse('${entry['count'] ?? 0}') ?? 0;
      return count > value ? count : value;
    });
    return MainCard(
      key: const Key('saju_sipseong_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('십신의 흐름', '사람·표현·현실·기준·회복 중 어떤 힘이 자주 등장하는지 살펴봐요.'),
          const SizedBox(height: 12),
          for (final entry in entries) ...[
            Row(
              children: [
                SizedBox(
                  width: 105,
                  child: Text(
                    '${entry['name'] ?? ''}',
                    style: mainBody(size: 12, weight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: max == 0
                          ? 0
                          : (double.tryParse('${entry['count'] ?? 0}') ?? 0) /
                                max,
                      backgroundColor: kMainBg,
                      color: kMainRose,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${entry['count'] ?? 0}',
                    textAlign: TextAlign.end,
                    style: mainBody(size: 12, color: kMainSub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 4),
          Text(
            '${sipseong['summary'] ?? ''}',
            style: mainBody(size: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _iljuCard(Map<String, dynamic> ilju) => MainCard(
    key: const Key('saju_ilju_card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('일주 포인트', '오늘의 나를 읽는 중심인 일주를 조금 더 전문적으로, 그래도 쉽게 풀어봤어요.'),
        const SizedBox(height: 10),
        Text(
          '${ilju['ganji'] ?? ''} · ${ilju['twelveStage'] ?? ''}',
          style: mainTitle(size: 22),
        ),
        const SizedBox(height: 5),
        Text(
          '${ilju['stageSummary'] ?? ''}',
          style: mainBody(size: 13, color: kMainRose, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${ilju['summary'] ?? ''}',
          style: mainBody(size: 13, height: 1.5),
        ),
      ],
    ),
  );

  Widget _reflectionCard(List prompts) => MainCard(
    key: const Key('saju_reflection_card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('오늘 가져갈 질문', '사주를 정답표가 아니라 나를 살펴보는 질문으로 사용해봐요.'),
        const SizedBox(height: 8),
        for (final prompt in prompts) ...[
          const SizedBox(height: 6),
          Text('✦  $prompt', style: mainBody(size: 13, height: 1.5)),
        ],
      ],
    ),
  );

  Widget _relationshipReading(Map<String, dynamic> relationship) {
    final patterns = (relationship['patterns'] as List? ?? const [])
        .whereType<Map>()
        .map((pattern) => Map<String, dynamic>.from(pattern))
        .toList(growable: false);
    final questions =
        (relationship['conversationQuestions'] as List? ?? const [])
            .map((question) => '$question')
            .toList(growable: false);
    return MainCard(
      key: const Key('saju_relationship_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('우리의 관계 사주', style: mainBody(weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '점수 대신 서로를 이해할 대화 실마리를 살펴봐요.',
            style: mainBody(size: 12, color: kMainSub, height: 1.5),
          ),
          for (final pattern in patterns) ...[
            const SizedBox(height: 12),
            Text(
              '${pattern['title'] ?? ''}',
              style: mainBody(weight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              '${pattern['summary'] ?? ''}',
              style: mainBody(size: 13, height: 1.5),
            ),
          ],
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('대화해볼 질문', style: mainBody(size: 12, color: kMainSub)),
            const SizedBox(height: 4),
            Text(
              questions.map((question) => '· $question').join('\n'),
              style: mainBody(size: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: MainCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: kMainSub, size: 34),
            const SizedBox(height: 10),
            Text(
              _messageFor(_error ?? const SajuApiException('unknown_error')),
              textAlign: TextAlign.center,
              style: mainBody(size: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      ),
    ),
  );
}
