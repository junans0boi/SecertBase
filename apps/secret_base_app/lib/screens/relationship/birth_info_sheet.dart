import 'package:flutter/material.dart';

import 'package:secret_base_app/v2/v2.dart';

import '../../core/auth_service.dart';
import '../../core/birth_profile_api.dart';

class BirthCountryOption {
  final String label;
  final String timezone;

  const BirthCountryOption(this.label, this.timezone);
}

const kBirthCountryOptions = [
  BirthCountryOption('대한민국', 'Asia/Seoul'),
  BirthCountryOption('일본', 'Asia/Tokyo'),
  BirthCountryOption('중국', 'Asia/Shanghai'),
  BirthCountryOption('대만', 'Asia/Taipei'),
  BirthCountryOption('홍콩', 'Asia/Hong_Kong'),
  BirthCountryOption('마카오', 'Asia/Macau'),
  BirthCountryOption('몽골', 'Asia/Ulaanbaatar'),
  BirthCountryOption('필리핀', 'Asia/Manila'),
  BirthCountryOption('인도네시아', 'Asia/Jakarta'),
  BirthCountryOption('말레이시아', 'Asia/Kuala_Lumpur'),
  BirthCountryOption('싱가포르', 'Asia/Singapore'),
  BirthCountryOption('베트남', 'Asia/Ho_Chi_Minh'),
  BirthCountryOption('태국', 'Asia/Bangkok'),
  BirthCountryOption('캄보디아', 'Asia/Phnom_Penh'),
  BirthCountryOption('라오스', 'Asia/Vientiane'),
  BirthCountryOption('미얀마', 'Asia/Yangon'),
  BirthCountryOption('인도', 'Asia/Kolkata'),
  BirthCountryOption('네팔', 'Asia/Kathmandu'),
  BirthCountryOption('스리랑카', 'Asia/Colombo'),
  BirthCountryOption('방글라데시', 'Asia/Dhaka'),
  BirthCountryOption('파키스탄', 'Asia/Karachi'),
  BirthCountryOption('카자흐스탄', 'Asia/Almaty'),
  BirthCountryOption('우즈베키스탄', 'Asia/Tashkent'),
  BirthCountryOption('아랍에미리트', 'Asia/Dubai'),
  BirthCountryOption('사우디아라비아', 'Asia/Riyadh'),
  BirthCountryOption('이스라엘', 'Asia/Jerusalem'),
  BirthCountryOption('튀르키예', 'Europe/Istanbul'),
  BirthCountryOption('호주', 'Australia/Sydney'),
  BirthCountryOption('뉴질랜드', 'Pacific/Auckland'),
  BirthCountryOption('피지', 'Pacific/Fiji'),
  BirthCountryOption('영국', 'Europe/London'),
  BirthCountryOption('아일랜드', 'Europe/Dublin'),
  BirthCountryOption('프랑스', 'Europe/Paris'),
  BirthCountryOption('독일', 'Europe/Berlin'),
  BirthCountryOption('네덜란드', 'Europe/Amsterdam'),
  BirthCountryOption('벨기에', 'Europe/Brussels'),
  BirthCountryOption('스페인', 'Europe/Madrid'),
  BirthCountryOption('포르투갈', 'Europe/Lisbon'),
  BirthCountryOption('이탈리아', 'Europe/Rome'),
  BirthCountryOption('스위스', 'Europe/Zurich'),
  BirthCountryOption('오스트리아', 'Europe/Vienna'),
  BirthCountryOption('스웨덴', 'Europe/Stockholm'),
  BirthCountryOption('노르웨이', 'Europe/Oslo'),
  BirthCountryOption('덴마크', 'Europe/Copenhagen'),
  BirthCountryOption('핀란드', 'Europe/Helsinki'),
  BirthCountryOption('폴란드', 'Europe/Warsaw'),
  BirthCountryOption('체코', 'Europe/Prague'),
  BirthCountryOption('헝가리', 'Europe/Budapest'),
  BirthCountryOption('그리스', 'Europe/Athens'),
  BirthCountryOption('루마니아', 'Europe/Bucharest'),
  BirthCountryOption('우크라이나', 'Europe/Kyiv'),
  BirthCountryOption('러시아', 'Europe/Moscow'),
  BirthCountryOption('미국', 'America/New_York'),
  BirthCountryOption('캐나다', 'America/Toronto'),
  BirthCountryOption('멕시코', 'America/Mexico_City'),
  BirthCountryOption('브라질', 'America/Sao_Paulo'),
  BirthCountryOption('아르헨티나', 'America/Argentina/Buenos_Aires'),
  BirthCountryOption('칠레', 'America/Santiago'),
  BirthCountryOption('콜롬비아', 'America/Bogota'),
  BirthCountryOption('페루', 'America/Lima'),
  BirthCountryOption('남아프리카공화국', 'Africa/Johannesburg'),
  BirthCountryOption('이집트', 'Africa/Cairo'),
  BirthCountryOption('모로코', 'Africa/Casablanca'),
  BirthCountryOption('케냐', 'Africa/Nairobi'),
  BirthCountryOption('나이지리아', 'Africa/Lagos'),
];

