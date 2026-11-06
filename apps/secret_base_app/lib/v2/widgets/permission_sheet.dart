import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart';
import 'icons.dart';
import 'illustration.dart';
import 'sheet.dart';

/// Which OS permission a [V2PermissionSheet] explains.
enum V2PermissionKind {
  location('위치', V2Icons.location, V2Tone.sage),
  camera('카메라', V2Icons.camera, V2Tone.rose),
  photos('사진', V2Icons.gallery, V2Tone.peach),
  notification('알림', V2Icons.bell, V2Tone.lilac);

  const V2PermissionKind(this.label, this.icon, this.tone);
  final String label;
  final IconData icon;
  final V2Tone tone;

  /// Default purpose copy (해요체). Override per screen when more specific.
  String get defaultPurpose => switch (this) {
    V2PermissionKind.location => '우리가 함께 간 곳을 지도에 남기고, 지금 있는 곳 근처를 보여 드려요.',
    V2PermissionKind.camera => '오늘의 순간을 바로 찍어서 기록으로 남길 수 있어요.',
    V2PermissionKind.photos => '갤러리의 사진을 골라 기록에 붙일 수 있어요.',
    V2PermissionKind.notification => '상대가 기록을 남기거나 기념일이 다가오면 알려 드려요.',
  };
}

/// What the user picked on a [V2PermissionSheet]. The sheet never calls
/// platform APIs itself; the screen requests the permission / opens
/// settings based on this.
enum V2PermissionChoice {
  /// Ask the OS now.
  allow,

  /// Dismissed or 나중에.
  later,

  /// Denied state: user wants to open system settings.
  openSettings,
}

/// Shows the purpose sheet right before requesting an OS permission, or
/// (with [denied]) the "설정에서 켜 주세요" guidance after a denial.
///
/// ```dart
/// final c = await showV2PermissionSheet(context, V2PermissionKind.location);
/// if (c == V2PermissionChoice.allow) await Geolocator.requestPermission();
///
/// final c2 = await showV2PermissionSheet(context, V2PermissionKind.camera, denied: true);
/// if (c2 == V2PermissionChoice.openSettings) await openAppSettings();
/// ```
Future<V2PermissionChoice> showV2PermissionSheet(
  BuildContext context,
  V2PermissionKind kind, {
  bool denied = false,
  String? purpose,
  List<String> points = const [],
}) async {
  final result = await showV2Sheet<V2PermissionChoice>(
    context,
    builder: (ctx) => V2PermissionSheet(
      kind: kind,
      denied: denied,
      purpose: purpose,
      points: points,
      onChoice: (c) => Navigator.of(ctx).pop(c),
    ),
  );
  return result ?? V2PermissionChoice.later;
}

/// Body of the permission purpose sheet (also usable inline, e.g. as the
/// denied state of a map screen).
class V2PermissionSheet extends StatelessWidget {
  const V2PermissionSheet({
    super.key,
    required this.kind,
    required this.onChoice,
    this.denied = false,
    this.purpose,
    this.points = const [],
  });

  final V2PermissionKind kind;
  final ValueChanged<V2PermissionChoice> onChoice;
  final bool denied;
  final String? purpose;

  /// Extra reassurance bullets, e.g. '서윤에게만 보여요'.
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final title = denied
        ? '설정에서 ${kind.label} 권한을 켜 주세요'
        : '${kind.label} 권한이 필요해요';
    final body = denied
        ? '${kind.label} 권한이 꺼져 있어서 이 기능을 쓸 수 없어요. '
              '설정 → 비밀기지 → ${kind.label}에서 허용으로 바꿔 주세요.'
        : (purpose ?? kind.defaultPurpose);
    final bullets = [...points, if (!denied) '언제든 설정에서 바꿀 수 있어요.'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: V2Art(
            icon: denied ? V2Icons.settings : kind.icon,
            tone: denied ? V2Tone.warn : kind.tone,
            size: 72,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: V2Text.title.copyWith(color: p.ink),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: V2Text.body.copyWith(color: p.sub),
        ),
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.soft,
              borderRadius: V2Radius.buttonAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            V2Icons.check,
                            size: 16,
                            color: p.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b,
                            style: V2Text.cap.copyWith(color: p.sub),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        V2Button(
          label: denied ? '설정 열기' : '허용하기',
          icon: denied ? V2Icons.settings : null,
          onPressed: () => onChoice(
            denied ? V2PermissionChoice.openSettings : V2PermissionChoice.allow,
          ),
        ),
        const SizedBox(height: 4),
        V2Button(
          label: denied ? '닫기' : '나중에',
          variant: V2ButtonVariant.text,
          onPressed: () => onChoice(V2PermissionChoice.later),
        ),
      ],
    );
  }
}
