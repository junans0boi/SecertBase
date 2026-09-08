import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/app_theme.dart';
import '../../core/assessment_catalog_api.dart';
import '../../core/birth_profile_api.dart';
import '../../core/main_design.dart';
import 'assessment_catalog_screen.dart';

enum RelationshipAssessmentStatus {
  profileIncomplete,
  notStarted,
  inProgress,
  resultReady,
}

class RelationshipEntryCard extends StatelessWidget {
  final RelationshipAssessmentStatus status;
  final VoidCallback onTap;

  const RelationshipEntryCard({
    super.key,
    required this.status,
    required this.onTap,
  });

  String get _title => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete => '관계 이해 준비하기',
    RelationshipAssessmentStatus.notStarted => '관계 이해 시작하기',
    RelationshipAssessmentStatus.inProgress => '관계 이해 이어하기',
    RelationshipAssessmentStatus.resultReady => '관계 이해 결과 보기',
  };

  String get _subtitle => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete => '출생 프로필을 먼저 완성해주세요',
    RelationshipAssessmentStatus.notStarted => '검사로 우리를 알아가요',
    RelationshipAssessmentStatus.inProgress => '진행 중인 검사를 이어가세요',
    RelationshipAssessmentStatus.resultReady => '새로운 관계 패턴을 확인해보세요',
  };

  IconData get _icon => switch (status) {
    RelationshipAssessmentStatus.profileIncomplete => Icons.edit_note_outlined,
    RelationshipAssessmentStatus.notStarted => Icons.psychology_outlined,
    RelationshipAssessmentStatus.inProgress => Icons.play_circle_outline,
    RelationshipAssessmentStatus.resultReady => Icons.insights_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kMainLilacSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_icon, color: kMainLilac),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title, style: mainBody(weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(_subtitle, style: mainBody(size: 12, color: kMainSub)),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: kMainMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelationshipUnderstandingScreen extends StatefulWidget {
  final BirthProfileApi? api;
  final RelationshipAssessmentStatus assessmentStatus;
  final bool hasActiveCouple;

  const RelationshipUnderstandingScreen({
    super.key,
    this.api,
    this.assessmentStatus = RelationshipAssessmentStatus.notStarted,
    this.hasActiveCouple = false,
  });

  @override
  State<RelationshipUnderstandingScreen> createState() =>
      _RelationshipUnderstandingScreenState();
}

class _RelationshipUnderstandingScreenState
    extends State<RelationshipUnderstandingScreen> {
  late final BirthProfileApi _api;
  late final bool _ownsApi;
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'Asia/Seoul');
  final _birthPlaceController = TextEditingController();
  BirthCalendarType _calendarType = BirthCalendarType.solar;
  BirthProfile? _profile;
  String? _errorMessage;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api =
        widget.api ??
        BirthProfileApi(
          baseUrl: AuthService().baseUrl,
          token: AuthService().token ?? '',
        );
    _loadProfile();
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _timezoneController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.fetch();
      if (!mounted) return;
      _setProfile(profile);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  void _setProfile(BirthProfile profile) {
    _calendarType = profile.calendarType;
    _birthDateController.text = profile.birthDate;
    _birthTimeController.text = profile.birthTime ?? '';
    _timezoneController.text = profile.timezone;
    _birthPlaceController.text = profile.birthPlace ?? '';
  }

  Future<void> _save() async {
    final birthDate = _birthDateController.text.trim();
    final timezone = _timezoneController.text.trim();
    if (birthDate.isEmpty || timezone.isEmpty) {
      setState(() => _errorMessage = '생년월일과 시간대를 입력해주세요.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final profile = await _api.update(
        BirthProfileInput(
          calendarType: _calendarType,
          birthDate: birthDate,
          birthTime: _birthTimeController.text.trim().isEmpty
              ? null
              : _birthTimeController.text.trim(),
          timezone: timezone,
          birthPlace: _birthPlaceController.text.trim().isEmpty
              ? null
              : _birthPlaceController.text.trim(),
        ),
      );
      if (!mounted) return;
      _setProfile(profile);
      setState(() {
        _profile = profile;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('출생 프로필을 저장했어요.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) {
    if (error is! BirthProfileApiException) return '출생 프로필을 불러오지 못했어요.';
    return switch (error.reason) {
      'network_error' => '네트워크 연결을 확인하고 다시 시도해주세요.',
      'invalid_calendar_type' => '양력 또는 음력을 선택해주세요.',
      'invalid_birth_date' => '생년월일을 올바르게 입력해주세요.',
      'future_birth_date' => '미래 날짜는 입력할 수 없어요.',
      'invalid_birth_time' => '출생 시각을 HH:mm 형식으로 입력해주세요.',
      'invalid_timezone' => '시간대 형식을 확인해주세요.',
      'missing_fields' => '생년월일과 시간대를 입력해주세요.',
      _ => '출생 프로필을 저장하지 못했어요.',
    };
  }

  RelationshipAssessmentStatus get _effectiveStatus {
    if (_profile == null || _profile!.birthDate.trim().isEmpty) {
      return RelationshipAssessmentStatus.profileIncomplete;
    }
    return widget.assessmentStatus;
  }

  String get _statusTitle => switch (_effectiveStatus) {
    RelationshipAssessmentStatus.profileIncomplete => '출생 프로필을 먼저 완성해주세요',
    RelationshipAssessmentStatus.notStarted => '아직 시작하지 않은 검사예요',
    RelationshipAssessmentStatus.inProgress => '진행 중인 검사가 있어요',
    RelationshipAssessmentStatus.resultReady => '확인할 결과가 준비됐어요',
  };

  String get _statusDescription => switch (_effectiveStatus) {
    RelationshipAssessmentStatus.profileIncomplete =>
      '기본 정보를 저장하면 관계 이해를 시작할 수 있어요.',
    RelationshipAssessmentStatus.notStarted => '개인 검사부터 천천히 시작할 수 있어요.',
    RelationshipAssessmentStatus.inProgress => '내가 답한 곳부터 이어서 살펴볼 수 있어요.',
    RelationshipAssessmentStatus.resultReady => '점수와 관계 패턴을 함께 확인해보세요.',
  };

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MainCard(
          key: const Key('relationship_hub_error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36, color: kMainSub),
              const SizedBox(height: 12),
              Text('관계 이해 정보를 불러오지 못했어요', style: mainTitle(size: 20)),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '잠시 후 다시 시도해주세요.',
                textAlign: TextAlign.center,
                style: mainBody(size: 13, color: kMainSub, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadProfile,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    return MainCard(
      key: const Key('relationship_status_card'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: kMainLilac),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 상태', style: mainBody(size: 12, color: kMainSub)),
                const SizedBox(height: 4),
                Text(_statusTitle, style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  _statusDescription,
                  style: mainBody(size: 13, color: kMainSub, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalArea() {
    return MainCard(
      key: const Key('relationship_personal_area'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: kMainRose),
              const SizedBox(width: 8),
              Text('개인 영역', style: mainBody(weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '파트너가 없어도 내 감정과 관계 패턴을 먼저 살펴볼 수 있어요.',
            style: mainBody(size: 13, color: kMainSub, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _openCatalog,
            child: const Text('검사 목록 보기'),
          ),
        ],
      ),
    );
  }

  void _openCatalog() {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssessmentCatalogScreen(
          api: AssessmentCatalogApi(
            baseUrl: auth.baseUrl,
            token: auth.token ?? '',
          ),
          hasActiveCouple: widget.hasActiveCouple,
        ),
      ),
    );
  }

  Widget _coupleArea() {
    final title = widget.hasActiveCouple ? '커플 영역' : '커플 영역은 잠겨 있어요';
    final description = widget.hasActiveCouple
        ? '두 사람이 검사를 완료하면 함께 보는 궁합 결과가 준비돼요.'
        : '파트너를 연결하면 두 사람의 관계 패턴을 함께 살펴볼 수 있어요.';
    return MainCard(
      key: const Key('relationship_couple_area'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.hasActiveCouple ? Icons.favorite_border : Icons.lock_outline,
            color: widget.hasActiveCouple ? kMainRose : kMainMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
              ],
            ),
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
        title: Text('관계 이해 허브', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kMainRose),
                  SizedBox(height: 12),
                  Text('관계 이해 정보를 불러오는 중이에요'),
                ],
              ),
            )
          : _profile == null && _errorMessage != null
          ? _errorState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                Text('관계 이해 허브', style: mainTitle(size: 26)),
                const SizedBox(height: 8),
                Text(
                  '개인 영역에서 나를 먼저 살펴보고, 준비가 되면 커플 영역으로 이어가요.',
                  style: mainBody(size: 14, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 16),
                _statusCard(),
                const SizedBox(height: 12),
                _personalArea(),
                const SizedBox(height: 12),
                _coupleArea(),
                const SizedBox(height: 24),
                Text('출생 프로필', style: mainTitle(size: 26)),
                const SizedBox(height: 8),
                Text(
                  '나중에 관계 이해 콘텐츠를 맞춤화할 때 사용할 정보예요. '
                  '출생 시각과 장소는 몰라도 괜찮아요.',
                  style: mainBody(size: 14, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 20),
                MainCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('달력 구분', style: mainBody(weight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BirthCalendarType>(
                        initialValue: _calendarType,
                        decoration: _decoration('달력 구분'),
                        items: const [
                          DropdownMenuItem(
                            value: BirthCalendarType.solar,
                            child: Text('양력'),
                          ),
                          DropdownMenuItem(
                            value: BirthCalendarType.lunar,
                            child: Text('음력'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _calendarType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _textField(_birthDateController, '생년월일 (YYYY-MM-DD)'),
                      const SizedBox(height: 14),
                      _textField(
                        _birthTimeController,
                        '출생 시각 (HH:mm, 선택)',
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 14),
                      _textField(_timezoneController, '시간대 (예: Asia/Seoul)'),
                      const SizedBox(height: 14),
                      _textField(_birthPlaceController, '출생지 (선택)'),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          key: const Key('birth_profile_error'),
                          style: mainBody(size: 13, color: kError),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: kMainRose,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('저장하기'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_profile != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '출생 프로필은 본인 계정에만 저장돼요.',
                    style: mainBody(size: 12, color: kMainMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: kMainPaperSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _decoration(hint),
    );
  }
}
