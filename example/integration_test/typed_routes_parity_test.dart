// Combined typed-routes parity check against a real host.
//
// Typed routes are the plugin's default, so each attachment uses plain
// default options: one run exercises the attach-time probe, all six
// pre-initialization route selections and the generated delivery of every
// event family together — the configuration every application gets and the
// example's home page map states explicitly. A guard fails fast if the
// defaults stop being the combined typed configuration. Against a host that
// predates the probe (see the older-host check in the validation doc) the
// same run proves every family falls back to the legacy plane untouched.
//
// Run from `example` on each platform (see TYPED_ROUTES_VALIDATION.md):
//   flutter test integration_test/typed_routes_parity_test.dart -d <android-device>
//   flutter test integration_test/typed_routes_parity_test.dart -d <ios-simulator>
//   flutter test integration_test/typed_routes_parity_test.dart -d macos
//
// Default run (no host setup needed): attachment without uncertain-route
// aborts, readiness, camera commands, region-event payload parity, two-map
// isolation, disposal and recreation. Parity is measured two ways: the
// region event against the camera queries (host correctness), and the
// default routes against a legacy attachment at the same position and
// viewport size (typed/legacy parity). Absolute bounds correctness is
// checked on every platform, including Apple with OSMFlutterFramework 0.9.2.
//
// Opt-in steps:
//   --dart-define=TYPED_ROUTES_LOCATION=true
//       user-location fixes through the typed location route (needs location
//       permission granted and a fix: `adb install -g` / `emu geo fix` on
//       Android, an allow decision on Apple). Records inter-fix deltas for
//       the rate check; asserts the fix parity against `myLocation()`, and
//       runs the same flow on a legacy attachment at the same time, so the
//       typed route's callback count is compared with the legacy plane over
//       one window instead of an assumed rate. Both planes must deliver at
//       least four fresh fixes after the flow starts, or the step fails: two
//       silent providers would otherwise compare as equal.
//   --dart-define=TYPED_ROUTES_GESTURES=true
//       synthetic map taps through the typed interaction route. Only the
//       Android harness forwards synthetic pointer events to platform views;
//       Apple maps take touches from UIKit/AppKit directly.
//   --dart-define=TYPED_ROUTES_FAMILIES=true
//       the command families the default run does not touch — markers,
//       layers, shapes, roads, user-location icons, and tracking when the
//       location step runs too — plus the marker, marker long-press, map and
//       user-location icons, and tracking when the location step runs too,
//       on one full-screen map. The negotiated route of every family is
//       recorded for every attachment (see the validation doc), so "typed"
//       is an observation on each host, not an inference.
//       Tap events (marker, marker long-press, map, road) are not part of
//       this harness: Apple maps take their touches from UIKit/AppKit and
//       the test binding cannot deliver them, and on Android a
//       Flutter-synthesized tap reaches the map but not the engine's marker
//       click confirmation. They are covered with real touches by the
//       plain-app probe `lib/typed_routes_tap_probe.dart` driven by
//       `tool/typed_routes_tap_injector.py`.
//
// Which route each family took is verified, not assumed: the run first
// classifies the host with two signals that the routing decision cannot
// influence (the legacy-channel capability probe and the presence of a
// generated channel handler on the first view). A current host must then
// hold a generated client for every family on every default attachment, and
// an older host must hold none; a silent legacy fallback on a current host
// fails the run.
//
// The platform interface's test-only route getters and the controller's
// platform field are read here on purpose: this harness is the place that
// observes which route each family negotiated.
// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as services;
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_roads_client.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _locationStep = bool.fromEnvironment('TYPED_ROUTES_LOCATION');
const _gestureStep = bool.fromEnvironment('TYPED_ROUTES_GESTURES');
const _familiesStep = bool.fromEnvironment('TYPED_ROUTES_FAMILIES');

final _target = GeoPoint(latitude: 48.8566, longitude: 2.3522);
final _other = GeoPoint(latitude: 51.5072, longitude: -0.1276);

/// The shipped configuration: typed routes are the default, so an option
/// without route flags negotiates every typed family the host advertises.
const _defaultRoutes = OSMOption(
  zoomOption: ZoomOption(initZoom: 10, minZoomLevel: 3, maxZoomLevel: 19),
);

/// Explicit opt-out for the parity baselines: every family stays on the
/// legacy method channel regardless of what the host advertises.
const _legacyRoutes = OSMOption(
  useTypedCameraRoute: false,
  useTypedMarkers: false,
  useTypedLayers: false,
  useTypedShapes: false,
  useTypedRoads: false,
  useTypedLocation: false,
  useTypedLocationUpdates: false,
  useTypedTracking: false,
  useTypedLocationIcons: false,
  useTypedLifecycleEvents: false,
  useTypedInteractionEvents: false,
  useTypedMarkerEvents: false,
  useTypedRoadEvents: false,
  useTypedLocationEvents: false,
  useTypedRegionEvents: false,
  zoomOption: ZoomOption(initZoom: 10, minZoomLevel: 3, maxZoomLevel: 19),
);

