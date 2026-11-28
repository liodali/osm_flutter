// Continuous-updates routing tests: the frozen routing decision (opt-in x
// host capability), the completion contract (idempotent start/stop,
// denial mapping through the public exception), and legacy payload parity
// for `startLocationUpdating` / `stopLocationUpdating`.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_location_updates_client.dart';

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapLocationUpdatesApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

/// Host advertising the continuous-updates capability.
final Map<Object?, Object?> updatesBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'location.updates'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: updates commands must stay legacy.
final Map<Object?, Object?> cameraOnlyBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera'],
  'sessionToken': 'token-7',
  'generation': 0,
};

ByteData? pigeonReply(Object? value) =>
    const StandardMessageCodec().encodeMessage(<Object?>[value]);

ByteData? pigeonError(String code, [String? message]) =>
    const StandardMessageCodec().encodeMessage(<Object?>[code, message ?? 'message', null]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invocations = <String>[];

  Future<void> mockLegacy(
    Future<Object?> Function(MethodCall call) handler,
  ) async {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(legacyChannelName),
      (call) async => handler(call),
    );
  }

  Future<void> mockPigeon(
    String method,
    ByteData? Function(ByteData? message) respond,
  ) async {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger.setMockMessageHandler(
      pigeonChannel(method),
      (ByteData? message) async => respond(message),
    );
  }

  tearDown(() {
    invocations.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(legacyChannelName),
      null,
    );
    for (final method in ['startLocationUpdates', 'stopLocationUpdates']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachLocationUpdatesRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationUpdatesRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('updates host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => updatesBootstrap);
      await mockPigeon('startLocationUpdates', (_) {
        invocations.add('pigeon:startLocationUpdates');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationUpdatesRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.startLocationUpdating(7);
      expect(invocations, contains('pigeon:startLocationUpdates'));
    });

    test('original camera-only host keeps updates commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'startLocationUpdating' ||
            call.method == 'stopLocationUpdating') {
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      await mockPigeon('startLocationUpdates', (_) {
        throw Exception('updates route must never activate');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationUpdatesRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await osm.startLocationUpdating(7);
      await osm.stopLocationUpdating(7);
      expect(
        invocations.where((m) => m.startsWith('pigeon:')),
        isEmpty,
      );
      expect(invocations, contains('legacy:startLocationUpdating'));
      expect(invocations, contains('legacy:stopLocationUpdating'));
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => updatesBootstrap);
      await mockPigeon('startLocationUpdates', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationUpdatesRoute(7, optIn: true);
      expect(osm.locationUpdatesClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.locationUpdatesClientFor(7), isNull);

      await osm.init(7);
      final selection = await osm.attachLocationUpdatesRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.locationUpdatesClientFor(7), isNull);
    });
  });

  group('completion contract', () {
    test('repeated starts and stops stay safe on the generated route',
        () async {
      final routed = <String>[];
      await mockLegacy((call) async => updatesBootstrap);
      await mockPigeon('startLocationUpdates', (_) {
        routed.add('start');
        return pigeonReply(null);
      });
      await mockPigeon('stopLocationUpdates', (_) {
        routed.add('stop');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationUpdatesRoute(7, optIn: true);

      await osm.startLocationUpdating(7);
      await osm.startLocationUpdating(7);
      await osm.stopLocationUpdating(7);
      await osm.stopLocationUpdating(7);
      expect(routed, ['start', 'start', 'stop', 'stop']);
    });

    test('permission_denied maps through the public exception', () async {
      await mockPigeon(
        'startLocationUpdates',
        (_) => pigeonError('permission_denied', 'location permission was not granted'),
      );
      await mockLegacy((call) async => updatesBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationUpdatesRoute(7, optIn: true);

      await expectLater(
        osm.startLocationUpdating(7),
        throwsA(
          isA<GeoPointException>().having(
            (e) => e.msg,
            'msg',
            contains('permission'),
          ),
        ),
      );
    });

    test('location_service_disabled maps through the public exception',
        () async {
      await mockPigeon(
        'startLocationUpdates',
        (_) => pigeonError('location_service_disabled'),
      );
      await mockLegacy((call) async => updatesBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationUpdatesRoute(7, optIn: true);

      await expectLater(
        osm.startLocationUpdating(7),
        throwsA(isA<GeoPointException>()),
      );
    });

    test('stale sessions map through the public exception', () async {
      await mockPigeon('startLocationUpdates', (_) => pigeonError('stale_session'));
      await mockLegacy((call) async => updatesBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationUpdatesRoute(7, optIn: true);

      await expectLater(
        osm.startLocationUpdating(7),
        throwsA(isA<GeoPointException>()),
      );
    });

    test('stop never maps an error route: legacy stop stays silent',
        () async {
      // Stop on the legacy route has no error surface in the contract.
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? updatesBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationUpdatesRoute(7, optIn: false);

      await osm.stopLocationUpdating(7);
      expect(invocations, contains('legacy:stopLocationUpdating'));
    });
  });

  group('map isolation', () {
    test('attachments decide per map id', () async {
      final calls7 = <String>[];
      final calls8 = <String>[];
      await mockLegacy((call) async => updatesBootstrap);
      // The second map's legacy channel answers its own bootstrap.
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_8'),
        (call) async {
          invocations.add('legacy8:${call.method}');
          if (call.method == 'startLocationUpdating' ||
              call.method == 'stopLocationUpdating') {
            return null;
          }
          return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.dali.hamza/osmview_8'),
          null,
        );
      });
      await mockPigeon('startLocationUpdates', (_) {
        calls7.add('start');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachLocationUpdatesRoute(7, optIn: true);
      await osm.attachLocationUpdatesRoute(8, optIn: false);

      await osm.startLocationUpdating(7);
      await osm.startLocationUpdating(8);
      expect(calls7, ['start']);
      expect(calls8, isEmpty);
      // Map 8 keeps its own frozen legacy decision on the legacy channel.
      expect(invocations, contains('legacy8:startLocationUpdating'));
      expect(
        invocations.where((m) => m.startsWith('legacy8:stopLocation')),
        isEmpty,
      );
    });
  });
}
