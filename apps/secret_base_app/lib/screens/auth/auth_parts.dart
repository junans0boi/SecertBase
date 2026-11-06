// 2.0 로그인·가입·연결 화면이 함께 쓰는 조각. 디자인 시스템(lib/v2)만 사용한다.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal_urls.dart';
import '../../v2/v2.dart';

/// 비밀번호 규칙: 8자 이상, 영문과 숫자를 함께(서버 정책과 같다).
bool isStrongPassword(String value) =>
    value.length >= 8 &&
    value.length <= 72 &&
    RegExp(r'[A-Za-z]').hasMatch(value) &&
    RegExp(r'\d').hasMatch(value);

bool isValidEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

String formatBirthDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 만 14세 이상인지(생일이 지나지 않았으면 한 살 덜).
bool isAtLeast14(DateTime birth, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age -= 1;
  }
  return age >= 14;
}

/// 서버 오류 코드를 사용자 문구로 바꾼다(내부 코드는 보이지 않는다).
String authErrorMessage(String code) => switch (code) {
  'invalid_credentials' => '이메일이나 비밀번호가 맞지 않아요. 다시 확인해 주세요.',
  'email_already_exists' => '이미 가입된 이메일이에요.',
  'weak_password' => '비밀번호는 8자 이상, 영문과 숫자를 함께 써 주세요.',
  'under_age' => '만 14세 이상만 가입할 수 있어요.',
  'consent_required' || 'invalid_consents' => '필수 항목에 동의하면 가입할 수 있어요.',
  'invalid_birth_date' => '생일을 다시 확인해 주세요.',
  'invalid_nickname' => '닉네임을 다시 확인해 주세요.',
  'missing_fields' => '빈 칸을 모두 채워 주세요.',
  'invalid_email' => '이메일 주소를 다시 확인해 주세요.',
  'mail_unavailable' => '지금은 메일을 보낼 수 없어요. 잠시 후 다시 시도해 주세요.',
  'invalid_code' => '코드가 맞지 않아요. 메일의 6자리 숫자를 다시 확인해 주세요.',
  'code_expired' => '코드가 만료됐어요. 새 코드를 받아 주세요.',
  'too_many_attempts' => '시도가 너무 많았어요. 새 코드를 받아 다시 해 주세요.',
  'rate_limited' => '잠시 후에 다시 시도해 주세요.',
  'network_error' || 'timeout' => '인터넷 연결을 확인하고 다시 시도해 주세요.',
  _ => '잠시 문제가 생겼어요. 다시 시도해 주세요.',
};

Future<void> openLegalUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// 2.0 인증 화면 뼈대: 장미 그라데이션 배경 위 가운데 정렬 컬럼(최대 440px).
/// [footer]는 아래에 고정되고, 본문만 스크롤된다.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.body,
    this.footer,
    this.header,
    this.hero = false,
  });

  final PreferredSizeWidget? header;
  final Widget body;
  final Widget? footer;

  /// true면 부드러운 장미빛 배경(로그인·온보딩).
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Theme(
      child: Scaffold(
        backgroundColor: hero ? null : p.bg,
        appBar: header,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: hero ? V2Gradients.heroSoft : null,
            color: hero ? null : p.bg,
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          V2Space.page,
                          V2Space.x4,
                          V2Space.page,
                          V2Space.x4,
                        ),
                        child: body,
                      ),
                    ),
                    if (footer != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          V2Space.page,
                          V2Space.x2,
                          V2Space.page,
                          V2Space.x5,
                        ),
                        child: footer,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 하트 열쇠구멍 문 엠블럼.
class AuthEmblem extends StatelessWidget {
  const AuthEmblem({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: V2Gradients.berry,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(size / 2),
          bottom: Radius.circular(size * 0.26),
        ),
        boxShadow: V2Shadow.level2,
      ),
      child: Icon(V2Icons.heart, size: size * 0.46, color: Colors.white),
    ),
  );
}

/// 이용약관·개인정보처리방침 링크(항상 보인다).
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.lead = '계속하면 '});
  final String lead;

  @override
  Widget build(BuildContext context) {
    final ink = V2Palette.of(context).ink;
    Widget link(String label, String url) => InkWell(
      onTap: () => openLegalUrl(url),
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              style: V2Text.cap.copyWith(
                color: ink,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(lead, style: V2Text.cap),
        link('이용약관', kTermsUrl),
        Text('과 ', style: V2Text.cap),
        link('개인정보처리방침', kPrivacyUrl),
        Text('을 확인한 것으로 봐요.', style: V2Text.cap),
      ],
    );
  }
}

