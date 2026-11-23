// Combined typed-routes parity check against a real host.
//
// Every typed family — commands and events — is enabled on each attachment,
// so one run exercises the attach-time probe, all six pre-initialization
// route selections and the generated delivery of every event family
// together: the configuration the example's home page map uses.
//
// Run from `example` on each platform (see TYPED_ROUTES_VALIDATION.md):
//   flutter test integration_test/typed_routes_parity_test.dart -d <android-device>
//   flutter test integration_test/typed_routes_parity_test.dart -d <ios-simulator>
//   flutter test integration_test/typed_routes_parity_test.dart -d macos
//
// Default run (no host setup needed): attachment without uncertain-route
// aborts, readiness through the typed lifecycle route, typed camera commands,
// region-event payload parity, two-map isolation, disposal and recreation.
// Parity is measured two ways: the typed region event against the typed
// camera queries (host correctness), and the typed routes against a legacy
// attachment at the same position (typed/legacy parity). The absolute bounds
// check runs on Android only: the Apple framework's `toBoundingBox()`
// reports a zero-area, lat/lon-swapped box on both routes (pre-existing,
// tracked in TYPED_ROUTES_VALIDATION.md), so Apple asserts parity with the
// legacy plane and records the values.
//
// Opt-in steps:
//   --dart-define=TYPED_ROUTES_LOCATION=true
//       user-location fixes through the typed location route (needs location
//       permission granted and a fix: `adb install -g` / `emu geo fix` on
//       Android, an allow decision on Apple). Records inter-fix deltas for
//       the rate check; asserts the fix parity against `myLocation()`.
//   --dart-define=TYPED_ROUTES_GESTURES=true
//       synthetic map taps through the typed interaction route. Only the
//       Android harness forwards synthetic pointer events to platform views;
//       Apple maps take touches from UIKit/AppKit directly.
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _locationStep = bool.fromEnvironment('TYPED_ROUTES_LOCATION');
const _gestureStep = bool.fromEnvironment('TYPED_ROUTES_GESTURES');

final _target = GeoPoint(latitude: 48.8566, longitude: 2.3522);
final _other = GeoPoint(latitude: 51.5072, longitude: -0.1276);

/// Every typed route the plugin can negotiate, enabled together.
const _allTypedRoutes = OSMOption(
  // Command families: probe once, freeze per family.
  useTypedCameraRoute: true,
  useTypedMarkers: true,
  useTypedLayers: true,
  useTypedShapes: true,
  useTypedRoads: true,
  useTypedLocation: true,
  useTypedLocationUpdates: true,
  useTypedTracking: true,
  useTypedLocationIcons: true,
  // Event families: additionally negotiate the delivery route before
  // initialization; exactly one route delivers per family.
  useTypedLifecycleEvents: true,
  useTypedInteractionEvents: true,
  useTypedMarkerEvents: true,
  useTypedRoadEvents: true,
  useTypedLocationEvents: true,
  useTypedRegionEvents: true,
  zoomOption: ZoomOption(initZoom: 10, minZoomLevel: 3, maxZoomLevel: 19),
);

/// Collects the values a controller's [ValueListenable] emits.
class _Values<T> {
  final List<T> values = [];
  late final VoidCallback _listener;
  _Values(ValueListenable<T?> listenable) {
    _listener = () {
      final value = listenable.value;
      if (value != null) values.add(value);
    };
    listenable.addListener(_listener);
  }

  void dispose(ValueListenable<T?> listenable) =>
      listenable.removeListener(_listener);

  T? getLast() => values.isEmpty ? null : values.last;

  /// Waits until at least [count] values arrived.
  Future<bool> waitFor(int count, {Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (values.length < count) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }
}

bool _near(double a, double b, double tolerance) => (a - b).abs() <= tolerance;

/// Field-exact view of a [BoundingBox] for typed/legacy comparisons.
class _Box {
  const _Box(this.north, this.east, this.south, this.west);
  factory _Box.of(BoundingBox b) => _Box(b.north, b.east, b.south, b.west);
  final double north, east, south, west;

  @override
  bool operator ==(Object other) =>
      other is _Box &&
      north == other.north &&
      east == other.east &&
      south == other.south &&
      west == other.west;

  @override
  int get hashCode => Object.hash(north, east, south, west);

