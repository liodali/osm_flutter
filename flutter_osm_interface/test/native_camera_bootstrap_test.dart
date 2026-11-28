// C1 compatibility tests: bootstrap contract, probe outcomes and per-map
// isolation of the generated camera channel suffixes.
//
// These tests run the attach-time probe against TestDefaultBinaryMessenger
// fixtures: new host (payload), old host (missing), broken host (malformed)
// and a not-implemented native reply. The probe must never initialize or
// mutate the map.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_bootstrap.dart';

typedef ProbeHandler = Future<Object?> Function(MethodCall call);

ProbeHandler handler(Future<Object?> Function(MethodCall call) handle) =>
    (MethodCall call) async => handle(call);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.dali.hamza/osmview_1'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.dali.hamza/osmview_2'),
      null,
    );
  });


  group('NativeProtocolBootstrap.parse', () {
    test('accepts a well-formed payload', () {
      final result = NativeProtocolBootstrap.parse({
        'revision': 1,
        'schemaId': 'flutter_osm.native.camera.v1',
        'capabilities': ['camera'],
        'sessionToken': 'token-a',
        'generation': 0,
      });
      expect(result, isA<NativeProtocolSupported>());
      final supported = result as NativeProtocolSupported;
      expect(supported.bootstrap.isSupportedRevision, isTrue);
      expect(supported.bootstrap.advertises(kCameraCapability), isTrue);
      expect(supported.bootstrap.sessionToken, 'token-a');
    });

    test('rejects a non-map payload', () {
      expect(
        NativeProtocolBootstrap.parse('nope'),
        isA<NativeProtocolInvalid>(),
      );
    });

    for (final missing in ['revision', 'schemaId', 'sessionToken', 'generation']) {
      test('rejects a payload without $missing', () {
        final payload = <Object?, Object?>{
          'revision': 1,
          'schemaId': 'flutter_osm.native.camera.v1',
          'capabilities': ['camera'],
          'sessionToken': 'token-a',
          'generation': 0,
        }..remove(missing);
        expect(
          NativeProtocolBootstrap.parse(payload),
          isA<NativeProtocolInvalid>(),
        );
      });
    }

    test('rejects an unknown schema family', () {
      final result = NativeProtocolBootstrap.parse({
        'revision': 1,
        'schemaId': 'someone.else.camera.v1',
        'capabilities': ['camera'],
        'sessionToken': 'token-a',
        'generation': 0,
      });
      expect(result, isA<NativeProtocolInvalid>());
    });

    test('flags a mismatched revision without rejecting the payload', () {
      final result = NativeProtocolBootstrap.parse({
        'revision': 99,
        'schemaId': 'flutter_osm.native.camera.v99',
        'capabilities': <String>[],
        'sessionToken': 'token-a',
        'generation': 3,
      });
      expect(result, isA<NativeProtocolSupported>());
      final supported = result as NativeProtocolSupported;
      expect(supported.bootstrap.isSupportedRevision, isFalse);
    });
  });

  group('MethodChannelOSM.probeNativeProtocol', () {
    test('reports a supported host with validated payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_1'),
        handler((call) async {
          expect(call.method, kNativeBootstrapMethod);
          return {
            'revision': 1,
            'schemaId': 'flutter_osm.native.camera.v1',
            'capabilities': ['camera'],
            'sessionToken': 'token-1',
            'generation': 0,
          };
        }),
      );
      final osm = MethodChannelOSM();
      await osm.init(1);
      final result = await osm.probeNativeProtocol(1);
      expect(result, isA<NativeProtocolSupported>());
    });

    test('maps an old host (missing probe) to legacy selection', () async {
      // No mock handler registered: the channel replies with
      // MissingPluginException, as an unhandled method does.
      final osm = MethodChannelOSM();
      await osm.init(1);
      final result = await osm.probeNativeProtocol(1);
      expect(result, isA<NativeProtocolLegacyHost>());
    });

    test('maps not_implemented to legacy selection', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_1'),
        handler((call) async =>
            throw PlatformException(code: 'not_implemented')),
      );
      final osm = MethodChannelOSM();
      await osm.init(1);
      final result = await osm.probeNativeProtocol(1);
      expect(result, isA<NativeProtocolLegacyHost>());
    });

    test('never treats malformed payloads as old-host compatibility',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_1'),
        handler((call) async => {'revision': 'one'}),
      );
      final osm = MethodChannelOSM();
      await osm.init(1);
      final result = await osm.probeNativeProtocol(1);
      expect(result, isA<NativeProtocolInvalid>());
    });

    test('never treats unexpected channel failures as old-host compatibility',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_1'),
        handler((call) async =>
            throw PlatformException(code: 'channel_error')),
      );
      final osm = MethodChannelOSM();
      await osm.init(1);
      final result = await osm.probeNativeProtocol(1);
      expect(result, isA<NativeProtocolInvalid>());
    });

    test('probes stay isolated between two live maps', () async {
      // Map 2 stays unhandled (old host): its per-map channel never answers.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_1'),
        handler((call) async => {
              'revision': 1,
              'schemaId': 'flutter_osm.native.camera.v1',
              'capabilities': ['camera'],
              'sessionToken': 'token-1',
              'generation': 0,
            }),
      );
      // Map 2 stays unhandled (old host).
      final osm = MethodChannelOSM();
      await osm.init(1);
      await osm.init(2);
      final first = await osm.probeNativeProtocol(1);
      final second = await osm.probeNativeProtocol(2);
      expect(first, isA<NativeProtocolSupported>());
      expect(second, isA<NativeProtocolLegacyHost>());
    });
  });

  group('generated channel suffixes', () {
    test('suffixes differ per view id', () {
      expect(nativeChannelSuffix(1), 'view_1');
      expect(nativeChannelSuffix(2), 'view_2');
      expect(nativeChannelSuffix(1), isNot(nativeChannelSuffix(2)));
    });

    test('the generated client and host agree on the channel base name', () {
      // Contract guard: pins the wire name shared by the Dart client,
      // the Kotlin host and the Swift host. Regenerating the schema with
      // a different package name or API name must update this test.
      expect(
        kNativeCameraSchemaId,
        'flutter_osm.native.camera.v1',
      );
      expect(kNativeProtocolRevision, 1);
    });
  });
}
