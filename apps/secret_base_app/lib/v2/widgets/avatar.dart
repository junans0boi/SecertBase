import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';

enum V2AvatarSize {
  /// 32px
  sm(32, 13),

  /// 44px
  md(44, 17),

  /// 64px
  lg(64, 24),

  /// 88px (profile)
  xl(88, 32);

  const V2AvatarSize(this.dimension, this.fontSize);
  final double dimension;
  final double fontSize;
}

/// Initial-letter avatar (ds.css `.avatar`). Default color is rose600 (me);
/// use [V2Avatar.partnerColor] for the partner. White initial is AA on
/// both (5.03 / 6.91 via skyText).
///
/// ```dart
/// V2Avatar(name: '민지')
/// V2Avatar(name: '서윤', color: V2Avatar.partnerColor, size: V2AvatarSize.lg)
/// V2Avatar(name: '서윤', image: NetworkImage(url))
/// ```
class V2Avatar extends StatelessWidget {
  const V2Avatar({
    super.key,
    required this.name,
    this.color = V2Colors.rose600,
    this.size = V2AvatarSize.md,
    this.image,
    this.ring,
  });

  static const meColor = V2Colors.rose600;
  static const partnerColor = V2Colors.skyText;

  final String name;
  final Color color;
  final V2AvatarSize size;
  final ImageProvider? image;

  /// Ring color (used by [V2AvatarPair] for overlap separation).
  final Color? ring;

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final d = size.dimension;
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: ring == null ? null : Border.all(color: ring!, width: 2.5),
          image: image == null
              ? null
              : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image != null
            ? null
            : Text(
                initial,
                textScaler: TextScaler.noScaling,
                style: V2Text.sans(
                  size: size.fontSize,
                  weight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

/// Two overlapping avatars (me + partner).
///
/// ```dart
/// V2AvatarPair(me: '민지', partner: '서윤')
/// ```
class V2AvatarPair extends StatelessWidget {
  const V2AvatarPair({
    super.key,
    required this.me,
    required this.partner,
    this.size = V2AvatarSize.md,
    this.meImage,
    this.partnerImage,
  });

  final String me;
  final String partner;
  final V2AvatarSize size;
  final ImageProvider? meImage;
  final ImageProvider? partnerImage;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final d = size.dimension;
    final overlap = d * 0.32;
    return Semantics(
      label: '$me, $partner',
      excludeSemantics: true,
      child: SizedBox(
        width: d * 2 - overlap + 5,
        height: d + 5,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: V2Avatar(name: me, size: size, image: meImage, ring: p.bg),
            ),
            Positioned(
              left: d - overlap,
              top: 0,
              child: V2Avatar(
                name: partner,
                size: size,
                color: V2Avatar.partnerColor,
                image: partnerImage,
                ring: p.bg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
