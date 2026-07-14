import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/archive/map_screen.dart';

void main() {
  test('normalizePlaceResultForMap accepts Kakao string coordinates', () {
    final result = normalizePlaceResultForMap({
      'provider': 'kakao',
      'name': '카카오 장소',
      'latitude': '37.55878289',
      'longitude': '126.8279012',
      'distanceMeters': '132',
    });

    expect(result['lat'], 37.55878289);
    expect(result['lon'], 126.8279012);
    expect(result['distanceMeters'], 132);
  });

  test('map value parsers accept database string values', () {
    expect(placeDoubleForMap('37.55878289'), 37.55878289);
    expect(placeDoubleForMap('126.8279012'), 126.8279012);
    expect(placeDoubleForMap(132), 132);
    expect(placeIntForMap('4'), 4);
    expect(placeIntForMap(4.0), 4);
  });

  test(
    'linkedSetlogPostsForMap prefers same-day posts that mention the place',
    () {
      final pin = {
        'place_name': '성수 카페',
        'visit_date': '2026-07-14T00:00:00.000Z',
      };
      final posts = [
        {'id': 1, 'taken_at': '2026-07-14', 'caption': '비 오는 날 성수 카페에서 찍은 사진'},
        {'id': 2, 'taken_at': '2026-07-14', 'caption': '장소명은 안 적었지만 같은 날 기록'},
        {'id': 3, 'taken_at': '2026-07-13', 'caption': '성수 카페 전날 기록'},
      ];

      final linked = linkedSetlogPostsForMap(pin, posts);

      expect(linked.map((post) => post['id']), [1]);
    },
  );

  test('linkedSetlogPostsForMap prefers direct map_pin_id links', () {
    final linked = linkedSetlogPostsForMap(
      {'id': 12, 'place_name': '성수 카페', 'visit_date': '2026-07-14'},
      [
        {
          'id': 1,
          'map_pin_id': 12,
          'taken_at': '2026-07-13',
          'caption': '직접 연결',
        },
        {'id': 2, 'taken_at': '2026-07-14', 'caption': '같은 날 기록'},
      ],
    );

    expect(linked.map((post) => post['id']), [1]);
  });

  test('linkedSetlogPostsForMap falls back to same-day posts', () {
    final linked = linkedSetlogPostsForMap(
      {'place_name': '성수 카페', 'visit_date': '2026-07-14'},
      [
        {'id': 1, 'taken_at': '2026-07-14', 'caption': '장소명은 안 적었지만 같은 날 기록'},
        {'id': 2, 'taken_at': '2026-07-13', 'caption': '성수 카페 전날 기록'},
      ],
    );

    expect(linked.map((post) => post['id']), [1]);
  });
}
