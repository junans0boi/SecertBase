import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/features/moment_loop/domain/photo_date.dart';

/// Minimal JPEG (SOI + APP1/Exif + EOI) whose EXIF carries [tag] = [value].
Uint8List jpegWithExif(int tag, String value) {
  final text = [...value.codeUnits, 0];
  final ifd0 = <int>[
    ..._u16(1),
    ..._u16(0x8769),
    ..._u16(4),
    ..._u32(1),
    ..._u32(26),
    ..._u32(0),
  ];
  final exifIfd = <int>[
    ..._u16(1),
    ..._u16(tag),
    ..._u16(2),
    ..._u32(text.length),
    ..._u32(44),
    ..._u32(0),
  ];
  final tiff = <int>[
    0x49,
    0x49,
    0x2a,
    0x00,
    ..._u32(8),
    ...ifd0,
    ...exifIfd,
    ...text,
  ];
  final body = <int>[0x45, 0x78, 0x69, 0x66, 0, 0, ...tiff];
  final len = body.length + 2;
  return Uint8List.fromList([
    0xff,
    0xd8,
    0xff,
    0xe1,
    len >> 8,
    len & 0xff,
    ...body,
    0xff,
    0xd9,
  ]);
}

List<int> _u16(int v) => [v & 0xff, (v >> 8) & 0xff];
List<int> _u32(int v) => [
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];

void main() {
  test('reads the capture day from EXIF DateTimeOriginal', () async {
    final bytes = jpegWithExif(0x9003, '2026:09:24 12:00:00');
    expect(await exifCaptureDate(bytes), DateTime(2026, 9, 24));
  });

  test('returns null when the image has no EXIF date', () async {
    expect(
      await exifCaptureDate(Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9])),
      isNull,
    );
  });

  test('ignores the placeholder date 0000:00:00', () async {
    final bytes = jpegWithExif(0x9003, '0000:00:00 00:00:00');
    expect(await exifCaptureDate(bytes), isNull);
  });
}
