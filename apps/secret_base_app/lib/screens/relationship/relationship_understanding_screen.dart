import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/app_theme.dart';
import '../../core/assessment_catalog_api.dart';
import '../../core/compatibility_api.dart';
import '../../core/counseling_api.dart';
import '../../core/birth_profile_api.dart';
import '../../core/fortune_api.dart';
import '../../core/main_design.dart';
import '../../core/mindcare_api.dart';
import '../../core/saju_api.dart';
import '../../core/tarot_api.dart';
import 'assessment_catalog_screen.dart';
import 'compatibility_screen.dart';
import 'counseling_screen.dart';
import 'fortune_screen.dart';
import 'saju_screen.dart';
import 'tarot_screen.dart';
import 'mindcare_screen.dart';

enum RelationshipAssessmentStatus {
  profileIncomplete,
  notStarted,
  inProgress,
  resultReady,
}

class _BirthCountryOption {
  final String label;
  final String timezone;

  const _BirthCountryOption(this.label, this.timezone);
}

const _birthCountryOptions = [
  _BirthCountryOption('대한민국', 'Asia/Seoul'),
  _BirthCountryOption('일본', 'Asia/Tokyo'),
  _BirthCountryOption('중국', 'Asia/Shanghai'),
  _BirthCountryOption('대만', 'Asia/Taipei'),
  _BirthCountryOption('홍콩', 'Asia/Hong_Kong'),
  _BirthCountryOption('마카오', 'Asia/Macau'),
  _BirthCountryOption('몽골', 'Asia/Ulaanbaatar'),
  _BirthCountryOption('필리핀', 'Asia/Manila'),
  _BirthCountryOption('인도네시아', 'Asia/Jakarta'),
  _BirthCountryOption('말레이시아', 'Asia/Kuala_Lumpur'),
  _BirthCountryOption('싱가포르', 'Asia/Singapore'),
  _BirthCountryOption('베트남', 'Asia/Ho_Chi_Minh'),
  _BirthCountryOption('태국', 'Asia/Bangkok'),
  _BirthCountryOption('캄보디아', 'Asia/Phnom_Penh'),
  _BirthCountryOption('라오스', 'Asia/Vientiane'),
  _BirthCountryOption('미얀마', 'Asia/Yangon'),
  _BirthCountryOption('인도', 'Asia/Kolkata'),
  _BirthCountryOption('네팔', 'Asia/Kathmandu'),
  _BirthCountryOption('스리랑카', 'Asia/Colombo'),
  _BirthCountryOption('방글라데시', 'Asia/Dhaka'),
  _BirthCountryOption('파키스탄', 'Asia/Karachi'),
  _BirthCountryOption('카자흐스탄', 'Asia/Almaty'),
  _BirthCountryOption('우즈베키스탄', 'Asia/Tashkent'),
  _BirthCountryOption('아랍에미리트', 'Asia/Dubai'),
  _BirthCountryOption('사우디아라비아', 'Asia/Riyadh'),
  _BirthCountryOption('이스라엘', 'Asia/Jerusalem'),
  _BirthCountryOption('튀르키예', 'Europe/Istanbul'),
  _BirthCountryOption('호주', 'Australia/Sydney'),
  _BirthCountryOption('뉴질랜드', 'Pacific/Auckland'),
  _BirthCountryOption('피지', 'Pacific/Fiji'),
  _BirthCountryOption('영국', 'Europe/London'),
  _BirthCountryOption('아일랜드', 'Europe/Dublin'),
  _BirthCountryOption('프랑스', 'Europe/Paris'),
  _BirthCountryOption('독일', 'Europe/Berlin'),
  _BirthCountryOption('네덜란드', 'Europe/Amsterdam'),
  _BirthCountryOption('벨기에', 'Europe/Brussels'),
  _BirthCountryOption('스페인', 'Europe/Madrid'),
  _BirthCountryOption('포르투갈', 'Europe/Lisbon'),
  _BirthCountryOption('이탈리아', 'Europe/Rome'),
  _BirthCountryOption('스위스', 'Europe/Zurich'),
  _BirthCountryOption('오스트리아', 'Europe/Vienna'),
  _BirthCountryOption('스웨덴', 'Europe/Stockholm'),
  _BirthCountryOption('노르웨이', 'Europe/Oslo'),
  _BirthCountryOption('덴마크', 'Europe/Copenhagen'),
  _BirthCountryOption('핀란드', 'Europe/Helsinki'),
  _BirthCountryOption('폴란드', 'Europe/Warsaw'),
  _BirthCountryOption('체코', 'Europe/Prague'),
  _BirthCountryOption('헝가리', 'Europe/Budapest'),
  _BirthCountryOption('그리스', 'Europe/Athens'),
  _BirthCountryOption('루마니아', 'Europe/Bucharest'),
  _BirthCountryOption('우크라이나', 'Europe/Kyiv'),
  _BirthCountryOption('러시아', 'Europe/Moscow'),
  _BirthCountryOption('미국', 'America/New_York'),
  _BirthCountryOption('캐나다', 'America/Toronto'),
  _BirthCountryOption('멕시코', 'America/Mexico_City'),
  _BirthCountryOption('브라질', 'America/Sao_Paulo'),
  _BirthCountryOption('아르헨티나', 'America/Argentina/Buenos_Aires'),
  _BirthCountryOption('칠레', 'America/Santiago'),
  _BirthCountryOption('콜롬비아', 'America/Bogota'),
  _BirthCountryOption('페루', 'America/Lima'),
  _BirthCountryOption('남아프리카공화국', 'Africa/Johannesburg'),
  _BirthCountryOption('이집트', 'Africa/Cairo'),
  _BirthCountryOption('모로코', 'Africa/Casablanca'),
  _BirthCountryOption('케냐', 'Africa/Nairobi'),
  _BirthCountryOption('나이지리아', 'Africa/Lagos'),
];

