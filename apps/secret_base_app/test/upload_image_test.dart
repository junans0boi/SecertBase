import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/upload_image.dart';

void main() {
  const base = 'https://secretbase.cloud';

  test('photos get the smallest server copy that is wide enough', () {
    expect(
      uploadUrl('/uploads/1730000000000-1.jpg', base, width: 120),
      '$base/uploads/w/160/1730000000000-1.jpg',
    );
    expect(
      uploadUrl('/uploads/a.png', base, width: 400),
      '$base/uploads/w/480/a.png',
    );
    expect(
      uploadUrl('/uploads/a.webp', base, width: 1080),
      '$base/uploads/w/1080/a.webp',
    );
    expect(
      uploadUrl('/uploads/a.jpg', base, width: 3000),
      '$base/uploads/w/1080/a.jpg',
    );
    expect(
      uploadUrl('$base/uploads/a.jpg', 'ignored', width: 160),
      '$base/uploads/w/160/a.jpg',
    );
  });

  test('videos, other paths and no width keep the original', () {
    expect(
      uploadUrl('/uploads/clip.mp4', base, width: 160),
      '$base/uploads/clip.mp4',
    );
    expect(
      uploadUrl('/uploads/album/a.jpg', base, width: 160),
      '$base/uploads/album/a.jpg',
    );
    expect(uploadUrl('/uploads/a.jpg', base), '$base/uploads/a.jpg');
    expect(
      uploadUrl('https://cdn.example/x.jpg', base, width: 160),
      'https://cdn.example/x.jpg',
    );
    expect(uploadUrl(null, base), isNull);
    expect(uploadUrl('  ', base), isNull);
  });
}
