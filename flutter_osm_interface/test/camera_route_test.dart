// C2 parity scenarios for the camera vertical slice: the frozen routing
// decision (opt-in x host capability) and the facade error mapping.
//
// The probe runs on the legacy method-channel fixture; generated camera
// channels are BasicMessageChannels speaking the pigeon wire envelope
// (StandardMessageCodec list-of-one success / [code, message, details] error).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapCameraApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

final Map<Object?, Object?> cameraBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera'],
  'sessionToken': 'token-7',
  'generation': 0,
};

ByteData? pigeonReply(Object? value) =>
    const StandardMessageCodec().encodeMessage(<Object?>[value]);

ByteData? pigeonError(String code) =>
    const StandardMessageCodec().encodeMessage(<Object?>[code, 'message', null]);

/// Test replica of the generated private codec: knows how to wrap custom
/// DTOs (marker 130 for NativeCameraPosition) in the pigeon wire envelope.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeCameraPosition) {
      buffer.putUint8(130);
      writeValue(buffer, value.encode());
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    if (type == 130) {
      return generated.NativeCameraPosition.decode(readValue(buffer)!);
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
    for (final method in [
      'getZoom',
      'setZoom',
      'moveTo',
      'setRotation',
      'getCameraPosition',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachCameraRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachCameraRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('supported host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => cameraBootstrap);
      await mockPigeon('getZoom', (_) {
        invocations.add('pigeon:getZoom');
        return pigeonReply(12.0);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachCameraRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      final zoom = await osm.getZoom(7);
      expect(zoom, 12.0);
      expect(invocations, ['pigeon:getZoom']);
    });

    test('legacy host + opt-in keeps the legacy route', () async {
      // No bootstrap handler: the host predates the probe.
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        throw MissingPluginException();
      });
      await mockPigeon(
        'getZoom',
        (_) => throw Exception(
          'generated route must never be used on a legacy host',
        ),
      );

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachCameraRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await expectLater(
        osm.getZoom(7),
        throwsA(isA<MissingPluginException>()),
      );
      expect(invocations, contains('legacy:get#Zoom'));
    });

    test('malformed probe + opt-in never activates the generated route',
        () async {
      await mockLegacy((call) async => {'revision': 'one'});
      await mockPigeon(
        'getZoom',
        (_) => throw Exception('generated route must never be used'),
      );

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachCameraRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('the routing decision is frozen after attachment', () async {
      await mockLegacy((call) async => cameraBootstrap);
      await mockPigeon('getZoom', (_) => pigeonReply(3.0));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);
      // Second call: decision already frozen, probe must not rerun.
      await mockLegacy(
        (call) async =>
            throw Exception('probe must not rerun after attachment'),
      );
      final second = await osm.attachCameraRoute(7, optIn: false);
      expect(second, CameraRouteSelection.generated);
    });

    test('close clears the frozen route of the closed map only', () async {
      await mockLegacy((call) async => cameraBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);
      osm.close(7);
      // Undecided again: a fresh attachment for the same id selects legacy.
      final selection = await osm.attachCameraRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });
  });

  group('camera facade interception', () {
    test('setZoom absolute goes through the generated route', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraBootstrap : null;
      });
      await mockPigeon('setZoom', (_) {
        invocations.add('pigeon:setZoom');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);
      await osm.setZoom(7, zoomLevel: 14.5);
      expect(invocations, contains('pigeon:setZoom'));
      expect(invocations.where((m) => m.startsWith('legacy:Zoom')), isEmpty);
    });

    test('stepZoom stays on the legacy route', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraBootstrap : null;
      });
      await mockPigeon('setZoom', (_) {
        invocations.add('pigeon:setZoom');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);
      await osm.setZoom(7, stepZoom: 2.0);
      expect(invocations, contains('legacy:Zoom'));
      expect(invocations, isNot(contains('pigeon:setZoom')));
    });

    test('getMapCenter reads the generated camera position', () async {
      await mockLegacy((call) async => cameraBootstrap);
      final codec = const _TestPigeonCodec();
      await mockPigeon('getCameraPosition', (_) {
        return codec.encodeMessage(<Object?>[
          generated.NativeCameraPosition(
            latitude: 48.8566,
            longitude: 2.3522,
            zoom: 13.0,
            rotation: 42.0,
          ),
        ]);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);
      final center = await osm.getMapCenter(7);
      expect(center.latitude, 48.8566);
      expect(center.longitude, 2.3522);
    });
  });

  group('facade error mapping', () {
    Future<PigeonCameraClient> activeClient() async {
      await mockLegacy((call) async => cameraBootstrap);
      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);
      return osm.cameraClientFor(7)!;
    }

    test('stale_session maps to StaleMapSessionException', () async {
      final client = await activeClient();
      await mockPigeon('getZoom', (_) => pigeonError('stale_session'));
      expect(
        client.getZoom(),
        throwsA(isA<StaleMapSessionException>()),
      );
    });

    test('camera_not_ready maps to CameraNotReadyException', () async {
      final client = await activeClient();
      await mockPigeon('getZoom', (_) => pigeonError('camera_not_ready'));
      expect(
        client.getZoom(),
        throwsA(isA<CameraNotReadyException>()),
      );
    });

    test('unknown codes keep propagating as PlatformException', () async {
      final client = await activeClient();
      await mockPigeon('getZoom', (_) => pigeonError('something_else'));
      expect(
        client.getZoom(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'something_else',
          ),
        ),
      );
    });
  });
}
