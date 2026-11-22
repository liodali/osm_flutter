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
}
