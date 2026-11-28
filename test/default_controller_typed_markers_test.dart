// Finding: the default (widget-driven) controller must freeze every routing
// decision — each command family and each event family — before any map
// mutation, driven by the widget-level flags.
//
// Typed routes are the plugin's default. The scenario tests therefore state
// their flags explicitly (so each keeps testing one family's opt-in on its
// own), and one test pins the widget defaults together with the attach order
// applications get.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';
import 'package:flutter_osm_plugin/src/widgets/mobile_osm_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) =>
    WidgetsApp(color: const Color(0xFFFFFFFF), builder: (_, child) => home);

/// Typed families in controller attach order (short names used by the
/// scenarios to switch individual families on).
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

/// Records the routing decisions the default controller freezes at init.
///
/// Answers every attachment itself: a widget test runs in fake async, so a
/// probe sent to a host that is not there would never be answered.
class _RecordingMarkersPlatform extends MethodChannelOSM {
  final events = <String>[];

  /// Opt-in received per family and map, in attach order.
  final optIns = <String, Map<int, bool>>{
    for (final family in _families) family: <int, bool>{},
  };

  CameraRouteSelection _record(String family, int idOSM, bool optIn) {
    events.add('$family:$optIn');
    optIns[family]![idOSM] = optIn;
    return CameraRouteSelection.legacy;
  }

