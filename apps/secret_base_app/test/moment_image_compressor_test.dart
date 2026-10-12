import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secret_base_app/features/moment_loop/data/moment_image_compressor.dart';

void main() {
  test('normalizes landscape photos to JPEG with a 1920px long edge', () {
    final source = img.Image(width: 2400, height: 1200);
    source.setPixel(0, 0, img.ColorRgb8(20, 90, 140));
    final compressed = compressMomentImage(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeJpg(compressed)!;
    expect(decoded.width, 1920);
    expect(decoded.height, 960);
  });

  test('does not enlarge small photos', () {
    final source = img.Image(width: 320, height: 240);
    final compressed = compressMomentImage(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeJpg(compressed)!;
    expect(decoded.width, 320);
    expect(decoded.height, 240);
  });
}
