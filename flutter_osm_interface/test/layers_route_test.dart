// Layers-family routing tests: the frozen routing decision (opt-in x
// host capability), the tile wire form, overlay visibility, and the facade
// error mapping.
//
// The probe runs on the legacy method-channel fixture; generated layers
// channels are BasicMessageChannels speaking the pigeon wire envelope
// (StandardMessageCodec list-of-one success / [code, message, details] error).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_layers_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapLayersApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

/// Host advertising the layers capability (tile sources + overlay
/// visibility) alongside the camera families.
final Map<Object?, Object?> layersBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'markers', 'layers'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: layers commands must stay legacy.
final Map<Object?, Object?> cameraOnlyBootstrap = {
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

/// Test replica of the generated private codec: knows how to wrap the
/// layers DTOs (135 NativeTileServer, 136 NativeTileConfiguration) and the
/// session envelope (129) in the pigeon wire form.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeTileServer) {
      buffer.putUint8(135);
      writeValue(buffer, value.encode());
    } else if (value is generated.NativeTileConfiguration) {
      buffer.putUint8(136);
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
    if (type == 135) {
      return generated.NativeTileServer.decode(readValue(buffer)!);
    }
    if (type == 136) {
      return generated.NativeTileConfiguration.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

CustomTile sampleTile() => CustomTile(
      urlsServers: [
        TileURLs(
          url: 'https://tiles.example.org/style/',
          subdomains: ['a', 'b'],
        ),
      ],
      tileExtension: '.png',
      sourceName: 'example-source',
      tileSize: 256,
      minZoomLevel: 3,
      maxZoomLevel: 18,
      keyApi: const MapEntry('access-token', 'secret'),
    );

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
    for (final method in ['changeTileLayer', 'setOverlaysVisible']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachLayersRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLayersRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('layers host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('setOverlaysVisible', (message) {
        invocations.add('pigeon:setOverlaysVisible');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachLayersRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.toggleLayer(7, toggle: false);
      expect(invocations, ['pigeon:setOverlaysVisible']);
    });

    test('original camera-only host keeps layers commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'toggle#Alllayer') {
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      await mockPigeon('setOverlaysVisible', (_) {
        throw Exception('layers route must never activate');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      // Opt-in accepted, but the host never advertised layers: the frozen
      // decision keeps tile and overlay commands on the legacy route.
      final selection = await osm.attachLayersRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await osm.toggleLayer(7, toggle: true);
      expect(
        invocations.where((m) => m.startsWith('pigeon:')),
        isEmpty,
      );
      expect(invocations, contains('legacy:toggle#Alllayer'));
    });

    test('the routing decision is frozen after attachment', () async {
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('setOverlaysVisible', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);
      // Second call: decision already frozen, probe must not rerun.
      await mockLegacy(
        (call) async => throw Exception('probe must not rerun'),
      );
      final selection = await osm.attachLayersRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.generated);
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('setOverlaysVisible', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);
      expect(osm.layersClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.layersClientFor(7), isNull);

      // A new attachment decides freshly (opt-in false now → legacy).
      await osm.init(7);
      final selection = await osm.attachLayersRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.layersClientFor(7), isNull);
    });
  });

  group('generated tile wire form', () {
    test('changeTileLayer carries the platform-neutral configuration',
        () async {
      generated.NativeTileConfiguration? wireTile;
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('changeTileLayer', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireTile = args[1] as generated.NativeTileConfiguration?;
        invocations.add('pigeon:changeTileLayer');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      await osm.changeTileLayer(7, sampleTile());
      expect(invocations, ['pigeon:changeTileLayer']);

      final tile = wireTile!;
      expect(tile.urls, hasLength(1));
      expect(tile.urls.single.url, 'https://tiles.example.org/style/');
      expect(tile.urls.single.subdomains, ['a', 'b']);
      expect(tile.tileExtension, '.png');
      expect(tile.sourceName, 'example-source');
      expect(tile.tileSize, 256);
      expect(tile.minZoomLevel, 3);
      expect(tile.maxZoomLevel, 18);
      expect(tile.apiKey, 'access-token');
      expect(tile.apiValue, 'secret');
      expect(tile.styleURL, isNull);
    });

    test('a null tile sends a null configuration (default-layer reset)',
        () async {
      Object? wireArg;
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('changeTileLayer', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireArg = args[1];
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      await osm.changeTileLayer(7, null);
      expect(wireArg, isNull);
    });

    test('toggleLayer routes through setOverlaysVisible', () async {
      final visibleArgs = <Object?>[];
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('setOverlaysVisible', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        visibleArgs.add(args[1]);
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      await osm.toggleLayer(7, toggle: true);
      await osm.toggleLayer(7, toggle: false);
      expect(visibleArgs, [true, false]);
    });
  });

  group('facade error mapping', () {
    test('stale_session maps to StaleMapSessionException', () async {
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('changeTileLayer', (_) => pigeonError('stale_session'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      await expectLater(
        osm.changeTileLayer(7, sampleTile()),
        throwsA(isA<StaleMapSessionException>()),
      );
    });

    test('layers_not_ready maps to LayersNotReadyException', () async {
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon(
        'setOverlaysVisible',
        (_) => pigeonError('layers_not_ready'),
      );

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      await expectLater(
        osm.toggleLayer(7, toggle: true),
        throwsA(isA<LayersNotReadyException>()),
      );
    });

    test('unknown codes rethrow as PlatformException', () async {
      await mockLegacy((call) async => layersBootstrap);
      await mockPigeon('changeTileLayer', (_) => pigeonError('boom'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      await expectLater(
        osm.changeTileLayer(7, sampleTile()),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('legacy route', () {
    test('tile change keeps the legacy map payload byte-for-byte',
        () async {
      Object? legacyArgs;
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'change#tile') {
          legacyArgs = call.arguments;
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachLayersRoute(7, optIn: true);

      final tile = sampleTile();
      await osm.changeTileLayer(7, tile);
      expect(invocations, contains('legacy:change#tile'));
      expect(legacyArgs, isA<Map<dynamic, dynamic>>());
      final map = legacyArgs as Map<dynamic, dynamic>;
      expect(map['name'], 'example-source');
      expect((map['urls'] as List).single, isA<List<dynamic>>());
      expect(map['tileSize'], 256);
    });
  });
}
