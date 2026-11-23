// Lifecycle event routing tests: the frozen pre-initialization negotiation
// (opt-in x host capability x route selection), exactly-once readiness
// delivery, single-route enforcement against the legacy plane, session
// identity (stale callbacks), two-map isolation, recreation and disposal.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';
const legacyChannelName8 = 'plugins.dali.hamza/osmview_8';

String readyChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapLifecycleEventsApi.'
    'onMapReady.view_$viewId';

String restoredChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapLifecycleEventsApi.'
    'onMapRestored.view_$viewId';

const bootstrapMethod = 'map#bootstrap#protocol';
const routeMethod = 'map#events#lifecycle#route';

/// Host advertising the lifecycle event capability.
final Map<Object?, Object?> lifecycleBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'events.lifecycle'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: lifecycle events must stay legacy.
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
  Future<void> emitNativeReady(
    int viewId,
    bool isReady, {
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
      isReady,
    ]);
    await messenger.handlePlatformMessage(
      readyChannel(viewId),
      message,
      (_) {},
    );
  }

  Future<void> emitNativeRestored(
    int viewId, {
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
    ]);
    await messenger.handlePlatformMessage(
      restoredChannel(viewId),
      message,
      (_) {},
    );
  }

  /// Simulates a legacy-plane lifecycle message from the host.
  Future<void> emitLegacy(String method, Object? arguments,
      {String channel = legacyChannelName}) async {
    final message =
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments));
    await messenger.handlePlatformMessage(channel, message, (_) {});
  }

  tearDown(() {
    invocations.clear();
    messenger.setMockMethodCallHandler(const MethodChannel(legacyChannelName), null);
    messenger.setMockMethodCallHandler(const MethodChannel(legacyChannelName8), null);
    // Drop any handlers a failed test left registered.
    for (final viewId in [7, 8]) {
      generated.NativeMapLifecycleEventsApi.setUp(
        null,
        messageChannelSuffix: 'view_$viewId',
      );
    }
  });

  group('attachLifecycleEventsRoute negotiation', () {
    test('no opt-in keeps the legacy route without probing or selecting',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLifecycleEventsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, isEmpty);
      expect(osm.lifecycleEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('capability + opt-in negotiates the route before initialization',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
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
      final selection = await osm.attachLifecycleEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      // Probe first, then the selection; no map mutation in between.
      expect(invocations, ['legacy:$bootstrapMethod', 'legacy:$routeMethod']);
      expect(osm.lifecycleEventsClientFor(7), isNotNull);
      osm.close(7);
    });

    test('camera-only host keeps lifecycle events on the legacy plane',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLifecycleEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, ['legacy:$bootstrapMethod']);
      expect(osm.lifecycleEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('rejected selection keeps legacy and unregisters the handlers',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) {
          throw PlatformException(code: 'stale_session');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLifecycleEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.lifecycleEventsClientFor(7), isNull);

      final events = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(events.add);
      // The pending client was deactivated: a pigeon callback finds no
      // handler, while the legacy plane keeps delivering.
      await emitNativeReady(7, true);
      await emitLegacy('map#init', true);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('older host without the selection endpoint keeps legacy', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) throw MissingPluginException();
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(osm.lifecycleEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('the decision is frozen: repeat attaches never re-negotiate',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
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
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selections = await Future.wait([
        osm.attachLifecycleEventsRoute(7, optIn: true),
        osm.attachLifecycleEventsRoute(7, optIn: true),
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
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
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
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      // The rollback rode the same channel after the pending selection.
      expect(selections, ['pigeon', 'legacy']);
      expect(osm.lifecycleEventsClientFor(7), isNull);

      // Handlers were deactivated: pigeon callbacks deliver nothing while
      // the confirmed legacy plane keeps delivering readiness.
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitNativeReady(7, true);
      await emitLegacy('map#init', true);
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('an unconfirmed rollback aborts attachment without freezing a route',
        () async {
      var hostResponsive = false;
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
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
        osm.attachLifecycleEventsRoute(7, optIn: true),
        throwsA(isA<LifecycleRouteUncertainException>()),
      );
      expect(osm.lifecycleEventsClientFor(7), isNull);

      // The pending client was deactivated: a pigeon callback finds no
      // handler while the host's route is unknown.
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(ready, isEmpty);

      // No decision was frozen: once the host answers, a retry negotiates
      // and delivers normally.
      hostResponsive = true;
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('a rejected rollback aborts attachment', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
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
        osm.attachLifecycleEventsRoute(7, optIn: true),
        throwsA(isA<LifecycleRouteUncertainException>()),
      );
      expect(osm.lifecycleEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('close during an uncertain selection discards instead of aborting',
        () async {
      final gate = Completer<Object?>();
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        // Neither the selection nor the rollback ever answers.
        if (call.method == routeMethod) return gate.future;
        return null;
      });
      final osm = MethodChannelOSM();
      osm.lifecycleRouteSelectionTimeout = const Duration(milliseconds: 30);
      await osm.init(7);
      final pending = osm.attachLifecycleEventsRoute(7, optIn: true);
      await Future<void>.delayed(Duration.zero);
      osm.close(7);
      // The attachment is gone: the stale uncertain outcome is discarded,
      // not surfaced as an abort, and nothing is frozen.
      expect(await pending, CameraRouteSelection.legacy);
      expect(osm.lifecycleEventsClientFor(7), isNull);

      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...lifecycleBootstrap, 'sessionToken': 'token-7-new'};
        }
        return true;
      });
      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      osm.close(7);
    });
  });

  group('exactly-once readiness on the generated route', () {
    late MethodChannelOSM osm;
    late List<EventOSM> readyEvents;
    late List<EventOSM> restoredEvents;
    late StreamSubscription<EventOSM> readySub;
    late StreamSubscription<EventOSM> restoredSub;

    setUp(() async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      readyEvents = [];
      restoredEvents = [];
      readySub = osm.onMapIsReady(7).listen(readyEvents.add);
      restoredSub = osm.onMapRestored(7).listen(restoredEvents.add);
    });

    tearDown(() async {
      await readySub.cancel();
      await restoredSub.cancel();
      osm.close(7);
    });

    test('one native readiness delivers exactly one public event', () async {
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(readyEvents.map((e) => e.value), [true]);
      expect(readyEvents.single.mapId, 7);
    });

    test('duplicate identical readiness is coalesced', () async {
      await emitNativeReady(7, true);
      await emitNativeReady(7, true);
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(readyEvents.map((e) => e.value), [true]);
    });

    test('readiness transitions always deliver', () async {
      await emitNativeReady(7, true);
      await emitNativeReady(7, false);
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(readyEvents.map((e) => e.value), [true, false, true]);
    });

    test('legacy map#init is dropped while the generated route owns the map',
        () async {
      await emitNativeReady(7, true);
      // A stale or duplicated legacy emission must not double-deliver.
      await emitLegacy('map#init', true);
      await emitLegacy('map#init', false);
      await Future<void>.delayed(Duration.zero);
      expect(readyEvents.map((e) => e.value), [true]);
    });

    test('restoration delivers once and legacy map#restored is dropped',
        () async {
      await emitNativeRestored(7);
      await emitLegacy('map#restored', null);
      await Future<void>.delayed(Duration.zero);
      expect(restoredEvents.length, 1);
      expect(restoredEvents.single.mapId, 7);
      // Restoration is discrete: a second native restoration delivers again.
      await emitNativeRestored(7);
      await Future<void>.delayed(Duration.zero);
      expect(restoredEvents.length, 2);
    });

    test('stale session identity is dropped (token and generation)',
        () async {
      await emitNativeReady(7, true, token: 'token-other');
      await emitNativeReady(7, true, generation: 1);
      await emitNativeRestored(7, token: 'token-other');
      await emitNativeRestored(7, generation: 1);
      await Future<void>.delayed(Duration.zero);
      expect(readyEvents, isEmpty);
      expect(restoredEvents, isEmpty);
      // The live session still delivers afterwards.
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(readyEvents.map((e) => e.value), [true]);
    });

    test('non-lifecycle legacy events keep flowing untouched', () async {
      final taps = <EventOSM>[];
      final sub = osm.onSinglePressMapClickListener(7).listen(taps.add);
      await emitLegacy('receiveSinglePress', {'lat': 1.0, 'lon': 2.0});
      await Future<void>.delayed(Duration.zero);
      expect(taps.length, 1);
      await sub.cancel();
    });
  });

  group('two-map isolation', () {
    test('each map negotiates and receives only its own callbacks', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {
            ...lifecycleBootstrap,
            'sessionToken': 'token-8',
          };
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      expect(
        await osm.attachLifecycleEventsRoute(8, optIn: true),
        CameraRouteSelection.generated,
      );

      final ready7 = <EventOSM>[];
      final ready8 = <EventOSM>[];
      final sub7 = osm.onMapIsReady(7).listen(ready7.add);
      final sub8 = osm.onMapIsReady(8).listen(ready8.add);

      await emitNativeReady(8, true, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(ready7, isEmpty);
      expect(ready8.map((e) => e.value), [true]);

      // Map 7's identity on map 8's channel is stale: dropped.
      await emitNativeReady(8, true, token: 'token-7');
      await emitNativeReady(7, true, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(ready7, isEmpty);
      expect(ready8.length, 1);

      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(ready7.map((e) => e.value), [true]);
      expect(ready8.length, 1);

      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });

    test('a disposed map\'s active subscription is closed, not forwarded the '
        'replacement events while another map keeps the source open',
        () async {
      await mockLegacy((call) async => null);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8); // keeps the shared source open across close(7)
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      await osm.attachLifecycleEventsRoute(8, optIn: false);

      final oldRestored = <EventOSM>[];
      var oldDone = false;
      final oldSub = osm.onMapRestored(7).listen(
        oldRestored.add,
        onDone: () => oldDone = true,
      );
      await emitLegacy('map#restored', null); // live to the active listener
      await Future<void>.delayed(Duration.zero);
      expect(oldRestored.length, 1);

      // Dispose map 7 only: map 8 keeps the shared source stream open, so
      // nothing else would complete the old subscription.
      osm.close(7);
      await Future<void>.delayed(Duration.zero);
      expect(oldDone, isTrue,
          reason: 'disposal must complete the attachment-owned wrapper');

      // Replacement attachment for the same view id, with its own listener.
      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      final newRestored = <EventOSM>[];
      final newSub = osm.onMapRestored(7).listen(newRestored.add);
      await emitLegacy('map#restored', null);
      await Future<void>.delayed(Duration.zero);

      expect(newRestored.length, 1,
          reason: 'the replacement\'s own subscriber receives its event');
      expect(oldRestored.length, 1,
          reason: 'the disposed subscription must not see the replacement');
      expect(oldDone, isTrue);

      // Map 8 is untouched by map 7's disposal cycle.
      final restored8 = <EventOSM>[];
      final sub8 = osm.onMapRestored(8).listen(restored8.add);
      await emitLegacy('map#restored', null, channel: legacyChannelName8);
      await Future<void>.delayed(Duration.zero);
      expect(restored8.length, 1);

      await oldSub.cancel();
      await newSub.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });

    test('mixed routes: generated map drops legacy, legacy map keeps it',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return cameraOnlyBootstrap;
        return null;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      expect(
        await osm.attachLifecycleEventsRoute(8, optIn: true),
        CameraRouteSelection.legacy,
      );

      final ready7 = <EventOSM>[];
      final ready8 = <EventOSM>[];
      final sub7 = osm.onMapIsReady(7).listen(ready7.add);
      final sub8 = osm.onMapIsReady(8).listen(ready8.add);

      await emitLegacy('map#init', true);
      await emitLegacy('map#init', true, channel: legacyChannelName8);
      await Future<void>.delayed(Duration.zero);
      expect(ready7, isEmpty);
      expect(ready8.map((e) => e.value), [true]);

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
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      final client = osm.lifecycleEventsClientFor(7)!;
      expect(client.isActive, isTrue);

      osm.close(7);
      expect(osm.lifecycleEventsClientFor(7), isNull);
      expect(client.isActive, isFalse);

      // Late native callbacks find no handler and never throw into the test.
      await emitNativeReady(7, true);
      await emitNativeRestored(7);
      await emitLegacy('map#init', true);
    });

    test('recreation decides freshly against the new session identity',
        () async {
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...lifecycleBootstrap, 'sessionToken': token};
        }
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      osm.close(7);

      // Replacement attachment: the recreated native session mints a new
      // token; the old identity must never deliver again.
      token = 'token-7-recreated';
      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitNativeReady(7, true, token: 'token-7');
      await Future<void>.delayed(Duration.zero);
      expect(ready, isEmpty);
      await emitNativeReady(7, true, token: 'token-7-recreated');
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('recreation without opt-in returns to the legacy plane', () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      osm.close(7);

      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: false),
        CameraRouteSelection.legacy,
      );
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitLegacy('map#init', true);
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('close during negotiation discards the stale decision', () async {
      final selectionGate = Completer<Object?>();
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) return selectionGate.future;
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final pending = osm.attachLifecycleEventsRoute(7, optIn: true);
      // Let the probe run and the selection start, then dispose.
      await Future<void>.delayed(Duration.zero);
      osm.close(7);
      selectionGate.complete(true);
      expect(await pending, CameraRouteSelection.legacy);
      expect(osm.lifecycleEventsClientFor(7), isNull);

      // The replacement attachment negotiates and delivers normally.
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...lifecycleBootstrap, 'sessionToken': 'token-7-new'};
        }
        return true;
      });
      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitNativeReady(7, true, token: 'token-7-new');
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('a failed stale negotiation never overwrites the replacement',
        () async {
      final selectionGate = Completer<Object?>();
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...lifecycleBootstrap, 'sessionToken': token};
        }
        if (call.method == routeMethod) {
          final args = call.arguments as Map;
          if (args['sessionToken'] == 'token-7') return selectionGate.future;
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      final pending = osm.attachLifecycleEventsRoute(7, optIn: true);
      await Future<void>.delayed(Duration.zero);
      osm.close(7);

      // The replacement attaches and freezes the generated route first.
      token = 'token-7-new';
      await osm.init(7);
      expect(
        await osm.attachLifecycleEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final replacement = osm.lifecycleEventsClientFor(7);
      expect(replacement, isNotNull);

      // The stale negotiation now fails: it must discard its decision
      // without unfreezing the replacement's route.
      selectionGate.completeError(PlatformException(code: 'stale_session'));
      expect(await pending, CameraRouteSelection.legacy);
      expect(identical(osm.lifecycleEventsClientFor(7), replacement), isTrue);

      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitNativeReady(7, true, token: 'token-7-new');
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('a stale client teardown never unregisters the replacement',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      final staleClient = osm.lifecycleEventsClientFor(7)!;
      osm.close(7);

      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      // Late teardown of the disposed attachment's client: identity-checked,
      // the live handlers must survive.
      staleClient.dispose();
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await emitNativeReady(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('legacy plane preservation', () {
    test('without opt-in the legacy lifecycle events flow unchanged',
        () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      final ready = <EventOSM>[];
      final restored = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      final sub2 = osm.onMapRestored(7).listen(restored.add);
      await emitLegacy('map#init', true);
      await emitLegacy('map#init', true);
      await emitLegacy('map#restored', null);
      await Future<void>.delayed(Duration.zero);
      // Legacy semantics are preserved byte-for-byte: no coalescing.
      expect(ready.map((e) => e.value), [true, true]);
      expect(restored.length, 1);
      await sub.cancel();
      await sub2.cancel();
      osm.close(7);
    });
  });

  group('lifecycle replay before subscription', () {
    test('restoration flushed during selection replays to a late subscriber',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) {
          // Android flushes a buffered restoration while answering the
          // selection, before the controller has subscribed.
          await emitNativeRestored(7);
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      // Subscribe only after attachment returns (the controller's ordering).
      final restored = <EventOSM>[];
      final sub = osm.onMapRestored(7).listen(restored.add);
      await Future<void>.delayed(Duration.zero);
      expect(restored.length, 1);
      expect(restored.single.mapId, 7);
      await sub.cancel();
      osm.close(7);
    });

    test('readiness emitted during attachment replays to a late subscriber',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) {
          await emitNativeReady(7, true);
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      final ready = <EventOSM>[];
      final sub = osm.onMapIsReady(7).listen(ready.add);
      await Future<void>.delayed(Duration.zero);
      expect(ready.map((e) => e.value), [true]);
      await sub.cancel();
      osm.close(7);
    });

    test('replayed restoration is not redelivered; live events flow once',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) {
          await emitNativeRestored(7);
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      final restored = <EventOSM>[];
      final sub = osm.onMapRestored(7).listen(restored.add);
      await Future<void>.delayed(Duration.zero);
      expect(restored.length, 1);
      // A new restoration after subscription flows live, exactly once.
      await emitNativeRestored(7);
      await Future<void>.delayed(Duration.zero);
      expect(restored.length, 2);
      await sub.cancel();
      osm.close(7);
    });

    test('buffered events are dropped on close, not leaked to a replacement',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        if (call.method == routeMethod) {
          await emitNativeRestored(7);
          return true;
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      // Dispose before anyone subscribes: the buffered restoration must not
      // leak into the replacement attachment.
      osm.close(7);
      // Replacement host does not flush a restoration during selection.
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return lifecycleBootstrap;
        return true;
      });
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: true);
      final restored = <EventOSM>[];
      final sub = osm.onMapRestored(7).listen(restored.add);
      await Future<void>.delayed(Duration.zero);
      expect(restored, isEmpty);
      await sub.cancel();
      osm.close(7);
    });

    test('a stream minted before disposal never replays stale restoration',
        () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      // A restoration is buffered while nobody listens.
      await emitLegacy('map#restored', null);
      // Grab the stream before disposal; it captures the buffer above.
      final oldStream = osm.onMapRestored(7);
      osm.close(7);
      // Replacement attachment with the same view id.
      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      final stale = <EventOSM>[];
      var staleDone = false;
      final sub = oldStream.listen(stale.add, onDone: () => staleDone = true);
      await Future<void>.delayed(Duration.zero);
      expect(stale, isEmpty);
      expect(staleDone, isTrue);
      await sub.cancel();
      osm.close(7);
    });

    test('a stale stream does not mark the replacement attachment listened',
        () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      final oldStream = osm.onMapRestored(7);
      osm.close(7);
      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      // Listening to the disposed attachment's stream must not flip the
      // replacement's listened flag.
      final sub = oldStream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      // The replacement therefore still buffers for its own late listener.
      await emitLegacy('map#restored', null);
      final restored = <EventOSM>[];
      final sub2 = osm.onMapRestored(7).listen(restored.add);
      await Future<void>.delayed(Duration.zero);
      expect(restored.length, 1);
      await sub2.cancel();
      osm.close(7);
    });

    test('closing the last map completes the lifecycle streams', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      var restoredDone = false;
      var readyDone = false;
      final restoredSub = osm.onMapRestored(7).listen(
        (_) {},
        onDone: () => restoredDone = true,
      );
      final readySub = osm.onMapIsReady(7).listen(
        (_) {},
        onDone: () => readyDone = true,
      );
      osm.close(7);
      await Future<void>.delayed(Duration.zero);
      expect(restoredDone, isTrue,
          reason: 'restoration wrapper must close with its source');
      expect(readyDone, isTrue,
          reason: 'readiness wrapper must close with its source');
      await restoredSub.cancel();
      await readySub.cancel();
    });

    test('legacy restoration emitted before subscription is replayed',
        () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLifecycleEventsRoute(7, optIn: false);
      await emitLegacy('map#restored', null); // no listener yet
      final restored = <EventOSM>[];
      final sub = osm.onMapRestored(7).listen(restored.add);
      await Future<void>.delayed(Duration.zero);
      expect(restored.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });
}
