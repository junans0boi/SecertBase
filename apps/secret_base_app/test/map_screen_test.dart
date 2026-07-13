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
}
