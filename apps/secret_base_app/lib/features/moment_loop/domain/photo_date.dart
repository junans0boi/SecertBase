import 'dart:typed_data';

import 'package:exif/exif.dart';

/// Day a photo was taken, read from its EXIF tags. Returns null when the file
/// has no usable EXIF date (screenshots, edited or stripped images).
Future<DateTime?> exifCaptureDate(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    for (final key in const [
      'EXIF DateTimeOriginal',
      'EXIF DateTimeDigitized',
      'Image DateTime',
    ]) {
      final parsed = _parseExifDate(tags[key]?.printable);
      if (parsed != null) return parsed;
    }
  } catch (_) {}
  return null;
}

DateTime? _parseExifDate(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4})[:\-](\d{2})[:\-](\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final day = int.parse(m.group(3)!);
  if (year < 1990 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(year, month, day);
}