  @override
  String toString() => 'N:$north E:$east S:$south W:$west';
}

bool _sameRegion(Region region, GeoPoint center, BoundingBox bounds) =>
    _near(region.center.latitude, center.latitude, 1e-4) &&
    _near(region.center.longitude, center.longitude, 1e-4) &&
    _near(region.boundingBox.north, bounds.north, 1e-4) &&
    _near(region.boundingBox.south, bounds.south, 1e-4) &&
    _near(region.boundingBox.east, bounds.east, 1e-4) &&
    _near(region.boundingBox.west, bounds.west, 1e-4);

Widget _twoMaps(MapController first, MapController second,
    {void Function(bool)? onFirstReady,
    void Function(bool)? onSecondReady,
    OnLocationChanged? onFirstLocation}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: OSMFlutter(
              controller: first,
              osmOption: _allTypedRoutes,
              onMapIsReady: onFirstReady,
              onLocationChanged: onFirstLocation,
            ),
          ),
          Expanded(
            child: OSMFlutter(
              controller: second,
              osmOption: _allTypedRoutes,
              onMapIsReady: onSecondReady,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Pumps until [condition] holds or [timeout] elapses.
Future<bool> _until(bool Function() condition,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final log = StringBuffer();

  void record(String line) {
    log.writeln(line);
    debugPrint('TYPED_ROUTES: $line');
  }

  testWidgets('all typed routes together: attach, parity, isolation, '
      'disposal, recreation${_locationStep ? ', location' : ''}'
      '${_gestureStep ? ', gestures' : ''}', (tester) async {
    // ---- attachment + readiness through the typed lifecycle route ----
    var firstReady = false;
    var secondReady = false;
    final first = MapController.withPosition(initPosition: _target);
    final second = MapController.withPosition(initPosition: _other);
    final firstRegions = _Values<Region>(first.listenerRegionIsChanging);
    final secondRegions = _Values<Region>(second.listenerRegionIsChanging);

    await tester.pumpWidget(_twoMaps(
      first,
      second,
      onFirstReady: (ready) => firstReady = ready,
      onSecondReady: (ready) => secondReady = ready,
    ));
    expect(
      await _until(() => firstReady && secondReady,
          timeout: const Duration(seconds: 30)),
      isTrue,
      reason: 'both maps must report ready (route selections must not abort '
          'attachment); exceptions: ${tester.takeException()}',
    );
    expect(tester.takeException(), isNull,
        reason: 'no uncertain-route abort or handler error during attachment');
    record('both maps ready (typed lifecycle route)');

    // ---- typed camera commands ----
    await first.moveTo(GeoPoint(latitude: 48.85, longitude: 2.35), animate: false);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final center = await first.centerMap;
    final zoom = await first.getZoom();
    expect(_near(center.latitude, 48.85, 1e-4), isTrue,
        reason: 'typed moveTo must be applied: center=$center');
    expect(_near(center.longitude, 2.35, 1e-4), isTrue,
        reason: 'typed moveTo must be applied: center=$center');
    expect(zoom > 0, isTrue, reason: 'typed getZoom must report a level');
    record('typed camera: center=$center zoom=$zoom');

    // ---- region-event payload parity: typed event route vs typed queries ----
    expect(await firstRegions.waitFor(1), isTrue,
        reason: 'a camera move must deliver a region change on the typed route');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final bounds = await first.bounds;
    final lastRegion = firstRegions.getLast()!;
    expect(_near(lastRegion.center.latitude, center.latitude, 1e-4), isTrue,
        reason: 'region center must match the camera query: '
            'event=${lastRegion.center} query=$center');
    expect(_near(lastRegion.center.longitude, center.longitude, 1e-4), isTrue,
        reason: 'region center must match the camera query: '
            'event=${lastRegion.center} query=$center');
    if (defaultTargetPlatform == TargetPlatform.android) {
      expect(_sameRegion(lastRegion, center, bounds), isTrue,
          reason: 'region event must match the camera queries: '
              'event=${lastRegion.center}/${lastRegion.boundingBox} '
              'query=$center/$bounds');
    }
    record('region parity: events=${firstRegions.values.length} '
        'last=${lastRegion.center} bounds=${lastRegion.boundingBox} '
        'queryBounds=$bounds');
    final typedBox = _Box.of(lastRegion.boundingBox);
    final typedQueryBox = _Box.of(bounds);

    // ---- two-map isolation ----
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final secondBefore = secondRegions.values.length;
    final firstBefore = firstRegions.values.length;
    await first.moveTo(GeoPoint(latitude: 48.86, longitude: 2.36), animate: false);
    expect(
      await _until(() => firstRegions.values.length > firstBefore,
          timeout: const Duration(seconds: 5)),
      isTrue,
      reason: 'moving map A must deliver region events to A',
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(secondRegions.values.length, secondBefore,
        reason: 'map B must not receive map A\'s region events');
    final secondCenter = await second.centerMap;
    expect(_near(secondCenter.latitude, _other.latitude, 1e-3), isTrue,
        reason: 'map B must not have moved: $secondCenter');
    record('isolation: A events=${firstRegions.values.length - firstBefore}, '
        'B events=${secondRegions.values.length - secondBefore}');

    // ---- optional gestures (Android harness) ----
    if (_gestureStep) {
      final firstTaps = _Values<GeoPoint>(first.listenerMapSingleTapping);
      final secondTaps = _Values<GeoPoint>(second.listenerMapSingleTapping);
      final maps = find.byType(OSMFlutter);
      await tester.tapAt(tester.getCenter(maps.at(0)));
      expect(await firstTaps.waitFor(1, timeout: const Duration(seconds: 5)),
          isTrue, reason: 'a tap on map A must deliver on A\'s typed route');
      final tap = firstTaps.getLast()!;
      final tapBounds = await first.bounds;
      expect(tap.latitude < tapBounds.north && tap.latitude > tapBounds.south,
          isTrue, reason: 'tap must fall inside A: tap=$tap bounds=$tapBounds');
      expect(secondTaps.values, isEmpty, reason: 'map B must stay silent');
      await tester.tapAt(tester.getCenter(maps.at(1)));
      expect(
          await secondTaps.waitFor(1, timeout: const Duration(seconds: 5)),
          isTrue,
          reason: 'a tap on map B must deliver on B\'s typed route');
      expect(firstTaps.values.length, 1, reason: 'map A must stay silent');
      record('gestures: A tap=$tap, B taps=${secondTaps.values.length}');
    }

    // ---- optional location fixes (typed location route) ----
    if (_locationStep) {
      final arrivalMs = <int>[];
      final fixes = <UserLocation>[];
      final started = DateTime.now();
      // Rebuild with the location callback wired; arrival times let the
      // run record the host's fix spacing for the rate check.
      await tester.pumpWidget(_twoMaps(
        first,
        second,
        onFirstLocation: (fix) {
          arrivalMs.add(DateTime.now().millisecondsSinceEpoch);
          fixes.add(fix as UserLocation);
        },
      ));
      expect(
        await _until(() => fixes.length >= 3,
            timeout: const Duration(seconds: 45)),
        isTrue,
        reason: 'location fixes must flow through the typed location route',
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      final spacing = <int>[
        for (var i = 1; i < arrivalMs.length; i++)
          arrivalMs[i] - arrivalMs[i - 1],
      ];
      final fix = await first.myLocation();
      final last = fixes.last;
      expect(_near(last.latitude, fix.latitude, 1e-2), isTrue,
          reason: 'typed fix events must match myLocation(): $last vs $fix');
      expect(_near(last.longitude, fix.longitude, 1e-2), isTrue,
          reason: 'typed fix events must match myLocation(): $last vs $fix');
      record('location: ${fixes.length} fixes in '
          '${DateTime.now().difference(started).inMilliseconds}ms, '
          'spacingMs=$spacing (Android expects >=~1000, Apple every callback) '
          'fix=$fix lastEvent=$last heading=${last.angle}');
      await tester.pumpWidget(_twoMaps(first, second));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // ---- disposal: both maps removed, no late delivery, no exception ----
    firstRegions.dispose(first.listenerRegionIsChanging);
    secondRegions.dispose(second.listenerRegionIsChanging);
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull,
        reason: 'disposal must not throw (handlers unregistered cleanly)');
    record('disposal: both maps removed without exceptions');

    // ---- recreation: a fresh attachment negotiates again, and a legacy
    // attachment at the same position provides the parity baseline ----
    var thirdReady = false;
    final third = MapController.withPosition(initPosition: _target);
    final thirdRegions = _Values<Region>(third.listenerRegionIsChanging);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OSMFlutter(
          controller: third,
          osmOption: _allTypedRoutes,
          onMapIsReady: (ready) => thirdReady = ready,
        ),
      ),
    ));
    expect(await _until(() => thirdReady, timeout: const Duration(seconds: 30)),
        isTrue,
        reason: 'a recreated attachment must become ready again');
    await third.moveTo(GeoPoint(latitude: 48.85, longitude: 2.35), animate: false);
    expect(await thirdRegions.waitFor(1, timeout: const Duration(seconds: 5)),
        isTrue,
        reason: 'the recreated attachment must deliver region events');
    thirdRegions.dispose(third.listenerRegionIsChanging);
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    record('recreation: ready again, region event delivered');

    var legacyReady = false;
    final legacy = MapController.withPosition(initPosition: _target);
    final legacyRegions = _Values<Region>(legacy.listenerRegionIsChanging);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OSMFlutter(
          controller: legacy,
          osmOption: const OSMOption(
            zoomOption: ZoomOption(initZoom: 10, minZoomLevel: 3, maxZoomLevel: 19),
          ),
          onMapIsReady: (ready) => legacyReady = ready,
        ),
      ),
    ));
    expect(await _until(() => legacyReady, timeout: const Duration(seconds: 30)),
        isTrue);
    await legacy.moveTo(GeoPoint(latitude: 48.85, longitude: 2.35), animate: false);
    expect(await legacyRegions.waitFor(1, timeout: const Duration(seconds: 5)),
        isTrue,
        reason: 'the legacy baseline must deliver region events on its plane');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final legacyRegion = legacyRegions.getLast()!;
    final legacyBox = _Box.of(legacyRegion.boundingBox);
    final legacyQueryBox = _Box.of(await legacy.bounds);
    expect(legacyBox, typedBox,
        reason: 'typed and legacy region events must carry the same bounds '
            'at the same position: typed=$typedBox legacy=$legacyBox');
    expect(legacyQueryBox, typedQueryBox,
        reason: 'typed and legacy bounds queries must agree: '
            'typed=$typedQueryBox legacy=$legacyQueryBox');
    legacyRegions.dispose(legacy.listenerRegionIsChanging);
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    record('typed/legacy parity at 48.85/2.35: regionBox=$typedBox '
        'queryBox=$typedQueryBox (legacy identical)');

    debugPrint('TYPED_ROUTES_SUMMARY\n$log');
  });
}