class _PickerSelection<T> {
  final bool confirmed;
  final T? value;

  const _PickerSelection.confirmed(this.value) : confirmed = true;
}

enum _RelationshipArea { personal, couple }

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
  final AssessmentCatalogApi? assessmentCatalogApi;
  final RelationshipAssessmentStatus assessmentStatus;
  final bool hasActiveCouple;
  final bool editBirthProfileOnly;

  const RelationshipUnderstandingScreen({
    super.key,
    this.api,
    this.assessmentCatalogApi,
    this.assessmentStatus = RelationshipAssessmentStatus.notStarted,
    this.hasActiveCouple = false,
    this.editBirthProfileOnly = false,
  });

  @override
  State<RelationshipUnderstandingScreen> createState() =>
      _RelationshipUnderstandingScreenState();
}

class _RelationshipUnderstandingScreenState
    extends State<RelationshipUnderstandingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _areaTabController;
  late final BirthProfileApi _api;
  late final bool _ownsApi;
  late final AssessmentCatalogApi? _assessmentCatalogApi;
  late final bool _ownsAssessmentCatalogApi;
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'Asia/Seoul');
  final _birthPlaceController = TextEditingController();
  BirthCalendarType _calendarType = BirthCalendarType.solar;
  bool _lunarLeapMonth = false;
  String? _birthCountry = '대한민국';
  BirthProfile? _profile;
  RelationshipAssessmentStatus? _loadedAssessmentStatus;
  String? _errorMessage;
  bool _loading = true;
  bool _saving = false;
  _RelationshipArea _selectedArea = _RelationshipArea.personal;

  @override
  void initState() {
    super.initState();
    _areaTabController = TabController(length: 2, vsync: this);
    _ownsApi = widget.api == null;
    _api =
        widget.api ??
        BirthProfileApi(
          baseUrl: AuthService().baseUrl,
          token: AuthService().token ?? '',
        );
    _ownsAssessmentCatalogApi =
        widget.assessmentCatalogApi == null &&
        widget.api == null &&
        !widget.editBirthProfileOnly;
    _assessmentCatalogApi =
        widget.assessmentCatalogApi ??
        (_ownsAssessmentCatalogApi
            ? AssessmentCatalogApi(
                baseUrl: AuthService().baseUrl,
                token: AuthService().token ?? '',
              )
            : null);
    _loadProfile();
  }

  @override
  void dispose() {
    _areaTabController.dispose();
    if (_ownsApi) _api.close();
    if (_ownsAssessmentCatalogApi) _assessmentCatalogApi?.close();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _timezoneController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.fetch();
      RelationshipAssessmentStatus? loadedAssessmentStatus;
      final catalogApi = _assessmentCatalogApi;
      if (catalogApi != null) {
        try {
          final assessments = await catalogApi.fetch();
          loadedAssessmentStatus = _statusFromAssessments(assessments);
        } catch (_) {
          // The relationship hub remains usable when assessment status is unavailable.
        }
      }
      if (!mounted) return;
      _setProfile(profile);
      setState(() {
        _profile = profile;
        _loadedAssessmentStatus = loadedAssessmentStatus;
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
    _lunarLeapMonth = profile.lunarLeapMonth;
    _birthDateController.text = profile.birthDate;
    _birthTimeController.text = profile.birthTime ?? '';
    _timezoneController.text = profile.timezone;
    _birthCountry = _birthCountryForTimezone(profile.timezone);
    _birthPlaceController.text = profile.birthPlace ?? '';
  }

  String? _birthCountryForTimezone(String timezone) {
    for (final option in _birthCountryOptions) {
      if (option.timezone == timezone) return option.label;
    }
    return null;
  }

  void _selectBirthCountry(String country) {
    for (final option in _birthCountryOptions) {
      if (option.label != country) continue;
      setState(() {
        _birthCountry = option.label;
        _timezoneController.text = option.timezone;
      });
      return;
    }
  }

  DateTime _initialBirthDate() {
    final parsed = DateTime.tryParse(_birthDateController.text.trim());
    if (parsed != null) return parsed;
    final today = DateTime.now();
    return DateTime(today.year - 20, today.month, today.day);
  }

  TimeOfDay? _initialBirthTime() {
    final match = RegExp(
      r'^(\d{2}):(\d{2})',
    ).firstMatch(_birthTimeController.text.trim());
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    const minYear = 1900;
    final maxYear = today.year;
    final initial = _initialBirthDate();
    var year = math.min(maxYear, math.max(minYear, initial.year));
    var month = initial.month;
    var day = math.min(initial.day, DateUtils.getDaysInMonth(year, month));
    final yearController = FixedExtentScrollController(
      initialItem: year - minYear,
    );
    final monthController = FixedExtentScrollController(initialItem: month - 1);
    final dayController = FixedExtentScrollController(initialItem: day - 1);

    final result = await showModalBottomSheet<_PickerSelection<DateTime>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final dayCount = DateUtils.getDaysInMonth(year, month);
          void updateDayBounds() {
            day = math.min(day, dayCount);
            dayController.jumpToItem(day - 1);
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('생년월일 선택', style: mainTitle(size: 20)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _PickerSelection.confirmed(DateTime(year, month, day)),
                      ),
                      child: const Text('선택'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 220,
                  child: Row(
                    children: [
                      _pickerWheel(
                        controller: yearController,
                        itemCount: maxYear - minYear + 1,
                        labelBuilder: (index) => '${minYear + index}년',
                        onSelectedItemChanged: (index) {
                          setModalState(() {
                            year = minYear + index;
                            updateDayBounds();
                          });
                        },
                      ),
                      _pickerWheel(
                        controller: monthController,
                        itemCount: 12,
                        labelBuilder: (index) => '${index + 1}월',
                        onSelectedItemChanged: (index) {
                          setModalState(() {
                            month = index + 1;
                            updateDayBounds();
                          });
                        },
                      ),
                      _pickerWheel(
                        controller: dayController,
                        itemCount: dayCount,
                        labelBuilder: (index) => '${index + 1}일',
                        onSelectedItemChanged: (index) => day = index + 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    if (!mounted ||
        result == null ||
        !result.confirmed ||
        result.value == null) {
      return;
    }
    final selected = result.value!;
    setState(() {
      _birthDateController.text =
          '${selected.year}-${_twoDigits(selected.month)}-${_twoDigits(selected.day)}';
    });
  }

  Future<void> _pickBirthTime() async {
    final initial = _initialBirthTime();
    var hour = initial?.hour ?? 12;
    var minute = initial?.minute ?? 0;
    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);

    final result = await showModalBottomSheet<_PickerSelection<String?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('출생 시각 선택', style: mainTitle(size: 20)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _PickerSelection.confirmed(
                      '${_twoDigits(hour)}:${_twoDigits(minute)}',
                    ),
                  ),
                  child: const Text('선택'),
                ),
              ],
            ),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  _pickerWheel(
                    controller: hourController,
                    itemCount: 24,
                    labelBuilder: (index) => '${_twoDigits(index)}시',
                    onSelectedItemChanged: (index) => hour = index,
                  ),
                  _pickerWheel(
                    controller: minuteController,
                    itemCount: 60,
                    labelBuilder: (index) => '${_twoDigits(index)}분',
                    onSelectedItemChanged: (index) => minute = index,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  const _PickerSelection<String?>.confirmed(null),
                ),
                icon: const Icon(Icons.backspace_outlined, size: 16),
                label: const Text('출생 시각 지우기'),
              ),
            ),
          ],
        ),
      ),
    );
    hourController.dispose();
    minuteController.dispose();
    if (!mounted || result == null || !result.confirmed) return;
    setState(() => _birthTimeController.text = result.value ?? '');
  }

  Widget _pickerWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 44,
        useMagnifier: true,
        magnification: 1.08,
        onSelectedItemChanged: onSelectedItemChanged,
        children: [
          for (var index = 0; index < itemCount; index++)
            Center(child: Text(labelBuilder(index))),
        ],
      ),
    );
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
          lunarLeapMonth: _lunarLeapMonth,
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
    if (!_hasSavedBirthProfile) {
      return RelationshipAssessmentStatus.profileIncomplete;
    }
    return _loadedAssessmentStatus ?? widget.assessmentStatus;
  }

  RelationshipAssessmentStatus _statusFromAssessments(
    List<AssessmentCatalogItem> assessments,
  ) {
    final personal = assessments.where(
      (assessment) => assessment.audience == AssessmentAudience.individual,
    );
    if (personal.any(
      (assessment) =>
          assessment.completionStatus == AssessmentCompletionStatus.inProgress,
    )) {
      return RelationshipAssessmentStatus.inProgress;
    }
    if (personal.any(
      (assessment) =>
          assessment.completionStatus == AssessmentCompletionStatus.completed,
    )) {
      return RelationshipAssessmentStatus.resultReady;
    }
    return RelationshipAssessmentStatus.notStarted;
  }

  bool get _hasSavedBirthProfile =>
      _profile?.birthDate.trim().isNotEmpty == true;

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
            onPressed: () => _openCatalog(AssessmentAudience.individual),
            child: const Text('개인 검사 보기'),
          ),
        ],
      ),
    );
  }

  Widget _sajuArea() {
    return MainCard(
      key: const Key('relationship_saju_area'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: kMainLilac),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('나의 사주', style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '어려운 용어보다 쉬운 설명부터 내 흐름을 살펴봐요.',
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('open_saju'),
                  onPressed: _openSaju,
                  child: const Text('사주 보기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarotArea() {
    return MainCard(
      key: const Key('relationship_tarot_area'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.style_outlined, color: kMainHoney),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘의 타로', style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '오늘은 한 장만, 가볍게 마음을 비춰봐요.',
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('open_tarot'),
                  onPressed: _openTarot,
                  child: const Text('타로 보기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCatalog(AssessmentAudience audience) {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssessmentCatalogScreen(
          api: AssessmentCatalogApi(
            baseUrl: auth.baseUrl,
            token: auth.token ?? '',
          ),
          hasActiveCouple: widget.hasActiveCouple,
          audienceFilter: audience,
        ),
      ),
    );
  }

  void _openCompatibility() {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CompatibilityDashboardScreen(
          api: CompatibilityApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
        ),
      ),
    );
  }

  void _openFortune(FortuneScope scope) {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RelationshipFortuneScreen(
          api: FortuneApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
          onOpenCounseling: scope == FortuneScope.personal
              ? _openPrivateCounseling
              : _openSharedCounseling,
          scope: scope,
        ),
      ),
    );
  }

  void _openPrivateCounseling() {
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

  void _openMindcare() {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MindcareScreen(
          api: MindcareApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
        ),
      ),
    );
  }

  void _openSaju() {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SajuScreen(
          api: SajuApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
          onEditProfile: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const RelationshipUnderstandingScreen(
                editBirthProfileOnly: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTarot() {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TarotScreen(
          api: TarotApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
        ),
      ),
    );
  }

  void _openSharedCounseling() {
    final auth = AuthService();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RelationshipCounselingScreen(
          api: CounselingApi(baseUrl: auth.baseUrl, token: auth.token ?? ''),
          shared: true,
        ),
      ),
    );
  }

  Widget _fortuneArea({required FortuneScope scope}) {
    final isCouple = scope == FortuneScope.couple;
    return MainCard(
      key: const Key('relationship_fortune_area'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, color: kMainRose),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCouple ? '오늘의 관계 운세' : '오늘의 운세',
                  style: mainBody(weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  isCouple
                      ? '두 사람의 관계 흐름과 오늘 확인해볼 대화 신호를 살펴봐요.'
                      : '출생 프로필을 바탕으로 오늘의 감정 흐름을 살펴봐요.',
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: Key(
                    isCouple ? 'open_relationship_fortune' : 'open_fortune',
                  ),
                  onPressed: () => _openFortune(scope),
                  child: Text(isCouple ? '관계 운세 보기' : '오늘의 운세 보기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counselingArea({required bool shared}) {
    return MainCard(
      key: Key(
        shared
            ? 'relationship_shared_counseling_area'
            : 'relationship_counseling_area',
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: kMainLilac),
              const SizedBox(width: 8),
              Text(
                shared ? '커플 상담' : '프라이빗 상담',
                style: mainBody(weight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shared
                ? '두 사람이 함께 확인할 수 있는 내용만 바탕으로 대화해요.'
                : '나만 볼 수 있는 공간에서 감정과 관계 패턴을 정리해요.',
            style: mainBody(size: 13, color: kMainSub, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: Key(
                  shared ? 'open_shared_counseling' : 'open_private_counseling',
                ),
                onPressed: shared
                    ? _openSharedCounseling
                    : _openPrivateCounseling,
                child: Text(shared ? '커플 상담 시작' : '프라이빗 상담 시작'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mindcareArea() {
    return MainCard(
      key: const Key('relationship_mindcare_area'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline, color: kMainLilac),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('마음관리 가이드', style: mainBody(weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '상담사와 채팅하듯 따뜻한 질문을 따라 감정과 작은 행동을 정리해요.',
                  style: mainBody(size: 13, color: kMainSub, height: 1.5),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('open_mindcare'),
                  onPressed: _openMindcare,
                  child: const Text('마음관리 시작'),
                ),
              ],
            ),
          ),
        ],
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
                if (widget.hasActiveCouple) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('open_couple_catalog'),
                    onPressed: () => _openCatalog(AssessmentAudience.couple),
                    child: const Text('커플 검사 보기'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('open_compatibility'),
                    onPressed: _openCompatibility,
                    child: const Text('궁합 분석 보기'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectArea(int index) {
    final area = index == 0
        ? _RelationshipArea.personal
        : _RelationshipArea.couple;
    if (area == _RelationshipArea.couple && !widget.hasActiveCouple) {
      _areaTabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파트너를 연결하면 커플 영역을 이용할 수 있어요.')),
      );
      return;
    }
    setState(() => _selectedArea = area);
  }

  @override
  Widget build(BuildContext context) {
    final showBirthProfile =
        widget.editBirthProfileOnly || !_hasSavedBirthProfile;
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text(
          widget.editBirthProfileOnly ? '출생 프로필 수정' : '관계 이해 허브',
          style: mainTitle(size: 22),
        ),
        bottom: widget.editBirthProfileOnly
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  controller: _areaTabController,
                  onTap: _selectArea,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: kMainInk, width: 3),
                    insets: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: kMainInk,
                  unselectedLabelColor: kMainMuted,
                  labelStyle: mainBody(size: 18, weight: FontWeight.w800),
                  unselectedLabelStyle: mainBody(
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 28),
                  tabs: [
                    const Tab(text: '개인'),
                    const Tab(text: '커플'),
                  ],
                ),
              ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.editBirthProfileOnly) ...[
                      Text('관계 이해 허브', style: mainTitle(size: 26)),
                      const SizedBox(height: 8),
                      Text(
                        _selectedArea == _RelationshipArea.personal
                            ? '내 감정과 관계 패턴을 먼저 살펴봐요.'
                            : '두 사람의 응답이 모이면 관계 패턴을 함께 살펴봐요.',
                        style: mainBody(size: 14, color: kMainSub, height: 1.5),
                      ),
                      if (_selectedArea == _RelationshipArea.personal) ...[
                        const SizedBox(height: 16),
                        _statusCard(),
                      ],
                    ],
                    if (showBirthProfile &&
                        _selectedArea == _RelationshipArea.personal) ...[
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
                            Text(
                              '달력 구분',
                              style: mainBody(weight: FontWeight.w700),
                            ),
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
                                  setState(() {
                                    _calendarType = value;
                                    if (value == BirthCalendarType.solar) {
                                      _lunarLeapMonth = false;
                                    }
                                  });
                                }
                              },
                            ),
                            if (_calendarType == BirthCalendarType.lunar) ...[
                              const SizedBox(height: 10),
                              CheckboxListTile(
                                key: const Key('lunar_leap_month_toggle'),
                                contentPadding: EdgeInsets.zero,
                                value: _lunarLeapMonth,
                                onChanged: (value) => setState(
                                  () => _lunarLeapMonth = value ?? false,
                                ),
                                title: const Text('윤달 생일이에요'),
                                subtitle: const Text('음력 윤달이면 꼭 알려주세요.'),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _pickerField(
                              _birthDateController,
                              '생년월일 (YYYY-MM-DD)',
                              icon: Icons.calendar_month_outlined,
                              onTap: _pickBirthDate,
                            ),
                            const SizedBox(height: 14),
                            _pickerField(
                              _birthTimeController,
                              '출생 시각 (HH:mm, 선택)',
                              icon: Icons.schedule_outlined,
                              onTap: _pickBirthTime,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _birthCountry,
                              decoration: _decoration('출생 국가·지역'),
                              items: [
                                for (final option in _birthCountryOptions)
                                  DropdownMenuItem(
                                    value: option.label,
                                    child: Text(option.label),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) _selectBirthCountry(value);
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '국가의 대표 시간대를 사용해요. 도시·지역은 출생지에 적어주세요.',
                              style: mainBody(size: 12, color: kMainMuted),
                            ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                    if (!widget.editBirthProfileOnly) ...[
                      const SizedBox(height: 18),
                      if (_selectedArea == _RelationshipArea.personal) ...[
                        _fortuneArea(scope: FortuneScope.personal),
                        const SizedBox(height: 12),
                        _sajuArea(),
                        const SizedBox(height: 12),
                        _tarotArea(),
                        const SizedBox(height: 12),
                        _personalArea(),
                        const SizedBox(height: 12),
                        _mindcareArea(),
                        const SizedBox(height: 12),
                        _counselingArea(shared: false),
                      ] else ...[
                        _fortuneArea(scope: FortuneScope.couple),
                        const SizedBox(height: 12),
                        _coupleArea(),
                        const SizedBox(height: 12),
                        _counselingArea(shared: true),
                      ],
                    ],
                  ],
                ),
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

  Widget _pickerField(
    TextEditingController controller,
    String hint, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: _decoration(
        hint,
      ).copyWith(suffixIcon: Icon(icon, color: kMainMuted)),
    );
  }
}
