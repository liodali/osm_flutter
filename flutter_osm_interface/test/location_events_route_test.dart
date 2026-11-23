// User-location event routing tests: the frozen pre-initialization
// negotiation (opt-in x host capability x route selection), payload
// precision of the typed callback against the legacy receiveUserLocation
// decode, the host-owned rate (the Dart forwarder never coalesces),
// exactly-once delivery against the legacy plane, independence from the
// tracking/updates command routes, session identity (stale callbacks),
// disposal, two-map isolation, attachment-scoped streams and recreation.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';
const legacyChannelName8 = 'plugins.dali.hamza/osmview_8';

String locationChangedChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapLocationEventsApi.'
    'onLocationChanged.view_$viewId';

String pigeonCommandChannel(String api, String method, int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.$api.$method.view_$viewId';

const bootstrapMethod = 'map#bootstrap#protocol';
const routeMethod = 'map#events#location#route';

/// Host advertising the user-location event capability.
final Map<Object?, Object?> locationEventsBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'events.location'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Host advertising the event capability next to the typed tracking and
/// continuous-updates command capabilities (current schema generation:
/// tracking also accepts omitted anchors).
final Map<Object?, Object?> locationFamilyBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': [
    'camera',
    'events.location',
    'location.updates',
    'location.tracking',
    'location.tracking.anchor',
  ],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Host without the user-location event capability.
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

