import 'package:latlong2/latlong.dart';

/// Pure helpers + constants for 비밀지도 (kept public so tests and other
/// screens can use them).
const mapCategories = ['식당', '카페', '활동', '여행', '쇼핑', '기타'];
const mapCategoryEmojis = {
  '식당': '🍽️',
  '카페': '☕',
  '활동': '🎯',
  '여행': '✈️',
  '쇼핑': '🛍️',
  '기타': '📍',
};

const mapEmotionTags = [
  '또 가자',
  '특별했어',
  '웃겼어',
  '우리 취향',
  '사진 맛집',
  '대화가 잘 됐어',
  '재방문 후보',
];

final koreaCenter = LatLng(36.35, 127.85);

String pinStatus(Map<String, dynamic> pin) {
  final status = pin['status'];
  if (status == 'wishlist' || status == 'visited') return '$status';
  final visitDate = pin['visit_date'];
  return visitDate == null || '$visitDate'.trim().isEmpty
      ? 'wishlist'
      : 'visited';
}

List<String> extractPinTags(Map<String, dynamic> pin) {
  final rawTags = pin['emotion_tags'];
  if (rawTags is List) {
    return rawTags
        .map((tag) => '$tag')
        .where((tag) => tag.trim().isNotEmpty)
        .toList();
  }

  final memo = '${pin['memo'] ?? ''}';
  final firstLine = memo.split('\n').firstOrNull ?? '';
  if (!firstLine.startsWith('#')) return const [];
  return firstLine
      .split(' ')
      .where((part) => part.startsWith('#') && part.length > 1)
      .map((part) => part.substring(1).replaceAll('_', ' '))
      .where((tag) => tag.trim().isNotEmpty)
      .toList();
}

String cleanPinMemo(dynamic memoValue) {
  final memo = '${memoValue ?? ''}'.trim();
  if (memo.isEmpty) return '';
  final lines = memo.split('\n');
  if (lines.isNotEmpty && lines.first.startsWith('#')) {
    return lines.skip(1).join('\n').trim();
  }
  return memo;
}

String composePinMemo(String memo, List<String> tags) {
  final cleanMemo = memo.trim();
  if (tags.isEmpty) return cleanMemo;
  final tagLine = tags.map((tag) => '#${tag.replaceAll(' ', '_')}').join(' ');
  return cleanMemo.isEmpty ? tagLine : '$tagLine\n$cleanMemo';
}