/// Fails fast if a typed family stops being the default, so this harness
/// keeps validating the combined configuration applications actually get.
void _expectTypedDefaults() {
  const option = OSMOption();
  final typedDefaults = <String, bool>{
    'useTypedCameraRoute': option.useTypedCameraRoute,
    'useTypedMarkers': option.useTypedMarkers,
    'useTypedLayers': option.useTypedLayers,
    'useTypedShapes': option.useTypedShapes,
    'useTypedRoads': option.useTypedRoads,
    'useTypedLocation': option.useTypedLocation,
    'useTypedLocationUpdates': option.useTypedLocationUpdates,
    'useTypedTracking': option.useTypedTracking,
    'useTypedLocationIcons': option.useTypedLocationIcons,
    'useTypedLifecycleEvents': option.useTypedLifecycleEvents,
    'useTypedInteractionEvents': option.useTypedInteractionEvents,
    'useTypedMarkerEvents': option.useTypedMarkerEvents,
    'useTypedRoadEvents': option.useTypedRoadEvents,
    'useTypedLocationEvents': option.useTypedLocationEvents,
    'useTypedRegionEvents': option.useTypedRegionEvents,
  };
  expect(
    typedDefaults.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key),
    isEmpty,
    reason:
        'every typed route must be the default; a deliberate change '
        'needs a conscious update of this harness and the validation doc',
  );
}

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
  Future<bool> waitFor(
    int count, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (values.length < count) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }
}

bool _near(double a, double b, double tolerance) => (a - b).abs() <= tolerance;

/// Typed families, in controller attach order.
const _families = <String>[
  'camera',
  'markers',
  'layers',
  'shapes',
  'roads',
  'location',
  'updates',
  'tracking',
  'icons',
  'lifecycle',
  'interaction',
  'markerEvents',
  'roadEvents',
  'locationEvents',
  'regionEvents',
];

/// The families whose generated client is active for [viewId], read through
/// the platform interface's route getters. Empty on a host that advertised
/// nothing (older host) or for an attachment that opted out.
List<String> _typedFamilies(int viewId) {
  final platform = MobileOSMController.osmPlatform;
  if (platform is! MethodChannelOSM) return const [];
  return [
    if (platform.cameraClientFor(viewId) != null) 'camera',
    if (platform.markersClientFor(viewId) != null) 'markers',
    if (platform.layersClientFor(viewId) != null) 'layers',
    if (platform.shapesClientFor(viewId) != null) 'shapes',
    if (platform.roadsClientFor(viewId) != null) 'roads',
    if (platform.locationClientFor(viewId) != null) 'location',
    if (platform.locationUpdatesClientFor(viewId) != null) 'updates',
    if (platform.trackingClientFor(viewId) != null) 'tracking',
    if (platform.userLocationIconsClientFor(viewId) != null) 'icons',
    if (platform.lifecycleEventsClientFor(viewId) != null) 'lifecycle',
    if (platform.interactionEventsClientFor(viewId) != null) 'interaction',
    if (platform.markerEventsClientFor(viewId) != null) 'markerEvents',
    if (platform.roadEventsClientFor(viewId) != null) 'roadEvents',
    if (platform.locationEventsClientFor(viewId) != null) 'locationEvents',
    if (platform.regionEventsClientFor(viewId) != null) 'regionEvents',
  ];
}

/// Ids of the attachments that currently hold typed routes. Disposal drops
/// a map's generated clients, so this is exactly the set of live typed
/// attachments; view ids come from a registry other widgets can also draw
/// from, so they are discovered, never counted.
List<int> _liveTypedIds({int limit = 64}) => [
  for (var id = 0; id < limit; id++)
    if (_typedFamilies(id).isNotEmpty) id,
];

/// The capability every family needs from a current host.
const _familyCapabilities = <String>[
  kCameraCapability,
  kMarkersCapability,
  kLayersCapability,
  kShapesCapability,
  kRoadsCapability,
  kLocationCapability,
  kLocationUpdatesCapability,
  kTrackingCapability,
  kLocationIconsCapability,
  kLifecycleEventsCapability,
  kInteractionEventsCapability,
  kMarkerEventsCapability,
  kRoadEventsCapability,
  kLocationEventsCapability,
  kRegionEventsCapability,
];

