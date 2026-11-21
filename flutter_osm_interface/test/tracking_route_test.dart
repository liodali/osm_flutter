// Follow-me tracking routing tests: the frozen routing decision (opt-in x
// host capability), the completion contract (idempotent enable/disable,
// denial mapping through the public exception), typed configuration
// parity, and legacy payload parity for `trackMe` / `deactivateTrackMe`.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_tracking_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapTrackingApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

/// Host advertising the tracking capability.
final Map<Object?, Object?> trackingBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'location.tracking'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: tracking commands must stay legacy.
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

/// Test replica of the generated private codec: knows how to wrap the
/// tracking DTO (140 NativeTrackingConfiguration, embedding the marker
/// anchor 131) and the session envelope (129) in the pigeon wire form.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeTrackingConfiguration) {
      buffer.putUint8(140);
      writeValue(buffer, value.encode());
    } else if (value is generated.NativeMarkerAnchor) {
      buffer.putUint8(131);
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
    if (type == 131) {
      return generated.NativeMarkerAnchor.decode(readValue(buffer)!);
    }
    if (type == 140) {
      return generated.NativeTrackingConfiguration.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

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
    for (final method in ['enableTracking', 'disableTracking']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachTrackingRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachTrackingRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('tracking host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => trackingBootstrap);
      await mockPigeon('enableTracking', (_) {
        invocations.add('pigeon:enableTracking');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachTrackingRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.enableTracking(7);
      expect(invocations, contains('pigeon:enableTracking'));
    });

    test('original camera-only host keeps tracking commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'trackMe' || call.method == 'deactivateTrackMe') {
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachTrackingRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await osm.enableTracking(7);
      await osm.disableTracking(7);
      expect(
        invocations.where((m) => m.startsWith('pigeon:')),
        isEmpty,
      );
      expect(invocations, contains('legacy:trackMe'));
      expect(invocations, contains('legacy:deactivateTrackMe'));
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => trackingBootstrap);
      await mockPigeon('enableTracking', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);
      expect(osm.trackingClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.trackingClientFor(7), isNull);

      await osm.init(7);
      final selection = await osm.attachTrackingRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.trackingClientFor(7), isNull);
    });
  });

  group('completion contract', () {
    test('repeated enables and disables stay safe on the generated route',
        () async {
      final routed = <String>[];
      await mockLegacy((call) async => trackingBootstrap);
      await mockPigeon('enableTracking', (_) {
        routed.add('enable');
        return pigeonReply(null);
      });
      await mockPigeon('disableTracking', (_) {
        routed.add('disable');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);

      await osm.enableTracking(7);
      await osm.enableTracking(7);
      await osm.disableTracking(7);
      await osm.disableTracking(7);
      expect(routed, ['enable', 'enable', 'disable', 'disable']);
    });

    test('enableTracking carries the typed configuration', () async {
      generated.NativeTrackingConfiguration? wireConfig;
      await mockLegacy((call) async => trackingBootstrap);
      await mockPigeon('enableTracking', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireConfig = args[1] as generated.NativeTrackingConfiguration;
        invocations.add('pigeon:enableTracking');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);

      await osm.enableTracking(
        7,
        stopFollowInDrag: true,
        disableMarkerRotation: true,
        anchor: Anchor.bottomRight,
        useDirectionMarker: true,
      );
      expect(invocations, ['pigeon:enableTracking']);
      expect(wireConfig!.stopFollowInDrag, isTrue);
      expect(wireConfig!.disableMarkerRotation, isTrue);
      expect(wireConfig!.useDirectionMarker, isTrue);
      // Anchor.bottomRight encodes the legacy enum value (0, 0).
      expect(wireConfig!.anchor.x, 0);
      expect(wireConfig!.anchor.y, 0);
    });

    test('legacy trackMe keeps the positional payload', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}:${call.arguments}');
        if (call.method == bootstrapMethod) return trackingBootstrap;
        if (call.method == 'trackMe' || call.method == 'deactivateTrackMe') {
          return null;
        }
        return null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: false);

      await osm.enableTracking(
        7,
        stopFollowInDrag: true,
        disableMarkerRotation: false,
        anchor: Anchor.top,
        useDirectionMarker: true,
      );
      await osm.disableTracking(7);
      // Legacy arg order: stopFollowInDrag, disableMarkerRotation,
      // useDirectionMarker, anchor [x, y].
      expect(
        invocations.any((m) => m.startsWith('legacy:trackMe:[true, false, true, [0.5, 1.0]]')),
        isTrue,
      );
      expect(invocations, contains('legacy:deactivateTrackMe:null'));
    });

    test('permission_denied maps through the public exception', () async {
      await mockPigeon(
        'enableTracking',
        (_) => pigeonError('permission_denied', 'location permission was not granted'),
      );
      await mockLegacy((call) async => trackingBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);

      await expectLater(
        osm.enableTracking(7),
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
        'enableTracking',
        (_) => pigeonError('location_service_disabled'),
      );
      await mockLegacy((call) async => trackingBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);

      await expectLater(
        osm.enableTracking(7),
        throwsA(isA<GeoPointException>()),
      );
    });

    test('stale sessions map through the public exception', () async {
      await mockPigeon('enableTracking', (_) => pigeonError('stale_session'));
      await mockLegacy((call) async => trackingBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);

      await expectLater(
        osm.enableTracking(7),
        throwsA(isA<GeoPointException>()),
      );
    });

    test('disable surfaces stale sessions through the guard', () async {
      await mockPigeon(
        'disableTracking',
        (_) => pigeonError('stale_session'),
      );
      await mockLegacy((call) async => trackingBootstrap);

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachTrackingRoute(7, optIn: true);

      await expectLater(
        osm.disableTracking(7),
        throwsA(isA<GeoPointException>()),
      );
    });
  });

  group('map isolation', () {
    test('attachments decide per map id', () async {
      final calls7 = <String>[];
      await mockLegacy((call) async => trackingBootstrap);
      // The second map's legacy channel answers its own bootstrap.
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_8'),
        (call) async {
          invocations.add('legacy8:${call.method}');
          if (call.method == 'trackMe' || call.method == 'deactivateTrackMe') {
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
      await mockPigeon('enableTracking', (_) {
        calls7.add('enable');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachTrackingRoute(7, optIn: true);
      await osm.attachTrackingRoute(8, optIn: false);

      await osm.enableTracking(7);
      await osm.enableTracking(8);
      expect(calls7, ['enable']);
      // Map 8 keeps its own frozen legacy decision on the legacy channel.
      expect(invocations, contains('legacy8:trackMe'));
    });
  });
}
