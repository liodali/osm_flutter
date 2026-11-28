// Tap-event probe for the typed routes: a plain app, not a test.
//
// `flutter test` cannot deliver native touches to the map platform view on
// iOS/macOS (the live test binding swallows them; see
// TYPED_ROUTES_VALIDATION.md), and Apple maps take their touches from
// UIKit/AppKit directly. On the shipped defaults and then on an explicitly
// legacy attachment, this app runs the marker, marker long-press, map and
// road tap phases, and draws/removes shapes, roads and tile layers while
// asking for labelled screenshots (roads, shapes and layers have no query
// API, so their removal is checked visually). It prints one `PROBE` line
// per step; an external injector taps the armed points and takes the
// screenshots:
//
//   flutter run -d <ios-simulator> -t lib/typed_routes_tap_probe.dart
//   python3 tool/typed_routes_tap_injector.py --udid <udid> --log <run log>
//
// On Android the integration harness injects the taps itself
// (`TYPED_ROUTES_FAMILIES=true`); this probe also works there with
// `adb shell input`.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/common/legacy_routes.dart';

Future<void> main() async {
  runApp(const ProbeApp());
}

final _target = GeoPoint(latitude: 48.8566, longitude: 2.3522);

/// Comma-separated passes to run: `typed` (the shipped defaults), `legacy`
/// (explicit opt-out) or both (default).
const _passes = String.fromEnvironment(
  'PROBE_PASSES',
  defaultValue: 'typed,legacy',
);

const _road = RoadOption(
  roadColor: Color(0xFF3355FF),
  roadWidth: 6,
  zoomInto: false,
);