/// What the host says about itself, asked outside the routing decision so a
/// silent legacy fallback can never pass for an older host.
///
/// In a fresh test app the two maps are the first platform views created, so
/// both signals address view 0:
///
/// - the legacy-channel capability probe (`map#bootstrap#protocol`): a
///   current host answers its capability list, an older one `notImplemented`;
/// - whether a generated channel handler exists: `clearRoads` with a dummy
///   session is rejected with `stale_session` by a current host before any
///   mutation, and has no handler on an older one.
///
/// The two must agree. A current host whose routes silently fell back to
/// legacy (a probe timeout, a dropped reply) still reports both signals, so
/// the generated-client assertions cannot be satisfied by that fallback.
Future<({bool currentHost, List<String> capabilities})> _classifyHost() async {
  const viewId = 0;
  const channelName = 'plugins.dali.hamza/osmview_$viewId';
  var probeAnswered = false;
  var capabilities = const <String>[];
  try {
    final reply = await const services.MethodChannel(channelName)
        .invokeMethod<Object>('map#bootstrap#protocol')
        .timeout(const Duration(seconds: 10));
    final parsed = NativeProtocolBootstrap.parse(reply);
    if (parsed is NativeProtocolSupported) {
      probeAnswered = true;
      capabilities = parsed.bootstrap.capabilities;
    } else {
      fail(
        'view $viewId answered the capability probe with a malformed '
        'payload: $parsed',
      );
    }
  } on services.MissingPluginException {
    probeAnswered = false; // Not implemented: an older host.
  } on services.PlatformException catch (error) {
    if (error.code != 'not_implemented' && error.code != 'notImplemented') {
      fail(
        'view $viewId failed the capability probe: '
        '${error.code} ${error.message}',
      );
    }
    probeAnswered = false;
  } on TimeoutException {
    fail('view $viewId did not answer the capability probe within 10 s');
  }

  final bool generatedHandlerRegistered;
  try {
    await PigeonRoadsClient(
      viewId: viewId,
      bootstrap: const NativeProtocolBootstrap(
        revision: kNativeProtocolRevision,
        schemaId: kNativeCameraSchemaId,
        capabilities: [],
        sessionToken: 'route-verification-probe',
        generation: -1,
      ),
    ).clearRoads();
    fail('a dummy session must be rejected before any road is touched');
  } on StaleMapSessionException {
    // The host answered `stale_session`: the generated handler exists.
    generatedHandlerRegistered = true;
  } on services.PlatformException catch (error) {
    // The generated codec reports a missing handler as `channel-error`.
    if (error.code != 'channel-error') {
      fail(
        'unexpected answer from the generated roads API: '
        '${error.code} ${error.message}',
      );
    }
    generatedHandlerRegistered = false;
  }
  expect(
    generatedHandlerRegistered,
    probeAnswered,
    reason:
        'the host signals disagree (capability probe: $probeAnswered, '
        'generated handler: $generatedHandlerRegistered); the run cannot '
        'tell a current host from an older one',
  );
  return (currentHost: probeAnswered, capabilities: capabilities);
}

/// A default attachment holds a generated client for every family on a
/// current host, and none on an older host. Anything else is a silent
/// fallback (or a leak) and fails.
void _expectDefaultRoutes(
  List<String> routes,
  String who, {
  required bool currentHost,
}) {
  expect(
    routes,
    currentHost ? _families : const <String>[],
    reason: currentHost
        ? '$who must hold a generated client for every family on a current '
              'host; anything fewer is a silent legacy fallback: $routes'
        : '$who must stay fully legacy on an older host: $routes',
  );
}