String dateValue(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime? parseDateString(dynamic value) {
  final str = dateKey(value);
  if (str == null) return null;
  try {
    return DateTime.parse(str);
  } catch (_) {
    return null;
  }
}

String dateLabel(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String? formattedDate(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  if (text.trim().isEmpty) return null;
  return text.split('T').first.replaceAll('-', '.');
}

String? dateKey(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  if (text.isEmpty) return null;
  return text.split(RegExp(r'[T ]')).first;
}

String matchText(dynamic value) {
  return '$value'.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

List<Map<String, dynamic>> linkedSetlogPostsForMap(
  Map<String, dynamic> pin,
  List<Map<String, dynamic>> posts,
) {
  final pinId = '${pin['id'] ?? ''}';
  final directlyLinked = pinId.isEmpty
      ? <Map<String, dynamic>>[]
      : posts.where((post) => '${post['map_pin_id'] ?? ''}' == pinId).toList();
  if (directlyLinked.isNotEmpty) {
    directlyLinked.sort((a, b) {
      final aDate = '${a['captured_at'] ?? a['taken_at'] ?? ''}';
      final bDate = '${b['captured_at'] ?? b['taken_at'] ?? ''}';
      return bDate.compareTo(aDate);
    });
    return directlyLinked;
  }

  final pinDate = dateKey(pin['visit_date']);
  final placeName = matchText(pin['place_name']);

  final dateMatched = posts.where((post) {
    final postDate = dateKey(post['taken_at']) ?? dateKey(post['captured_at']);
    if (pinDate != null) return postDate == pinDate;

    if (placeName.isEmpty) return false;
    final caption = matchText(post['caption']);
    return caption.contains(placeName);
  }).toList();

  final placeMatched = placeName.isEmpty
      ? <Map<String, dynamic>>[]
      : dateMatched
            .where((post) => matchText(post['caption']).contains(placeName))
            .toList();

  final matched = placeMatched.isNotEmpty ? placeMatched : dateMatched;

  matched.sort((a, b) {
    final aCaption = matchText(a['caption']);
    final bCaption = matchText(b['caption']);
    final aPlaceMatch = placeName.isNotEmpty && aCaption.contains(placeName);
    final bPlaceMatch = placeName.isNotEmpty && bCaption.contains(placeName);
    if (aPlaceMatch != bPlaceMatch) return aPlaceMatch ? -1 : 1;

    final aDate = '${a['captured_at'] ?? a['taken_at'] ?? ''}';
    final bDate = '${b['captured_at'] ?? b['taken_at'] ?? ''}';
    return bDate.compareTo(aDate);
  });

  return matched;
}

String? formatDistanceMeters(dynamic value) {
  final meters = placeDoubleForMap(value)?.round();
  if (meters == null || meters < 0) return null;
  if (meters < 1000) return '${meters}m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km';
}

String placeProviderLabel(dynamic value) {
  return switch ('${value ?? ''}'.toLowerCase()) {
    'kakao' => '카카오',
    'naver' => '네이버',
    'naver_maps' => '네이버 지도',
    'osm' => 'OSM',
    _ => '',
  };
}

Map<String, dynamic> normalizePlaceResultForMap(Map<String, dynamic> place) {
  final lat = placeDoubleForMap(place['latitude']) ?? 37.5665;
  final lng = placeDoubleForMap(place['longitude']) ?? 126.9780;
  final name = '${place['name'] ?? ''}'.trim();
  final distanceMeters = placeDoubleForMap(place['distanceMeters']);
  final categoryText = [
    place['categoryCode'],
    place['category'],
  ].where((value) => value != null && '$value'.trim().isNotEmpty).join(' ');

  return {
    ...place,
    'display_name': name,
    'name': name,
    'lat': lat,
    'lon': lng,
    'distanceMeters': distanceMeters,
    'category': mapPlaceCategory(categoryText),
  };
}

double? placeDoubleForMap(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? placeIntForMap(dynamic value) {
  final parsed = placeDoubleForMap(value);
  return parsed?.round();
}

String mapPlaceCategory(String categoryText) {
  final text = categoryText.toLowerCase();
  if (text.contains('fd6') ||
      text.contains('음식') ||
      text.contains('식당') ||
      text.contains('맛집') ||
      text.contains('한식') ||
      text.contains('중식') ||
      text.contains('일식') ||
      text.contains('양식') ||
      text.contains('분식') ||
      text.contains('술집')) {
    return '식당';
  }
  if (text.contains('ce7') ||
      text.contains('카페') ||
      text.contains('커피') ||
      text.contains('디저트') ||
      text.contains('베이커리')) {
    return '카페';
  }
  if (text.contains('at4') ||
      text.contains('ct1') ||
      text.contains('문화') ||
      text.contains('공연') ||
      text.contains('영화') ||
      text.contains('전시') ||
      text.contains('체험') ||
      text.contains('스포츠') ||
      text.contains('놀이')) {
    return '활동';
  }
  if (text.contains('ad5') ||
      text.contains('숙박') ||
      text.contains('호텔') ||
      text.contains('펜션') ||
      text.contains('여행') ||
      text.contains('관광') ||
      text.contains('명소')) {
    return '여행';
  }
  if (text.contains('mt1') ||
      text.contains('쇼핑') ||
      text.contains('백화점') ||
      text.contains('마트') ||
      text.contains('편집샵') ||
      text.contains('소품샵')) {
    return '쇼핑';
  }
  return '기타';
}
