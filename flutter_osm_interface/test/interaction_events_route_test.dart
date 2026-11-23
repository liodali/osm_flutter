// Interaction event routing tests: the frozen pre-initialization
// negotiation (opt-in x host capability x route selection), coordinate
// precision of the typed callbacks, exactly-once delivery against the
// legacy plane, session identity (stale callbacks), two-map isolation,
// recreation and disposal.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';
const legacyChannelName8 = 'plugins.dali.hamza/osmview_8';

String singlePressChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapInteractionEventsApi.'
    'onSinglePress.view_$viewId';

String longPressChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapInteractionEventsApi.'
    'onLongPress.view_$viewId';

const bootstrapMethod = 'map#bootstrap#protocol';
const routeMethod = 'map#events#interaction#route';

/// Host advertising the interaction event capability.
final Map<Object?, Object?> interactionBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'events.interaction'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: interactions must stay legacy.
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

  /// Simulates one native-to-Dart pigeon callback on the per-view channel.
  Future<void> emitNativeSinglePress(
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
      singlePressChannel(viewId),
      message,
      (_) {},
    );
  }

  Future<void> emitNativeLongPress(
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
      longPressChannel(viewId),
      message,
      (_) {},
    );
  }

  /// Simulates a legacy-plane interaction message from the host.
  Future<void> emitLegacyPress(String method, double lat, double lon,
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
    // Drop any handlers a failed test left registered.
    for (final viewId in [7, 8]) {
      generated.NativeMapInteractionEventsApi.setUp(
        null,
        messageChannelSuffix: 'view_$viewId',
      );
    }
  });

  group('attachInteractionEventsRoute negotiation', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachInteractionEventsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, isEmpty);
      expect(osm.interactionEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('capability + opt-in negotiates the route before initialization',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return interactionBootstrap;
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
      final selection = await osm.attachInteractionEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      // Probe first, then the selection; no map mutation in between.
      expect(invocations, ['legacy:$bootstrapMethod', 'legacy:$routeMethod']);
      expect(osm.interactionEventsClientFor(7), isNotNull);
      osm.close(7);
    });

    test('camera-only host keeps interactions on the legacy plane', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachInteractionEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, ['legacy:$bootstrapMethod']);
      expect(osm.interactionEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('rejected selection keeps legacy and unregisters the handlers',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        if (call.method == routeMethod) {
          throw PlatformException(code: 'stale_session');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachInteractionEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.interactionEventsClientFor(7), isNull);

      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      // The pending client was deactivated: a pigeon callback finds no
      // handler, while the legacy plane keeps delivering.
      await emitNativeSinglePress(7, 47.0, -1.0);
      await emitLegacyPress('receiveSinglePress', 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('older host without the selection endpoint keeps legacy', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        if (call.method == routeMethod) throw MissingPluginException();
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(osm.interactionEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('the decision is frozen: repeat attaches never re-negotiate',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      expect(
        invocations.where((m) => m == 'legacy:$routeMethod').length,
        1,
      );
      osm.close(7);
    });

    test('concurrent attaches converge on one probe and one selection',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selections = await Future.wait([
        osm.attachInteractionEventsRoute(7, optIn: true),
        osm.attachInteractionEventsRoute(7, optIn: true),
      ]);
      expect(selections, [
        CameraRouteSelection.generated,
        CameraRouteSelection.generated,
      ]);
      expect(
        invocations.where((m) => m == 'legacy:$routeMethod').length,
        1,
      );
      osm.close(7);
    });
  });

  group('uncertain negotiation outcomes', () {
    test('selection timeout with a confirmed rollback keeps legacy delivery',
        () async {
      final selections = <String>[];
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        if (call.method == routeMethod) {
          final route = (call.arguments as Map)['route'] as String;
          selections.add(route);
          if (route == 'pigeon') {
            // The reply is lost: Dart times out while the host may already
            // have processed the switch.
            return Completer<Object?>().future;
          }
          return true; // rollback confirmed
        }
        return null;
      });
      final osm = MethodChannelOSM();
      osm.lifecycleRouteSelectionTimeout = const Duration(milliseconds: 30);
      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      // The rollback rode the same channel after the pending selection.
      expect(selections, ['pigeon', 'legacy']);
      expect(osm.interactionEventsClientFor(7), isNull);

      // Handlers were deactivated: pigeon callbacks deliver nothing while
      // the confirmed legacy plane keeps delivering presses.
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitNativeSinglePress(7, 47.0, -1.0);
      await emitLegacyPress('receiveSinglePress', 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('an unconfirmed rollback aborts attachment without freezing a route',
        () async {
      var hostResponsive = false;
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
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
        osm.attachInteractionEventsRoute(7, optIn: true),
        throwsA(isA<InteractionRouteUncertainException>()),
      );
      expect(osm.interactionEventsClientFor(7), isNull);

      // The pending client was deactivated: a pigeon callback finds no
      // handler while the host's route is unknown.
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitNativeSinglePress(7, 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);

      // No decision was frozen: once the host answers, a retry negotiates
      // and delivers normally.
      hostResponsive = true;
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      await emitNativeSinglePress(7, 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('a rejected rollback aborts attachment', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        if (call.method == routeMethod) {
          final route = (call.arguments as Map)['route'] as String;
          if (route == 'pigeon') return Completer<Object?>().future;
          throw PlatformException(code: 'disposed');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      osm.lifecycleRouteSelectionTimeout = const Duration(milliseconds: 30);
      await osm.init(7);
      await expectLater(
        osm.attachInteractionEventsRoute(7, optIn: true),
        throwsA(isA<InteractionRouteUncertainException>()),
      );
      expect(osm.interactionEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('close during an uncertain selection discards instead of aborting',
        () async {
      final gate = Completer<Object?>();
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        // Neither the selection nor the rollback ever answers.
        if (call.method == routeMethod) return gate.future;
        return null;
      });
      final osm = MethodChannelOSM();
      osm.lifecycleRouteSelectionTimeout = const Duration(milliseconds: 30);
      await osm.init(7);
      final pending = osm.attachInteractionEventsRoute(7, optIn: true);
      await Future<void>.delayed(Duration.zero);
      osm.close(7);
      // The attachment is gone: the stale uncertain outcome is discarded,
      // not surfaced as an abort, and nothing is frozen.
      expect(await pending, CameraRouteSelection.legacy);
      expect(osm.interactionEventsClientFor(7), isNull);

      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...interactionBootstrap, 'sessionToken': 'token-7-new'};
        }
        return true;
      });
      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitNativeSinglePress(7, 47.0, -1.0, token: 'token-7-new');
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('typed delivery', () {
    test('single and long presses forward with full coordinate precision',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);

      final taps = <SingleTapEvent>[];
      final longPresses = <LongTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      final sub2 = osm.onLongPressMapClickListener(7).listen(longPresses.add);

      // Wire doubles carry the host's full precision; the values sit one
      // representable step apart from round numbers to catch any lossy
      // conversion or map round-trip.
      const lat = 47.218071429999996;
      const lon = -1.5536219999999902;
      const longLat = 8.000000000000002;
      const longLon = -0.9999999999999999;
      await emitNativeSinglePress(7, lat, lon);
      await emitNativeLongPress(7, longLat, longLon);
      await Future<void>.delayed(Duration.zero);

      expect(taps.length, 1);
      expect(taps.single.mapId, 7);
      expect(taps.single.value.latitude, lat);
      expect(taps.single.value.longitude, lon);
      expect(longPresses.length, 1);
      expect(longPresses.single.mapId, 7);
      expect(longPresses.single.value.latitude, longLat);
      expect(longPresses.single.value.longitude, longLon);
      await sub.cancel();
      await sub2.cancel();
      osm.close(7);
    });

    test('interactions are discrete: repeated presses are never coalesced',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      // Two identical taps are two events, unlike readiness transitions.
      await emitNativeSinglePress(7, 47.0, -1.0);
      await emitNativeSinglePress(7, 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 2);
      await sub.cancel();
      osm.close(7);
    });

    test('exactly one route: legacy tap messages are dropped on the '
        'generated route (no duplicate delivery)', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      final taps = <SingleTapEvent>[];
      final longPresses = <LongTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      final sub2 = osm.onLongPressMapClickListener(7).listen(longPresses.add);

      await emitNativeSinglePress(7, 47.0, -1.0);
      // The host must never emit on both planes; if it does (a stale or
      // duplicated emission), the legacy copy is dropped, not re-delivered.
      await emitLegacyPress('receiveSinglePress', 47.0, -1.0);
      await emitNativeLongPress(7, 48.0, -2.0);
      await emitLegacyPress('receiveLongPress', 48.0, -2.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      expect(longPresses.length, 1);
      await sub.cancel();
      await sub2.cancel();
      osm.close(7);
    });

    test('without opt-in the legacy interaction events flow unchanged',
        () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: false);
      final taps = <SingleTapEvent>[];
      final longPresses = <LongTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      final sub2 = osm.onLongPressMapClickListener(7).listen(longPresses.add);
      await emitLegacyPress('receiveSinglePress', 47.5, -1.5);
      await emitLegacyPress('receiveLongPress', 48.5, -2.5);
      await Future<void>.delayed(Duration.zero);
      // Legacy semantics preserved: every message delivers once.
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
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);

      await emitNativeSinglePress(7, 1.0, 2.0, token: 'token-7-replaced');
      await emitNativeSinglePress(7, 3.0, 4.0, generation: 1);
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);

      // The live identity still delivers.
      await emitNativeSinglePress(7, 5.0, 6.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      expect(taps.single.value.latitude, 5.0);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('two-map isolation', () {
    test('each map receives only its own callbacks', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {
            ...interactionBootstrap,
            'sessionToken': 'token-8',
          };
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      expect(
        await osm.attachInteractionEventsRoute(8, optIn: true),
        CameraRouteSelection.generated,
      );

      final taps7 = <EventOSM>[];
      final taps8 = <EventOSM>[];
      final sub7 = osm.onSinglePressMapClickListener(7).listen(taps7.add);
      final sub8 = osm.onSinglePressMapClickListener(8).listen(taps8.add);

      await emitNativeSinglePress(8, 8.0, 8.0, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(taps7, isEmpty);
      expect(taps8.length, 1);
      expect(taps8.single.mapId, 8);

      // Map 7's identity on map 8's channel is stale: dropped.
      await emitNativeSinglePress(8, 9.0, 9.0, token: 'token-7');
      // Map 8's identity on map 7's channel is stale: dropped.
      await emitNativeSinglePress(7, 10.0, 10.0, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(taps7, isEmpty);
      expect(taps8.length, 1);

      await emitNativeSinglePress(7, 7.0, 7.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps7.length, 1);
      expect(taps7.single.mapId, 7);
      expect(taps8.length, 1);

      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });

    test(
        'a disposed map\'s typed callbacks never reach the live map\'s '
        'streams',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {
            ...interactionBootstrap,
            'sessionToken': 'token-8',
          };
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      await osm.attachInteractionEventsRoute(8, optIn: true);

      // Dispose map 7 only; map 8 keeps delivering.
      osm.close(7);
      final taps8 = <EventOSM>[];
      final sub8 = osm.onSinglePressMapClickListener(8).listen(taps8.add);
      await emitNativeSinglePress(8, 8.0, 8.0, token: 'token-8');
      // Late callback for the disposed map finds no handler.
      await emitNativeSinglePress(7, 7.0, 7.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps8.length, 1);
      expect(taps8.single.mapId, 8);
      await sub8.cancel();
      osm.close(8);
    });
  });

  group('recreation and disposal', () {
    test('disposal unregisters handlers; late callbacks deliver nothing',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      final client = osm.interactionEventsClientFor(7)!;
      expect(client.isActive, isTrue);

      osm.close(7);
      expect(osm.interactionEventsClientFor(7), isNull);
      expect(client.isActive, isFalse);

      // Late native callbacks find no handler and never throw into the test.
      await emitNativeSinglePress(7, 47.0, -1.0);
      await emitNativeLongPress(7, 47.0, -1.0);
      await emitLegacyPress('receiveSinglePress', 47.0, -1.0);
    });

    test('recreation decides freshly against the new session identity',
        () async {
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...interactionBootstrap, 'sessionToken': token};
        }
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      osm.close(7);

      // Replacement attachment: the recreated native session mints a new
      // token; the old identity must never deliver again.
      token = 'token-7-recreated';
      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitNativeSinglePress(7, 1.0, 2.0, token: 'token-7');
      await Future<void>.delayed(Duration.zero);
      expect(taps, isEmpty);
      await emitNativeSinglePress(7, 3.0, 4.0, token: 'token-7-recreated');
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      expect(taps.single.value.latitude, 3.0);
      await sub.cancel();
      osm.close(7);
    });

    test('recreation without opt-in returns to the legacy plane', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      osm.close(7);

      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: false),
        CameraRouteSelection.legacy,
      );
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitLegacyPress('receiveSinglePress', 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('a stale client teardown never unregisters the replacement',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      final staleClient = osm.interactionEventsClientFor(7)!;
      osm.close(7);

      await osm.init(7);
      await osm.attachInteractionEventsRoute(7, optIn: true);
      // Late teardown of the disposed attachment's client: identity-checked,
      // the live handlers must survive.
      staleClient.dispose();
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitNativeSinglePress(7, 47.0, -1.0);
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('close during negotiation discards the stale decision', () async {
      final selectionGate = Completer<Object?>();
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return interactionBootstrap;
        if (call.method == routeMethod) return selectionGate.future;
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final pending = osm.attachInteractionEventsRoute(7, optIn: true);
      // Let the probe run and the selection start, then dispose.
      await Future<void>.delayed(Duration.zero);
      osm.close(7);
      selectionGate.complete(true);
      expect(await pending, CameraRouteSelection.legacy);
      expect(osm.interactionEventsClientFor(7), isNull);

      // The replacement attachment negotiates and delivers normally.
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...interactionBootstrap, 'sessionToken': 'token-7-new'};
        }
        return true;
      });
      await osm.init(7);
      expect(
        await osm.attachInteractionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final taps = <SingleTapEvent>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitNativeSinglePress(7, 47.0, -1.0, token: 'token-7-new');
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });
}
