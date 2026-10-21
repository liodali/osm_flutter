import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/src/widgets/mobile_osm_flutter.dart';
import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final creates = <MethodCall>[];
  setUp(() {
    creates.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') creates.add(call);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  PlatformView view(ValueChanged<int> onCreated) => PlatformView(
        onPlatformCreatedView: onCreated,
        uuidMapCache: 'apple-test',
        configuration: (
          customTile: CustomTile.osm(),
          bounds: [48, 9, 47, 8],
          zoomOption: const ZoomOption(initZoom: 10),
          enableRotationGesture: true,
          initlocation:
              GeoPoint(latitude: 47.376912345, longitude: 8.541712345),
          userlocation: false,
          isStaticMap: true,
        ),
      );

  for (final target in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('$target initializes once and forwards readiness to the widget',
        (tester) async {
      final previous = MobileOSMController.osmPlatform;
      final platform = _CountingApplePlatform();
      MobileOSMController.osmPlatform = platform;
      // Keep another channel alive: closing this widget must cancel its own
      // subscriptions rather than relying on the global stream closing.
      await platform.init(999);
      addTearDown(() {
        platform.close(999);
        MobileOSMController.osmPlatform = previous;
      });
      final controller = MapController.withPosition(
          initPosition: GeoPoint(latitude: 47, longitude: 8));
      final ready = <bool>[];
      final channelCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // Platform-view ids are allocated by Flutter; register the map channel
      // when the engine receives its create request.
      String? channelName;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,
          (call) async {
        if (call.method == 'create') {
          channelName = 'plugins.dali.hamza/osmview_${call.arguments['id']}';
          messenger.setMockMethodCallHandler(MethodChannel(channelName!),
              (command) async {
            channelCalls.add(command);
            return null;
          });
        }
        return null;
      });
      await tester.pumpWidget(MaterialApp(
          home: OSMFlutter(
              controller: controller,
              osmOption: const OSMOption(),
              onMapIsReady: ready.add)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1250));
      Future<void> emit(String method, bool value) async {
        final done = Completer<void>();
        messenger.handlePlatformMessage(
            channelName!,
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall(method, value)),
            (_) => done.complete());
        await tester.pump();
        await done.future;
      }

      expect(
          channelCalls.where((c) => c.method == 'init#ios#map'), hasLength(1));
      await emit('map#init#ios', true);
      await emit('map#init#ios', true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(channelCalls.where((c) => c.method == 'initMap'), hasLength(1));
      await emit('map#init', true);
      expect(ready, [false, true]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(platform.readyListeners, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(platform.readyListeners, 0);
      messenger.setMockMethodCallHandler(MethodChannel(channelName!), null);
    }, variant: TargetPlatformVariant({target}));

    testWidgets(
        '$target creates the correct native view and forwards its id once',
        (tester) async {
      final ids = <int>[];
      await tester.pumpWidget(MaterialApp(home: view(ids.add)));
      await tester.pump();
      expect(find.byType(UiKitView),
          target == TargetPlatform.iOS ? findsOneWidget : findsNothing);
      expect(find.byType(AppKitView),
          target == TargetPlatform.macOS ? findsOneWidget : findsNothing);
      expect(creates, hasLength(1));
      expect(ids, [creates.single.arguments['id']]);
      final native = target == TargetPlatform.iOS
          ? tester.widget<UiKitView>(find.byType(UiKitView)).creationParams
              as Map
          : tester.widget<AppKitView>(find.byType(AppKitView)).creationParams
              as Map;
      expect(native['location'], {'lat': 47.376912345, 'lon': 8.541712345});
      expect(native['isStaticMap'], isTrue);
      expect(native['enableRotationGesture'], isTrue);
      expect(native['bounds'], [48, 9, 47, 8]);
      expect(native['customTile']['urls'].first, isA<Map>());
      await tester.pump();
      expect(ids, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant({target}));

    testWidgets('$target rejects an Android-only controller before attaching',
        (tester) async {
      final controller = AndroidMapController.withPosition(
          initPosition: GeoPoint(latitude: 47, longitude: 8));
      final ready = ValueNotifier(false);
      final marker = ValueNotifier<Widget?>(null);
      await tester.pumpWidget(MaterialApp(
          home: MobileOsmFlutter(
        controller: controller,
        mapIsReadyListener: ready,
        dynamicMarkerWidgetNotifier: marker,
        globalKeys: List.generate(8, (_) => GlobalKey()),
        staticIconGlobalKeys: const {},
      )));
      expect(tester.takeException(), isA<UnsupportedError>());
      expect(creates, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
      ready.dispose();
      marker.dispose();
    }, variant: TargetPlatformVariant({target}));
  }

  testWidgets('unsupported desktop fails clearly before native creation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: view((_) {})));
    expect(tester.takeException(), isA<UnsupportedError>());
    expect(creates, isEmpty);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
}

class _CountingApplePlatform extends MethodChannelOSM {
  int readyListeners = 0;

  @override
  Stream<MapInitialization> onMapIsReady(int idMap) {
    StreamSubscription<MapInitialization>? subscription;
    late StreamController<MapInitialization> controller;
    controller = StreamController<MapInitialization>(onListen: () {
      readyListeners++;
      subscription = super.onMapIsReady(idMap).listen(controller.add);
    }, onCancel: () async {
      readyListeners--;
      await subscription?.cancel();
    });
    return controller.stream;
  }
}
