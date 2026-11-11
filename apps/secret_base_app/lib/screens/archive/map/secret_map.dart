import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

/// 비밀지도 base map (2.1): MapLibre with the free OpenFreeMap "Positron"
/// style (no key, no usage limit, commercial use allowed). Labels are
/// rewritten to Korean names, pins are ordinary Flutter widgets.
///
/// Widget tests can't run the native/JS map, so [debugFake] swaps in a plain
/// stack that still builds every marker (keys and taps keep working).
class SecretMap extends StatefulWidget {
  const SecretMap({
    super.key,
    required this.center,
    required this.zoom,
    this.fit = const [],
    this.fitPadding = const EdgeInsets.all(48),
    this.fitMaxZoom = 15,
    this.markers = const [],
    this.interactive = true,
    this.onTap,
    this.onReady,
    this.showAttribution = true,
  });

  final LatLng center;
  final double zoom;

  /// When there are 2+ points the camera fits them once the map is ready.
  final List<LatLng> fit;
  final EdgeInsets fitPadding;
  final double fitMaxZoom;
  final List<SecretMapMarker> markers;
  final bool interactive;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<SecretMapController>? onReady;
  final bool showAttribution;

  static const styleUrl = 'https://tiles.openfreemap.org/styles/positron';
  static const attribution =
      'OpenFreeMap © OpenMapTiles · Data from OpenStreetMap';

  /// Tests set this to true (no platform map available).
  static bool debugFake = false;

  static Future<String>? _style;

  /// The Positron style with every place label showing the Korean name
  /// (`name:ko`, then the local `name`) instead of "Latin + local".
  /// Falls back to the plain style URL if the JSON can't be fetched.
  static Future<String> koreanStyle({http.Client? client}) =>
      _style ??= _loadStyle(client);

  static Future<String> _loadStyle(http.Client? client) async {
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse(styleUrl));
      if (res.statusCode != 200) return styleUrl;
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      return jsonEncode(koreanizeStyle(Map<String, dynamic>.from(json)));
    } catch (_) {
      _style = null; // try again next time
      return styleUrl;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Rewrites `text-field` of symbol layers that show place names.
  @visibleForTesting
  static Map<String, dynamic> koreanizeStyle(Map<String, dynamic> style) {
    const korean = [
      'coalesce',
      ['get', 'name:ko'],
      ['get', 'name'],
    ];
    final layers = style['layers'];
    if (layers is List) {
      for (final layer in layers.whereType<Map>()) {
        final layout = layer['layout'];
        if (layout is! Map) continue;
        final field = layout['text-field'];
        if (field == null) continue;
        final text = jsonEncode(field);
        if (text.contains('name')) layout['text-field'] = korean;
      }
    }
    return style;
  }

  @override
  State<SecretMap> createState() => _SecretMapState();
}

/// A widget pinned to a coordinate.
class SecretMapMarker {
  const SecretMapMarker({
    required this.point,
    required this.child,
    this.size = const Size(48, 48),
  });

  final LatLng point;
  final Size size;
  final Widget child;
}

/// The bits of the camera the screen needs.
class SecretMapController {
  SecretMapController._(this._map);

  final ml.MapController? _map;

  LatLng? get center {
    final c = _map?.camera?.center;
    return c == null ? null : LatLng(c.lat, c.lon);
  }

  Future<void> move(LatLng point, {double zoom = 15}) async {
    final map = _map;
    if (map == null) return;
    await map.animateCamera(
      center: ml.Geographic(lon: point.longitude, lat: point.latitude),
      zoom: zoom,
      nativeDuration: const Duration(milliseconds: 600),
    );
  }
}

class _SecretMapState extends State<SecretMap> {
  String? _style;

  @override
  void initState() {
    super.initState();
    if (!SecretMap.debugFake) {
      SecretMap.koreanStyle().then((s) {
        if (mounted) setState(() => _style = s);
      });
    }
  }

  ml.Geographic _geo(LatLng p) =>
      ml.Geographic(lon: p.longitude, lat: p.latitude);

  void _ready(ml.MapController map) {
    widget.onReady?.call(SecretMapController._(map));
  }

  /// Center and zoom that show every [SecretMap.fit] point inside [size]
  /// minus padding (web mercator, 512px tiles as MapLibre uses).
  ({LatLng center, double zoom}) _fitCamera(Size size) {
    final pts = widget.fit;
    if (pts.length < 2 || size.isEmpty) {
      return (center: widget.center, zoom: widget.zoom);
    }
    double y(double lat) {
      final r = lat * math.pi / 180;
      return math.log(math.tan(math.pi / 4 + r / 2));
    }

    var west = pts.first.longitude, east = west;
    var south = pts.first.latitude, north = south;
    for (final p in pts) {
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
    }
    final pad = widget.fitPadding;
    final w = math.max(40.0, size.width - pad.horizontal);
    final h = math.max(40.0, size.height - pad.vertical);
    final lonSpan = math.max(east - west, 1e-6);
    final ySpan = math.max(y(north) - y(south), 1e-6);
    const tile = 512.0;
    final zx = math.log(w * 360 / (tile * lonSpan)) / math.ln2;
    final zy = math.log(h * 2 * math.pi / (tile * ySpan)) / math.ln2;
    final zoom = math.min(math.min(zx, zy), widget.fitMaxZoom);
    final midY = (y(north) + y(south)) / 2;
    final midLat =
        (2 * math.atan(math.exp(midY)) - math.pi / 2) * 180 / math.pi;
    return (center: LatLng(midLat, (west + east) / 2), zoom: zoom);
  }

  @override
  Widget build(BuildContext context) {
    if (SecretMap.debugFake) return _fake();
    final style = _style;
    if (style == null) {
      return const ColoredBox(color: Color(0xFFF2F3F0));
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cam = _fitCamera(box.biggest);
        return _map(style, cam.center, cam.zoom);
      },
    );
  }

  Widget _map(String style, LatLng center, double zoom) {
    return Stack(
      children: [
        ml.MapLibreMap(
          options: ml.MapOptions(
            initStyle: style,
            initCenter: _geo(center),
            initZoom: zoom,
            minZoom: 3,
            maxZoom: 18,
            gestures: widget.interactive
                ? const ml.MapGestures.all(rotate: false, pitch: false)
                : const ml.MapGestures.none(),
          ),
          onMapCreated: _ready,
          onEvent: (event) {
            if (event is ml.MapEventClick) {
              widget.onTap?.call(LatLng(event.point.lat, event.point.lon));
            }
          },
          children: [
            ml.WidgetLayer(
              allowInteraction: true,
              markers: [
                for (final m in widget.markers)
                  ml.Marker(point: _geo(m.point), size: m.size, child: m.child),
              ],
            ),
          ],
        ),
        if (widget.showAttribution)
          const Positioned(right: 6, bottom: 4, child: _Attribution()),
      ],
    );
  }

  Widget _fake() {
    return ColoredBox(
      color: const Color(0xFFF2F3F0),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap?.call(widget.center),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 120,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final m in widget.markers)
                  SizedBox(
                    width: m.size.width,
                    height: m.size.height,
                    child: m.child,
                  ),
              ],
            ),
          ),
          if (widget.showAttribution)
            const Positioned(right: 6, bottom: 4, child: _Attribution()),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        SecretMap.attribution,
        style: TextStyle(fontSize: 9.5, color: Color(0xFF555555)),
      ),
    );
  }
}
