// Finding: the default (widget-driven) controller must freeze both routing
// decisions — camera and markers — before any map mutation, driven by the
// widget-level opt-ins.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';
import 'package:flutter_osm_plugin/src/widgets/mobile_osm_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => WidgetsApp(
      color: const Color(0xFFFFFFFF),
      builder: (_, child) => home,
    );

/// Records the routing decisions the default controller freezes at init.
class _RecordingMarkersPlatform extends MethodChannelOSM {
  final events = <String>[];
  final cameraOptIns = <int, bool>{};
  final markerOptIns = <int, bool>{};
  final layersOptIns = <int, bool>{};
  final trackingOptIns = <int, bool>{};
  final locationIconsOptIns = <int, bool>{};

  /// User-location icon requests captured through the platform contract.
  final iconRequests = <
      ({
        int id,
        GlobalKey personKey,
        GlobalKey directionKey,
        IconAnchor? personAnchor,
        IconAnchor? directionAnchor,
      })>[];

  @override
  Future<CameraRouteSelection> attachCameraRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    events.add('camera:$optIn');
    cameraOptIns[idOSM] = optIn;
    return CameraRouteSelection.legacy;
  }

  @override
  Future<CameraRouteSelection> attachMarkersRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    events.add('markers:$optIn');
    markerOptIns[idOSM] = optIn;
    return CameraRouteSelection.legacy;
  }

  @override
  Future<CameraRouteSelection> attachLayersRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    events.add('layers:$optIn');
    layersOptIns[idOSM] = optIn;
    return CameraRouteSelection.legacy;
  }

  @override
  Future<CameraRouteSelection> attachTrackingRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    events.add('tracking:$optIn');
    trackingOptIns[idOSM] = optIn;
    return CameraRouteSelection.legacy;
  }

  @override
  Future<CameraRouteSelection> attachUserLocationIconsRoute(
    int idOSM, {
    bool optIn = false,
  }) async {
    events.add('icons:$optIn');
    locationIconsOptIns[idOSM] = optIn;
    return CameraRouteSelection.legacy;
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
    bool useTypedMarkers = false,
    bool useTypedLayers = false,
    bool useTypedTracking = false,
    bool useTypedLocationIcons = false,
    UserLocationMaker? userLocationMarker,
  }) async {
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
    await tester.pumpWidget(_app(
      MobileOsmFlutter(
        key: stateKey,
        controller: controller,
        mapIsReadyListener: ready,
        dynamicMarkerWidgetNotifier: marker,
        globalKeys: List.generate(8, (_) => GlobalKey()),
        staticIconGlobalKeys: const {},
        useTypedMarkers: useTypedMarkers,
        useTypedLayers: useTypedLayers,
        useTypedTracking: useTypedTracking,
        useTypedLocationIcons: useTypedLocationIcons,
        userLocationMarker: userLocationMarker,
      ),
    ));
    await tester.pump();
    return stateKey.currentState!;
  }

  testWidgets('init attaches the markers route after the camera route',
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
      useTypedMarkers: true,
    );

    // Production path: the default controller freezes all three families
    // before any map mutation, camera first, then markers, then layers.
    await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.markerOptIns[7], isTrue);
    expect(
      platform.events,
      [
        'camera:false',
        'markers:true',
        'layers:false',
        'tracking:false',
        'icons:false',
      ],
    );

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('default keeps the legacy markers route', (tester) async {
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

    await MobileOSMController.init(9, state);
    addTearDown(() => platform.close(9));

    expect(platform.markerOptIns[9], isFalse);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('useTypedLayers freezes the layers route after the markers',
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
      useTypedLayers: true,
    );

    // Regression: the layers family must attach before initialization, or
    // tile and overlay commands would silently stay on the legacy route.
    await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.layersOptIns[7], isTrue);
    expect(
      platform.events,
      [
        'camera:false',
        'markers:false',
        'layers:true',
        'tracking:false',
        'icons:false',
      ],
    );

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });

  testWidgets('useTypedTracking freezes the tracking route after the layers',
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
      useTypedTracking: true,
    );

    // Regression: the tracking family must attach before initialization,
    // or follow-me commands would silently stay on the legacy route even
    // with the opt-in set.
    await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.trackingOptIns[7], isTrue);
    expect(
      platform.events,
      [
        'camera:false',
        'markers:false',
        'layers:false',
        'tracking:true',
        'icons:false',
      ],
    );

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
      useTypedLocationIcons: true,
      userLocationMarker: UserLocationMaker(
        personMarker: MarkerIcon(icon: const SizedBox(width: 12, height: 20)),
        directionArrowMarker:
            MarkerIcon(icon: const SizedBox(width: 8, height: 14)),
        personAnchor: IconAnchor(anchor: Anchor.bottom),
        directionAnchor: IconAnchor(anchor: Anchor.center),
      ),
    );

    // The icon family must attach before initialization, or icon
    // replacement would silently stay on the legacy route even with the
    // opt-in set.
    final controller = await MobileOSMController.init(7, state);
    addTearDown(() => platform.close(7));

    expect(platform.locationIconsOptIns[7], isTrue);
    expect(platform.events, [
      'camera:false',
      'markers:false',
      'layers:false',
      'tracking:false',
      'icons:true',
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
  });

  testWidgets('an explicit tracking anchor still overrides the icon pivots',
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
