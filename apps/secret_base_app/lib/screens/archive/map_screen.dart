import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/afterglow_api.dart';
import '../../core/auth_service.dart';
import '../../core/http/api_client.dart';
import '../../v2/v2.dart';
import 'map/map_api.dart';
import 'map/map_logic.dart';
import 'map/map_sheets.dart';
import 'moment/couple_names.dart';
import 'moment_loop_screen.dart';

export 'map/map_logic.dart'
    show
        linkedSetlogPostsForMap,
        mapFallbackTileUrl,
        mapTileUrl,
        normalizePlaceResultForMap,
        placeDoubleForMap,
        placeIntForMap;

enum _Directions { naver, kakao, tmap, web }

/// 비밀지도: 오버레이는 검색 + 내 위치뿐. 장소는 미니 시트로 추가하고,
/// 상세는 3섹션 + 하단 CTA.
class MapScreen extends StatefulWidget {
  final bool closeAsModal;

  /// Test seam; production uses the ambient HTTP client.
  final http.Client? client;

  const MapScreen({super.key, this.closeAsModal = false, this.client});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _auth = AuthService();
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  late final MapApi _api = MapApi(auth: _auth, client: widget.client);
  Timer? _debounce;
  int _searchSeq = 0;

  List<Map<String, dynamic>> _pins = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  MapApiException? _error;
  bool _searching = false;
  bool _searchFailed = false;
  bool _showResults = false;
  bool _locating = false;
  String? _locationNotice;
  bool _tileError = false;
  String _status = 'all';
  String? _category;
  LatLng? _user;
  LatLng? _temp;
  Object? _selectedId;
  String _partner = CoupleNames.cachedPartner ?? '상대';

  int? get _myId {
    final value = _auth.user?['UserId'] ?? _auth.user?['id'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  String get _myName => CoupleNames.myNickname(_auth);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadPartner());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _api.close();
    super.dispose();
  }

  void _toast(String message, {V2Tone tone = V2Tone.neutral}) {
    if (!mounted) return;
    showV2Snack(context, message, tone: tone);
  }

