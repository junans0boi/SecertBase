// Shared safety layer for 마음관리 and 상담.
//
// Everything here works offline: the crisis contacts are built into the app so
// they are visible even when the server resource API fails.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secret_base_app/core/mindcare_api.dart';
import 'package:secret_base_app/core/safety_location.dart';
import 'package:secret_base_app/v2/v2.dart';

class CareContact {
  const CareContact({
    required this.number,
    required this.name,
    required this.note,
  });

  /// Display number, e.g. `1577-0199`.
  final String number;
  final String name;
  final String note;

  String get dialPath => number.replaceAll(RegExp(r'[^0-9]'), '');
}

// TODO 검수 필요: 번호 5곳의 명칭·운영 시간은 담당자 검수 전 값이다.
// 검수 후 마지막 확인일(2026-10 예정)과 validUntil(2027-12-31)을 갱신할 것.
const List<CareContact> kCareContacts = [
  CareContact(number: '112', name: '경찰 긴급신고', note: '지금 위험할 때 · 24시간'),
  CareContact(number: '119', name: '소방·구급', note: '응급 상황 · 24시간'),
  CareContact(number: '109', name: '자살예방 상담전화', note: '마음이 너무 힘들 때 · 24시간'),
  CareContact(number: '1577-0199', name: '정신건강 상담전화', note: '마음 건강 상담 · 24시간'),
  CareContact(number: '1366', name: '여성긴급전화', note: '폭력 피해 상담 · 24시간'),
];

/// Persistent choices for the care area (consent, pre-chosen location use).
class CarePrefs {
  const CarePrefs._();

  static const consentKey = 'care_consent_v1';
  static const locationKey = 'care_location_pref_v1';

  static Future<bool> consented() => _read(consentKey);
  static Future<void> setConsented() => _write(consentKey, true);

  /// Defaults to OFF. Location is only ever used when the user chose it here,
  /// ahead of time, never at the moment of a crisis.
  static Future<bool> locationEnabled() => _read(locationKey);
  static Future<void> setLocationEnabled(bool value) =>
      _write(locationKey, value);