void _say(String line) => debugPrint('PROBE $line');

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});

  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  MapController? _controller;
  OSMOption _option = const OSMOption(
    zoomOption: ZoomOption(initZoom: 16, minZoomLevel: 3, maxZoomLevel: 19),
  );
  Completer<bool>? _ready;
  List<GeoPoint> geoClicks = [];
  List<GeoPoint> geoLongPresses = [];
  List<GeoPoint> mapTaps = [];
  List<GeoPoint> mapLongTaps = [];
  List<RoadInfo> roadTaps = [];
  int regions = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_runAll());
  }

  MapController _attach(OSMOption option) {
    final controller = MapController.withPosition(initPosition: _target);
    controller.listenerMapSingleTapping.addListener(() {
      final value = controller.listenerMapSingleTapping.value;
      if (value != null) mapTaps.add(value);
    });
    controller.listenerMapLongTapping.addListener(() {
      final value = controller.listenerMapLongTapping.value;
      if (value != null) mapLongTaps.add(value);
    });
    controller.listenerRoadTapped.addListener(() {
      final value = controller.listenerRoadTapped.value;
      if (value != null) roadTaps.add(value);
    });
    controller.listenerRegionIsChanging.addListener(() => regions++);
    setState(() {
      _option = option;
      _controller = controller;
      _ready = Completer<bool>();
    });
    return controller;
  }

  Future<void> _detach() async {
    setState(() => _controller = null);
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  /// Prints one armed point, waits for [arrived] and reports what the map
  /// delivered meanwhile.
  Future<void> _phase(
    String pass,
    String name,
    Offset at, {
    bool longPress = false,
    required bool Function() arrived,
  }) async {
    geoClicks = [];
    geoLongPresses = [];
    mapTaps = [];
    mapLongTaps = [];
    roadTaps = [];
    final before = regions;
    _say(
      'armed: $name at (${at.dx.toStringAsFixed(1)}, '
      '${at.dy.toStringAsFixed(1)})${longPress ? ' long-press' : ''}',
    );
    final started = DateTime.now();
    while (!arrived() &&
        DateTime.now().difference(started) < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final delivered = arrived();
    String where(List<GeoPoint> points) => points.isEmpty
        ? '-'
        : '${points.last.latitude.toStringAsFixed(7)},'
              '${points.last.longitude.toStringAsFixed(7)}';
    _say(
      '$pass $name ${delivered ? 'DELIVERED' : 'not delivered'} '
      '(+${DateTime.now().difference(started).inMilliseconds}ms); '
      'markerTap=${where(geoClicks)} '
      'markerLongPress=${where(geoLongPresses)} '
      'mapTap=${where(mapTaps)} mapLongTap=${where(mapLongTaps)} '
      'roadTap=${roadTaps.isEmpty ? '-' : 'distance=${roadTaps.last.distance} '
                'routePoints=${roadTaps.last.route.length}'} '
      'regions=${regions - before}',
    );
  }

  /// Asks the injector for a labelled screenshot and lets it land.
  Future<void> _shot(String label) async {
    _say('screenshot: $label');
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  Future<void> _pass(String name, OSMOption option) async {
    final controller = _attach(option);
    final ready = await _ready!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
    if (!ready) {
      _say('$name: map never became ready');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final view = View.of(context);
    // A full-screen map: the camera center is the window center.
    final center = Offset(
      view.physicalSize.width / view.devicePixelRatio / 2,
      view.physicalSize.height / view.devicePixelRatio / 2,
    );
    await controller.moveTo(_target, animate: false);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _say('$name: ready, camera on $_target, center=$center');

    // ---- visual state: draw, remove, and screenshot each step ----
    await _shot('$name-base');

    await controller.drawCircle(
      CircleOSM(
        key: 'probe-circle',
        centerPoint: _target,
        radius: 150,
        strokeWidth: 6,
        color: const Color(0xFF00AA00),
      ),
    );
    await controller.drawRect(
      RectOSM(
        key: 'probe-rect',
        centerPoint: _target,
        distance: 260,
        strokeWidth: 4,
        color: const Color(0xFF0000CC),
      ),
    );
    await _shot('$name-shapes-drawn');
    await controller.removeAllShapes();
    await _shot('$name-shapes-removed');

    final west = GeoPoint(
      latitude: _target.latitude,
      longitude: _target.longitude - 0.01,
    );
    final east = GeoPoint(
      latitude: _target.latitude,
      longitude: _target.longitude + 0.01,
    );
    await controller.drawRoadManually([west, _target, east], _road);
    await _shot('$name-manual-drawn');
    await controller.removeLastRoad();
    await _shot('$name-manual-after-removeLast');
    await controller.clearAllRoads();
    await _shot('$name-manual-after-clear');

    RoadInfo? route;
    try {
      route = await controller
          .drawRoad(
            _target,
            GeoPoint(latitude: 48.8666, longitude: 2.3622),
            roadOption: _road,
          )
          .timeout(const Duration(seconds: 25));
      _say(
        '$name drawRoad -> ${route!.distance}km, ${route.route.length} points',
      );
    } catch (error) {
      _say('$name drawRoad failed: $error');
    }
    await _shot('$name-route-drawn');
    await controller.removeLastRoad();
    await _shot('$name-route-after-removeLast');
    if (route != null) {
      await controller.removeRoad(roadKey: route.key);
      await _shot('$name-route-after-remove-by-key');
    }
    await controller.clearAllRoads();
    await _shot('$name-route-after-clear');

    await controller.changeTileLayer(
      tileLayer: CustomTile(
        urlsServers: [TileURLs(url: 'https://tile.opentopomap.org/')],
        tileExtension: '.png',
        sourceName: 'probe-topo',
        tileSize: 256,
        minZoomLevel: 2,
        maxZoomLevel: 17,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot('$name-topo-tiles');
    await controller.changeTileLayer();
    await _shot('$name-default-tiles');

    await controller.addMarker(_target);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _phase(
      name,
      'marker-tap',
      center,
      arrived: () => geoClicks.isNotEmpty,
    );
    await _phase(
      name,
      'marker-long-press',
      center,
      longPress: true,
      arrived: () => geoLongPresses.isNotEmpty,
    );

    await controller.removeMarker(_target);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _phase(
      name,
      'map-tap',
      center,
      arrived: () => mapTaps.isNotEmpty,
    );

    await controller.drawRoadManually([
      GeoPoint(latitude: _target.latitude, longitude: _target.longitude - 0.02),
      _target,
      GeoPoint(latitude: _target.latitude, longitude: _target.longitude + 0.02),
    ], _road);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await _phase(
      name,
      'road-tap',
      center,
      arrived: () => roadTaps.isNotEmpty,
    );

    // Informational: what wins when a marker sits on a road?
    await controller.addMarker(_target);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _phase(
      name,
      'marker-on-road-tap',
      center,
      arrived: () => geoClicks.isNotEmpty || roadTaps.isNotEmpty,
    );

    await controller.clearAllRoads();
    await controller.removeMarker(_target);
    await _detach();
  }

  Future<void> _runAll() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final selected = _passes.split(',');
    if (selected.contains('typed')) {
      await _pass('typed', _option);
    }
    if (selected.contains('legacy')) {
      await _pass(
        'legacy',
        legacyOsmOption(
          zoomOption: const ZoomOption(
            initZoom: 16,
            minZoomLevel: 3,
            maxZoomLevel: 19,
          ),
        ),
      );
    }
    _say('done');
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return MaterialApp(
      home: Scaffold(
        body: OSMFlutter(
          controller: controller,
          osmOption: _option,
          onMapIsReady: (ready) {
            // The widget reports false while initializing and true once.
            if (ready) _ready?.complete(true);
          },
          onGeoPointClicked: (point) => geoClicks.add(point),
          onGeoPointLongPress: (point) => geoLongPresses.add(point),
        ),
      ),
    );
  }
}
