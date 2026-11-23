// Road tap event routing tests: the frozen pre-initialization negotiation
// (opt-in x host capability x route selection), payload preservation of
// the typed callbacks against the legacy receiveRoad decode, exactly-once
// delivery, session identity (stale callbacks), disposal, two-map
// isolation, attachment-scoped streams and recreation.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';
const legacyChannelName8 = 'plugins.dali.hamza/osmview_8';

String roadTapChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapRoadEventsApi.'
    'onRoadTap.view_$viewId';

const bootstrapMethod = 'map#bootstrap#protocol';
const routeMethod = 'map#events#roads#route';

/// Host advertising the road event capability.
final Map<Object?, Object?> roadEventsBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'events.roads'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Host without the road event capability.
final Map<Object?, Object?> cameraOnlyBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Test replica of the generated private codec: wraps the session (129)
/// and the tapped-road payload (143/144) in the pigeon wire form.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeCameraSession) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    } else if (value is generated.NativeTappedRoad) {
      buffer.putUint8(144);
      writeValue(buffer, value.encode());
    } else if (value is generated.NativeRoadInstruction) {
      buffer.putUint8(143);
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

/// Classic two-point encoded polyline: (38.5, -120.2) and (40.7, -120.95).
const encodedRoute = '_p~iF~ps|U_ulLnnqC';

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

  Future<void> emitNativeRoadTap(
    int viewId,
    generated.NativeTappedRoad road, {
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
      road,
    ]);
    await messenger.handlePlatformMessage(
      roadTapChannel(viewId),
      message,
      (_) {},
    );
  }

  /// Simulates a legacy-plane receiveRoad message from the host.
  Future<void> emitLegacyRoad(Map<Object?, Object?> payload,
      {String channel = legacyChannelName}) async {
    final message = const StandardMethodCodec()
        .encodeMethodCall(MethodCall('receiveRoad', payload));
    await messenger.handlePlatformMessage(channel, message, (_) {});
  }

  tearDown(() {
    invocations.clear();
    messenger.setMockMethodCallHandler(
        const MethodChannel(legacyChannelName), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel(legacyChannelName8), null);
    for (final viewId in [7, 8]) {
      generated.NativeMapRoadEventsApi.setUp(
        null,
        messageChannelSuffix: 'view_$viewId',
      );
    }
  });

  group('attachRoadEventsRoute negotiation', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachRoadEventsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, isEmpty);
      expect(osm.roadEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('capability + opt-in negotiates the route before initialization',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
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
      final selection = await osm.attachRoadEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      expect(invocations, ['legacy:$bootstrapMethod', 'legacy:$routeMethod']);
      expect(osm.roadEventsClientFor(7), isNotNull);
      osm.close(7);
    });

    test('camera-only host keeps road taps on the legacy plane', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachRoadEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(invocations, ['legacy:$bootstrapMethod']);
      expect(osm.roadEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('rejected selection keeps legacy and unregisters the handlers',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        if (call.method == routeMethod) {
          throw PlatformException(code: 'stale_session');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachRoadEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(osm.roadEventsClientFor(7), isNull);

      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);
      await emitNativeRoadTap(
        7,
        generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0),
      );
      await emitLegacyRoad({'key': 'k', 'distance': 1.0, 'duration': 2.0});
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('an unconfirmed rollback aborts attachment without freezing a route',
        () async {
      var hostResponsive = false;
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
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
        osm.attachRoadEventsRoute(7, optIn: true),
        throwsA(isA<RoadRouteUncertainException>()),
      );
      expect(osm.roadEventsClientFor(7), isNull);

      hostResponsive = true;
      expect(
        await osm.attachRoadEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      osm.close(7);
    });
  });

  group('typed road delivery', () {
    test('road taps preserve the legacy payload field for field', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);

      // Full double precision on the numeric fields and the instruction
      // anchors; the polyline string crosses unchanged.
      const distance = 12.500000000000002;
      const duration = 8.000000000000002;
      const instructionLat = 47.218071429999996;
      const instructionLon = -1.5536219999999902;
      await emitNativeRoadTap(
        7,
        generated.NativeTappedRoad(
          key: 'road-42',
          distance: distance,
          duration: duration,
          routePoints: encodedRoute,
          instructions: [
            generated.NativeRoadInstruction(
              instruction: 'Turn left onto the bridge',
              latitude: instructionLat,
              longitude: instructionLon,
            ),
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(taps.length, 1);
      final road = taps.single.value;
      expect(taps.single.mapId, 7);
      expect(road.key, 'road-42');
      expect(road.distance, distance);
      expect(road.duration, duration);
      expect(road.route.length, 2);
      expect(road.route.first.latitude, 38.5);
      expect(road.route.first.longitude, -120.2);
      expect(road.route.last.latitude, 40.7);
      expect(road.route.last.longitude, -120.95);
      expect(road.instructions.length, 1);
      expect(road.instructions.single.instruction, 'Turn left onto the bridge');
      expect(road.instructions.single.geoPoint.latitude, instructionLat);
      expect(road.instructions.single.geoPoint.longitude, instructionLon);
      await sub.cancel();
      osm.close(7);
    });

    test('a typed payload with null optionals decodes like the legacy '
        'key-only message', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);

      await emitNativeRoadTap(7, generated.NativeTappedRoad(key: 'road-7'));
      await Future<void>.delayed(Duration.zero);
      expect(taps.single.value.key, 'road-7');
      expect(taps.single.value.distance, isNull);
      expect(taps.single.value.duration, isNull);
      expect(taps.single.value.route, isEmpty);
      expect(taps.single.value.instructions, isEmpty);
      await sub.cancel();
      osm.close(7);
    });

    test('road taps are discrete: repeats are never coalesced', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);
      final road = generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0);
      await emitNativeRoadTap(7, road);
      await emitNativeRoadTap(7, road);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 2);
      await sub.cancel();
      osm.close(7);
    });

    test('exactly one route: legacy receiveRoad messages are dropped on the '
        'generated route (no duplicate delivery)', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);

      await emitNativeRoadTap(
        7,
        generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0),
      );
      await emitLegacyRoad({'key': 'k', 'distance': 1.0, 'duration': 2.0});
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('without opt-in the legacy road taps flow unchanged', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: false);
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);
      await emitLegacyRoad({
        'key': 'k',
        'distance': 12.5,
        'duration': 8.25,
        'routePoints': encodedRoute,
      });
      await Future<void>.delayed(Duration.zero);
      expect(taps.single.value.key, 'k');
      expect(taps.single.value.distance, 12.5);
      expect(taps.single.value.route.length, 2);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('session identity', () {
    test('stale token or generation callbacks are dropped', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);
      final road = generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0);

      await emitNativeRoadTap(7, road, token: 'token-7-r');
      await emitNativeRoadTap(7, road, generation: 1);
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);

      await emitNativeRoadTap(7, road);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('two-map isolation', () {
    test('each map receives only its own road taps', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...roadEventsBootstrap, 'sessionToken': 'token-8'};
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachRoadEventsRoute(7, optIn: true);
      await osm.attachRoadEventsRoute(8, optIn: true);

      final taps7 = <RoadTapEvent>[];
      final taps8 = <RoadTapEvent>[];
      final sub7 = osm.onRoadMapClickListener(7).listen(taps7.add);
      final sub8 = osm.onRoadMapClickListener(8).listen(taps8.add);
      final road = generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0);

      await emitNativeRoadTap(8, road, token: 'token-8');
      await emitNativeRoadTap(8, road, token: 'token-7');
      await emitNativeRoadTap(7, road, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(taps7, isEmpty);
      expect(taps8.length, 1);

      await emitNativeRoadTap(7, road);
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
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      final client = osm.roadEventsClientFor(7)!;
      expect(client.isActive, isTrue);

      osm.close(7);
      expect(osm.roadEventsClientFor(7), isNull);
      expect(client.isActive, isFalse);

      await emitNativeRoadTap(
        7,
        generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0),
      );
      await emitLegacyRoad({'key': 'k'});
    });

    test('recreation decides freshly against the new session identity',
        () async {
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...roadEventsBootstrap, 'sessionToken': token};
        }
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      osm.close(7);

      token = 'token-7-recreated';
      await osm.init(7);
      expect(
        await osm.attachRoadEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);
      final road = generated.NativeTappedRoad(key: 'k', distance: 1.0, duration: 2.0);
      await emitNativeRoadTap(7, road, token: 'token-7');
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);
      await emitNativeRoadTap(7, road, token: 'token-7-recreated');
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('recreation without opt-in returns to the legacy plane', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return roadEventsBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: true);
      osm.close(7);

      await osm.init(7);
      expect(
        await osm.attachRoadEventsRoute(7, optIn: false),
        CameraRouteSelection.legacy,
      );
      final taps = <RoadTapEvent>[];
      final sub = osm.onRoadMapClickListener(7).listen(taps.add);
      await emitLegacyRoad({'key': 'k', 'distance': 1.0, 'duration': 2.0});
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('an active road subscription of a disposed map never receives the '
        'recreated map\'s taps while another map keeps the source open',
        () async {
      await mockLegacy((call) async => null);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachRoadEventsRoute(7, optIn: false);
      await osm.attachRoadEventsRoute(8, optIn: false);

      final oldTaps = <RoadTapEvent>[];
      var oldDone = false;
      final oldSub = osm.onRoadMapClickListener(7).listen(
        oldTaps.add,
        onDone: () => oldDone = true,
      );
      await emitLegacyRoad({'key': 'k1', 'distance': 1.0, 'duration': 2.0});
      await Future<void>.delayed(Duration.zero);
      expect(oldTaps.length, 1);

      osm.close(7);
      await Future<void>.delayed(Duration.zero);
      expect(oldDone, isTrue,
          reason: 'disposal must complete the attachment-owned wrapper');

      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachRoadEventsRoute(7, optIn: false);
      final newTaps = <RoadTapEvent>[];
      final newSub = osm.onRoadMapClickListener(7).listen(newTaps.add);
      await emitLegacyRoad({'key': 'k2', 'distance': 3.0, 'duration': 4.0});
      await Future<void>.delayed(Duration.zero);
      expect(newTaps.single.value.key, 'k2');
      expect(oldTaps.length, 1,
          reason: 'the disposed subscription must not see the replacement');

      await oldSub.cancel();
      await newSub.cancel();
      osm.close(7);
      osm.close(8);
    });
  });
}