/// The command families the default run leaves untouched, and the marker,
/// map and road tap events, on one full-screen default attachment.
Future<void> _runFamilies(
  WidgetTester tester, {
  required void Function(String) record,
  required bool currentHost,
}) async {
  final geoClicks = <GeoPoint>[];
  final geoLongPresses = <GeoPoint>[];
  final locations = <UserLocation>[];
  var ready = false;
  final controller = MapController.withPosition(initPosition: _target);
  const iconBlue = Color(0xFF2196F3);
  const iconBlack = Color(0xFF000000);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OSMFlutter(
          controller: controller,
          // The user-location icons exercise the icon family at initialization.
          osmOption: OSMOption(
            zoomOption: const ZoomOption(
              initZoom: 16,
              minZoomLevel: 3,
              maxZoomLevel: 19,
            ),
            userLocationMarker: UserLocationMaker(
              personMarker: const MarkerIcon(
                icon: SizedBox(
                  width: 28,
                  height: 28,
                  child: ColoredBox(color: iconBlue),
                ),
              ),
              directionArrowMarker: const MarkerIcon(
                icon: SizedBox(
                  width: 20,
                  height: 20,
                  child: ColoredBox(color: iconBlack),
                ),
              ),
            ),
          ),
          onMapIsReady: (value) => ready = value,
          onGeoPointClicked: geoClicks.add,
          onGeoPointLongPress: geoLongPresses.add,
          onLocationChanged: (fix) => locations.add(fix as UserLocation),
        ),
      ),
    ),
  );
  expect(
    await _until(() => ready, timeout: const Duration(seconds: 30)),
    isTrue,
    reason: 'the families map must become ready',
  );
  await tester.pumpAndSettle();
  // A current host is recognized by its generated clients (and the map is
  // then the only live typed attachment, the earlier maps being disposed);
  // an older host holds none, so there is nothing to discover and nothing
  // to hold.
  final live = _liveTypedIds();
  expect(
    live,
    currentHost ? hasLength(1) : isEmpty,
    reason: currentHost
        ? 'the families map must be the only live typed attachment: $live'
        : 'an older host must keep the families map fully legacy',
  );
  final viewId = currentHost ? live.single : -1;
  final routes = _typedFamilies(viewId);
  record(
    'families: map ready${currentHost ? ' (view $viewId)' : ''}, '
    'typed=$routes',
  );
  _expectDefaultRoutes(routes, 'the families map', currentHost: currentHost);

  // ---- markers: the public query proves what the commands applied ----
  final second = GeoPoint(
    latitude: _target.latitude + 0.001,
    longitude: _target.longitude,
  );
  final moved = GeoPoint(
    latitude: _target.latitude + 0.002,
    longitude: _target.longitude,
  );
  Future<bool> has(GeoPoint p) async =>
      (await controller.osmBaseController.geoPoints()).any(
        (m) =>
            _near(m.latitude, p.latitude, 1e-9) &&
            _near(m.longitude, p.longitude, 1e-9),
      );
  await controller.addMarker(_target);
  await controller.addMarker(second);
  expect(
    await has(_target) && await has(second),
    isTrue,
    reason: 'addMarker must register both markers',
  );
  await controller.osmBaseController.changeMarker(
    oldLocation: second,
    newLocation: moved,
  );
  expect(
    await has(moved) && !(await has(second)),
    isTrue,
    reason: 'changeMarker must move the marker',
  );
  await controller.setStaticPosition(
    [
      GeoPoint(
        latitude: _target.latitude - 0.001,
        longitude: _target.longitude,
      ),
    ],
    'families-static',
  );
  await controller.removeMarkers([_target]);
  expect(
    !(await has(_target)),
    isTrue,
    reason: 'removeMarkers must remove the marker',
  );
  record(
    'markers: add/change/static group/remove ok, '
    'geoPoints=${await controller.osmBaseController.geoPoints()}',
  );

  // ---- layers ----
  await controller.changeTileLayer(
    tileLayer: CustomTile(
      urlsServers: [TileURLs(url: 'https://tile.openstreetmap.org/')],
      tileExtension: '.png',
      sourceName: 'families-check',
      tileSize: 256,
      minZoomLevel: 2,
      maxZoomLevel: 19,
    ),
  );
  await controller.changeTileLayer();
  record('layers: changeTileLayer custom -> default ok');

  // ---- shapes ----
  const green = Color(0xFF33AA33);
  const blue = Color(0xFF3333AA);
  await controller.drawCircle(
    CircleOSM(
      key: 'families-c1',
      centerPoint: _target,
      radius: 400,
      strokeWidth: 4,
      color: green,
    ),
  );
  await controller.drawRect(
    RectOSM(
      key: 'families-r1',
      centerPoint: _target,
      distance: 900,
      strokeWidth: 3,
      color: blue,
    ),
  );
  await controller.removeCircle('families-c1');
  await controller.removeRect('families-r1');
  await controller.drawCircle(
    CircleOSM(
      key: 'families-c2',
      centerPoint: _target,
      radius: 250,
      strokeWidth: 2,
      color: green,
    ),
  );
  await controller.removeAllShapes();
  record('shapes: circle/rect draw, remove, removeAllShapes ok');

  // ---- roads ----
  const roadColor = Color(0xFF3355FF);
  const roadOption = RoadOption(roadColor: roadColor, roadWidth: 6);
  final west = GeoPoint(
    latitude: _target.latitude,
    longitude: _target.longitude - 0.02,
  );
  final east = GeoPoint(
    latitude: _target.latitude,
    longitude: _target.longitude + 0.02,
  );
  await controller.drawRoadManually([west, _target, east], roadOption);
  await controller.removeLastRoad();
  await controller.drawRoadManually([west, _target, east], roadOption);
  await controller.clearAllRoads();
  double? routeKm;
  try {
    final route = await controller
        .drawRoad(
          GeoPoint(latitude: 48.8566, longitude: 2.3522),
          GeoPoint(latitude: 48.8666, longitude: 2.3622),
          roadOption: roadOption,
        )
        .timeout(const Duration(seconds: 25));
    routeKm = route.distance;
    await controller.removeLastRoad();
  } catch (error) {
    // Route fetching is a network call outside the typed routes; a failed
    // fetch is recorded, not counted against them.
    record('roads: drawRoad (network) skipped: $error');
  }
  record(
    'roads: manual draw/removeLast/clearAll ok'
    '${routeKm == null ? '' : ', drawRoad ${routeKm}km'}',
  );

  // ---- tracking (needs the location step's permission and fix) ----
  if (_locationStep) {
    locations.clear();
    await controller.enableTracking(enableStopFollow: false);
    expect(
      await _until(
        () => locations.isNotEmpty,
        timeout: const Duration(seconds: 30),
      ),
      isTrue,
      reason: 'enableTracking must deliver fixes',
    );
    await controller.disabledTracking();
    record(
      'tracking: enableTracking delivered ${locations.length} fix(es), '
      'disabledTracking ok',
    );
  }

  // Tap events need real touches: see lib/typed_routes_tap_probe.dart.
  record('taps: covered by lib/typed_routes_tap_probe.dart (real touches)');

  await tester.pumpWidget(const SizedBox.shrink());
  await Future<void>.delayed(const Duration(milliseconds: 800));
  expect(
    tester.takeException(),
    isNull,
    reason: 'removing the families map must not throw',
  );
  record('families: map removed without exceptions');
}

