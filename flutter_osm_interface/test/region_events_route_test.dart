// Visible-region event routing tests: the frozen pre-initialization
// negotiation (opt-in x host capability x route selection), payload
// precision of the typed callback against the legacy receiveRegionIsChanging
// decode on both host shapes (Android without zoom, Apple with an ignored
// `zoomLevel`), the host-owned rate (the Dart forwarder never coalesces and
// trailing coalesced changes are delivered), exactly-once delivery against
// the legacy plane, session identity (stale callbacks), disposal, two-map
// isolation, attachment-scoped streams and recreation.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';
const legacyChannelName8 = 'plugins.dali.hamza/osmview_8';

String regionChangedChannel(int viewId) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapRegionEventsApi.'
    'onRegionChanged.view_$viewId';

const bootstrapMethod = 'map#bootstrap#protocol';
const routeMethod = 'map#events#region#route';

/// Host advertising the visible-region event capability.
final Map<Object?, Object?> regionEventsBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'events.region'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Host without the visible-region event capability.
final Map<Object?, Object?> cameraOnlyBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Test replica of the generated private codec: wraps the session envelope
/// (129) and the bounds DTO (133) in the pigeon wire form.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeCameraSession) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    } else if (value is generated.NativeBounds) {
      buffer.putUint8(133);
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

