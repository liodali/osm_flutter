// Marker interaction event routing tests: the frozen pre-initialization
// negotiation (opt-in x host capability x route selection), coordinate
// precision of the typed callbacks, exactly-once delivery against the
// legacy plane, session identity (stale callbacks), disposal, two-map
// isolation, attachment-scoped streams and recreation.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';
const legacyChannelName8 = 'plugins.dali.hamza/osmview_8';

String markerSinglePressChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapMarkerEventsApi.'
    'onMarkerSinglePress.view_$viewId';

String markerLongPressChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapMarkerEventsApi.'
    'onMarkerLongPress.view_$viewId';

const bootstrapMethod = 'map#bootstrap#protocol';
const routeMethod = 'map#events#markers#route';

/// Host advertising the marker event capability.
final Map<Object?, Object?> markerEventsBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'events.markers'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Host without the marker event capability.
final Map<Object?, Object?> cameraOnlyBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Test replica of the generated private codec: wraps the session envelope
/// (129) in the pigeon wire form for native-to-Dart callbacks.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeCameraSession) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    if (type == 129) {
      return generated.NativeCameraSession.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

generated.NativeCameraSession wireSession({
  String token = 'token-7',
  int generation = 0,
}) =>
    generated.NativeCameraSession(sessionToken: token, generation: generation);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invocations = <String>[];
  const codec = _TestPigeonCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> mockLegacy(
    Future<Object?> Function(MethodCall call) handler, {
    String channel = legacyChannelName,
  }) async {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => handler(call),
    );
  }

  Future<void> emitNativeMarkerSinglePress(
    int viewId,
    double latitude,
    double longitude, {
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
      latitude,
      longitude,
    ]);
    await messenger.handlePlatformMessage(
      markerSinglePressChannel(viewId),
      message,
      (_) {},
    );
  }

  Future<void> emitNativeMarkerLongPress(
    int viewId,
    double latitude,
    double longitude, {
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
      latitude,
      longitude,
    ]);
    await messenger.handlePlatformMessage(
      markerLongPressChannel(viewId),
      message,
      (_) {},
    );
  }

  /// Simulates a legacy-plane marker interaction message from the host.
  Future<void> emitLegacyMarker(String method, double lat, double lon,
      {String channel = legacyChannelName}) async {
    final message = const StandardMethodCodec()
        .encodeMethodCall(MethodCall(method, {'lat': lat, 'lon': lon}));
    await messenger.handlePlatformMessage(channel, message, (_) {});
  }

  tearDown(() {
    invocations.clear();
    messenger.setMockMethodCallHandler(
        const MethodChannel(legacyChannelName), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel(legacyChannelName8), null);
    for (final viewId in [7, 8]) {
      generated.NativeMapMarkerEventsApi.setUp(
        null,
        messageChannelSuffix: 'view_$viewId',
      );
    }
  });

  group('attachMarkerEventsRoute negotiation', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachMarkerEventsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, isEmpty);
      expect(osm.markerEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('capability + opt-in negotiates the route before initialization',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        if (call.method == routeMethod) {
          final args = call.arguments as Map;
          expect(args['sessionToken'], 'token-7');
          expect(args['generation'], 0);
          expect(args['route'], 'pigeon');
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachMarkerEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      expect(invocations, ['legacy:$bootstrapMethod', 'legacy:$routeMethod']);
      expect(osm.markerEventsClientFor(7), isNotNull);
      osm.close(7);
    });

    test('camera-only host keeps marker interactions on the legacy plane',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachMarkerEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(invocations, ['legacy:$bootstrapMethod']);
      expect(osm.markerEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('rejected selection keeps legacy and unregisters the handlers',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        if (call.method == routeMethod) {
          throw PlatformException(code: 'stale_session');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachMarkerEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(osm.markerEventsClientFor(7), isNull);

      final taps = <GeoPointEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      await emitNativeMarkerSinglePress(7, 47.0, -1.0);
      await emitLegacyMarker('receiveGeoPoint', 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('the decision is frozen: repeat attaches never re-negotiate',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      expect(invocations.where((m) => m == 'legacy:$routeMethod').length, 1);
      osm.close(7);
    });

    test('an unconfirmed rollback aborts attachment without freezing a route',
        () async {
      var hostResponsive = false;
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        if (call.method == routeMethod) {
          if (!hostResponsive) return Completer<Object?>().future;
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      osm.lifecycleRouteSelectionTimeout = const Duration(milliseconds: 30);
      await osm.init(7);
      await expectLater(
        osm.attachMarkerEventsRoute(7, optIn: true),
        throwsA(isA<MarkerRouteUncertainException>()),
      );
      expect(osm.markerEventsClientFor(7), isNull);

      hostResponsive = true;
      expect(
        await osm.attachMarkerEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      osm.close(7);
    });
  });

  group('typed marker delivery', () {
    test('marker presses forward with full coordinate precision', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);

      final taps = <GeoPointEvent>[];
      final longPresses = <GeoPointLongPressEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      final sub2 = osm.onGeoPointLongPressListener(7).listen(longPresses.add);

      const lat = 47.218071429999996;
      const lon = -1.5536219999999902;
      const longLat = 8.000000000000002;
      const longLon = -0.9999999999999999;
      await emitNativeMarkerSinglePress(7, lat, lon);
      await emitNativeMarkerLongPress(7, longLat, longLon);
      await Future<void>.delayed(Duration.zero);

      expect(taps.length, 1);
      expect(taps.single.mapId, 7);
      expect(taps.single.value.latitude, lat);
      expect(taps.single.value.longitude, lon);
      expect(longPresses.length, 1);
      expect(longPresses.single.value.latitude, longLat);
      expect(longPresses.single.value.longitude, longLon);
      await sub.cancel();
      await sub2.cancel();
      osm.close(7);
    });

    test('marker interactions are discrete: repeats are never coalesced',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      final taps = <GeoPointEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      await emitNativeMarkerSinglePress(7, 47.0, -1.0);
      await emitNativeMarkerSinglePress(7, 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 2);
      await sub.cancel();
      osm.close(7);
    });

    test('exactly one route: legacy marker messages are dropped on the '
        'generated route (no duplicate delivery)', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      final taps = <GeoPointEvent>[];
      final longPresses = <GeoPointLongPressEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      final sub2 = osm.onGeoPointLongPressListener(7).listen(longPresses.add);

      await emitNativeMarkerSinglePress(7, 47.0, -1.0);
      await emitLegacyMarker('receiveGeoPoint', 47.0, -1.0);
      await emitNativeMarkerLongPress(7, 48.0, -2.0);
      await emitLegacyMarker('receiveGeoPointLongPress', 48.0, -2.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      expect(longPresses.length, 1);
      await sub.cancel();
      await sub2.cancel();
      osm.close(7);
    });

    test('without opt-in the legacy marker events flow unchanged', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: false);
      final taps = <GeoPointEvent>[];
      final longPresses = <GeoPointLongPressEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      final sub2 = osm.onGeoPointLongPressListener(7).listen(longPresses.add);
      await emitLegacyMarker('receiveGeoPoint', 47.5, -1.5);
      await emitLegacyMarker('receiveGeoPointLongPress', 48.5, -2.5);
      await Future<void>.delayed(Duration.zero);
      expect(taps.single.value.latitude, 47.5);
      expect(taps.single.value.longitude, -1.5);
      expect(longPresses.single.value.latitude, 48.5);
      expect(longPresses.single.value.longitude, -2.5);
      await sub.cancel();
      await sub2.cancel();
      osm.close(7);
    });
  });

  group('session identity', () {
    test('stale token or generation callbacks are dropped', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      final taps = <GeoPointEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);

      await emitNativeMarkerSinglePress(7, 1.0, 2.0, token: 'token-7-r');
      await emitNativeMarkerSinglePress(7, 3.0, 4.0, generation: 1);
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);

      await emitNativeMarkerSinglePress(7, 5.0, 6.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('two-map isolation', () {
    test('each map receives only its own marker callbacks', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...markerEventsBootstrap, 'sessionToken': 'token-8'};
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      await osm.attachMarkerEventsRoute(8, optIn: true);

      final taps7 = <GeoPointEvent>[];
      final taps8 = <GeoPointEvent>[];
      final sub7 = osm.onGeoPointClickListener(7).listen(taps7.add);
      final sub8 = osm.onGeoPointClickListener(8).listen(taps8.add);

      await emitNativeMarkerSinglePress(8, 8.0, 8.0, token: 'token-8');
      await emitNativeMarkerSinglePress(8, 9.0, 9.0, token: 'token-7');
      await emitNativeMarkerSinglePress(7, 10.0, 10.0, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(taps7, isEmpty);
      expect(taps8.length, 1);

      await emitNativeMarkerSinglePress(7, 7.0, 7.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps7.length, 1);
      expect(taps8.length, 1);
      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });
  });

  group('recreation and disposal', () {
    test('disposal unregisters handlers; late callbacks deliver nothing',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      final client = osm.markerEventsClientFor(7)!;
      expect(client.isActive, isTrue);

      osm.close(7);
      expect(osm.markerEventsClientFor(7), isNull);
      expect(client.isActive, isFalse);

      await emitNativeMarkerSinglePress(7, 47.0, -1.0);
      await emitNativeMarkerLongPress(7, 47.0, -1.0);
      await emitLegacyMarker('receiveGeoPoint', 47.0, -1.0);
    });

    test('recreation decides freshly against the new session identity',
        () async {
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...markerEventsBootstrap, 'sessionToken': token};
        }
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      osm.close(7);

      token = 'token-7-recreated';
      await osm.init(7);
      expect(
        await osm.attachMarkerEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final taps = <GeoPointEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      await emitNativeMarkerSinglePress(7, 1.0, 2.0, token: 'token-7');
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);
      await emitNativeMarkerSinglePress(7, 3.0, 4.0, token: 'token-7-recreated');
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('recreation without opt-in returns to the legacy plane', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      osm.close(7);

      await osm.init(7);
      expect(
        await osm.attachMarkerEventsRoute(7, optIn: false),
        CameraRouteSelection.legacy,
      );
      final taps = <GeoPointEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      await emitLegacyMarker('receiveGeoPoint', 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('a stale client teardown never unregisters the replacement',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return markerEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      final staleClient = osm.markerEventsClientFor(7)!;
      osm.close(7);

      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: true);
      staleClient.dispose();
      final taps = <GeoPointEvent>[];
      final sub = osm.onGeoPointClickListener(7).listen(taps.add);
      await emitNativeMarkerSinglePress(7, 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('an active marker subscription of a disposed map never receives '
        'the recreated map\'s taps while another map keeps the source open',
        () async {
      await mockLegacy((call) async => null);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachMarkerEventsRoute(7, optIn: false);
      await osm.attachMarkerEventsRoute(8, optIn: false);

      final oldTaps = <GeoPointEvent>[];
      var oldDone = false;
      final oldSub = osm.onGeoPointClickListener(7).listen(
        oldTaps.add,
        onDone: () => oldDone = true,
      );
      await emitLegacyMarker('receiveGeoPoint', 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(oldTaps.length, 1);

      osm.close(7);
      await Future<void>.delayed(Duration.zero);
      expect(oldDone, isTrue,
          reason: 'disposal must complete the attachment-owned wrapper');

      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachMarkerEventsRoute(7, optIn: false);
      final newTaps = <GeoPointEvent>[];
      final newSub = osm.onGeoPointClickListener(7).listen(newTaps.add);
      await emitLegacyMarker('receiveGeoPoint', 48.0, -2.0);
      await Future<void>.delayed(Duration.zero);
      expect(newTaps.length, 1);
      expect(oldTaps.length, 1,
          reason: 'the disposed subscription must not see the replacement');

      await oldSub.cancel();
      await newSub.cancel();
      osm.close(7);
      osm.close(8);
    });
  });
}