/// Inter-arrival deltas in milliseconds.
List<int> _spacing(List<int> arrivalMs) => [
  for (var i = 1; i < arrivalMs.length; i++) arrivalMs[i] - arrivalMs[i - 1],
];

/// Matcher for a callback count equal to [reference] up to one cadence of
/// start-up skew (two callbacks, plus one per ten): the typed and legacy
/// routes share one host rate state, so a wider gap means one of them
/// dropped or duplicated callbacks.
Matcher _sameCount(int reference) => predicate<int>(
  (value) => (value - reference).abs() <= 2 + reference ~/ 10,
  'within start-up skew of $reference',
);

Widget _locationMaps(
  MapController first,
  MapController second,
  MapController legacy, {
  OnLocationChanged? onFirstLocation,
  OnLocationChanged? onLegacyLocation,
  void Function(bool)? onLegacyReady,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: OSMFlutter(
              controller: first,
              osmOption: _defaultRoutes,
              onLocationChanged: onFirstLocation,
            ),
          ),
          Expanded(
            child: OSMFlutter(controller: second, osmOption: _defaultRoutes),
          ),
          Expanded(
            child: OSMFlutter(
              controller: legacy,
              osmOption: _legacyRoutes,
              onMapIsReady: onLegacyReady,
              onLocationChanged: onLegacyLocation,
            ),
          ),
        ],
      ),
    ),
  );
}

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

void _expectVisibleBounds(BoundingBox bounds, GeoPoint center) {
  for (final latitude in [bounds.north, bounds.south]) {
    expect(latitude.isFinite && latitude >= -90 && latitude <= 90, isTrue);
  }
  for (final longitude in [bounds.east, bounds.west]) {
    expect(longitude.isFinite && longitude >= -180 && longitude <= 180, isTrue);
  }
  expect(
    bounds.north,
    greaterThan(bounds.south),
    reason: 'a laid-out map must have a positive visible latitude span',
  );
  expect(center.latitude, inInclusiveRange(bounds.south, bounds.north));
  expect(
    bounds.east == bounds.west,
    isFalse,
    reason: 'a laid-out map must have a positive visible longitude span',
  );
  final containsLongitude = bounds.west <= bounds.east
      ? center.longitude >= bounds.west && center.longitude <= bounds.east
      : center.longitude >= bounds.west || center.longitude <= bounds.east;
  expect(
    containsLongitude,
    isTrue,
    reason: 'visible bounds must contain the camera center: $center/$bounds',
  );
}

