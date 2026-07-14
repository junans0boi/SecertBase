import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_service.dart';
import '../../core/main_design.dart';

const _categories = ['식당', '카페', '활동', '여행', '쇼핑', '기타'];
const _categoryEmojis = {
  '식당': '🍽️',
  '카페': '☕',
  '활동': '🎯',
  '여행': '✈️',
  '쇼핑': '🛍️',
  '기타': '📍',
};

const _emotionTags = [
  '또 가자',
  '특별했어',
  '웃겼어',
  '우리 취향',
  '사진 맛집',
  '대화가 잘 됐어',
  '재방문 후보',
];

final _koreaCenter = LatLng(36.35, 127.85);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _auth = AuthService();
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.86);
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _pins = [];
  List<Map<String, dynamic>> _setlogPosts = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  bool _isSearching = false;
  bool _showSearchResults = false;
  bool _locatingUser = false;
  bool _locationDenied = false;
  String? _activeCategory;
  String _activeStatus = 'all';
  LatLng? _userLatLng;
  LatLng? _tempSelectedLatLng;
  String? _tempSelectedName;
  String? _tempSelectedCategory;
  int _activeCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _requestUserLocation(quiet: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int? get _currentUserId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Map<String, String> _jsonHeaders({bool includeAuth = false}) {
    return {
      'Content-Type': 'application/json',
      if (includeAuth && _auth.token != null)
        'Authorization': 'Bearer ${_auth.token}',
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _currentUserId;
      final mapUrl = userId != null
          ? '${_auth.baseUrl}/api/map?user_id=$userId'
          : '${_auth.baseUrl}/api/map?user_id=0';
      final res = await http.get(Uri.parse(mapUrl));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        setState(() {
          _pins =
              (data['pins'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _activeCardIndex = 0;
        });
      }

      if (userId != null) {
        final setlogUri = Uri.parse(
          '${_auth.baseUrl}/api/setlog',
        ).replace(queryParameters: {'user_id': '$userId'});
        final setlogRes = await http.get(setlogUri);
        final setlogData = jsonDecode(setlogRes.body) as Map<String, dynamic>;
        if (setlogData['ok'] == true && mounted) {
          setState(() {
            _setlogPosts =
                (setlogData['posts'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [];
          });
        }
      }
    } catch (_) {
      debugPrint('map load error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPins {
    return _pins.where((pin) {
      final statusMatches =
          _activeStatus == 'all' || _pinStatus(pin) == _activeStatus;
      final categoryMatches =
          _activeCategory == null || pin['category'] == _activeCategory;
      return statusMatches && categoryMatches;
    }).toList();
  }

  int get _visitedCount =>
      _pins.where((pin) => _pinStatus(pin) == 'visited').length;
  int get _wishlistCount =>
      _pins.where((pin) => _pinStatus(pin) == 'wishlist').length;

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
      _tempSelectedLatLng = null;
      _tempSelectedName = null;
      _tempSelectedCategory = null;
    });

    try {
      final center = _searchOrigin();
      final url = Uri.parse(
        '${_auth.baseUrl}/api/places/search?q=${Uri.encodeQueryComponent(query)}&limit=10&lat=${center.latitude}&lng=${center.longitude}',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final places = data['places'] as List? ?? [];
        setState(() {
          _searchResults = places
              .map(
                (e) => normalizePlaceResultForMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        });
      } else {
        await _searchAddressFallback(query);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      await _searchAddressFallback(query);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchAddressFallback(String query) async {
    try {
      final center = _searchOrigin();
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=6&countrycodes=kr',
      );
      final res = await http.get(url, headers: {'User-Agent': 'SecretBaseApp'});
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as List;
      if (!mounted) return;
      setState(() {
        _searchResults =
            data
                .map(
                  (e) => {
                    'display_name': e['display_name'],
                    'name': e['display_name'].toString().split(',')[0],
                    'address': e['display_name'],
                    'provider': 'osm',
                    'lat': double.tryParse('${e['lat']}') ?? 37.5665,
                    'lon': double.tryParse('${e['lon']}') ?? 126.9780,
                    'category': '기타',
                  },
                )
                .map((place) {
                  final lat = place['lat'] as double;
                  final lon = place['lon'] as double;
                  return {
                    ...place,
                    'distanceMeters': const Distance().as(
                      LengthUnit.Meter,
                      center,
                      LatLng(lat, lon),
                    ),
                  };
                })
                .toList()
              ..sort((a, b) {
                final aDistance =
                    placeDoubleForMap(a['distanceMeters']) ?? double.infinity;
                final bDistance =
                    placeDoubleForMap(b['distanceMeters']) ?? double.infinity;
                return aDistance.compareTo(bDistance);
              });
      });
    } catch (e) {
      debugPrint('Fallback search error: $e');
    }
  }

  LatLng _searchOrigin() {
    if (_userLatLng != null) return _userLatLng!;
    try {
      return _mapController.camera.center;
    } catch (_) {
      return _koreaCenter;
    }
  }

  Future<void> _requestUserLocation({
    bool moveMap = false,
    bool quiet = false,
  }) async {
    if (_locatingUser) return;
    setState(() => _locatingUser = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationDenied = true);
        if (!quiet) _toast('위치 서비스를 켜면 주변 장소를 먼저 볼 수 있어요');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationDenied = true);
        if (!quiet) _toast('위치 권한 없이도 검색은 계속 사용할 수 있어요');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _userLatLng = point;
        _locationDenied = false;
      });

      if (moveMap || _pins.isEmpty) {
        try {
          _mapController.move(point, 14.0);
        } catch (_) {
          // The map can still be mounting during the first permission prompt.
        }
      }
    } catch (e) {
      debugPrint('location error: $e');
      if (mounted) setState(() => _locationDenied = true);
      if (!quiet) _toast('현재 위치를 가져오지 못했어요');
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  Future<void> _addPin({
    required String name,
    required String status,
    required String category,
    required int rating,
    DateTime? visitDate,
    required List<String> emotionTags,
    required String memo,
    required double lat,
    required double lng,
  }) async {
    final userCode =
        _auth.user?['UserCode'] ?? _auth.user?['userCode'] ?? 'unknown';
    final userId = _currentUserId;
    final visitDateStr = visitDate == null ? null : _dateValue(visitDate);
    final bodyMemo = _composeMemo(memo, emotionTags);

    try {
      await http.post(
        Uri.parse('${_auth.baseUrl}/api/map'),
        headers: _jsonHeaders(includeAuth: true),
        body: jsonEncode({
          'place_name': name,
          'category': category,
          'rating': status == 'visited' ? rating : null,
          'visit_date': status == 'visited' ? visitDateStr : null,
          'memo': bodyMemo.isNotEmpty ? bodyMemo : null,
          'created_by': userCode,
          'user_id': userId,
          'latitude': lat,
          'longitude': lng,
          'status': status,
          'emotion_tags': emotionTags,
        }),
      );
      setState(() {
        _tempSelectedLatLng = null;
        _tempSelectedName = null;
        _tempSelectedCategory = null;
        _activeStatus = status;
        _activeCategory = category;
      });
      await _load();
      if (_filteredPins.isNotEmpty) {
        _onCardChanged(0);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('장소를 저장하지 못했어요', style: mainBody(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _markVisited(Map<String, dynamic> pin) async {
    DateTime selectedDate = DateTime.now();
    int selectedRating = placeIntForMap(pin['rating']) ?? 5;
    final selectedTags = <String>{..._extractTags(pin)};
    final memoCtrl = TextEditingController(text: _cleanMemo(pin['memo']));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => _SheetFrame(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kMainLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('다녀온 기록 남기기', style: mainTitle(size: 24)),
                  const SizedBox(height: 4),
                  Text(
                    pin['place_name'] ?? '',
                    style: mainBody(
                      size: 14,
                      color: kMainSub,
                      weight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  _DatePickerTile(
                    date: selectedDate,
                    label: '방문 날짜',
                    onPick: () async {
                      final picked = await _pickDate(ctx, selectedDate);
                      if (picked != null) setSheet(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  _RatingPicker(
                    rating: selectedRating,
                    onChanged: (value) =>
                        setSheet(() => selectedRating = value),
                  ),
                  const SizedBox(height: 16),
                  _EmotionPicker(
                    selectedTags: selectedTags,
                    onToggle: (tag) => setSheet(() {
                      selectedTags.contains(tag)
                          ? selectedTags.remove(tag)
                          : selectedTags.add(tag);
                    }),
                  ),
                  const SizedBox(height: 16),
                  _SoftTextField(
                    controller: memoCtrl,
                    hintText: '오늘 어땠는지 짧게 남겨줘',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                      label: Text(
                        '기록하고 리워드 받기',
                        style: mainBody(
                          color: Colors.white,
                          weight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: kMainRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saved != true) return;

    final updatedMemo = _composeMemo(memoCtrl.text, selectedTags.toList());
    final id = pin['id'];
    final userId = _currentUserId;
    if (id == null || userId == null) {
      _toast('방문 기록을 저장하지 못했어요');
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse('${_auth.baseUrl}/api/map/$id'),
        headers: _jsonHeaders(includeAuth: true),
        body: jsonEncode({
          'rating': selectedRating,
          'memo': updatedMemo,
          'visit_date': _dateValue(selectedDate),
          'status': 'visited',
          'emotion_tags': selectedTags.toList(),
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['ok'] != true) {
        _toast('작성자만 방문 기록을 수정할 수 있어요');
        return;
      }
    } catch (_) {
      debugPrint('map visit patch error');
      _toast('방문 기록을 저장하지 못했어요');
      return;
    }

    setState(() {
      pin['rating'] = selectedRating;
      pin['memo'] = updatedMemo;
      pin['visit_date'] = _dateValue(selectedDate);
      _activeStatus = 'visited';
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '방문 기록 +12 포인트',
          style: mainBody(color: Colors.white, weight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showAddDialog(
    LatLng latLng, {
    String? initialName,
    String? initialCategory,
  }) {
    final nameCtrl = TextEditingController(
      text: initialName ?? _tempSelectedName ?? '',
    );
    final memoCtrl = TextEditingController();
    String selectedStatus = _activeStatus == 'wishlist'
        ? 'wishlist'
        : 'visited';
    String selectedCategory =
        initialCategory ?? _tempSelectedCategory ?? _activeCategory ?? '기타';
    int selectedRating = 5;
    DateTime selectedDate = DateTime.now();
    final selectedTags = <String>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _SheetFrame(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kMainLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.add_location_alt_rounded,
                        color: kMainRose,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text('비밀 장소 추가', style: mainTitle(size: 24)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
                    style: mainBody(size: 11, color: kMainMuted),
                  ),
                  const SizedBox(height: 18),
                  _StatusSegment(
                    value: selectedStatus,
                    onChanged: (value) =>
                        setSheet(() => selectedStatus = value),
                  ),
                  const SizedBox(height: 16),
                  _SoftTextField(
                    controller: nameCtrl,
                    hintText: '장소 이름',
                    prefixIcon: Icons.place_outlined,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '카테고리',
                    style: mainBody(
                      size: 12,
                      color: kMainMuted,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories
                        .map(
                          (cat) => _ChoiceChip(
                            label: '${_categoryEmojis[cat]} $cat',
                            selected: selectedCategory == cat,
                            onTap: () => setSheet(() => selectedCategory = cat),
                          ),
                        )
                        .toList(),
                  ),
                  if (selectedStatus == 'visited') ...[
                    const SizedBox(height: 16),
                    _DatePickerTile(
                      date: selectedDate,
                      label: '방문 날짜',
                      onPick: () async {
                        final picked = await _pickDate(ctx, selectedDate);
                        if (picked != null) {
                          setSheet(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _RatingPicker(
                      rating: selectedRating,
                      onChanged: (value) =>
                          setSheet(() => selectedRating = value),
                    ),
                    const SizedBox(height: 16),
                    _EmotionPicker(
                      selectedTags: selectedTags,
                      onToggle: (tag) => setSheet(() {
                        selectedTags.contains(tag)
                            ? selectedTags.remove(tag)
                            : selectedTags.add(tag);
                      }),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SoftTextField(
                    controller: memoCtrl,
                    hintText: selectedStatus == 'visited'
                        ? '우리 메모'
                        : '가보고 싶은 이유',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        await _addPin(
                          name: nameCtrl.text.trim(),
                          status: selectedStatus,
                          category: selectedCategory,
                          rating: selectedRating,
                          visitDate: selectedStatus == 'visited'
                              ? selectedDate
                              : null,
                          emotionTags: selectedStatus == 'visited'
                              ? selectedTags.toList()
                              : const [],
                          memo: memoCtrl.text.trim(),
                          lat: latLng.latitude,
                          lng: latLng.longitude,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kMainRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        '지도에 저장',
                        style: mainBody(
                          color: Colors.white,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kMainRose,
            onPrimary: Colors.white,
            surface: kMainPaper,
            onSurface: kMainInk,
          ),
        ),
        child: child!,
      ),
    );
  }

  void _onCardChanged(int index) {
    final pins = _filteredPins;
    if (index < 0 || index >= pins.length) return;
    setState(() => _activeCardIndex = index);
    final pin = pins[index];
    _moveToPin(pin);
  }

  void _moveToPin(Map<String, dynamic> pin, {double zoom = 15.0}) {
    final lat = placeDoubleForMap(pin['latitude']) ?? 37.5665;
    final lng = placeDoubleForMap(pin['longitude']) ?? 126.9780;
    _mapController.move(LatLng(lat, lng), zoom);
  }

  void _focusPin(int index, {bool openDetail = false}) {
    final pins = _filteredPins;
    if (index < 0 || index >= pins.length) return;
    setState(() {
      _tempSelectedLatLng = null;
      _tempSelectedName = null;
      _showSearchResults = false;
      _activeCardIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    _moveToPin(pins[index]);
    if (openDetail) _showPinDetail(pins[index]);
  }

  void _showPinDetail(Map<String, dynamic> pin) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final category = pin['category'] ?? '기타';
        final emoji = _categoryEmojis[category] ?? '📍';
        final status = _pinStatus(pin);
        final isVisited = status == 'visited';
        final rating = placeIntForMap(pin['rating']) ?? 0;
        final tags = _extractTags(pin);
        final memo = _cleanMemo(pin['memo']);
        final date = _formattedDate(pin['visit_date']);
        final author = '${pin['created_by'] ?? '우리'}';
        final linkedPosts = linkedSetlogPostsForMap(pin, _setlogPosts);

        return _SheetFrame(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 22,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kMainLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PinBubble(
                        emoji: emoji,
                        status: status,
                        active: true,
                        size: 58,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pin['place_name'] ?? '',
                              style: mainTitle(size: 26),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _MiniPill(
                                  label: isVisited ? '다녀온 곳' : '가고 싶은 곳',
                                  color: isVisited ? kMainRose : kMainLilac,
                                  backgroundColor: isVisited
                                      ? kMainRoseSoft
                                      : kMainLilacSoft,
                                ),
                                _MiniPill(
                                  label: category,
                                  color: kMainPeach,
                                  backgroundColor: kMainPeachSoft,
                                ),
                                if (date != null)
                                  _MiniPill(
                                    label: date,
                                    color: kMainSage,
                                    backgroundColor: kMainSageSoft,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isVisited && rating > 0) ...[
                    _DetailBlock(
                      icon: Icons.favorite_rounded,
                      title: '우리 온도',
                      child: Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 22,
                              color: i < rating ? kMainHoney : kMainLine,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$rating.0',
                            style: mainBody(
                              size: 13,
                              color: kMainInk,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (tags.isNotEmpty) ...[
                    _DetailBlock(
                      icon: Icons.auto_awesome_rounded,
                      title: '감정 태그',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags
                            .map(
                              (tag) => _MiniPill(
                                label: tag,
                                color: kMainRose,
                                backgroundColor: kMainRoseSoft,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DetailBlock(
                    icon: Icons.edit_note_rounded,
                    title: isVisited ? '우리 메모' : '가보고 싶은 이유',
                    child: Text(
                      memo.isEmpty
                          ? (isVisited ? '아직 메모가 없어요' : '언젠가 같이 가볼 장소예요')
                          : memo,
                      style: mainBody(
                        size: 13.5,
                        color: kMainInk,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailBlock(
                    icon: Icons.photo_library_outlined,
                    title: '연결된 추억',
                    child: _LinkedMemorySummary(
                      posts: linkedPosts,
                      isVisited: isVisited,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showDirectionsSheet(pin),
                      icon: const Icon(Icons.near_me_rounded, size: 18),
                      label: Text(
                        '길찾기',
                        style: mainBody(
                          color: Colors.white,
                          weight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: kMainInk,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.favorite_border_rounded,
                          label: '하트',
                          onTap: () => _toast('하트를 남겼어요'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '댓글',
                          onTap: () => _toast('댓글은 다음 연결에서 붙일게요'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.ios_share_rounded,
                          label: '공유',
                          onTap: () => _sharePin(pin),
                        ),
                      ),
                    ],
                  ),
                  if (!isVisited) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _markVisited(pin),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          '다녀왔어요',
                          style: mainBody(
                            color: Colors.white,
                            weight: FontWeight.w900,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: kMainRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '등록: $author',
                      style: mainBody(size: 11, color: kMainMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showListSheet() {
    final pins = _filteredPins;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetFrame(
        child: DraggableScrollableSheet(
          initialChildSize: 0.66,
          minChildSize: 0.38,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kMainLine,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('장소 모아보기', style: mainTitle(size: 24)),
                    ),
                    Text(
                      '${pins.length}곳',
                      style: mainBody(
                        size: 13,
                        color: kMainMuted,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: pins.isEmpty
                      ? Center(
                          child: Text(
                            '조건에 맞는 장소가 없어요',
                            style: mainBody(size: 13, color: kMainMuted),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: pins.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final pin = pins[i];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _focusPin(i, openDetail: true);
                              },
                              child: _ListTilePin(pin: pin),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sharePin(Map<String, dynamic> pin) async {
    final lat = placeDoubleForMap(pin['latitude']) ?? 0;
    final lng = placeDoubleForMap(pin['longitude']) ?? 0;
    final text = [
      'Secret Base 비밀지도',
      pin['place_name'] ?? '우리 장소',
      '${_categoryEmojis[pin['category']] ?? '📍'} ${pin['category'] ?? '기타'}',
      'https://maps.google.com/?q=$lat,$lng',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _toast('공유 문구를 복사했어요');
  }

  void _showDirectionsSheet(Map<String, dynamic> pin) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kMainLine,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('어떤 지도로 갈까요?', style: mainTitle(size: 24)),
              const SizedBox(height: 4),
              Text(
                pin['place_name'] ?? '선택한 장소',
                style: mainBody(
                  size: 13,
                  color: kMainMuted,
                  weight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _MapAppTile(
                icon: Icons.map_rounded,
                title: '네이버지도',
                subtitle: '대중교통/도보 길찾기 추천',
                color: kMainSage,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchDirections(pin, _DirectionsProvider.naver);
                },
              ),
              const SizedBox(height: 9),
              _MapAppTile(
                icon: Icons.route_rounded,
                title: '카카오맵',
                subtitle: '차/대중교통/도보 선택이 쉬워요',
                color: kMainHoney,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchDirections(pin, _DirectionsProvider.kakao);
                },
              ),
              const SizedBox(height: 9),
              _MapAppTile(
                icon: Icons.navigation_rounded,
                title: 'TMAP',
                subtitle: '차로 이동할 때 빠르게',
                color: kMainSky,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchDirections(pin, _DirectionsProvider.tmap);
                },
              ),
              const SizedBox(height: 9),
              _MapAppTile(
                icon: Icons.public_rounded,
                title: '웹 지도로 열기',
                subtitle: '앱이 없어도 브라우저에서 확인',
                color: kMainRose,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchDirections(pin, _DirectionsProvider.web);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchDirections(
    Map<String, dynamic> pin,
    _DirectionsProvider provider,
  ) async {
    final lat = placeDoubleForMap(pin['latitude']) ?? 0;
    final lng = placeDoubleForMap(pin['longitude']) ?? 0;
    final name = '${pin['place_name'] ?? '목적지'}';
    final encodedName = Uri.encodeComponent(name);
    final fallback = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    final uri = switch (provider) {
      _DirectionsProvider.naver => Uri.parse(
        'nmap://route/public?dlat=$lat&dlng=$lng&dname=$encodedName&appname=secertbase.kro.kr',
      ),
      _DirectionsProvider.kakao => Uri.parse(
        'kakaomap://route?ep=$lat,$lng&by=publictransit',
      ),
      _DirectionsProvider.tmap => Uri.parse(
        'tmap://route?goalname=$encodedName&goalx=$lng&goaly=$lat',
      ),
      _DirectionsProvider.web => fallback,
    };

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && provider != _DirectionsProvider.web) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (provider != _DirectionsProvider.web) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } else {
        _toast('지도를 열지 못했어요');
      }
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: mainBody(color: Colors.white, weight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pins = _filteredPins;
    final centerLatLng = pins.isNotEmpty
        ? LatLng(
            placeDoubleForMap(pins.first['latitude']) ?? 37.5665,
            placeDoubleForMap(pins.first['longitude']) ?? 126.9780,
          )
        : _userLatLng ?? _koreaCenter;
    final initialZoom = pins.isNotEmpty
        ? 14.0
        : (_userLatLng == null ? 6.5 : 14.0);

    return Scaffold(
      backgroundColor: kMainBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: kMainRose))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centerLatLng,
                    initialZoom: initialZoom,
                    maxZoom: 18.0,
                    minZoom: 3.0,
                    onTap: (_, point) {
                      setState(() {
                        _tempSelectedLatLng = point;
                        _tempSelectedName = null;
                        _showSearchResults = false;
                      });
                      _mapController.move(point, _mapController.camera.zoom);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      userAgentPackageName: 'com.secretbase.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_userLatLng != null)
                          Marker(
                            point: _userLatLng!,
                            width: 42,
                            height: 42,
                            child: const _UserLocationMarker(),
                          ),
                        ...pins.asMap().entries.map((entry) {
                          final i = entry.key;
                          final pin = entry.value;
                          final lat = placeDoubleForMap(pin['latitude']) ?? 0.0;
                          final lng =
                              placeDoubleForMap(pin['longitude']) ?? 0.0;
                          final category = pin['category'] ?? '기타';
                          final emoji = _categoryEmojis[category] ?? '📍';
                          final status = _pinStatus(pin);
                          final isActive = i == _activeCardIndex;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: isActive ? 66 : 48,
                            height: isActive ? 66 : 48,
                            child: GestureDetector(
                              onTap: () => _focusPin(i, openDetail: true),
                              child: _PinBubble(
                                emoji: emoji,
                                status: status,
                                active: isActive,
                                size: isActive ? 58 : 44,
                              ),
                            ),
                          );
                        }),
                        if (_tempSelectedLatLng != null)
                          Marker(
                            point: _tempSelectedLatLng!,
                            width: 64,
                            height: 64,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: kMainRose,
                              size: 52,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      kMainBg.withAlpha(215),
                      kMainBg.withAlpha(55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: kMainPaper.withAlpha(245),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: kMainLine.withAlpha(180)),
                            boxShadow: [
                              BoxShadow(
                                color: kMainRose.withAlpha(16),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: _searchAddress,
                            decoration: InputDecoration(
                              hintText: '장소 검색',
                              hintStyle: mainBody(size: 13, color: kMainMuted),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: kMainRose,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: kMainMuted,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {
                                          _searchResults.clear();
                                          _showSearchResults = false;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                            ),
                            style: mainBody(size: 14, color: kMainInk),
                            onChanged: (val) {
                              setState(() {});
                              if (val.isEmpty) {
                                setState(() {
                                  _searchResults.clear();
                                  _showSearchResults = false;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        icon: _locationDenied
                            ? Icons.location_disabled_rounded
                            : (_locatingUser
                                  ? Icons.gps_fixed_rounded
                                  : Icons.my_location_rounded),
                        onTap: () => _requestUserLocation(moveMap: true),
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        icon: Icons.format_list_bulleted_rounded,
                        onTap: _showListSheet,
                      ),
                    ],
                  ),
                  if (_showSearchResults) ...[
                    const SizedBox(height: 8),
                    _SearchResultPanel(
                      isSearching: _isSearching,
                      results: _searchResults,
                      onTap: (item) {
                        final pos = LatLng(item['lat'], item['lon']);
                        setState(() {
                          _tempSelectedLatLng = pos;
                          _tempSelectedName =
                              item['name'] as String? ??
                              item['display_name'].toString().split(',')[0];
                          _tempSelectedCategory = item['category'] as String?;
                          _showSearchResults = false;
                          _searchCtrl.text = _tempSelectedName ?? '';
                        });
                        _mapController.move(pos, 15.0);
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusChip(
                          label: '전체',
                          count: _pins.length,
                          selected: _activeStatus == 'all',
                          color: kMainInk,
                          onTap: () => _setStatus('all'),
                        ),
                        _StatusChip(
                          label: '다녀온 곳',
                          count: _visitedCount,
                          selected: _activeStatus == 'visited',
                          color: kMainRose,
                          onTap: () => _setStatus('visited'),
                        ),
                        _StatusChip(
                          label: '가고 싶은 곳',
                          count: _wishlistCount,
                          selected: _activeStatus == 'wishlist',
                          color: kMainLilac,
                          onTap: () => _setStatus('wishlist'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip(null, '전체'),
                        ..._categories.map(
                          (cat) => _buildCategoryChip(
                            cat,
                            '${_categoryEmojis[cat]} $cat',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tempSelectedLatLng != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MainCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      color: kMainPaper.withAlpha(246),
                      borderColor: kMainRose.withAlpha(90),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_location_alt_rounded,
                            color: kMainRose,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _tempSelectedName == null
                                  ? '선택한 위치 저장하기'
                                  : _tempSelectedName!,
                              style: mainBody(
                                size: 13,
                                color: kMainInk,
                                weight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _tempSelectedLatLng = null;
                              _tempSelectedName = null;
                              _tempSelectedCategory = null;
                            }),
                            child: Text(
                              '취소',
                              style: mainBody(size: 12, color: kMainMuted),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _showAddDialog(
                              _tempSelectedLatLng!,
                              initialName: _tempSelectedName,
                              initialCategory: _tempSelectedCategory,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: kMainRose,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            child: Text(
                              '저장',
                              style: mainBody(
                                size: 12,
                                color: Colors.white,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (pins.isNotEmpty)
                  SizedBox(
                    height: 142,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pins.length,
                      onPageChanged: _onCardChanged,
                      itemBuilder: (ctx, i) {
                        final pin = pins[i];
                        return AnimatedScale(
                          scale: i == _activeCardIndex ? 1.0 : 0.95,
                          duration: const Duration(milliseconds: 200),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => _showPinDetail(pin),
                              child: _pinCard(pin),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: MainCard(
                      color: kMainPaper.withAlpha(248),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('아직 우리 지도가 비어 있어요', style: mainTitle(size: 20)),
                          const SizedBox(height: 5),
                          Text(
                            '검색하거나 지도 위를 눌러 첫 장소를 남겨봐요',
                            style: mainBody(size: 12, color: kMainMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tempSelectedLatLng != null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 148),
              child: FloatingActionButton(
                onPressed: () {
                  final center = _mapController.camera.center;
                  _showAddDialog(center);
                },
                backgroundColor: kMainRose,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_location_alt_outlined),
              ),
            ),
    );
  }

  void _setStatus(String status) {
    setState(() {
      _activeStatus = status;
      _activeCardIndex = 0;
      _tempSelectedLatLng = null;
      _tempSelectedName = null;
    });
    if (_filteredPins.isNotEmpty) _onCardChanged(0);
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isActive = _activeCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeCategory = category;
            _activeCardIndex = 0;
            _tempSelectedLatLng = null;
            _tempSelectedName = null;
          });
          if (_filteredPins.isNotEmpty) _onCardChanged(0);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? kMainPeach : kMainPaper.withAlpha(235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? kMainPeach : kMainLine.withAlpha(180),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: mainBody(
              size: 12,
              color: isActive ? Colors.white : kMainInk,
              weight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinCard(Map<String, dynamic> pin) {
    final category = pin['category'] ?? '기타';
    final emoji = _categoryEmojis[category] ?? '📍';
    final rating = placeIntForMap(pin['rating']) ?? 0;
    final status = _pinStatus(pin);
    final isVisited = status == 'visited';
    final tags = _extractTags(pin);
    final memo = _cleanMemo(pin['memo']);
    final visitDateStr = _formattedDate(pin['visit_date']);

    return MainCard(
      padding: const EdgeInsets.all(14),
      color: kMainPaper.withAlpha(248),
      borderColor: isVisited
          ? kMainRose.withAlpha(70)
          : kMainLilac.withAlpha(70),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PinBubble(emoji: emoji, status: status, active: true, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pin['place_name'] ?? '',
                        style: mainBody(
                          size: 14,
                          color: kMainInk,
                          weight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: kMainMuted.withAlpha(180),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _MiniPill(
                      label: isVisited ? '다녀온 곳' : '가고 싶은 곳',
                      color: isVisited ? kMainRose : kMainLilac,
                      backgroundColor: isVisited
                          ? kMainRoseSoft
                          : kMainLilacSoft,
                    ),
                    _MiniPill(
                      label: category,
                      color: kMainPeach,
                      backgroundColor: kMainPeachSoft,
                    ),
                    if (visitDateStr != null)
                      _MiniPill(
                        label: visitDateStr,
                        color: kMainSage,
                        backgroundColor: kMainSageSoft,
                      ),
                  ],
                ),
                if (isVisited && rating > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < rating ? kMainHoney : kMainLine,
                      ),
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    tags.take(2).join(' · '),
                    style: mainBody(
                      size: 11,
                      color: kMainRose,
                      weight: FontWeight.w800,
                    ),
                  ),
                ] else if (memo.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    memo,
                    style: mainBody(size: 11, color: kMainSub, height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBubble extends StatelessWidget {
  final String emoji;
  final String status;
  final bool active;
  final double size;

  const _PinBubble({
    required this.emoji,
    required this.status,
    required this.active,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isVisited = status == 'visited';
    final color = isVisited ? kMainRose : kMainLilac;
    final bg = isVisited ? kMainRoseSoft : kMainLilacSoft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? color : bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? Colors.white : color.withAlpha(170),
          width: active ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(active ? 88 : 40),
            blurRadius: active ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: active ? size * 0.42 : size * 0.36),
        ),
      ),
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kMainSky.withAlpha(45),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: kMainSky,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: kMainSky.withAlpha(90),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kMainPaper.withAlpha(245),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kMainLine.withAlpha(180)),
          ),
          child: Icon(icon, size: 18, color: kMainInk),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : kMainPaper.withAlpha(235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : kMainLine.withAlpha(180),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(selected ? 34 : 8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: mainBody(
                  size: 12,
                  color: selected ? Colors.white : kMainInk,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: mainBody(
                  size: 11,
                  color: selected ? Colors.white.withAlpha(220) : kMainMuted,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultPanel extends StatelessWidget {
  final bool isSearching;
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _SearchResultPanel({
    required this.isSearching,
    required this.results,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MainCard(
      padding: EdgeInsets.zero,
      color: kMainPaper.withAlpha(250),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 230),
        child: isSearching
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: kMainRose),
                ),
              )
            : results.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '검색 결과가 없어요',
                  style: mainBody(size: 13, color: kMainMuted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, index) =>
                    const Divider(height: 1, color: kMainLine),
                itemBuilder: (ctx, idx) {
                  final item = results[idx];
                  final address =
                      '${item['roadAddress'] ?? item['address'] ?? ''}';
                  final provider = _placeProviderLabel(item['provider']);
                  final distance = _formatDistanceMeters(
                    item['distanceMeters'],
                  );
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: kMainRose),
                    title: Text(
                      item['name'] ?? item['display_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mainBody(
                        size: 13,
                        color: kMainInk,
                        weight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (address.isNotEmpty) address,
                        ?distance,
                        if (provider.isNotEmpty) provider,
                      ].join(' · '),
                      style: mainBody(size: 11, color: kMainMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onTap(item),
                  );
                },
              ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final Widget child;

  const _SheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kMainPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _StatusSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMainLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: '다녀온 곳',
              icon: Icons.favorite_rounded,
              selected: value == 'visited',
              color: kMainRose,
              onTap: () => onChanged('visited'),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: '가고 싶은 곳',
              icon: Icons.bookmark_rounded,
              selected: value == 'wishlist',
              color: kMainLilac,
              onTap: () => onChanged('wishlist'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: mainBody(
                size: 12,
                color: selected ? Colors.white : kMainInk,
                weight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final IconData? prefixIcon;

  const _SoftTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: kMainRose, size: 20),
        filled: true,
        fillColor: kMainPaperSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kMainRose),
        ),
        hintStyle: mainBody(size: 13, color: kMainMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      style: mainBody(size: 14, color: kMainInk),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kMainPeach : kMainPaperSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kMainPeach : kMainLine),
        ),
        child: Text(
          label,
          style: mainBody(
            size: 12,
            color: selected ? Colors.white : kMainInk,
            weight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final String label;
  final VoidCallback onPick;

  const _DatePickerTile({
    required this.date,
    required this.label,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: kMainPaperSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kMainLine),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: kMainRose,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: mainBody(
                size: 12,
                color: kMainMuted,
                weight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              _dateLabel(date),
              style: mainBody(
                size: 13,
                color: kMainInk,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _RatingPicker({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '우리 온도',
          style: mainBody(size: 12, color: kMainMuted, weight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(
                  Icons.star_rounded,
                  color: star <= rating ? kMainHoney : kMainLine,
                  size: 30,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _EmotionPicker extends StatelessWidget {
  final Set<String> selectedTags;
  final ValueChanged<String> onToggle;

  const _EmotionPicker({required this.selectedTags, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '감정 태그',
          style: mainBody(size: 12, color: kMainMuted, weight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emotionTags
              .map(
                (tag) => _ChoiceChip(
                  label: tag,
                  selected: selectedTags.contains(tag),
                  onTap: () => onToggle(tag),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const _MiniPill({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: mainBody(
          size: 10.5,
          color: color,
          weight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailBlock({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMainLine.withAlpha(170)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: kMainRose),
              const SizedBox(width: 6),
              Text(
                title,
                style: mainBody(
                  size: 12,
                  color: kMainMuted,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: mainBody(size: 12, color: kMainInk, weight: FontWeight.w800),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: kMainInk,
        side: const BorderSide(color: kMainLine),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _LinkedMemorySummary extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isVisited;

  const _LinkedMemorySummary({required this.posts, required this.isVisited});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Row(
        children: [
          _MemoryDot(color: kMainRoseSoft, icon: Icons.favorite_rounded),
          const SizedBox(width: 8),
          _MemoryDot(color: kMainSkySoft, icon: Icons.image_outlined),
          const SizedBox(width: 8),
          _MemoryDot(
            color: kMainHoneySoft,
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isVisited
                  ? '같은 날 MomentLoop 기록이 아직 없어요'
                  : '다녀온 뒤 MomentLoop 기록과 이어져요',
              style: mainBody(size: 12, color: kMainMuted),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _MemoryDot(color: kMainRoseSoft, icon: Icons.auto_stories_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'MomentLoop 기록 ${posts.length}개와 연결됐어요',
                style: mainBody(
                  size: 12.5,
                  color: kMainInk,
                  weight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...posts.take(3).map((post) {
          final caption = '${post['caption'] ?? ''}'.trim();
          final mediaType = '${post['media_type'] ?? 'text'}';
          final date = _formattedDate(post['taken_at'] ?? post['captured_at']);
          final icon = switch (mediaType) {
            'image' => Icons.image_outlined,
            'video' => Icons.play_circle_outline_rounded,
            _ => Icons.notes_rounded,
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: kMainRose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      ?date,
                      if (caption.isNotEmpty) caption else '사진/영상 기록',
                    ].join(' · '),
                    style: mainBody(size: 12, color: kMainSub, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MapAppTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MapAppTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kMainPaperSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kMainLine.withAlpha(170)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: mainBody(
                        size: 14,
                        color: kMainInk,
                        weight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: mainBody(
                        size: 11.5,
                        color: kMainMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: kMainMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryDot extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MemoryDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 16, color: kMainInk.withAlpha(170)),
    );
  }
}

class _ListTilePin extends StatelessWidget {
  final Map<String, dynamic> pin;

  const _ListTilePin({required this.pin});

  @override
  Widget build(BuildContext context) {
    final category = pin['category'] ?? '기타';
    final emoji = _categoryEmojis[category] ?? '📍';
    final status = _pinStatus(pin);
    final isVisited = status == 'visited';
    final memo = _cleanMemo(pin['memo']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMainPaperSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMainLine),
      ),
      child: Row(
        children: [
          _PinBubble(emoji: emoji, status: status, active: true, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin['place_name'] ?? '',
                  style: mainBody(
                    size: 14,
                    color: kMainInk,
                    weight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${isVisited ? '다녀온 곳' : '가고 싶은 곳'} · $category${memo.isNotEmpty ? ' · $memo' : ''}',
                  style: mainBody(size: 11.5, color: kMainMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: kMainMuted, size: 18),
        ],
      ),
    );
  }
}

enum _DirectionsProvider { naver, kakao, tmap, web }

String _pinStatus(Map<String, dynamic> pin) {
  final status = pin['status'];
  if (status == 'wishlist' || status == 'visited') return '$status';
  final visitDate = pin['visit_date'];
  return visitDate == null || '$visitDate'.trim().isEmpty
      ? 'wishlist'
      : 'visited';
}

List<String> _extractTags(Map<String, dynamic> pin) {
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

String _cleanMemo(dynamic memoValue) {
  final memo = '${memoValue ?? ''}'.trim();
  if (memo.isEmpty) return '';
  final lines = memo.split('\n');
  if (lines.isNotEmpty && lines.first.startsWith('#')) {
    return lines.skip(1).join('\n').trim();
  }
  return memo;
}

String _composeMemo(String memo, List<String> tags) {
  final cleanMemo = memo.trim();
  if (tags.isEmpty) return cleanMemo;
  final tagLine = tags.map((tag) => '#${tag.replaceAll(' ', '_')}').join(' ');
  return cleanMemo.isEmpty ? tagLine : '$tagLine\n$cleanMemo';
}

String _dateValue(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _dateLabel(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String? _formattedDate(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  if (text.trim().isEmpty) return null;
  return text.split('T').first.replaceAll('-', '.');
}

String? _dateKey(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  if (text.isEmpty) return null;
  return text.split(RegExp(r'[T ]')).first;
}

String _matchText(dynamic value) {
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

  final pinDate = _dateKey(pin['visit_date']);
  final placeName = _matchText(pin['place_name']);

  final dateMatched = posts.where((post) {
    final postDate =
        _dateKey(post['taken_at']) ?? _dateKey(post['captured_at']);
    if (pinDate != null) return postDate == pinDate;

    if (placeName.isEmpty) return false;
    final caption = _matchText(post['caption']);
    return caption.contains(placeName);
  }).toList();

  final placeMatched = placeName.isEmpty
      ? <Map<String, dynamic>>[]
      : dateMatched
            .where((post) => _matchText(post['caption']).contains(placeName))
            .toList();

  final matched = placeMatched.isNotEmpty ? placeMatched : dateMatched;

  matched.sort((a, b) {
    final aCaption = _matchText(a['caption']);
    final bCaption = _matchText(b['caption']);
    final aPlaceMatch = placeName.isNotEmpty && aCaption.contains(placeName);
    final bPlaceMatch = placeName.isNotEmpty && bCaption.contains(placeName);
    if (aPlaceMatch != bPlaceMatch) return aPlaceMatch ? -1 : 1;

    final aDate = '${a['captured_at'] ?? a['taken_at'] ?? ''}';
    final bDate = '${b['captured_at'] ?? b['taken_at'] ?? ''}';
    return bDate.compareTo(aDate);
  });

  return matched;
}

String? _formatDistanceMeters(dynamic value) {
  final meters = placeDoubleForMap(value)?.round();
  if (meters == null || meters < 0) return null;
  if (meters < 1000) return '${meters}m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km';
}

String _placeProviderLabel(dynamic value) {
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
    'category': _mapPlaceCategory(categoryText),
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

String _mapPlaceCategory(String categoryText) {
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
