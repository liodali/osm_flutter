// Location-family routing tests: the frozen routing decision (opt-in x
// host capability), the completion contract (exactly-once outcomes mapped
// to typed failures), and the legacy payload parity for `currentLocation`
// and `user#position`.
//
// The probe runs on the legacy method-channel fixture; generated location
// channels are BasicMessageChannels speaking the pigeon wire envelope
// (StandardMessageCodec list-of-one success / [code, message, details] error).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_location_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapLocationApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

/// Host advertising the location capability alongside the camera families.
final Map<Object?, Object?> locationBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'markers', 'location'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: location commands must stay legacy.
final Map<Object?, Object?> cameraOnlyBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera'],
  'sessionToken': 'token-7',
  'generation': 0,
};

ByteData? pigeonReply(Object? value) =>
    const LocationTestCodec().encodeMessage(<Object?>[value]);

/// Test replica of the generated private codec: knows how to wrap the
/// location DTO (139 NativeLocationFix) in the pigeon wire form.
class LocationTestCodec extends StandardMessageCodec {
  const LocationTestCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeLocationFix) {
      buffer.putUint8(139);
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
    if (type == 139) {
      return generated.NativeLocationFix.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

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
    for (final method in ['showMyLocation', 'getCurrentLocation']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachLocationRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('location host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => locationBootstrap);
      await mockPigeon('showMyLocation', (_) {
        invocations.add('pigeon:showMyLocation');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.currentLocation(7);
      expect(invocations, contains('pigeon:showMyLocation'));
    });

    test('original camera-only host keeps location commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'currentLocation' || call.method == 'user#position') {
          return call.method == 'currentLocation' ? true : {'lat': 47.0, 'lon': 8.0};
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      await mockPigeon('showMyLocation', (_) {
        throw Exception('location route must never activate');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLocationRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await osm.currentLocation(7);
      await osm.myLocation(7);
      expect(
        invocations.where((m) => m.startsWith('pigeon:')),
        isEmpty,
      );
      expect(invocations, contains('legacy:currentLocation'));
      expect(invocations, contains('legacy:user#position'));
    });

    test('the routing decision is frozen after attachment', () async {
      await mockLegacy((call) async => locationBootstrap);
      await mockPigeon('showMyLocation', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationRoute(7, optIn: true);
      await mockLegacy(
        (call) async => throw Exception('probe must not rerun'),
      );
      final selection = await osm.attachLocationRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.generated);
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => locationBootstrap);
      await mockPigeon('showMyLocation', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationRoute(7, optIn: true);
      expect(osm.locationClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.locationClientFor(7), isNull);

      await osm.init(7);
      final selection = await osm.attachLocationRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.locationClientFor(7), isNull);
    });
  });

  group('generated wire form', () {
    test('getCurrentLocation returns the fix coordinates', () async {
      await mockLegacy((call) async => locationBootstrap);
      await mockPigeon('getCurrentLocation', (message) {
        final args =
            const LocationTestCodec().decodeMessage(message)! as List<Object?>;
        // args[0] = the typed session envelope.
        expect(args, hasLength(1));
        final session = args.single as generated.NativeCameraSession;
        expect(session.sessionToken, 'token-7');
        expect(session.generation, 0);
        invocations.add('pigeon:getCurrentLocation');
        return pigeonReply(
          generated.NativeLocationFix(latitude: 47.376912345, longitude: 8.541712345),
        );
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationRoute(7, optIn: true);

      final location = await osm.myLocation(7);
      expect(invocations, contains('pigeon:getCurrentLocation'));
      expect(location.latitude, 47.376912345);
      expect(location.longitude, 8.541712345);
    });
  });

  group('completion contract error mapping', () {
    Future<MethodChannelOSM> attached() async {
      await mockLegacy((call) async => locationBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationRoute(7, optIn: true);
      return osm;
    }

    test('permission_denied maps to LocationPermissionDeniedException',
        () async {
      await mockPigeon('getCurrentLocation', (_) => pigeonError('permission_denied'));
      final osm = await attached();

      await expectLater(
        osm.myLocation(7),
        throwsA(
          isA<GeoPointException>().having(
            (e) => e.msg,
            'msg',
            contains('permission'),
          ),
        ),
      );
    });

    test('location_timeout maps through the facade', () async {
      await mockPigeon('getCurrentLocation', (_) => pigeonError('location_timeout'));
      final osm = await attached();

      await expectLater(
        osm.myLocation(7),
        throwsA(isA<GeoPointException>()),
      );
    });

    test('overlap fails immediately without touching the legacy route',
        () async {
      await mockPigeon(
        'getCurrentLocation',
        (_) => pigeonError('location_request_in_progress'),
      );
      final osm = await attached();

      await expectLater(
        osm.myLocation(7),
        throwsA(isA<GeoPointException>().having(
          (e) => e.msg,
          'msg',
          contains('pending'),
        )),
      );
      expect(invocations.where((m) => m.contains('user#position')), isEmpty);
    });

    test('activity_unavailable maps through the facade', () async {
      await mockPigeon('showMyLocation', (_) => pigeonError('activity_unavailable'));
      final osm = await attached();

      await expectLater(
        osm.currentLocation(7),
        throwsA(isA<GeoPointException>()),
      );
    });

    test('disposed maps through the facade', () async {
      await mockPigeon('getCurrentLocation', (_) => pigeonError('disposed'));
      final osm = await attached();

      await expectLater(osm.myLocation(7), throwsA(isA<GeoPointException>()));
    });

    test('service-disabled codes map through the facade', () async {
      for (final code in ['location_service_disabled', 'location_start_failed']) {
        await mockPigeon('getCurrentLocation', (_) => pigeonError(code));
        final osm = await attached();
        await expectLater(osm.myLocation(7), throwsA(isA<GeoPointException>()));
      }
    });

    test('lifecycle cancellations map through the facade, not PlatformException',
        () async {
      // Reproduction: activity detachment and disposal must surface as the
      // public GeoPointException, never as a raw PlatformException.
      for (final code in ['activity_detached', 'location_request_paused', 'location_request_cancelled']) {
        await mockPigeon('getCurrentLocation', (_) => pigeonError(code, code));
        final osm = await attached();
        await expectLater(
          osm.myLocation(7),
          throwsA(
            isA<GeoPointException>().having(
              (e) => e.msg,
              'msg',
              contains(code),
            ),
          ),
        );
      }
    });
  });

  group('legacy route', () {
    test('myLocation keeps the legacy user#position payload parity',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'user#position') {
          return {'lat': 47.3769, 'lon': 8.5417};
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationRoute(7, optIn: true);

      final location = await osm.myLocation(7);
      expect(location.latitude, 47.3769);
      expect(location.longitude, 8.5417);
      expect(invocations, contains('legacy:user#position'));
    });

    test('legacy errors map to GeoPointException', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'user#position') {
          throw PlatformException(code: 'location_timeout', message: 'timed out');
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLocationRoute(7, optIn: true);

      await expectLater(
        osm.myLocation(7),
        throwsA(isA<GeoPointException>().having(
          (e) => e.msg,
          'msg',
          contains('timed out'),
        )),
      );
    });
  });
}