Widget _twoMaps(
  MapController first,
  MapController second, {
  void Function(bool)? onFirstReady,
  void Function(bool)? onSecondReady,
  OnLocationChanged? onFirstLocation,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: OSMFlutter(
              controller: first,
              osmOption: _defaultRoutes,
              onMapIsReady: onFirstReady,
              onLocationChanged: onFirstLocation,
            ),
          ),
          Expanded(
            child: OSMFlutter(
              controller: second,
              osmOption: _defaultRoutes,
              onMapIsReady: onSecondReady,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Pumps until [condition] holds or [timeout] elapses.
Future<bool> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
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
    // ---- the shipped defaults must stay the combined typed configuration ----
    _expectTypedDefaults();

    // ---- attachment + readiness (route per the host's negotiation) ----
    var firstReady = false;
    var secondReady = false;
    final first = MapController.withPosition(initPosition: _target);
    final second = MapController.withPosition(initPosition: _other);
    final firstRegions = _Values<Region>(first.listenerRegionIsChanging);
    final secondRegions = _Values<Region>(second.listenerRegionIsChanging);

    await tester.pumpWidget(
      _twoMaps(
        first,
        second,
        onFirstReady: (ready) => firstReady = ready,
        onSecondReady: (ready) => secondReady = ready,
      ),
    );
    expect(
      await _until(
        () => firstReady && secondReady,
        timeout: const Duration(seconds: 30),
      ),
      isTrue,
      reason:
          'both maps must report ready (route selections must not abort '
          'attachment); exceptions: ${tester.takeException()}',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'no uncertain-route abort or handler error during attachment',
    );
    // ---- which host is this, and which route did each family take? ----
    // Checked before anything else: a current host that silently fell back
    // to legacy must fail here, not pass by delivering on the legacy plane.
    final host = await _classifyHost();
    final currentHost = host.currentHost;
    record(
      'host: ${currentHost ? 'generated protocol available' : 'no generated protocol (older host)'}, '
      'capabilities=${host.capabilities}',
    );
    if (currentHost) {
      expect(
        host.capabilities,
        containsAll(_familyCapabilities),
        reason: 'a current host advertises every family capability',
      );
      // The two maps are the first platform views: ids 0 and 1.
      expect(
        _liveTypedIds(),
        [0, 1],
        reason:
            'on a current host the two maps are exactly the live typed '
            'attachments',
      );
    }
    final routesA = _typedFamilies(0);
    final routesB = _typedFamilies(1);
    record('routes: A(view 0)=$routesA B(view 1)=$routesB');
    _expectDefaultRoutes(routesA, 'map A', currentHost: currentHost);
    _expectDefaultRoutes(routesB, 'map B', currentHost: currentHost);
    record('both maps ready');
    // Readiness can arrive before Flutter submits the platform-view geometry.
    await tester.pumpAndSettle();

    // ---- typed camera commands ----
    await first.moveTo(
      GeoPoint(latitude: 48.85, longitude: 2.35),
      animate: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final center = await first.centerMap;
    final zoom = await first.getZoom();
    expect(
      _near(center.latitude, 48.85, 1e-4),
      isTrue,
      reason: 'moveTo must be applied: center=$center',
    );
    expect(
      _near(center.longitude, 2.35, 1e-4),
      isTrue,
      reason: 'moveTo must be applied: center=$center',
    );
    expect(zoom > 0, isTrue, reason: 'getZoom must report a level');
    record('camera: center=$center zoom=$zoom');

    // ---- region-event payload parity: event route vs camera queries ----
    expect(
      await firstRegions.waitFor(1),
      isTrue,
      reason: 'a camera move must deliver a region change',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final bounds = await first.bounds;
    final lastRegion = firstRegions.getLast()!;
    expect(
      _near(lastRegion.center.latitude, center.latitude, 1e-4),
      isTrue,
      reason:
          'region center must match the camera query: '
          'event=${lastRegion.center} query=$center',
    );
    expect(
      _near(lastRegion.center.longitude, center.longitude, 1e-4),
      isTrue,
      reason:
          'region center must match the camera query: '
          'event=${lastRegion.center} query=$center',
    );
    _expectVisibleBounds(bounds, center);
    _expectVisibleBounds(lastRegion.boundingBox, center);
    expect(
      _sameRegion(lastRegion, center, bounds),
      isTrue,
      reason:
          'region event must match the camera queries: '
          'event=${lastRegion.center}/${lastRegion.boundingBox} '
          'query=$center/$bounds',
    );
    record(
      'region parity: events=${firstRegions.values.length} '
      'last=${lastRegion.center} bounds=${lastRegion.boundingBox} '
      'queryBounds=$bounds',
    );
    final typedBox = _Box.of(lastRegion.boundingBox);
    final typedQueryBox = _Box.of(bounds);

    await first.setZoom(zoomLevel: zoom + 1);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final zoomedBounds = await first.bounds;
    _expectVisibleBounds(zoomedBounds, await first.centerMap);
    expect(
      zoomedBounds.north - zoomedBounds.south,
      lessThan(bounds.north - bounds.south),
      reason:
          'zooming in must shrink the visible viewport, not return world bounds',
    );
    await first.setZoom(zoomLevel: zoom);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    record('absolute bounds: valid, contain center, shrink after zoom');

    // ---- two-map isolation ----
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final secondBefore = secondRegions.values.length;
    final firstBefore = firstRegions.values.length;
    await first.moveTo(
      GeoPoint(latitude: 48.86, longitude: 2.36),
      animate: false,
    );
    expect(
      await _until(
        () => firstRegions.values.length > firstBefore,
        timeout: const Duration(seconds: 5),
      ),
      isTrue,
      reason: 'moving map A must deliver region events to A',
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(
      secondRegions.values.length,
      secondBefore,
      reason: 'map B must not receive map A\'s region events',
    );
    final secondCenter = await second.centerMap;
    expect(
      _near(secondCenter.latitude, _other.latitude, 1e-3),
      isTrue,
      reason: 'map B must not have moved: $secondCenter',
    );
    record(
      'isolation: A events=${firstRegions.values.length - firstBefore}, '
      'B events=${secondRegions.values.length - secondBefore}',
    );

    // ---- optional gestures (Android harness) ----
    if (_gestureStep) {
      final firstTaps = _Values<GeoPoint>(first.listenerMapSingleTapping);
      final secondTaps = _Values<GeoPoint>(second.listenerMapSingleTapping);
      final maps = find.byType(OSMFlutter);
      await tester.tapAt(tester.getCenter(maps.at(0)));
      expect(
        await firstTaps.waitFor(1, timeout: const Duration(seconds: 5)),
        isTrue,
        reason: 'a tap on map A must deliver on A\'s typed route',
      );
      final tap = firstTaps.getLast()!;
      final tapBounds = await first.bounds;
      expect(
        tap.latitude < tapBounds.north && tap.latitude > tapBounds.south,
        isTrue,
        reason: 'tap must fall inside A: tap=$tap bounds=$tapBounds',
      );
      expect(secondTaps.values, isEmpty, reason: 'map B must stay silent');
      await tester.tapAt(tester.getCenter(maps.at(1)));
      expect(
        await secondTaps.waitFor(1, timeout: const Duration(seconds: 5)),
        isTrue,
        reason: 'a tap on map B must deliver on B\'s typed route',
      );
      expect(firstTaps.values.length, 1, reason: 'map A must stay silent');
      record('gestures: A tap=$tap, B taps=${secondTaps.values.length}');
    }

    // ---- optional location fixes (typed location route) ----
    // Map A (default routes) and an explicitly legacy attachment run the same
    // flow at the same time against the same location source, so the typed
    // route is compared with the legacy plane over one wall-clock window: it
    // only changes where fixes travel, so it must deliver the same number of
    // callbacks (no drops, no duplicates) at the host's cadence.
    if (_locationStep) {
      final typedArrivalMs = <int>[];
      final legacyArrivalMs = <int>[];
      final fixes = <UserLocation>[];
      final legacyLocation = MapController.withPosition(initPosition: _target);
      var legacyReady = false;
      await tester.pumpWidget(
        _locationMaps(
          first,
          second,
          legacyLocation,
          onFirstLocation: (fix) {
            typedArrivalMs.add(DateTime.now().millisecondsSinceEpoch);
            fixes.add(fix as UserLocation);
          },
          onLegacyLocation: (_) =>
              legacyArrivalMs.add(DateTime.now().millisecondsSinceEpoch),
          onLegacyReady: (ready) => legacyReady = ready,
        ),
      );
      expect(
        await _until(() => legacyReady, timeout: const Duration(seconds: 30)),
        isTrue,
        reason: 'the legacy location baseline must become ready',
      );
      // Nothing streams until a consumer starts the flow: the `location`
      // family enables the my-location layer and the `location.updates`
      // family starts continuous fixes; delivery then follows each
      // attachment's negotiated `events.location` route at the host's rate.
      await first.currentLocation();
      await first.startLocationUpdating();
      await legacyLocation.currentLocation();
      await legacyLocation.startLocationUpdating();
      expect(
        await _until(
          () => typedArrivalMs.isNotEmpty && legacyArrivalMs.isNotEmpty,
          timeout: const Duration(seconds: 45),
        ),
        isTrue,
        reason: 'location fixes must flow through the typed and legacy routes',
      );
      // Only fixes that arrive after the first one count: a provider that
      // falls silent would otherwise leave two empty windows that compare
      // as equal, and a cadence check needs at least a few intervals.
      const minFreshFixes = 4;
      final windowStart = DateTime.now();
      List<int> fresh(List<int> arrivals) => arrivals
          .where((ms) => ms >= windowStart.millisecondsSinceEpoch)
          .toList();
      List<int> typedFresh = [];
      List<int> legacyFresh = [];
      final collected = await _until(() {
        typedFresh = fresh(typedArrivalMs);
        legacyFresh = fresh(legacyArrivalMs);
        return typedFresh.length >= minFreshFixes &&
            legacyFresh.length >= minFreshFixes;
      }, timeout: const Duration(seconds: 60));
      await first.stopLocationUpdating();
      await legacyLocation.stopLocationUpdating();
      expect(
        collected,
        isTrue,
        reason:
            'both planes must deliver at least $minFreshFixes fresh '
            'fixes after the flow starts, or there is no cadence to compare '
            '(typed=${typedFresh.length}, legacy=${legacyFresh.length}); '
            'grant location permission and supply a moving fix',
      );
      final typedCount = typedFresh.length;
      final legacyCount = legacyFresh.length;
      final typedSpacing = _spacing(typedFresh);
      final legacySpacing = _spacing(legacyFresh);
      final fix = await first.myLocation();
      final last = fixes.last;
      expect(
        _near(last.latitude, fix.latitude, 1e-2),
        isTrue,
        reason: 'typed fix events must match myLocation(): $last vs $fix',
      );
      expect(
        _near(last.longitude, fix.longitude, 1e-2),
        isTrue,
        reason: 'typed fix events must match myLocation(): $last vs $fix',
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(
          typedSpacing.every((ms) => ms >= 900),
          isTrue,
          reason:
              'Android must forward typed fixes at the host\'s 1 s '
              'cadence: $typedSpacing',
        );
        expect(
          legacySpacing.every((ms) => ms >= 900),
          isTrue,
          reason:
              'Android must forward legacy fixes at the host\'s 1 s '
              'cadence: $legacySpacing',
        );
      }
      expect(
        _liveTypedIds(),
        currentHost ? [0, 1] : const <int>[],
        reason:
            'the location baseline must negotiate nothing: the typed '
            'maps stay the only typed attachments',
      );
      expect(
        legacyCount,
        _sameCount(typedCount),
        reason:
            'the typed route must deliver the legacy plane\'s callbacks: '
            'typed=$typedCount legacy=$legacyCount over the same span',
      );
      record(
        'location (from the first fix until both planes had '
        '$minFreshFixes fresh fixes, both live): '
        'typed fixes=$typedCount spacingMs=$typedSpacing, '
        'legacy fixes=$legacyCount spacingMs=$legacySpacing '
        '(Android expects >=~1000, Apple every callback) '
        'fix=$fix lastEvent=$last heading=${last.angle}',
      );
      // The legacy baseline leaves; A and B stay for the remaining steps.
      await tester.pumpWidget(_twoMaps(first, second));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        tester.takeException(),
        isNull,
        reason: 'removing the legacy baseline must not throw',
      );
    }

    // ---- disposal: both maps removed, no late delivery, no exception ----
    firstRegions.dispose(first.listenerRegionIsChanging);
    secondRegions.dispose(second.listenerRegionIsChanging);
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(
      tester.takeException(),
      isNull,
      reason: 'disposal must not throw (handlers unregistered cleanly)',
    );
    record('disposal: both maps removed without exceptions');

    // ---- optional: the remaining command families and the tap events ----
    if (_familiesStep) {
      await _runFamilies(tester, record: record, currentHost: currentHost);
    }

    // ---- recreation: a fresh attachment negotiates again, and a legacy
    // attachment at the same position provides the parity baseline ----
    var thirdReady = false;
    final third = MapController.withPosition(initPosition: _target);
    final thirdRegions = _Values<Region>(third.listenerRegionIsChanging);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OSMFlutter(
            controller: third,
            osmOption: _defaultRoutes,
            onMapIsReady: (ready) => thirdReady = ready,
          ),
        ),
      ),
    );
    expect(
      await _until(() => thirdReady, timeout: const Duration(seconds: 30)),
      isTrue,
      reason: 'a recreated attachment must become ready again',
    );
    // Checked while the map is live: disposal drops generated clients. On a
    // current host the recreated map is the only live typed attachment; an
    // older host holds none.
    final recreated = _liveTypedIds();
    expect(
      recreated,
      currentHost ? hasLength(1) : isEmpty,
      reason: currentHost
          ? 'the recreated map must be the only live typed attachment: '
                '$recreated'
          : 'an older host must keep the recreated map fully legacy',
    );
    if (currentHost) {
      _expectDefaultRoutes(
        _typedFamilies(recreated.single),
        'the recreated map',
        currentHost: true,
      );
    }
    await third.moveTo(
      GeoPoint(latitude: 48.85, longitude: 2.35),
      animate: false,
    );
    expect(
      await thirdRegions.waitFor(1, timeout: const Duration(seconds: 5)),
      isTrue,
      reason: 'the recreated attachment must deliver region events',
    );
    record(
      'recreation: ready again, region event delivered, '
      'typed=${currentHost ? _typedFamilies(recreated.single) : const <String>[]}',
    );
    thirdRegions.dispose(third.listenerRegionIsChanging);
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(
      tester.takeException(),
      isNull,
      reason: 'removing the recreated map must not throw',
    );
    expect(
      _liveTypedIds(),
      isEmpty,
      reason: 'no typed route may linger once its map is removed',
    );

    var legacyReady = false;
    final legacy = MapController.withPosition(initPosition: _target);
    final legacyRegions = _Values<Region>(legacy.listenerRegionIsChanging);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Explicitly legacy; match the typed map's half-window viewport for
          // bounds parity.
          body: Column(
            children: [
              Expanded(
                child: OSMFlutter(
                  controller: legacy,
                  osmOption: _legacyRoutes,
                  onMapIsReady: (ready) => legacyReady = ready,
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
    expect(
      await _until(() => legacyReady, timeout: const Duration(seconds: 30)),
      isTrue,
    );
    // While the map is live (disposal drops generated clients).
    expect(
      _liveTypedIds(),
      isEmpty,
      reason: 'the explicitly legacy baseline must negotiate nothing',
    );
    await tester.pumpAndSettle();
    await legacy.moveTo(
      GeoPoint(latitude: 48.85, longitude: 2.35),
      animate: false,
    );
    expect(
      await legacyRegions.waitFor(1, timeout: const Duration(seconds: 5)),
      isTrue,
      reason: 'the legacy baseline must deliver region events on its plane',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final legacyRegion = legacyRegions.getLast()!;
    final legacyBox = _Box.of(legacyRegion.boundingBox);
    final legacyBounds = await legacy.bounds;
    final legacyCenter = await legacy.centerMap;
    _expectVisibleBounds(legacyBounds, legacyCenter);
    _expectVisibleBounds(legacyRegion.boundingBox, legacyCenter);
    expect(_sameRegion(legacyRegion, legacyCenter, legacyBounds), isTrue);
    final legacyQueryBox = _Box.of(legacyBounds);
    expect(
      legacyBox,
      typedBox,
      reason:
          'typed and legacy region events must carry the same bounds '
          'at the same position: typed=$typedBox legacy=$legacyBox',
    );
    expect(
      legacyQueryBox,
      typedQueryBox,
      reason:
          'typed and legacy bounds queries must agree: '
          'typed=$typedQueryBox legacy=$legacyQueryBox',
    );
    legacyRegions.dispose(legacy.listenerRegionIsChanging);
    await tester.pumpWidget(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    record(
      'typed/legacy parity at 48.85/2.35: regionBox=$typedBox '
      'queryBox=$typedQueryBox (legacy identical, '
      'legacy typed=[])',
    );

    debugPrint('TYPED_ROUTES_SUMMARY\n$log');
  });
}