  static Future<bool> _read(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _write(String key, bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {
      // Preferences are best-effort; the screen keeps working.
    }
  }
}

/// Location for safety resources: only when the user pre-chose it and the OS
/// permission is already granted. Never prompts.
Future<SafetyLocation> resolvePreChosenLocation(
  SafetyLocationProvider provider,
) async {
  if (!await CarePrefs.locationEnabled()) return const SafetyLocation.denied();
  try {
    return await provider.resolve();
  } catch (_) {
    return const SafetyLocation.denied();
  }
}

/// One-time consent sheet. Returns true when the user agreed (now or before).
Future<bool> ensureCareConsent(BuildContext context) async {
  if (await CarePrefs.consented()) return true;
  if (!context.mounted) return false;
  final agreed = await showV2Sheet<bool>(
    context,
    title: '시작하기 전에 알려드려요',
    isDismissible: false,
    enableDrag: false,
    dark: false,
    builder: (ctx) => const _ConsentBody(),
    actions: [
      Builder(
        builder: (ctx) => V2Button(
          label: '확인했고 시작할게요',
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ),
      Builder(
        builder: (ctx) => V2Button(
          label: '나중에 할게요',
          variant: V2ButtonVariant.text,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ),
    ],
  );
  if (agreed != true) return false;
  await CarePrefs.setConsented();
  return true;
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody();

  @override
  Widget build(BuildContext context) {
    const items = [
      (V2Icons.sparkle, 'AI 가이드예요', '사람 상담사가 아니라 AI가 도와요. 전문 상담이나 의료를 대신하지 않아요.'),
      (V2Icons.lock, '파트너에게 공유되지 않아요', '내가 직접 고른 한 문장만 보낼 수 있고, 대화 원문은 나만 봐요.'),
      (V2Icons.send, 'AI 서비스로 전송돼요', '답변을 만들기 위해 입력한 내용이 AI 서비스로 전달돼요.'),
      (V2Icons.phone, '위급할 땐 바로 연락해 주세요', '지금 위험하면 112·119, 마음이 너무 힘들면 109에 전화해 주세요.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V2Art(icon: item.$1, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$2, style: V2Text.bodyStrong),
                      const SizedBox(height: 2),
                      Text(item.$3, style: V2Text.cap),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Always-visible "도움이 필요하면" chip. Opens the crisis sheet.
class CareHelpChip extends StatelessWidget {
  const CareHelpChip({super.key, this.resources});

  final SafetyResources? resources;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      label: '도움이 필요하면',
      onTap: () => showCrisisSheet(context, resources: resources),
      child: ExcludeSemantics(
        child: Material(
          color: p.errSoft,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showCrisisSheet(context, resources: resources),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: V2Space.tap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(V2Icons.shield, size: 18, color: p.err),
                    const SizedBox(width: 6),
                    Text(
                      '도움이 필요하면',
                      style: V2Text.buttonSm.copyWith(color: p.ink),
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

/// General help first. Contacts are built in, so this never waits on a server.
Future<void> showCrisisSheet(
  BuildContext context, {
  SafetyResources? resources,
}) {
  return showV2Sheet<void>(
    context,
    title: '지금 도움받을 수 있는 곳',
    subtitle: '혼자 버티지 않아도 괜찮아요. 번호를 누르면 전화하거나 복사할 수 있어요.',
    builder: (ctx) => CrisisContactsCard(resources: resources, framed: false),
  );
}

/// Built-in contacts (+ optional server catalog). Tap → call or copy.
class CrisisContactsCard extends StatelessWidget {
  const CrisisContactsCard({
    super.key,
    this.resources,
    this.framed = true,
    this.dark = false,
  });

  final SafetyResources? resources;
  final bool framed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final known = kCareContacts.map((c) => c.dialPath).toSet();
    List<String> numbersOf(String raw) => RegExp(
      r'\d[\d-]*',
    ).allMatches(raw).map((m) => m.group(0)!.replaceAll('-', '')).toList();
    final server = (resources?.resources ?? const <SafetyResource>[])
        .where((r) => r.contact != null && numbersOf(r.contact!).isNotEmpty)
        .where((r) => !numbersOf(r.contact!).every(known.contains))
        .toList();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지금 위험하다고 느끼면 먼저 112·119에 전화해 주세요.',
          style: V2Text.body.copyWith(color: p.ink),
        ),
        const SizedBox(height: 12),
        for (final c in kCareContacts)
          _ContactRow(
            title: c.name,
            subtitle: c.note,
            number: c.number,
            onTap: () => showCareContactActions(
              context,
              number: c.number,
              dial: c.dialPath,
              name: c.name,
            ),
          ),
        if (resources?.locationMode == 'region' &&
            resources?.adminArea != null) ...[
          const SizedBox(height: 8),
          Text(
            '${resources!.adminArea} 기준 안내도 함께 보여드려요. 위치는 저장하지 않아요.',
            style: V2Text.cap,
          ),
        ],
        for (final r in server)
          _ContactRow(
            title: r.title,
            subtitle: r.description,
            number: r.contact!,
            onTap: () => showCareContactActions(
              context,
              number: r.contact!,
              dial: numbersOf(r.contact!).first,
              name: r.title,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '번호와 운영 시간은 바뀔 수 있어요. 연결이 안 되면 119로 문의해 주세요.',
          style: V2Text.cap.copyWith(color: p.muted),
        ),
      ],
    );
    if (!framed) return body;
    return V2Card(
      variant: V2CardVariant.soft,
      padding: const EdgeInsets.all(16),
      child: body,
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.title,
    required this.subtitle,
    required this.number,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      label: '$title $number, 전화하거나 복사',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(V2Radius.ctl),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: V2Text.bodyStrong),
                        Text(
                          subtitle,
                          style: V2Text.cap.copyWith(color: p.sub),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(V2Radius.pill),
                    ),
                    child: Text(
                      number,
                      style: V2Text.buttonSm.copyWith(color: p.onPrimarySoft),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Call (`tel:`) or copy the number.
Future<void> showCareContactActions(
  BuildContext context, {
  required String number,
  required String dial,
  required String name,
}) {
  return showV2Sheet<void>(
    context,
    title: '$name $number',
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('전화를 걸거나 번호를 복사할 수 있어요.', style: V2Text.cap),
        const SizedBox(height: 16),
        V2Button(
          label: '전화 걸기',
          icon: V2Icons.phone,
          onPressed: () async {
            Navigator.of(ctx).pop();
            final ok = await _dial(dial);
            if (!ok && context.mounted) {
              await Clipboard.setData(ClipboardData(text: number));
              if (context.mounted) {
                showV2Snack(context, '전화를 걸 수 없어서 번호를 복사했어요');
              }
            }
          },
        ),
        const SizedBox(height: 8),
        V2Button(
          label: '번호 복사',
          icon: V2Icons.copy,
          variant: V2ButtonVariant.soft,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: number));
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) showV2Snack(context, '$number 번호를 복사했어요');
          },
        ),
      ],
    ),
  );
}

Future<bool> _dial(String dial) async {
  try {
    return await launchUrl(Uri(scheme: 'tel', path: dial));
  } catch (_) {
    return false;
  }
}

/// Shown instead of repeating the same sentence when the AI is unavailable.
class CareFallbackNotice extends StatelessWidget {
  const CareFallbackNotice({super.key, this.message});

  /// The server's stand-in text, when there is one.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Card(
      variant: V2CardVariant.soft,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const V2Chip(label: '기본 안내', tone: V2Tone.lilac),
          const SizedBox(height: 8),
          Text(
            message ?? '지금은 AI 답변을 준비하지 못했어요. 대신 이렇게 해 보세요.',
            style: V2Text.bodyStrong.copyWith(color: p.ink),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '지금은 AI 답변을 준비하지 못했어요. 아래 방법을 먼저 해 보세요.',
                style: V2Text.cap,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '숨을 4초 들이마시고 6초 동안 천천히 내쉬어 보세요. 세 번만 해도 몸이 조금 풀려요. '
            '잠시 물을 마시거나 창가에서 쉬어 가도 좋아요. 조금 뒤에 다시 이야기해 주세요.',
            style: V2Text.body.copyWith(color: p.sub),
          ),
        ],
      ),
    );
  }
}

/// "AI이며 전문 상담/의료가 아니에요" notice, 13px+.
class CareAiNotice extends StatelessWidget {
  const CareAiNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(V2Icons.info, size: 16, color: p.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'AI 가이드예요. 전문 상담이나 의료가 아니에요.',
            style: V2Text.cap.copyWith(color: p.sub),
          ),
        ),
      ],
    );
  }
}