/// 필드 아래 오류 문구(아이콘 + 글자, 색만으로 알리지 않는다).
class AuthErrorLine extends StatelessWidget {
  const AuthErrorLine(this.message, {super.key, this.trailing});
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: V2Space.x2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(V2Icons.error, size: 18, color: V2Colors.errText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: V2Text.cap.copyWith(
                  color: V2Colors.errText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// 비밀번호 규칙 체크리스트(입력하는 동안 바로 갱신).
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist(this.password, {super.key});
  final String password;

  @override
  Widget build(BuildContext context) {
    final lengthOk = password.length >= 8;
    final mixOk =
        RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password);
    return Padding(
      padding: const EdgeInsets.only(top: V2Space.x2),
      child: Wrap(
        spacing: V2Space.x2,
        runSpacing: V2Space.x1,
        children: [
          V2Chip(
            label: '8자 이상',
            tone: lengthOk ? V2Tone.ok : V2Tone.neutral,
            icon: lengthOk ? V2Icons.ok : null,
          ),
          V2Chip(
            label: '영문과 숫자 포함',
            tone: mixOk ? V2Tone.ok : V2Tone.neutral,
            icon: mixOk ? V2Icons.ok : null,
          ),
        ],
      ),
    );
  }
}

/// 가입 동의 값.
class ConsentValue {
  const ConsentValue({
    this.age14 = false,
    this.terms = false,
    this.privacy = false,
    this.marketing = false,
  });
  final bool age14;
  final bool terms;
  final bool privacy;
  final bool marketing;

  bool get requiredOk => age14 && terms && privacy;
  bool get all => requiredOk && marketing;

  ConsentValue copyWith({
    bool? age14,
    bool? terms,
    bool? privacy,
    bool? marketing,
  }) => ConsentValue(
    age14: age14 ?? this.age14,
    terms: terms ?? this.terms,
    privacy: privacy ?? this.privacy,
    marketing: marketing ?? this.marketing,
  );

  ConsentValue setAll(bool v) =>
      ConsentValue(age14: v, terms: v, privacy: v, marketing: v);

  Map<String, bool> toJson() => {
    'age14': age14,
    'terms': terms,
    'privacy': privacy,
    'marketing': marketing,
  };
}

/// 전체 동의 + 항목별 동의(필수 3개, 선택 1개).
class ConsentChecks extends StatelessWidget {
  const ConsentChecks({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final ConsentValue value;
  final ValueChanged<ConsentValue> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    Widget row(
      String text,
      bool v,
      ValueChanged<bool> set, {
      bool required = true,
      String? url,
    }) => V2Check(
      value: v,
      onChanged: enabled ? set : null,
      label: '${required ? '(필수)' : '(선택)'} $text',
      trailing: url == null
          ? null
          : TextButton(
              onPressed: () => openLegalUrl(url),
              child: Text('보기', style: V2Text.buttonSm.copyWith(color: p.sub)),
            ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2Card(
          variant: V2CardVariant.soft,
          padding: const EdgeInsets.symmetric(
            horizontal: V2Space.x3,
            vertical: V2Space.x1,
          ),
          child: V2Check(
            value: value.all,
            onChanged: enabled ? (v) => onChanged(value.setAll(v)) : null,
            label: '전체 동의',
          ),
        ),
        const SizedBox(height: V2Space.x1),
        row(
          '만 14세 이상이에요',
          value.age14,
          (v) => onChanged(value.copyWith(age14: v)),
        ),
        row(
          '이용약관에 동의해요',
          value.terms,
          (v) => onChanged(value.copyWith(terms: v)),
          url: kTermsUrl,
        ),
        row(
          '개인정보 수집·이용에 동의해요',
          value.privacy,
          (v) => onChanged(value.copyWith(privacy: v)),
          url: kPrivacyUrl,
        ),
        row(
          '이벤트·혜택 알림을 받을래요',
          value.marketing,
          (v) => onChanged(value.copyWith(marketing: v)),
          required: false,
        ),
      ],
    );
  }
}

/// 생일 선택(읽기 전용 필드 + 날짜 선택).
Future<DateTime?> pickBirthDate(BuildContext context, DateTime? current) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: current ?? DateTime(now.year - 20, now.month, now.day),
    firstDate: DateTime(1900),
    lastDate: now,
    helpText: '생일 선택',
    cancelText: '취소',
    confirmText: '선택',
    builder: (ctx, child) => V2Theme(child: child!),
  );
}