  @override
  Future<CameraRouteSelection> attachShapesRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('shapes', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachRoadsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('roads', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachLocationRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('location', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachLocationUpdatesRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('updates', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachLifecycleEventsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('lifecycle', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachInteractionEventsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('interaction', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachMarkerEventsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('markerEvents', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachRoadEventsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('roadEvents', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachLocationEventsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('locationEvents', idOSM, optIn);

  @override
  Future<CameraRouteSelection> attachRegionEventsRoute(
    int idOSM, {
    bool optIn = false,
  }) async => _record('regionEvents', idOSM, optIn);

  /// User-location icon requests captured through the platform contract.
  final iconRequests =
      <
        ({
          int id,
          GlobalKey personKey,
          GlobalKey directionKey,
          IconAnchor? personAnchor,
          IconAnchor? directionAnchor,
        })
      >[];

  @override
  Future<CameraRouteSelection> attachCameraRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    return _record('camera', idOSM, optIn);
  }

  @override
  Future<CameraRouteSelection> attachMarkersRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    return _record('markers', idOSM, optIn);
  }

  @override
  Future<CameraRouteSelection> attachLayersRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    return _record('layers', idOSM, optIn);
  }

  @override
  Future<CameraRouteSelection> attachTrackingRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    return _record('tracking', idOSM, optIn);
  }

  @override
  Future<CameraRouteSelection> attachUserLocationIconsRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    return _record('icons', idOSM, optIn);
  }

  /// Tracking starts requested by the controller, in call order.
  final trackingStarts = <({bool stopFollow, Anchor? anchor})>[];

  @override
  Future<void> enableTracking(
    int idOSM, {
    bool stopFollowInDrag = false,
    bool disableMarkerRotation = false,
    Anchor? anchor,
    bool useDirectionMarker = false,
  }) async {
    events.add('enableTracking:$idOSM');
    trackingStarts.add((stopFollow: stopFollowInDrag, anchor: anchor));
  }

  @override
  Future<void> customUserLocationMarker(
    int idOSM,
    GlobalKey personGlobalKey,
    GlobalKey directionArrowGlobalKey, {
    IconAnchor? personAnchor,
    IconAnchor? directionAnchor,
  }) async {
    events.add('userLocationMarker:$idOSM');
    iconRequests.add((
      id: idOSM,
      personKey: personGlobalKey,
      directionKey: directionArrowGlobalKey,
      personAnchor: personAnchor,
      directionAnchor: directionAnchor,
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MobileOsmFlutterState> pumpMap(
    WidgetTester tester, {
    required ValueNotifier<bool> ready,
    required ValueNotifier<Widget?> marker,
    required GlobalKey<MobileOsmFlutterState> stateKey,
    // Typed families switched on for this scenario; every other family is
    // switched off explicitly. `null` passes no flags at all, so the widget
    // supplies its own (typed) defaults.
    Set<String>? typed,
    UserLocationMaker? userLocationMarker,
  }) async {
    final on = typed ?? <String>{};
    final explicit = typed != null;
    bool flag(String family) => explicit && on.contains(family);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Keep platform-view creation unresolved: no creation callback may fire,
    // so the only MobileOSMController.init run is the one the test drives.
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) => Completer<dynamic>().future,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });
    final controller = MapController.withPosition(
      initPosition: GeoPoint(latitude: 47, longitude: 8),
    );
    Widget map({
      bool camera = false,
      bool markers = false,
      bool layers = false,
      bool shapes = false,
      bool roads = false,
      bool location = false,
      bool updates = false,
      bool tracking = false,
      bool icons = false,
      bool lifecycle = false,
      bool interaction = false,
      bool markerEvents = false,
      bool roadEvents = false,
      bool locationEvents = false,
      bool regionEvents = false,
    }) => MobileOsmFlutter(
      key: stateKey,
      controller: controller,
      mapIsReadyListener: ready,
      dynamicMarkerWidgetNotifier: marker,
      globalKeys: List.generate(8, (_) => GlobalKey()),
      staticIconGlobalKeys: const {},
      userLocationMarker: userLocationMarker,
      useTypedCameraRoute: camera,
      useTypedMarkers: markers,
      useTypedLayers: layers,
      useTypedShapes: shapes,
      useTypedRoads: roads,
      useTypedLocation: location,
      useTypedLocationUpdates: updates,
      useTypedTracking: tracking,
      useTypedLocationIcons: icons,
      useTypedLifecycleEvents: lifecycle,
      useTypedInteractionEvents: interaction,
      useTypedMarkerEvents: markerEvents,
      useTypedRoadEvents: roadEvents,
      useTypedLocationEvents: locationEvents,
      useTypedRegionEvents: regionEvents,
    );
    final Widget widget;
    if (explicit) {
      widget = map(
        camera: flag('camera'),
        markers: flag('markers'),
        layers: flag('layers'),
        shapes: flag('shapes'),
        roads: flag('roads'),
        location: flag('location'),
        updates: flag('updates'),
        tracking: flag('tracking'),
        icons: flag('icons'),
        lifecycle: flag('lifecycle'),
        interaction: flag('interaction'),
        markerEvents: flag('markerEvents'),
        roadEvents: flag('roadEvents'),
        locationEvents: flag('locationEvents'),
        regionEvents: flag('regionEvents'),
      );
    } else {
      // Library defaults: no route flag passed at all.
      widget = MobileOsmFlutter(
        key: stateKey,
        controller: controller,
        mapIsReadyListener: ready,
        dynamicMarkerWidgetNotifier: marker,
        globalKeys: List.generate(8, (_) => GlobalKey()),
        staticIconGlobalKeys: const {},
        userLocationMarker: userLocationMarker,
      );
    }
    await tester.pumpWidget(_app(widget));
    await tester.pump();
    return stateKey.currentState!;
  }

  testWidgets('init attaches the markers route after the camera route', (
    tester,
  ) async {
    final previous = MobileOSMController.osmPlatform;
    final platform = _RecordingMarkersPlatform();
    MobileOSMController.osmPlatform = platform;
    addTearDown(() {
      MobileOSMController.osmPlatform = previous;
    });

    final ready = ValueNotifier<bool>(false);
    final marker = ValueNotifier<Widget?>(null);
    final stateKey = GlobalKey<MobileOsmFlutterState>();
    final state = await pumpMap(
      tester,
      ready: ready,
      marker: marker,
      stateKey: stateKey,
      typed: const {'markers'},
    );

    // Production path: the controller freezes every family before any map
    // mutation, in attach order (camera, markers, layers, ...); only the
    // opted-in family receives `true`.
    await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.optIns['markers']![7], isTrue);
    expect(platform.events, [
      for (final family in _families) '$family:${family == 'markers'}',
    ]);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('all families off keeps the legacy markers route', (
    tester,
  ) async {
    final previous = MobileOSMController.osmPlatform;
    final platform = _RecordingMarkersPlatform();
    MobileOSMController.osmPlatform = platform;
    addTearDown(() {
      MobileOSMController.osmPlatform = previous;
    });

    final ready = ValueNotifier<bool>(false);
    final marker = ValueNotifier<Widget?>(null);
    final stateKey = GlobalKey<MobileOsmFlutterState>();
    final state = await pumpMap(
      tester,
      ready: ready,
      marker: marker,
      stateKey: stateKey,
      typed: {},
    );

    await MobileOSMController.init(9, state);
    addTearDown(() => platform.close(9));

    expect(platform.optIns['markers']![9], isFalse);
    expect(platform.events, [for (final family in _families) '$family:false']);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('useTypedLayers freezes the layers route after the markers', (
    tester,
  ) async {
    final previous = MobileOSMController.osmPlatform;
    final platform = _RecordingMarkersPlatform();
    MobileOSMController.osmPlatform = platform;
    addTearDown(() {
      MobileOSMController.osmPlatform = previous;
    });

    final ready = ValueNotifier<bool>(false);
    final marker = ValueNotifier<Widget?>(null);
    final stateKey = GlobalKey<MobileOsmFlutterState>();
    final state = await pumpMap(
      tester,
      ready: ready,
      marker: marker,
      stateKey: stateKey,
      typed: const {'layers'},
    );

    // Regression: the layers family must attach before initialization, or
    // tile and overlay commands would silently stay on the legacy route.
    await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.optIns['layers']![7], isTrue);
    expect(platform.events, [
      for (final family in _families) '$family:${family == 'layers'}',
    ]);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('useTypedTracking freezes the tracking route after the layers', (
    tester,
  ) async {
    final previous = MobileOSMController.osmPlatform;
    final platform = _RecordingMarkersPlatform();
    MobileOSMController.osmPlatform = platform;
    addTearDown(() {
      MobileOSMController.osmPlatform = previous;
    });

    final ready = ValueNotifier<bool>(false);
    final marker = ValueNotifier<Widget?>(null);
    final stateKey = GlobalKey<MobileOsmFlutterState>();
    final state = await pumpMap(
      tester,
      ready: ready,
      marker: marker,
      stateKey: stateKey,
      typed: const {'tracking'},
    );

    // Regression: the tracking family must attach before initialization,
    // or follow-me commands would silently stay on the legacy route even
    // with the opt-in set.
    await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.optIns['tracking']![7], isTrue);
    expect(platform.events, [
      for (final family in _families) '$family:${family == 'tracking'}',
    ]);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets(
    'useTypedLocationIcons freezes the icon route and forwards anchors',
    (tester) async {
      final previous = MobileOSMController.osmPlatform;
      final platform = _RecordingMarkersPlatform();
      MobileOSMController.osmPlatform = platform;
      addTearDown(() {
        MobileOSMController.osmPlatform = previous;
      });

      final ready = ValueNotifier<bool>(false);
      final marker = ValueNotifier<Widget?>(null);
      final stateKey = GlobalKey<MobileOsmFlutterState>();
      final state = await pumpMap(
        tester,
        ready: ready,
        marker: marker,
        stateKey: stateKey,
        typed: const {'icons'},
        userLocationMarker: UserLocationMaker(
          personMarker: const MarkerIcon(icon: SizedBox(width: 12, height: 20)),
          directionArrowMarker: const MarkerIcon(
            icon: SizedBox(width: 8, height: 14),
          ),
          personAnchor: IconAnchor(anchor: Anchor.bottom),
          directionAnchor: IconAnchor(anchor: Anchor.center),
        ),
      );

      // The icon family must attach before initialization, or icon
      // replacement would silently stay on the legacy route even with the
      // opt-in set.
      final controller = await MobileOSMController.init(7, state);
      addTearDown(() => platform.close(7));

      expect(platform.optIns['icons']![7], isTrue);
      expect(platform.events, [
        for (final family in _families) '$family:${family == 'icons'}',
      ]);

      // The prepared widget keys and the per-icon anchors reach the platform
      // contract unchanged; rendering itself stays in the interface package.
      await controller.initMap(null, null, false, null, null);
      expect(platform.iconRequests, hasLength(1));
      final request = platform.iconRequests.single;
      expect(request.id, 7);
      expect(request.personKey, state.personIconMarkerKey);
      expect(request.directionKey, state.arrowDirectionMarkerKey);
      // Legacy `Anchor.bottom` encodes (0.5, 0), `Anchor.center` (0.5, 0.5).
      expect(request.personAnchor!.anchor.value.$1, 0.5);
      expect(request.personAnchor!.anchor.value.$2, 0.0);
      expect(request.directionAnchor!.anchor.value.$1, 0.5);
      expect(request.directionAnchor!.anchor.value.$2, 0.5);

      // Initial tracking must not override the configured pivots: the
      // controller starts tracking without an anchor override, so the host
      // keeps the per-icon anchors applied above. Apple's permission path is
      // a no-op in the harness, so no platform permission call is issued.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await controller.enableTracking(enableStopFollow: true);
      expect(platform.trackingStarts, hasLength(1));
      expect(platform.trackingStarts.single.anchor, isNull);
      expect(platform.trackingStarts.single.stopFollow, isTrue);

      await tester.pumpWidget(const SizedBox());
      ready.dispose();
      marker.dispose();
    },
  );

  testWidgets('widget defaults opt every typed family in, in attach order', (
    tester,
  ) async {
    final previous = MobileOSMController.osmPlatform;
    final platform = _RecordingMarkersPlatform();
    MobileOSMController.osmPlatform = platform;
    addTearDown(() {
      MobileOSMController.osmPlatform = previous;
    });

    final ready = ValueNotifier<bool>(false);
    final marker = ValueNotifier<Widget?>(null);
    final stateKey = GlobalKey<MobileOsmFlutterState>();
    final state = await pumpMap(
      tester,
      ready: ready,
      marker: marker,
      stateKey: stateKey,
    );

    // No flag passed: the widget's own defaults must be the combined typed
    // configuration, frozen for all fifteen families before initialization.
    await MobileOSMController.init(13, state);
    addTearDown(() => platform.close(13));

    expect(
      platform.events,
      [for (final family in _families) '$family:true'],
      reason:
          'typed routes are the default; a deliberate change needs a '
          'conscious update here and in TYPED_ROUTES_VALIDATION.md',
    );

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('an explicit tracking anchor still overrides the icon pivots', (
    tester,
  ) async {
    final previous = MobileOSMController.osmPlatform;
    final platform = _RecordingMarkersPlatform();
    MobileOSMController.osmPlatform = platform;
    addTearDown(() {
      MobileOSMController.osmPlatform = previous;
    });

    final ready = ValueNotifier<bool>(false);
    final marker = ValueNotifier<Widget?>(null);
    final stateKey = GlobalKey<MobileOsmFlutterState>();
    final state = await pumpMap(
      tester,
      ready: ready,
      marker: marker,
      stateKey: stateKey,
      typed: {},
    );

    final controller = await MobileOSMController.init(11, state);
    addTearDown(() => platform.close(11));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await controller.enableTracking(anchor: Anchor.left);
    expect(platform.trackingStarts.single.anchor, Anchor.left);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });
}
