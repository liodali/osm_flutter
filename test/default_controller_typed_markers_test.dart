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
    expect(platform.events, ['camera:false', 'markers:true', 'layers:false']);

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
    expect(platform.events, ['camera:false', 'markers:false', 'layers:true']);

    await tester.pumpWidget(const SizedBox());
    ready.dispose();
    marker.dispose();
  });
}
