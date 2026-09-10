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
    final isLimited =
        personal.mode == 'limited' || personal.limitations.isNotEmpty;
    return ListView(
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
              ],
            ),
          ),
        ],
      ],
    );
  }

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
