import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Normalizes uploaded photos to JPEG, 85% quality, with a 1920px long edge.
Uint8List compressMomentImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image');
  }
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest > 1920
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1920 : null,
          height: oriented.height > oriented.width ? 1920 : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