  Future<void> _loadPartner() async {
    final api = ApiClient(
      baseUrl: _auth.baseUrl,
      tokenProvider: () => _auth.token,
      client: widget.client,
    );
    try {
      final name = await CoupleNames.loadPartner(
        api,
        userKey: '${_myId ?? ''}',
      );
      if (mounted && name != null) setState(() => _partner = name);
    } finally {
      api.close();
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
        _tileError = false;
      });
    }
    try {
      final pins = await _api.fetchPins();
      if (!mounted) return;
      setState(() {
        _pins = pins;
        _error = null;
      });
      final id = _myId;
      if (id != null) {
        unawaited(
          _api.fetchPosts(id).then((posts) {
            if (mounted) setState(() => _posts = posts);
          }),
        );
      }
    } on MapApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _pins.where((pin) {
    final statusOk = _status == 'all' || pinStatus(pin) == _status;
    final categoryOk = _category == null || pin['category'] == _category;
    return statusOk && categoryOk;
  }).toList();

  int _count(String status) =>
      _pins.where((p) => pinStatus(p) == status).length;

  LatLng _searchOrigin() {
    if (_user != null) return _user!;
    try {
      return _mapController.camera.center;
    } catch (_) {
      return koreaCenter;
    }
  }

  void _moveTo(LatLng point, {double zoom = 15}) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // The map may still be mounting.
    }
  }

  LatLng? _pinPoint(Map<String, dynamic> pin) {
    final lat = placeDoubleForMap(pin['latitude']);
    final lng = placeDoubleForMap(pin['longitude']);
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    if (value.trim().isEmpty) {
      setState(() {
        _showResults = false;
        _results = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    final seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _searchFailed = false;
      _showResults = true;
    });
    try {
      final origin = _searchOrigin();
      final results = await _api.searchPlaces(
        q,
        lat: origin.latitude,
        lng: origin.longitude,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() => _results = results);
    } on MapApiException {
      if (mounted && seq == _searchSeq) {
        setState(() {
          _results = [];
          _searchFailed = true;
        });
      }
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _searching = false);
    }
  }

  void _pickResult(Map<String, dynamic> place) {
    final point = LatLng(
      placeDoubleForMap(place['lat']) ?? koreaCenter.latitude,
      placeDoubleForMap(place['lon']) ?? koreaCenter.longitude,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showResults = false;
      _temp = point;
    });
    _moveTo(point);
    _openAdd(
      point,
      name: '${place['name'] ?? ''}',
      category: '${place['category'] ?? '기타'}',
    );
  }

  // ── Location (only on user action) ─────────────────────────────────────────

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _locationNotice = '위치 서비스가 꺼져 있어요');
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        final choice = await showV2PermissionSheet(
          context,
          V2PermissionKind.location,
        );
        if (choice != V2PermissionChoice.allow) return;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationNotice = '위치 권한이 꺼져 있어요');
        final choice = await showV2PermissionSheet(
          context,
          V2PermissionKind.location,
          denied: true,
        );
        if (choice == V2PermissionChoice.openSettings) {
          await Geolocator.openAppSettings();
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _user = point;
        _locationNotice = null;
      });
      _moveTo(point, zoom: 15);
    } catch (_) {
      _toast('현재 위치를 가져오지 못했어요. 잠시 후 다시 눌러 주세요.', tone: V2Tone.err);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Add ────────────────────────────────────────────────────────────────────

  Future<void> _openAdd(
    LatLng point, {
    String name = '',
    String category = '기타',
  }) async {
    setState(() => _temp = point);
    await showV2Sheet<void>(
      context,
      title: '장소 추가',
      subtitle: name.isEmpty ? '고른 위치에 이름을 붙여 주세요' : '이 장소를 우리 지도에 남길까요?',
      builder: (ctx) => AddPlaceSheet(
        initialName: name,
        initialCategory: category,
        onSave: (r) async {
          await _savePin(point, r);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
    if (mounted) setState(() => _temp = null);
  }

  Future<void> _savePin(LatLng point, AddPlaceResult r) async {
    final before = _pins.map((p) => '${p['id']}').toSet();
    int? newId;
    try {
      newId = await _api.createPin(
        name: r.name,
        status: r.status,
        category: r.category,
        lat: point.latitude,
        lng: point.longitude,
        visitDate: DateTime.now(),
      );
    } on MapApiException catch (e) {
      if (e.unpaired && mounted) setState(() => _error = e);
      rethrow;
    }
    await _load(quiet: true);
    if (!mounted) return;
    Map<String, dynamic>? created;
    for (final p in _pins) {
      if (newId != null && placeIntForMap(p['id']) == newId) created = p;
    }
    created ??= _pins.where((p) => !before.contains('${p['id']}')).lastOrNull;
    setState(() {
      _temp = null;
      _selectedId = created?['id'];
      // Never hide the pin the user just made.
      if (_status != 'all' && _status != r.status) _status = 'all';
      if (_category != null && _category != r.category) _category = null;
    });
    _moveTo(point);
    _toast(r.status == 'visited' ? '다녀온 곳으로 남겼어요' : '가고 싶은 곳으로 남겼어요');
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> _fresh(Map<String, dynamic> pin) => _pins.firstWhere(
    (p) => '${p['id']}' == '${pin['id']}',
    orElse: () => pin,
  );

  void _closeSheet() => Navigator.of(context, rootNavigator: true).pop();

  Future<void> _openPin(Map<String, dynamic> pin) async {
    final point = _pinPoint(pin);
    setState(() => _selectedId = pin['id']);
    if (point != null) _moveTo(point);
    await _showDetail(pin);
  }

  Future<void> _showDetail(Map<String, dynamic> raw) async {
    final pin = _fresh(raw);
    final visited = pinStatus(pin) == 'visited';
    final directions = V2Button(
      key: const Key('map_cta_directions'),
      label: '길찾기',
      icon: V2Icons.location,
      variant: visited ? V2ButtonVariant.primary : V2ButtonVariant.soft,
      onPressed: () => _showDirections(pin),
    );
    await showV2Sheet<void>(
      context,
      title: '${pin['place_name'] ?? '우리 장소'}',
      builder: (ctx) => PlaceDetailBody(
        pin: pin,
        api: _api,
        posts: _posts,
        myUserId: _myId,
        myName: _myName,
        partnerName: _partner,
        onEdit: () {
          _closeSheet();
          unawaited(_editPin(pin));
        },
        onDelete: () {
          _closeSheet();
          unawaited(_deletePin(pin));
        },
        onShare: () => _sharePin(pin),
        onLeaveMoment: widget.closeAsModal
            ? null
            : () {
                _closeSheet();
                _leaveMoment(pin);
              },
        onContributeAfterglow: () {
          _closeSheet();
          unawaited(_contributeFor(pin));
        },
        onWriteNote: _writeNote,
      ),
      actions: [
        if (visited)
          directions
        else
          Row(
            children: [
              Expanded(child: directions),
              const SizedBox(width: V2Space.x3),
              Expanded(
                child: V2Button(
                  key: const Key('map_cta_visited'),
                  label: '다녀왔어요',
                  onPressed: () {
                    _closeSheet();
                    unawaited(_markVisited(pin));
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _leaveMoment(Map<String, dynamic> pin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentLoopScreen(
          openComposer: true,
          initialPinId: placeIntForMap(pin['id']),
          initialPinName: '${pin['place_name'] ?? ''}',
        ),
      ),
    );
  }

  Future<void> _writeNote(Map<String, dynamic> pin) async {
    await showV2Sheet<void>(
      context,
      title: '한마디 남기기',
      builder: (ctx) => NoteComposeSheet(
        onSubmit: (content, image) async {
          await _api.addReview(pin['id'], content: content, image: image);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _sharePin(Map<String, dynamic> pin) async {
    final lat = placeDoubleForMap(pin['latitude']) ?? 0;
    final lng = placeDoubleForMap(pin['longitude']) ?? 0;
    final text = [
      '비밀기지 비밀지도',
      '${pin['place_name'] ?? '우리 장소'}',
      '${mapCategoryEmojis[pin['category']] ?? '📍'} ${pin['category'] ?? '기타'}',
      'https://maps.google.com/?q=$lat,$lng',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _toast('장소 정보를 복사했어요');
  }

  Future<void> _editPin(Map<String, dynamic> pin) async {
    final id = pin['id'];
    if (id == null) {
      _toast('이 장소는 고칠 수 없어요', tone: V2Tone.err);
      return;
    }
    final visited = pinStatus(pin) == 'visited';
    var saved = false;
    await showV2Sheet<void>(
      context,
      title: '장소 고치기',
      subtitle: '${pin['place_name'] ?? ''}',
      builder: (ctx) => EditPlaceSheet(
        pin: pin,
        baseUrl: _auth.baseUrl,
        onSave: (r) async {
          final fields = <String, dynamic>{
            'memo': composePinMemo(r.memo, r.tags),
            'emotion_tags': r.tags,
            if (r.removeImage && r.newImage == null) 'media_url': '',
            if (visited && r.rating > 0) 'rating': r.rating,
            if (visited) 'visit_date': dateValue(r.date),
          };
          await _api.updatePin(id, fields: fields, newImage: r.newImage);
          saved = true;
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
    if (saved) {
      await _load(quiet: true);
      _toast('고쳤어요');
    }
    if (mounted) await _showDetail(pin);
  }

  Future<void> _deletePin(Map<String, dynamic> pin) async {
    final ok = await showV2ConfirmDestructiveSheet(
      context,
      title: '이 장소를 지울까요?',
      consequences: const [
        '지도에서 장소가 사라져요',
        '남긴 한마디와 여운도 함께 사라져요',
        '연결해 둔 기록은 그대로 남아요',
      ],
      confirmLabel: '지우기',
    );
    if (!ok || !mounted) return;
    try {
      await _api.deletePin(pin['id']);
      if (!mounted) return;
      setState(() => _selectedId = null);
      await _load(quiet: true);
      _toast('장소를 지웠어요');
    } on MapApiException {
      _toast('지우지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    }
  }

  // ── Visited / afterglow ────────────────────────────────────────────────────

  Future<void> _markVisited(Map<String, dynamic> pin) async {
    final token = _auth.token;
    final pinId = placeIntForMap(pin['id']);
    if (token == null || pinId == null) return;
    final api = AfterglowApi(baseUrl: _auth.baseUrl, token: token);
    try {
      final visit = await api.createVisit(pinId);
      await _load(quiet: true);
      if (!mounted) return;
      setState(() => _status = _status == 'wishlist' ? 'all' : _status);
      _toast('다녀온 곳으로 바꿨어요');
      await _showContribution(pin, visit);
    } on AfterglowApiException {
      _toast('다녀온 곳으로 바꾸지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    } finally {
      api.close();
    }
    if (mounted) await _showDetail(pin);
  }

  Future<void> _contributeFor(Map<String, dynamic> pin) async {
    final token = _auth.token;
    final pinId = placeIntForMap(pin['id']);
    if (token == null || pinId == null) return;
    final api = AfterglowApi(baseUrl: _auth.baseUrl, token: token);
    try {
      final state = await api.fetchForPin(pinId);
      if (state.visit == null) {
        _toast('다녀온 기록을 찾지 못했어요', tone: V2Tone.err);
      } else if (mounted) {
        await _showContribution(pin, state.visit!);
      }
    } catch (_) {
      _toast('여운을 불러오지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    } finally {
      api.close();
    }
    if (mounted) await _showDetail(pin);
  }

  Future<void> _showContribution(
    Map<String, dynamic> pin,
    AfterglowVisit visit,
  ) async {
    final userId = _myId;
    final token = _auth.token;
    if (!mounted || userId == null || token == null) return;
    final candidates = afterglowMomentCandidates(
      pinId: visit.mapPinId,
      visitDate: visit.visitDate,
      userId: userId,
      posts: _posts,
    );
    var leave = false;
    final result = await showV2Sheet<AfterglowPickResult>(
      context,
      title: '우리의 여운 남기기',
      subtitle: '${pin['place_name'] ?? ''}',
      builder: (ctx) => AfterglowPickSheet(
        candidates: candidates,
        onLeaveMoment: () {
          leave = true;
          Navigator.pop(ctx);
        },
      ),
    );
    if (leave && mounted) {
      _leaveMoment(pin);
      return;
    }
    if (result == null) return;
    final api = AfterglowApi(baseUrl: _auth.baseUrl, token: token);
    try {
      await api.contribute(
        visitId: visit.id,
        postId: result.postId,
        caption: result.caption,
        emotionTag: result.emotion,
      );
      _toast('우리의 여운에 한 장을 남겼어요');
    } catch (_) {
      _toast('여운을 저장하지 못했어요. 다시 시도해 주세요.', tone: V2Tone.err);
    } finally {
      api.close();
    }
  }

  // ── Directions ─────────────────────────────────────────────────────────────

  void _showDirections(Map<String, dynamic> pin) {
    showV2Sheet<void>(
      context,
      title: '길찾기',
      subtitle: '${pin['place_name'] ?? ''}',
      builder: (ctx) => V2List(
        children: [
          for (final (provider, label, icon) in const [
            (_Directions.naver, '네이버 지도', V2Icons.map),
            (_Directions.kakao, '카카오맵', V2Icons.map),
            (_Directions.tmap, '티맵', V2Icons.map),
            (_Directions.web, '웹에서 열기', V2Icons.link),
          ])
            V2ListTile(
              icon: icon,
              title: label,
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_launchDirections(pin, provider));
              },
            ),
        ],
      ),
    );
  }

  Future<void> _launchDirections(
    Map<String, dynamic> pin,
    _Directions provider,
  ) async {
    final lat = placeDoubleForMap(pin['latitude']) ?? 0;
    final lng = placeDoubleForMap(pin['longitude']) ?? 0;
    final name = Uri.encodeComponent('${pin['place_name'] ?? '목적지'}');
    final fallback = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    final uri = switch (provider) {
      _Directions.naver => Uri.parse(
        'nmap://route/public?dlat=$lat&dlng=$lng&dname=$name&appname=secretbase.cloud',
      ),
      _Directions.kakao => Uri.parse(
        'kakaomap://route?ep=$lat,$lng&by=publictransit',
      ),
      _Directions.tmap => Uri.parse(
        'tmap://route?goalname=$name&goalx=$lng&goaly=$lat',
      ),
      _Directions.web => fallback,
    };
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && provider != _Directions.web) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } catch (_) {
        _toast('지도를 열지 못했어요', tone: V2Tone.err);
      }
    }
  }

  // ── Lists ──────────────────────────────────────────────────────────────────

  void _showList() {
    final pins = _filtered;
    showV2Sheet<void>(
      context,
      title: '우리 장소 ${pins.length}곳',
      builder: (ctx) {
        if (pins.isEmpty) {
          return const V2EmptyState(
            illustration: V2SceneIllustration(V2Scene.map),
            title: '표시할 장소가 없어요',
            body: '필터를 바꾸거나, 검색하거나 지도를 눌러 장소를 추가해 보세요.',
          );
        }
        return V2List(
          children: [
            for (final pin in pins)
              V2ListTile(
                key: Key('map_list_${pin['id']}'),
                icon: V2Icons.location,
                tone: pinStatus(pin) == 'visited' ? V2Tone.ok : V2Tone.lilac,
                title: '${pin['place_name'] ?? ''}',
                subtitle:
                    '${pinStatus(pin) == 'visited' ? '다녀온 곳' : '가고 싶은 곳'} · ${pin['category'] ?? '기타'}',
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_openPin(pin));
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickCategory() async {
    final picked = await showV2Sheet<String>(
      context,
      title: '분류',
      builder: (ctx) => V2List(
        children: [
          V2ListTile(
            icon: V2Icons.filter,
            title: '모든 분류',
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final c in mapCategories)
            V2ListTile(
              title: '${mapCategoryEmojis[c]} $c',
              trailing: _category == c
                  ? const Icon(V2Icons.ok, color: V2Colors.rose600)
                  : null,
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _category = picked.isEmpty ? null : picked);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return V2Theme(
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: V2Header(
          title: '비밀지도',
          showBack: widget.closeAsModal ? true : null,
          backTooltip: widget.closeAsModal ? '닫기' : '뒤로 가기',
        ),
        body: _body(p),
      ),
    );
  }

  Widget _body(V2Palette p) {
    if (_loading && _pins.isEmpty && _error == null) {
      return const Padding(
        padding: EdgeInsets.all(V2Space.page),
        child: V2Shimmer(
          child: V2SkeletonBox(height: 420, radius: V2Radius.card),
        ),
      );
    }
    final error = _error;
    if (error != null && _pins.isEmpty) {
      if (error.unpaired) {
        return V2EmptyState.unpaired(
          body: '상대와 연결하면 둘만의 지도를 함께 채울 수 있어요.',
          onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
        );
      }
      return error.offline
          ? V2ErrorState.offline(onRetry: _load)
          : V2ErrorState(
              title: '지도를 불러오지 못했어요',
              body: '잠시 후 다시 시도해 주세요.',
              onRetry: _load,
            );
    }

    final pins = _filtered;
    final points = [for (final pin in _pins) ?_pinPoint(pin)];
    final center = pins.isNotEmpty
        ? (_pinPoint(pins.first) ?? koreaCenter)
        : (_user ?? koreaCenter);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: pins.isNotEmpty ? 14 : (_user == null ? 6.5 : 14),
            initialCameraFit: points.length >= 2
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.fromLTRB(48, 150, 48, 120),
                    maxZoom: 15,
                  )
                : null,
            maxZoom: 18,
            minZoom: 3,
            onTap: (_, point) {
              setState(() => _showResults = false);
              FocusManager.instance.primaryFocus?.unfocus();
              _openAdd(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: mapTileUrl,
              fallbackUrl: mapFallbackTileUrl,
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.secretbase.app',
              errorTileCallback: (_, _, _) {
                if (mounted && !_tileError) setState(() => _tileError = true);
              },
            ),
            MarkerLayer(
              markers: [
                if (_user != null)
                  Marker(
                    point: _user!,
                    width: 28,
                    height: 28,
                    child: const _UserDot(),
                  ),
                for (final pin in pins)
                  if (_pinPoint(pin) != null)
                    Marker(
                      point: _pinPoint(pin)!,
                      width: 56,
                      height: 56,
                      child: _PinMarker(
                        key: Key('map-pin-${pin['id']}'),
                        label:
                            '${pin['place_name'] ?? '장소'}, ${pinStatus(pin) == 'visited' ? '다녀온 곳' : '가고 싶은 곳'}',
                        emoji: mapCategoryEmojis[pin['category']] ?? '📍',
                        visited: pinStatus(pin) == 'visited',
                        active:
                            _selectedId != null &&
                            '$_selectedId' == '${pin['id']}',
                        onTap: () => _openPin(pin),
                      ),
                    ),
                if (_temp != null)
                  Marker(
                    point: _temp!,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: V2Colors.rose600,
                      size: 44,
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  '© OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: V2Space.x4,
          right: V2Space.x4,
          top: V2Space.x3,
          child: _overlay(p),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Center(child: _listHandle(pins.length)),
        ),
      ],
    );
  }

  Widget _overlay(V2Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Material(
                color: p.surface,
                elevation: 3,
                shadowColor: V2Colors.scrim,
                borderRadius: BorderRadius.circular(V2Radius.button),
                child: TextField(
                  key: const Key('map_search'),
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: _search,
                  style: V2Text.body.copyWith(color: p.ink),
                  decoration: InputDecoration(
                    hintText: '장소나 주소를 검색해요',
                    prefixIcon: const Icon(V2Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : V2IconButton(
                            icon: V2Icons.close,
                            tooltip: '검색어 지우기',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _showResults = false;
                                _results = [];
                              });
                            },
                          ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: V2Space.x2),
            Material(
              color: p.surface,
              elevation: 3,
              shadowColor: V2Colors.scrim,
              shape: const CircleBorder(),
              child: _locating
                  ? const SizedBox(
                      width: V2Space.tap,
                      height: V2Space.tap,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : V2IconButton(
                      key: const Key('map_locate'),
                      icon: V2Icons.myLocation,
                      tooltip: '내 위치로 이동',
                      onPressed: _locate,
                    ),
            ),
          ],
        ),
        if (_showResults) ...[
          const SizedBox(height: V2Space.x2),
          _resultsPanel(p),
        ] else ...[
          const SizedBox(height: V2Space.x2),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                V2Chip(
                  key: const Key('map_chip_all'),
                  label: '전체 ${_pins.length}',
                  selected: _status == 'all',
                  onTap: () => setState(() => _status = 'all'),
                ),
                const SizedBox(width: V2Space.x2),
                V2Chip(
                  key: const Key('map_chip_visited'),
                  label: '다녀온 곳 ${_count('visited')}',
                  selected: _status == 'visited',
                  onTap: () => setState(() => _status = 'visited'),
                ),
                const SizedBox(width: V2Space.x2),
                V2Chip(
                  key: const Key('map_chip_wishlist'),
                  label: '가고 싶은 곳 ${_count('wishlist')}',
                  selected: _status == 'wishlist',
                  onTap: () => setState(() => _status = 'wishlist'),
                ),
                const SizedBox(width: V2Space.x2),
                V2Chip(
                  key: const Key('map_chip_category'),
                  label: _category == null
                      ? '분류'
                      : '${mapCategoryEmojis[_category]} $_category',
                  selected: _category != null,
                  icon: V2Icons.filter,
                  onTap: _pickCategory,
                ),
              ],
            ),
          ),
        ],
        if (_locationNotice != null) ...[
          const SizedBox(height: V2Space.x2),
          V2Banner(
            tone: V2BannerTone.warn,
            message: _locationNotice!,
            actionLabel: '설정 열기',
            onAction: () => Geolocator.openAppSettings(),
            onDismiss: () => setState(() => _locationNotice = null),
          ),
        ],
        if (_tileError) ...[
          const SizedBox(height: V2Space.x2),
          V2Banner(
            tone: V2BannerTone.warn,
            message: '지도 이미지를 모두 불러오지 못했어요',
            actionLabel: '다시 시도',
            onAction: () => _load(),
            onDismiss: () => setState(() => _tileError = false),
          ),
        ],
        if (_error != null && _pins.isNotEmpty) ...[
          const SizedBox(height: V2Space.x2),
          V2Banner(
            tone: V2BannerTone.warn,
            message: '최신 장소를 불러오지 못했어요',
            actionLabel: '다시 시도',
            onAction: () => _load(),
          ),
        ],
        if (_pins.isEmpty && !_showResults) ...[
          const SizedBox(height: V2Space.x2),
          const V2Banner(
            key: Key('map_empty_hint'),
            tone: V2BannerTone.info,
            title: '아직 저장한 장소가 없어요',
            message: '검색하거나 지도를 눌러 첫 장소를 남겨 보세요.',
          ),
        ],
      ],
    );
  }

  Widget _resultsPanel(V2Palette p) {
    final Widget content;
    if (_searching) {
      content = const Padding(
        padding: EdgeInsets.all(V2Space.x4),
        child: V2Shimmer(child: V2SkeletonLine(width: 220)),
      );
    } else if (_searchFailed) {
      content = V2Banner(
        tone: V2BannerTone.err,
        message: '검색하지 못했어요. 연결을 확인해 주세요.',
        actionLabel: '다시 시도',
        onAction: () => _search(_searchCtrl.text),
      );
    } else if (_results.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(V2Space.x4),
        child: Text(
          '검색 결과가 없어요. 지도를 눌러 직접 고를 수도 있어요.',
          style: V2Text.cap.copyWith(color: p.sub),
        ),
      );
    } else {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .4,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final r in _results.take(8))
              V2ListTile(
                icon: V2Icons.location,
                tone: V2Tone.sage,
                title: '${r['name'] ?? ''}',
                subtitle: [
                  if ('${r['address'] ?? ''}'.trim().isNotEmpty)
                    '${r['address']}',
                  ?formatDistanceMeters(r['distanceMeters']),
                ].join(' · '),
                showChevron: false,
                onTap: () => _pickResult(r),
              ),
          ],
        ),
      );
    }
    return Material(
      color: p.surface,
      elevation: 3,
      shadowColor: V2Colors.scrim,
      borderRadius: BorderRadius.circular(V2Radius.card),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _listHandle(int count) {
    final p = V2Palette.of(context);
    return Semantics(
      button: true,
      label: '장소 목록 $count곳 보기',
      onTap: _showList,
      child: ExcludeSemantics(
        child: Material(
          color: p.surface,
          elevation: 4,
          shadowColor: V2Colors.scrim,
          shape: const StadiumBorder(),
          child: InkWell(
            key: const Key('map_list_handle'),
            customBorder: const StadiumBorder(),
            onTap: _showList,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: V2Space.tap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: V2Space.x5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_rounded, color: p.ink, size: 20),
                    const SizedBox(width: V2Space.x2),
                    Text(
                      '장소 $count곳 보기',
                      style: V2Text.bodyStrong.copyWith(color: p.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  final String label;
  final String emoji;
  final bool visited;
  final bool active;
  final VoidCallback onTap;

  const _PinMarker({
    super.key,
    required this.label,
    required this.emoji,
    required this.visited,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = V2ToneColors.of(visited ? V2Tone.ok : V2Tone.lilac);
    final size = active ? 52.0 : 42.0;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: V2Motion.of(context, V2Motion.fast),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.soft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? V2Colors.rose600 : tone.base,
                  width: active ? 3 : 2,
                ),
                boxShadow: V2Shadow.level1,
              ),
              child: Text(emoji, style: TextStyle(fontSize: active ? 24 : 20)),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '내 위치',
      child: Container(
        decoration: BoxDecoration(
          color: V2Colors.skyText,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: V2Shadow.level1,
        ),
      ),
    );
  }
}