ByteData? pigeonReply(Object? value) =>
    const StandardMessageCodec().encodeMessage(<Object?>[value]);

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

  Future<void> mockPigeonCommand(String api, String method) async {
    messenger.setMockMessageHandler(
      pigeonCommandChannel(api, method, 7),
      (ByteData? message) async {
        invocations.add('pigeon:$method');
        return pigeonReply(null);
      },
    );
  }

  /// Host that advertises [bootstrap] and accepts the event route
  /// selection, recording every legacy method it sees.
  Future<void> mockHost(Map<Object?, Object?> bootstrap) async {
    await mockLegacy((call) async {
      invocations.add('legacy:${call.method}');
      if (call.method == bootstrapMethod) return bootstrap;
      if (call.method == routeMethod) return true;
      return null;
    });
  }

  Future<void> emitNativeLocation(
    int viewId,
    double latitude,
    double longitude,
    double heading, {
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
      latitude,
      longitude,
      heading,
    ]);
    await messenger.handlePlatformMessage(
      locationChangedChannel(viewId),
      message,
      (_) {},
    );
  }

  /// Simulates a legacy-plane receiveUserLocation message from the host.
  Future<void> emitLegacyLocation(
    double lat,
    double lon,
    double heading, {
    String channel = legacyChannelName,
  }) async {
    final message = const StandardMethodCodec().encodeMethodCall(
      MethodCall('receiveUserLocation', {'lat': lat, 'lon': lon, 'heading': heading}),
    );
    await messenger.handlePlatformMessage(channel, message, (_) {});
  }

  tearDown(() {
    invocations.clear();
    for (final channel in [legacyChannelName, legacyChannelName8]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    for (final viewId in [7, 8]) {
      generated.NativeMapLocationEventsApi.setUp(
        null,
        messageChannelSuffix: 'view_$viewId',
      );
    }
    for (final method in ['enableTracking', 'disableTracking']) {
      messenger.setMockMessageHandler(
        pigeonCommandChannel('NativeMapTrackingApi', method, 7),
        null,
      );
    }
    for (final method in ['startLocationUpdates', 'stopLocationUpdates']) {
      messenger.setMockMessageHandler(
        pigeonCommandChannel('NativeMapLocationUpdatesApi', method, 7),
        null,
      );
    }
  });

  group('attachLocationEventsRoute negotiation', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationEventsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, isEmpty);
      expect(osm.locationEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('capability + opt-in negotiates the route before initialization',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return locationEventsBootstrap;
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
      final selection = await osm.attachLocationEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      expect(invocations, ['legacy:$bootstrapMethod', 'legacy:$routeMethod']);
      expect(osm.locationEventsClientFor(7), isNotNull);
      osm.close(7);
    });

    test('camera-only host keeps location fixes on the legacy plane',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachLocationEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(invocations, ['legacy:$bootstrapMethod']);
      expect(osm.locationEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('rejected selection keeps legacy and unregisters the handler',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return locationEventsBootstrap;
        if (call.method == routeMethod) {
          throw PlatformException(code: 'stale_session');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachLocationEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(osm.locationEventsClientFor(7), isNull);

      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);
      await emitNativeLocation(7, 47.0, -1.0, 0.0);
      await emitLegacyLocation(47.0, -1.0, 0.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('the decision is frozen: repeat attaches never re-negotiate',
        () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      await osm.attachLocationEventsRoute(7, optIn: true);
      expect(invocations.where((m) => m == 'legacy:$routeMethod').length, 1);
      osm.close(7);
    });

    test('an unconfirmed rollback aborts attachment without freezing a route',
        () async {
      var hostResponsive = false;
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return locationEventsBootstrap;
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
        osm.attachLocationEventsRoute(7, optIn: true),
        throwsA(isA<LocationRouteUncertainException>()),
      );
      expect(osm.locationEventsClientFor(7), isNull);

      hostResponsive = true;
      expect(
        await osm.attachLocationEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      osm.close(7);
    });
  });

  group('typed location delivery', () {
    test('fixes forward with full coordinate and heading precision',
        () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      const lat = 47.218071429999996;
      const lon = -1.5536219999999902;
      const heading = 359.99999999999994;
      await emitNativeLocation(7, lat, lon, heading);
      await Future<void>.delayed(Duration.zero);

      expect(fixes.length, 1);
      expect(fixes.single.mapId, 7);
      expect(fixes.single.value.latitude, lat);
      expect(fixes.single.value.longitude, lon);
      // The heading decodes exactly like the legacy payload: the raw
      // degrees land in `angle` with no unit conversion.
      expect(fixes.single.value.angle, heading);
      await sub.cancel();
      osm.close(7);
    });

    test('the Dart forwarder never coalesces: the host owns the rate',
        () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      // Five fixes inside any host interval (Android coalesces to 1 s,
      // Apple forwards every CoreLocation callback): whatever the host
      // emits arrives once each, in order, without a Dart-side buffer.
      for (var i = 0; i < 5; i++) {
        unawaited(emitNativeLocation(7, 47.0 + i, -1.0, i * 10.0));
      }
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 5);
      expect(fixes.map((f) => f.value.latitude).toList(), [47.0, 48.0, 49.0, 50.0, 51.0]);
      await sub.cancel();
      osm.close(7);
    });

    test('typed and legacy routes decode the same public event', () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      await emitNativeLocation(7, 47.5, -1.25, 12.5);
      await Future<void>.delayed(Duration.zero);
      final typed = fixes.single;
      expect(typed.value, UserLocation.fromMap({'lat': 47.5, 'lon': -1.25, 'heading': 12.5}));
      expect(typed.value.toMap(), {'lat': 47.5, 'lon': -1.25, 'angle': 12.5});
      await sub.cancel();
      osm.close(7);
    });

    test('exactly one route: legacy fix messages are dropped on the '
        'generated route (no duplicate delivery)', () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      await emitNativeLocation(7, 47.0, -1.0, 1.0);
      await emitLegacyLocation(47.0, -1.0, 1.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('without opt-in the legacy location events flow unchanged',
        () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: false);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);
      await emitLegacyLocation(47.5, -1.5, 90.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.single.value.latitude, 47.5);
      expect(fixes.single.value.longitude, -1.5);
      expect(fixes.single.value.angle, 90.0);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('tracking and updates coexistence', () {
    test('typed tracking + typed updates command routes share the typed '
        'event route; stopping a consumer leaves it in place', () async {
      await mockHost(locationFamilyBootstrap);
      for (final method in ['enableTracking', 'disableTracking']) {
        await mockPigeonCommand('NativeMapTrackingApi', method);
      }
      for (final method in ['startLocationUpdates', 'stopLocationUpdates']) {
        await mockPigeonCommand('NativeMapLocationUpdatesApi', method);
      }
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(await osm.attachTrackingRoute(7, optIn: true),
          CameraRouteSelection.generated);
      expect(await osm.attachLocationUpdatesRoute(7, optIn: true),
          CameraRouteSelection.generated);
      expect(await osm.attachLocationEventsRoute(7, optIn: true),
          CameraRouteSelection.generated);

      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      // Both consumers start on their typed command routes.
      await osm.enableTracking(7);
      await osm.startLocationUpdating(7);
      expect(invocations, containsAll(['pigeon:enableTracking', 'pigeon:startLocationUpdates']));
      expect(invocations, isNot(contains('legacy:trackMe')));
      expect(invocations, isNot(contains('legacy:startLocationUpdating')));

      await emitNativeLocation(7, 47.0, -1.0, 10.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);

      // Stopping one consumer is a command-plane change only: the event
      // route stays frozen and keeps delivering what the host emits.
      await osm.stopLocationUpdating(7);
      expect(invocations, contains('pigeon:stopLocationUpdates'));
      expect(invocations.where((m) => m == 'legacy:$routeMethod').length, 1);
      expect(osm.locationEventsClientFor(7), isNotNull);
      await emitNativeLocation(7, 47.1, -1.1, 20.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 2);
      expect(fixes.last.value.angle, 20.0);

      await osm.disableTracking(7);
      expect(invocations, contains('pigeon:disableTracking'));
      await emitLegacyLocation(47.2, -1.2, 30.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 2,
          reason: 'the legacy plane stays dropped for this attachment');
      await sub.cancel();
      osm.close(7);
    });

    test('legacy tracking and updates coexist with the typed event route',
        () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      // Consumers that never opted in keep their legacy command routes.
      await osm.enableTracking(7, useDirectionMarker: true);
      await osm.startLocationUpdating(7);
      expect(invocations, containsAll(['legacy:trackMe', 'legacy:startLocationUpdating']));

      await emitNativeLocation(7, 47.0, -1.0, 0.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.single.value.latitude, 47.0);

      await osm.stopLocationUpdating(7);
      expect(invocations, contains('legacy:stopLocationUpdating'));
      await sub.cancel();
      osm.close(7);
    });

    test('typed command routes coexist with the legacy event route',
        () async {
      await mockHost(locationFamilyBootstrap);
      for (final method in ['enableTracking']) {
        await mockPigeonCommand('NativeMapTrackingApi', method);
      }
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);
      await osm.attachLocationEventsRoute(7, optIn: false);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      await osm.enableTracking(7);
      expect(invocations, contains('pigeon:enableTracking'));
      expect(invocations, isNot(contains('legacy:$routeMethod')));

      await emitLegacyLocation(47.0, -1.0, 5.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.single.value.angle, 5.0);
      await emitNativeLocation(7, 1.0, 2.0, 3.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1,
          reason: 'no handler is registered on the generated route');
      await sub.cancel();
      osm.close(7);
    });
  });

  group('session identity', () {
    test('stale token or generation callbacks are dropped', () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);

      await emitNativeLocation(7, 1.0, 2.0, 3.0, token: 'token-7-r');
      await emitNativeLocation(7, 3.0, 4.0, 5.0, generation: 1);
      await Future<void>.delayed(Duration.zero);
      expect(fixes, isEmpty);

      await emitNativeLocation(7, 5.0, 6.0, 7.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('two-map isolation', () {
    test('each map receives only its own location callbacks', () async {
      await mockHost(locationEventsBootstrap);
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...locationEventsBootstrap, 'sessionToken': 'token-8'};
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachLocationEventsRoute(7, optIn: true);
      await osm.attachLocationEventsRoute(8, optIn: true);

      final fixes7 = <UserLocationEvent>[];
      final fixes8 = <UserLocationEvent>[];
      final sub7 = osm.onUserPositionListener(7).listen(fixes7.add);
      final sub8 = osm.onUserPositionListener(8).listen(fixes8.add);

      await emitNativeLocation(8, 8.0, 8.0, 8.0, token: 'token-8');
      await emitNativeLocation(8, 9.0, 9.0, 9.0, token: 'token-7');
      await emitNativeLocation(7, 10.0, 10.0, 10.0, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(fixes7, isEmpty);
      expect(fixes8.length, 1);

      await emitNativeLocation(7, 7.0, 7.0, 7.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes7.length, 1);
      expect(fixes8.length, 1);
      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });

    test('one map on the typed route does not switch another map\'s '
        'legacy plane', () async {
      await mockHost(locationEventsBootstrap);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachLocationEventsRoute(7, optIn: true);
      await osm.attachLocationEventsRoute(8, optIn: false);

      final fixes7 = <UserLocationEvent>[];
      final fixes8 = <UserLocationEvent>[];
      final sub7 = osm.onUserPositionListener(7).listen(fixes7.add);
      final sub8 = osm.onUserPositionListener(8).listen(fixes8.add);
      await emitLegacyLocation(47.0, 8.0, 1.0);
      await emitLegacyLocation(48.0, 9.0, 2.0, channel: legacyChannelName8);
      await Future<void>.delayed(Duration.zero);
      expect(fixes7, isEmpty);
      expect(fixes8.single.value.latitude, 48.0);
      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });
  });

  group('recreation and disposal', () {
    test('disposal unregisters the handler; late callbacks deliver nothing',
        () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final client = osm.locationEventsClientFor(7)!;
      expect(client.isActive, isTrue);

      osm.close(7);
      expect(osm.locationEventsClientFor(7), isNull);
      expect(client.isActive, isFalse);

      await emitNativeLocation(7, 47.0, -1.0, 0.0);
      await emitLegacyLocation(47.0, -1.0, 0.0);
    });

    test('recreation decides freshly against the new session identity',
        () async {
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...locationEventsBootstrap, 'sessionToken': token};
        }
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      osm.close(7);

      token = 'token-7-recreated';
      await osm.init(7);
      expect(
        await osm.attachLocationEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);
      await emitNativeLocation(7, 1.0, 2.0, 3.0, token: 'token-7');
      await Future<void>.delayed(Duration.zero);
      expect(fixes, isEmpty);
      await emitNativeLocation(7, 3.0, 4.0, 5.0, token: 'token-7-recreated');
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('recreation without opt-in returns to the legacy plane', () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      osm.close(7);

      await osm.init(7);
      expect(
        await osm.attachLocationEventsRoute(7, optIn: false),
        CameraRouteSelection.legacy,
      );
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);
      await emitLegacyLocation(47.0, -1.0, 0.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('a stale client teardown never unregisters the replacement',
        () async {
      await mockHost(locationEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      final staleClient = osm.locationEventsClientFor(7)!;
      osm.close(7);

      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: true);
      staleClient.dispose();
      final fixes = <UserLocationEvent>[];
      final sub = osm.onUserPositionListener(7).listen(fixes.add);
      await emitNativeLocation(7, 47.0, -1.0, 0.0);
      await Future<void>.delayed(Duration.zero);
      expect(fixes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('an active location subscription of a disposed map completes at '
        'disposal and never receives the recreated map\'s fixes', () async {
      await mockLegacy((call) async => null);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachLocationEventsRoute(7, optIn: false);
      await osm.attachLocationEventsRoute(8, optIn: false);

      final oldFixes = <UserLocationEvent>[];
      var oldDone = false;
      final oldSub = osm.onUserPositionListener(7).listen(
        oldFixes.add,
        onDone: () => oldDone = true,
      );
      await emitLegacyLocation(47.0, -1.0, 1.0);
      await Future<void>.delayed(Duration.zero);
      expect(oldFixes.length, 1);

      osm.close(7);
      await Future<void>.delayed(Duration.zero);
      expect(oldDone, isTrue,
          reason: 'disposal must complete the attachment-owned wrapper');

      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachLocationEventsRoute(7, optIn: false);
      final newFixes = <UserLocationEvent>[];
      final newSub = osm.onUserPositionListener(7).listen(newFixes.add);
      await emitLegacyLocation(48.0, -2.0, 2.0);
      await Future<void>.delayed(Duration.zero);
      expect(newFixes.length, 1);
      expect(oldFixes.length, 1,
          reason: 'the disposed subscription must not see the replacement');

      await oldSub.cancel();
      await newSub.cancel();
      osm.close(7);
      osm.close(8);
    });
  });
}
