import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/app_theme.dart';
import '../../core/birth_profile_api.dart';
import '../../core/main_design.dart';

class RelationshipUnderstandingScreen extends StatefulWidget {
  final BirthProfileApi? api;

  const RelationshipUnderstandingScreen({super.key, this.api});

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
    _api = widget.api ??
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출생 프로필을 저장했어요.')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMainBg,
      appBar: AppBar(
        backgroundColor: kMainBg,
        title: Text('관계 이해', style: mainTitle(size: 22)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMainRose))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
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
                          if (value != null) setState(() => _calendarType = value);
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