String? birthCountryForTimezone(String timezone) {
  for (final o in kBirthCountryOptions) {
    if (o.timezone == timezone) return o.label;
  }
  return null;
}

/// The birthday given at signup (`YYYY-MM-DD`), if the session has it.
String? signupBirthday() {
  final user = AuthService().user;
  final raw = user?['birthDate'] ?? user?['birth_date'];
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('$raw');
  return m == null ? null : '${m.group(1)}-${m.group(2)}-${m.group(3)}';
}

String birthProfileErrorMessage(Object error) {
  if (error is! BirthProfileApiException) {
    return '출생 정보를 저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
  }
  return switch (error.reason) {
    'network_error' => '네트워크 연결을 확인하고 다시 시도해 주세요.',
    'invalid_calendar_type' => '양력 또는 음력을 골라 주세요.',
    'invalid_birth_date' => '생년월일을 다시 확인해 주세요.',
    'future_birth_date' => '미래 날짜는 입력할 수 없어요.',
    'invalid_birth_time' => '태어난 시각을 다시 골라 주세요.',
    'invalid_timezone' => '태어난 곳을 다시 골라 주세요.',
    'missing_fields' => '생년월일을 입력해 주세요.',
    _ => '출생 정보를 저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };
}

/// Opens the birth-info sheet. Saves through [api] and returns the saved
/// profile (null when dismissed). Prefilled from [existing], else from the
/// birthday given at signup.
Future<BirthProfile?> showBirthInfoSheet(
  BuildContext context, {
  required BirthProfileApi api,
  BirthProfile? existing,
  String? prefillBirthDate,
}) {
  return showV2Sheet<BirthProfile>(
    context,
    title: '출생 정보',
    subtitle: '사주와 운세를 계산할 때만 써요. 상대에게는 보이지 않아요.',
    builder: (ctx) => BirthInfoForm(
      api: api,
      existing: existing,
      prefillBirthDate: prefillBirthDate ?? signupBirthday(),
      onSaved: (p) => Navigator.of(ctx).pop(p),
    ),
  );
}

/// Loads the saved profile (if any), opens the sheet, and reports whether the
/// user saved. Safe to call from any screen without callbacks.
Future<bool> editBirthProfile(
  BuildContext context, {
  BirthProfileApi? api,
}) async {
  final auth = AuthService();
  final client =
      api ?? BirthProfileApi(baseUrl: auth.baseUrl, token: auth.token ?? '');
  BirthProfile? existing;
  try {
    existing = await client.fetch();
  } catch (_) {
    existing = null; // first time: prefill from the signup birthday
  }
  if (!context.mounted) return false;
  final saved = await showBirthInfoSheet(
    context,
    api: client,
    existing: existing,
  );
  if (api == null) client.close();
  return saved != null;
}

class BirthInfoForm extends StatefulWidget {
  const BirthInfoForm({
    super.key,
    required this.api,
    required this.onSaved,
    this.existing,
    this.prefillBirthDate,
  });

  final BirthProfileApi api;
  final BirthProfile? existing;
  final String? prefillBirthDate;
  final ValueChanged<BirthProfile> onSaved;

  @override
  State<BirthInfoForm> createState() => _BirthInfoFormState();
}

class _BirthInfoFormState extends State<BirthInfoForm> {
  late BirthCalendarType _calendar;
  late bool _leap;
  late bool _timeUnknown;
  late String? _country;
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _place = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _calendar = e?.calendarType ?? BirthCalendarType.solar;
    _leap = e?.lunarLeapMonth ?? false;
    _date.text = e?.birthDate.isNotEmpty == true
        ? e!.birthDate
        : (widget.prefillBirthDate ?? '');
    _prefilled = e == null && widget.prefillBirthDate != null;
    _time.text = e?.birthTime ?? '';
    _timeUnknown = e != null && e.birthTime == null;
    _country = e == null ? '대한민국' : birthCountryForTimezone(e.timezone);
    _place.text = e?.birthPlace ?? '';
  }

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _place.dispose();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial =
        DateTime.tryParse(_date.text.trim()) ??
        DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '태어난 날',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) return;
    setState(() {
      _date.text = '${picked.year}-${_two(picked.month)}-${_two(picked.day)}';
      _prefilled = false;
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final m = RegExp(r'^(\d{2}):(\d{2})').firstMatch(_time.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: m == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay(
              hour: int.parse(m.group(1)!),
              minute: int.parse(m.group(2)!),
            ),
      helpText: '태어난 시각',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) return;
    setState(() {
      _time.text = '${_two(picked.hour)}:${_two(picked.minute)}';
      _timeUnknown = false;
    });
  }

  Future<void> _save() async {
    final date = _date.text.trim();
    if (date.isEmpty) {
      setState(() => _error = '생년월일을 입력해 주세요.');
      return;
    }
    final tz = kBirthCountryOptions
        .firstWhere(
          (o) => o.label == _country,
          orElse: () => widget.existing == null
              ? kBirthCountryOptions.first
              : BirthCountryOption('', widget.existing!.timezone),
        )
        .timezone;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await widget.api.update(
        BirthProfileInput(
          calendarType: _calendar,
          birthDate: date,
          lunarLeapMonth: _calendar == BirthCalendarType.lunar && _leap,
          birthTime: _timeUnknown || _time.text.trim().isEmpty
              ? null
              : _time.text.trim(),
          timezone: tz,
          birthPlace: _place.text.trim().isEmpty ? null : _place.text.trim(),
        ),
      );
      if (!mounted) return;
      widget.onSaved(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = birthProfileErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lunar = _calendar == BirthCalendarType.lunar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V2Segmented<BirthCalendarType>(
          segments: const [
            V2Segment(value: BirthCalendarType.solar, label: '양력'),
            V2Segment(value: BirthCalendarType.lunar, label: '음력'),
          ],
          selected: _calendar,
          onChanged: (v) => setState(() => _calendar = v),
        ),
        const SizedBox(height: 14),
        V2TextField(
          label: '태어난 날',
          controller: _date,
          readOnly: true,
          hint: '날짜를 골라 주세요',
          onTap: _pickDate,
          suffix: const Icon(V2Icons.calendar, size: 20),
          help: _prefilled ? '가입할 때 알려 주신 생일로 채웠어요. 다르면 바꿔 주세요.' : null,
        ),
        if (lunar) ...[
          const SizedBox(height: 6),
          V2Check(
            value: _leap,
            onChanged: (v) => setState(() => _leap = v),
            label: '윤달이에요',
          ),
        ],
        const SizedBox(height: 14),
        V2TextField(
          label: '태어난 시각 (선택)',
          controller: _time,
          readOnly: true,
          enabled: !_timeUnknown,
          hint: _timeUnknown ? '시각을 몰라요' : '시각을 골라 주세요',
          onTap: _pickTime,
          suffix: const Icon(V2Icons.chevron, size: 20),
        ),
        const SizedBox(height: 6),
        V2Check(
          value: _timeUnknown,
          onChanged: (v) => setState(() {
            _timeUnknown = v;
            if (v) _time.clear();
          }),
          label: '시각을 몰라요',
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _country,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '태어난 나라'),
          items: [
            for (final o in kBirthCountryOptions)
              DropdownMenuItem(value: o.label, child: Text(o.label)),
          ],
          onChanged: (v) => setState(() => _country = v),
        ),
        const SizedBox(height: 14),
        V2TextField(label: '태어난 곳 (선택)', controller: _place, hint: '예: 서울'),
        if (_error != null) ...[
          const SizedBox(height: 12),
          V2Banner(tone: V2BannerTone.err, message: _error!),
        ],
        const SizedBox(height: 16),
        V2Button(
          label: '저장하고 보기',
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