/// Classic visible region around the example app's home city.
generated.NativeBounds visibleBounds({
  double north = 48.0,
  double east = 9.0,
  double south = 47.0,
  double west = 8.0,
}) =>
    generated.NativeBounds(north: north, east: east, south: south, west: west);

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

  Future<void> emitNativeRegion(
    int viewId, {
    double centerLatitude = 47.5,
    double centerLongitude = 8.5,
    generated.NativeBounds? bounds,
    double zoom = 12.0,
    String token = 'token-7',
    int generation = 0,
  }) async {
    final message = codec.encodeMessage(<Object?>[
      wireSession(token: token, generation: generation),
      centerLatitude,
      centerLongitude,
      bounds ?? visibleBounds(),
      zoom,
    ]);
    await messenger.handlePlatformMessage(
      regionChangedChannel(viewId),
      message,
      (_) {},
    );
  }

  /// Simulates a legacy-plane receiveRegionIsChanging message from the
  /// host; Apple hosts add a `zoomLevel` the Dart decode never read.
  Future<void> emitLegacyRegion({
    double lat = 47.5,
    double lon = 8.5,
    Map<Object?, Object?> bounding = const {
      'north': 48.0,
      'east': 9.0,
      'south': 47.0,
      'west': 8.0,
    },
    double? zoomLevel,
    String channel = legacyChannelName,
  }) async {
    final message = const StandardMethodCodec().encodeMethodCall(
      MethodCall('receiveRegionIsChanging', {
        'center': {'lat': lat, 'lon': lon},
        'bounding': bounding,
        if (zoomLevel != null) 'zoomLevel': zoomLevel,
      }),
    );
    await messenger.handlePlatformMessage(channel, message, (_) {});
  }

  tearDown(() {
    invocations.clear();
    for (final channel in [legacyChannelName, legacyChannelName8]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    for (final viewId in [7, 8]) {
      generated.NativeMapRegionEventsApi.setUp(
        null,
        messageChannelSuffix: 'view_$viewId',
      );
    }
  });

  group('attachRegionEventsRoute negotiation', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachRegionEventsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(invocations, isEmpty);
      expect(osm.regionEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('capability + opt-in negotiates the route before initialization',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return regionEventsBootstrap;
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
      final selection = await osm.attachRegionEventsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      expect(invocations, ['legacy:$bootstrapMethod', 'legacy:$routeMethod']);
      expect(osm.regionEventsClientFor(7), isNotNull);
      osm.close(7);
    });

    test('camera-only host keeps region changes on the legacy plane',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachRegionEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(invocations, ['legacy:$bootstrapMethod']);
      expect(osm.regionEventsClientFor(7), isNull);
      osm.close(7);
    });

    test('rejected selection keeps legacy and unregisters the handler',
        () async {
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return regionEventsBootstrap;
        if (call.method == routeMethod) {
          throw PlatformException(code: 'stale_session');
        }
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      expect(
        await osm.attachRegionEventsRoute(7, optIn: true),
        CameraRouteSelection.legacy,
      );
      expect(osm.regionEventsClientFor(7), isNull);

      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);
      await emitNativeRegion(7);
      await emitLegacyRegion();
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('the decision is frozen: repeat attaches never re-negotiate',
        () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      await osm.attachRegionEventsRoute(7, optIn: true);
      expect(invocations.where((m) => m == 'legacy:$routeMethod').length, 1);
      osm.close(7);
    });

    test('an unconfirmed rollback aborts attachment without freezing a route',
        () async {
      var hostResponsive = false;
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) return regionEventsBootstrap;
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
        osm.attachRegionEventsRoute(7, optIn: true),
        throwsA(isA<RegionRouteUncertainException>()),
      );
      expect(osm.regionEventsClientFor(7), isNull);

      hostResponsive = true;
      expect(
        await osm.attachRegionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      osm.close(7);
    });
  });

  group('typed region delivery', () {
    test('changes forward with full center, bounds and zoom precision',
        () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      const lat = 47.218071429999996;
      const lon = -1.5536219999999902;
      await emitNativeRegion(
        7,
        centerLatitude: lat,
        centerLongitude: lon,
        bounds: visibleBounds(
          north: 48.00000000000001,
          east: 9.000000000000002,
          south: -0.9999999999999999,
          west: 8.000000000000002,
        ),
        zoom: 12.345678901234567,
      );
      await Future<void>.delayed(Duration.zero);

      expect(changes.length, 1);
      final region = changes.single.value;
      expect(changes.single.mapId, 7);
      expect(region.center.latitude, lat);
      expect(region.center.longitude, lon);
      expect(region.boundingBox.north, 48.00000000000001);
      expect(region.boundingBox.east, 9.000000000000002);
      expect(region.boundingBox.south, -0.9999999999999999);
      expect(region.boundingBox.west, 8.000000000000002);
      await sub.cancel();
      osm.close(7);
    });

    test('the typed zoom is carried but the public Region never had one, '
        'matching the Apple legacy zoomLevel the decode ignored', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      await emitNativeRegion(7, zoom: 5.5);
      await Future<void>.delayed(Duration.zero);
      await emitNativeRegion(7, zoom: 17.25);
      await Future<void>.delayed(Duration.zero);

      // Same center and bounds: the public events are equal regardless of
      // the zoom each carried, exactly like the legacy decode.
      expect(changes.length, 2);
      expect(changes[0].value, changes[1].value);
      expect(
        changes[0].value,
        Region(
          center: GeoPoint(latitude: 47.5, longitude: 8.5),
          boundingBox: BoundingBox(north: 48.0, east: 9.0, south: 47.0, west: 8.0),
        ),
      );
      await sub.cancel();
      osm.close(7);
    });

    test('typed and legacy routes decode the same public event on either '
        'host shape', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      await emitNativeRegion(7);
      await Future<void>.delayed(Duration.zero);
      final typed = changes.single.value;
      expect(
        typed,
        Region.fromMap({
          'center': {'lat': 47.5, 'lon': 8.5},
          'bounding': {'north': 48.0, 'east': 9.0, 'south': 47.0, 'west': 8.0},
        }),
      );
      expect(
        typed,
        Region.fromMap({
          'center': {'lat': 47.5, 'lon': 8.5},
          'bounding': {'north': 48.0, 'east': 9.0, 'south': 47.0, 'west': 8.0},
          'zoomLevel': 12.0,
        }),
      );
      await sub.cancel();
      osm.close(7);
    });

    test('the Dart forwarder never coalesces and delivers the trailing '
        'change: host bursts arrive once each, in order', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      // What a 100 ms first-immediate/newest-wins coalescer flushes for a
      // five-change burst: the first change, then the newest. Both must
      // arrive, in order, untouched — the Dart layer adds no rate of its
      // own on hosts that forward every change either.
      unawaited(emitNativeRegion(7, centerLatitude: 1.0, zoom: 10.0));
      unawaited(emitNativeRegion(7, centerLatitude: 5.0, zoom: 14.0));
      unawaited(emitNativeRegion(7, centerLatitude: 9.0, zoom: 18.0));
      await Future<void>.delayed(Duration.zero);
      expect(changes.map((c) => c.value.center.latitude).toList(), [1.0, 5.0, 9.0]);
      await sub.cancel();
      osm.close(7);
    });

    test('exactly one route: legacy region messages are dropped on the '
        'generated route (no duplicate delivery)', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      await emitNativeRegion(7);
      await emitLegacyRegion(zoomLevel: 12.0);
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('without opt-in the legacy region events flow unchanged', () async {
      await mockLegacy((call) async => null);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: false);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);
      await emitLegacyRegion(lat: 47.25, lon: 8.75, zoomLevel: 9.0);
      await Future<void>.delayed(Duration.zero);
      expect(changes.single.value.center.latitude, 47.25);
      expect(changes.single.value.center.longitude, 8.75);
      expect(changes.single.value.boundingBox.north, 48.0);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('session identity', () {
    test('stale token or generation callbacks are dropped', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      await emitNativeRegion(7, centerLatitude: 1.0, token: 'token-7-r');
      await emitNativeRegion(7, centerLatitude: 3.0, generation: 1);
      await Future<void>.delayed(Duration.zero);
      expect(changes, isEmpty);

      await emitNativeRegion(7, centerLatitude: 5.0);
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      await sub.cancel();
      osm.close(7);
    });
  });

  group('two-map isolation', () {
    test('each map receives only its own region callbacks', () async {
      await mockHost(regionEventsBootstrap);
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...regionEventsBootstrap, 'sessionToken': 'token-8'};
        }
        return true;
      }, channel: legacyChannelName8);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachRegionEventsRoute(7, optIn: true);
      await osm.attachRegionEventsRoute(8, optIn: true);

      final changes7 = <RegionIsChangingEvent>[];
      final changes8 = <RegionIsChangingEvent>[];
      final sub7 = osm.onRegionIsChangingListener(7).listen(changes7.add);
      final sub8 = osm.onRegionIsChangingListener(8).listen(changes8.add);

      await emitNativeRegion(8, centerLatitude: 8.0, token: 'token-8');
      await emitNativeRegion(8, centerLatitude: 9.0, token: 'token-7');
      await emitNativeRegion(7, centerLatitude: 10.0, token: 'token-8');
      await Future<void>.delayed(Duration.zero);
      expect(changes7, isEmpty);
      expect(changes8.length, 1);

      await emitNativeRegion(7, centerLatitude: 7.0);
      await Future<void>.delayed(Duration.zero);
      expect(changes7.length, 1);
      expect(changes8.length, 1);
      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });

    test('one map on the typed route does not switch another map\'s '
        'legacy plane', () async {
      await mockHost(regionEventsBootstrap);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachRegionEventsRoute(7, optIn: true);
      await osm.attachRegionEventsRoute(8, optIn: false);

      final changes7 = <RegionIsChangingEvent>[];
      final changes8 = <RegionIsChangingEvent>[];
      final sub7 = osm.onRegionIsChangingListener(7).listen(changes7.add);
      final sub8 = osm.onRegionIsChangingListener(8).listen(changes8.add);
      await emitLegacyRegion(lat: 47.0);
      await emitLegacyRegion(lat: 48.0, channel: legacyChannelName8);
      await Future<void>.delayed(Duration.zero);
      expect(changes7, isEmpty);
      expect(changes8.single.value.center.latitude, 48.0);
      await sub7.cancel();
      await sub8.cancel();
      osm.close(7);
      osm.close(8);
    });
  });

  group('recreation and disposal', () {
    test('disposal unregisters the handler; a trailing coalesced change '
        'arriving after disposal delivers nothing', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final client = osm.regionEventsClientFor(7)!;
      expect(client.isActive, isTrue);
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);

      osm.close(7);
      expect(osm.regionEventsClientFor(7), isNull);
      expect(client.isActive, isFalse);

      // The host's coalescer may still flush a pending change after the
      // attachment is gone: no handler is registered, nothing is delivered
      // and the legacy plane is not revived.
      await emitNativeRegion(7);
      await emitLegacyRegion();
      await Future<void>.delayed(Duration.zero);
      expect(changes, isEmpty);
      await sub.cancel();
    });

    test('a listener cancelled before the trailing change still receives '
        'nothing, and a later listener gets what follows', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final first = <RegionIsChangingEvent>[];
      final firstSub = osm.onRegionIsChangingListener(7).listen(first.add);
      await emitNativeRegion(7, centerLatitude: 1.0);
      await Future<void>.delayed(Duration.zero);
      await firstSub.cancel();

      await emitNativeRegion(7, centerLatitude: 2.0);
      final second = <RegionIsChangingEvent>[];
      final secondSub = osm.onRegionIsChangingListener(7).listen(second.add);
      await emitNativeRegion(7, centerLatitude: 3.0);
      await Future<void>.delayed(Duration.zero);
      expect(first.map((c) => c.value.center.latitude).toList(), [1.0]);
      expect(second.map((c) => c.value.center.latitude).toList(), [3.0]);
      await secondSub.cancel();
      osm.close(7);
    });

    test('recreation decides freshly against the new session identity',
        () async {
      var token = 'token-7';
      await mockLegacy((call) async {
        if (call.method == bootstrapMethod) {
          return {...regionEventsBootstrap, 'sessionToken': token};
        }
        return true;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      osm.close(7);

      token = 'token-7-recreated';
      await osm.init(7);
      expect(
        await osm.attachRegionEventsRoute(7, optIn: true),
        CameraRouteSelection.generated,
      );
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);
      await emitNativeRegion(7, centerLatitude: 1.0, token: 'token-7');
      await Future<void>.delayed(Duration.zero);
      expect(changes, isEmpty);
      await emitNativeRegion(7, centerLatitude: 3.0, token: 'token-7-recreated');
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('recreation without opt-in returns to the legacy plane', () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      osm.close(7);

      await osm.init(7);
      expect(
        await osm.attachRegionEventsRoute(7, optIn: false),
        CameraRouteSelection.legacy,
      );
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);
      await emitLegacyRegion();
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('a stale client teardown never unregisters the replacement',
        () async {
      await mockHost(regionEventsBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      final staleClient = osm.regionEventsClientFor(7)!;
      osm.close(7);

      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: true);
      staleClient.dispose();
      final changes = <RegionIsChangingEvent>[];
      final sub = osm.onRegionIsChangingListener(7).listen(changes.add);
      await emitNativeRegion(7);
      await Future<void>.delayed(Duration.zero);
      expect(changes.length, 1);
      await sub.cancel();
      osm.close(7);
    });

    test('an active region subscription of a disposed map completes at '
        'disposal and never receives the recreated map\'s changes', () async {
      await mockLegacy((call) async => null);
      await mockLegacy((call) async => null, channel: legacyChannelName8);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachRegionEventsRoute(7, optIn: false);
      await osm.attachRegionEventsRoute(8, optIn: false);

      final oldChanges = <RegionIsChangingEvent>[];
      var oldDone = false;
      final oldSub = osm.onRegionIsChangingListener(7).listen(
        oldChanges.add,
        onDone: () => oldDone = true,
      );
      await emitLegacyRegion(lat: 47.0);
      await Future<void>.delayed(Duration.zero);
      expect(oldChanges.length, 1);

      osm.close(7);
      await Future<void>.delayed(Duration.zero);
      expect(oldDone, isTrue,
          reason: 'disposal must complete the attachment-owned wrapper');

      await mockLegacy((call) async => null);
      await osm.init(7);
      await osm.attachRegionEventsRoute(7, optIn: false);
      final newChanges = <RegionIsChangingEvent>[];
      final newSub = osm.onRegionIsChangingListener(7).listen(newChanges.add);
      await emitLegacyRegion(lat: 48.0);
      await Future<void>.delayed(Duration.zero);
      expect(newChanges.length, 1);
      expect(oldChanges.length, 1,
          reason: 'the disposed subscription must not see the replacement');

      await oldSub.cancel();
      await newSub.cancel();
      osm.close(7);
      osm.close(8);
    });
  });
}
