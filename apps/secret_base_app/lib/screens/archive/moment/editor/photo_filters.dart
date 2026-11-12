import 'package:flutter/painting.dart';

/// One look offered in the editor's 필터 row.
class PhotoFilter {
  final String id;
  final String label;

  /// 5x4 color matrix, null for the untouched photo.
  final List<double>? matrix;

  const PhotoFilter(this.id, this.label, this.matrix);

  ColorFilter? get colorFilter =>
      matrix == null ? null : ColorFilter.matrix(matrix!);
}

const _identity = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// a · b for 5x4 color matrices (b applied first).
List<double> _mul(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = col == 4 ? a[row * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[row * 5 + k] * b[k * 5 + col];
      }
      out[row * 5 + col] = v;
    }
  }
  return out;
}

List<double> _saturation(double s) {
  const lr = .2126, lg = .7152, lb = .0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return [
    sr + s, sg, sb, 0, 0, //
    sr, sg + s, sb, 0, 0, //
    sr, sg, sb + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

List<double> _contrast(double c, [double lift = 0]) {
  final t = (1 - c) * 128 + lift;
  return [
    c, 0, 0, 0, t, //
    0, c, 0, 0, t, //
    0, 0, c, 0, t, //
    0, 0, 0, 1, 0, //
  ];
}

List<double> _tint(double r, double g, double b, [double add = 0]) => [
  r, 0, 0, 0, add, //
  0, g, 0, 0, add * .5, //
  0, 0, b, 0, 0, //
  0, 0, 0, 1, 0, //
];

const _sepia = <double>[
  .393, .769, .189, 0, 0, //
  .349, .686, .168, 0, 0, //
  .272, .534, .131, 0, 0, //
  0, 0, 0, 1, 0, //
];

List<double> _mix(List<double> a, List<double> b, double t) => [
  for (var i = 0; i < 20; i++) a[i] * (1 - t) + b[i] * t,
];

final photoFilters = <PhotoFilter>[
  const PhotoFilter('original', '원본', null),
  PhotoFilter(
    'warm',
    '따뜻하게',
    _mul(_tint(1.08, 1.02, .88, 6), _saturation(1.08)),
  ),
  PhotoFilter('vivid', '선명하게', _mul(_contrast(1.12), _saturation(1.38))),
  PhotoFilter(
    'film',
    '필름',
    _mul(_tint(.98, 1.03, 1.0), _mul(_contrast(.86, 14), _saturation(.82))),
  ),
  PhotoFilter('mono', '흑백', _mul(_contrast(1.1), _saturation(0))),
  PhotoFilter(
    'vintage',
    '빈티지',
    _mul(_contrast(.9, 10), _mix(_identity, _sepia, .55)),
  ),
];

PhotoFilter photoFilterById(String id) => photoFilters.firstWhere(
  (f) => f.id == id,
  orElse: () => photoFilters.first,
);
