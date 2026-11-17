// C2 parity scenarios for the camera vertical slice: the frozen routing
// decision (opt-in x host capability), probe/disposal races, and the facade
// error mapping.
//
// The probe runs on the legacy method-channel fixture; generated camera
// channels are BasicMessageChannels speaking the pigeon wire envelope
// (StandardMessageCodec list-of-one success / [code, message, details] error).
import 'dart:async';

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

/// Host implementing the expanded camera surface (bounds, zoom-to-bounds,
/// limits and zoom configuration) alongside the original five operations.
final Map<Object?, Object?> expandedCameraBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'camera.config'],
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
    } else if (value is generated.NativeBounds) {
      buffer.putUint8(133);
      writeValue(buffer, value.encode());
    } else if (value is generated.NativeZoomConfiguration) {
      buffer.putUint8(134);
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
    if (type == 130) {
      return generated.NativeCameraPosition.decode(readValue(buffer)!);
    }
    if (type == 133) {
      return generated.NativeBounds.decode(readValue(buffer)!);
    }
    if (type == 134) {
      return generated.NativeZoomConfiguration.decode(readValue(buffer)!);
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
      'getBounds',
      'zoomToBoundingBox',
      'setBoundsLimit',
      'removeBoundsLimit',
      'configureZoom',
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

    test('an incompatible schema never activates the generated route',
        () async {
      // Same revision + capability but a different schema generation:
      // the v1 client codec must not be pointed at a v99 host payload.
      await mockLegacy((call) async => {
            ...cameraBootstrap,
            'schemaId': 'flutter_osm.native.camera.v99',
          });
      await mockPigeon(
        'getZoom',
        (_) => throw Exception('generated route must never be used'),
      );

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachCameraRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('a probe completing after disposal is discarded, not stored',
        () async {
      // Probe response is delayed until after close: the decision must not
      // attach to a dead (or replaced) attachment.
      final probeCompleter = Completer<Object?>();
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return probeCompleter.future;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final pending = osm.attachCameraRoute(7, optIn: true);
      osm.close(7);
      probeCompleter.complete(cameraBootstrap);
      expect(await pending, CameraRouteSelection.legacy);

      // A replacement attachment must decide freshly, not inherit the stale
      // probe result.
      await osm.init(7);
      await mockLegacy((call) async {
        invocations.add('legacy2:${call.method}');
        return {'revision': 'one'}; // malformed: forces legacy
      });
      final selection = await osm.attachCameraRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.cameraClientFor(7), isNull);
    });

    test('concurrent attach calls share one probe decision', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return cameraBootstrap;
      });
      await mockPigeon('getZoom', (_) => pigeonReply(1.0));

      final osm = MethodChannelOSM();
      await osm.init(7);
      final first = osm.attachCameraRoute(7, optIn: true);
      final second = osm.attachCameraRoute(7, optIn: true);
      final selections = await Future.wait([first, second]);
      expect(selections, everyElement(CameraRouteSelection.generated));
      // One probe only.
      expect(
        invocations.where((m) => m == 'legacy:$bootstrapMethod'),
        hasLength(1),
      );
    });

    test('a replacement attachment probes its own host after disposal',
        () async {
      // Reproduction: the first attachment's probe is still in flight when
      // the map is closed and re-created. The replacement must not join the
      // disposed probe — it probes its own host and decides on its answer.
      final staleProbe = Completer<Object?>();
      var probesSeen = 0;
      await mockLegacy((call) async {
        probesSeen += 1;
        invocations.add('probe-$probesSeen');
        return probesSeen == 1 ? staleProbe.future : cameraBootstrap;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final stale = osm.attachCameraRoute(7, optIn: true);
      osm.close(7); // must drop the pending job
      await osm.init(7);

      final selection = await osm.attachCameraRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      expect(probesSeen, 2, reason: 'replacement must probe its own host');
      expect(osm.cameraClientFor(7), isNotNull);

      // The disposed attachment's decision stays discarded even when its
      // probe finally answers.
      staleProbe.complete(cameraBootstrap);
      expect(await stale, CameraRouteSelection.legacy);
      expect(osm.cameraClientFor(7), isNotNull);
    });

    test('a late disposed probe cannot overwrite a replacement decision',
        () async {
      final staleProbe = Completer<Object?>();
      var probesSeen = 0;
      await mockLegacy((call) async {
        probesSeen += 1;
        return probesSeen == 1 ? staleProbe.future : cameraBootstrap;
      });
      await mockPigeon('getZoom', (_) => pigeonReply(1.0));

      final osm = MethodChannelOSM();
      await osm.init(7);
      final stale = osm.attachCameraRoute(7, optIn: true);
      osm.close(7);
      await osm.init(7);
      expect(await osm.attachCameraRoute(7, optIn: true),
          CameraRouteSelection.generated);

      // Now the disposed attachment's probe resolves: it must not store
      // anything over the replacement's frozen decision.
      staleProbe.complete(cameraBootstrap);
      expect(await stale, CameraRouteSelection.legacy);
      expect(osm.cameraClientFor(7), isNotNull);
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

    test('bounds and zoom configuration route through the generated channel',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? expandedCameraBootstrap : null;
      });
      final codec = const _TestPigeonCodec();
      final decoded = <String, Object?>{};
      await mockPigeon('getBounds', (_) {
        invocations.add('pigeon:getBounds');
        return codec.encodeMessage(<Object?>[
          generated.NativeBounds(north: 49, south: 48, east: 3, west: 2),
        ]);
      });
      await mockPigeon('zoomToBoundingBox', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        decoded['bounds'] = args[1];
        decoded['padding'] = args[2];
        invocations.add('pigeon:zoomToBoundingBox');
        return pigeonReply(null);
      });
      await mockPigeon('setBoundsLimit', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        decoded['limit'] = args[1];
        invocations.add('pigeon:setBoundsLimit');
        return pigeonReply(null);
      });
      await mockPigeon('removeBoundsLimit', (_) {
        invocations.add('pigeon:removeBoundsLimit');
        return pigeonReply(null);
      });
      await mockPigeon('configureZoom', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        decoded['zoomConfig'] = args[1];
        invocations.add('pigeon:configureZoom');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachCameraRoute(7, optIn: true);

      final bounds = await osm.getBounds(7);
      expect(bounds.north, 49);
      expect(bounds.south, 48);
      expect(bounds.east, 3);
      expect(bounds.west, 2);

      await osm.zoomToBoundingBox(
        7,
        BoundingBox(north: 48.9, south: 48.1, east: 2.5, west: 2.1),
        paddinInPixel: 24,
      );
      final boundsArg = decoded['bounds'] as generated.NativeBounds;
      expect(boundsArg.north, 48.9);
      expect(boundsArg.south, 48.1);
      expect(boundsArg.east, 2.5);
      expect(boundsArg.west, 2.1);
      expect(decoded['padding'], 24);

      await osm.limitArea(
        7,
        BoundingBox(north: 49, south: 47, east: 4, west: 1),
      );
      final limitArg = decoded['limit'] as generated.NativeBounds;
      expect(limitArg.east, 4);
      expect(limitArg.west, 1);

      await osm.removeLimitArea(7);
      await (osm as MethodChannelOSM).configureZoomMap(7, 8, 2, 19, 1);
      final zoomConfig = decoded['zoomConfig'] as generated.NativeZoomConfiguration;
      expect(zoomConfig.initZoom, 8);
      expect(zoomConfig.minZoomLevel, 2);
      expect(zoomConfig.maxZoomLevel, 19);
      expect(zoomConfig.stepZoom, 1);

      // No legacy camera command for these families ran.
      expect(
        invocations.where(
          (m) => m.contains('map#bounds') ||
              m.contains('zoomToRegion') ||
              m.contains('limitArea') ||
              m.contains('config#Zoom'),
        ),
        isEmpty,
      );
      expect(
        invocations,
        containsAll([
          'pigeon:getBounds',
          'pigeon:zoomToBoundingBox',
          'pigeon:setBoundsLimit',
          'pigeon:removeBoundsLimit',
          'pigeon:configureZoom',
        ]),
      );
    });

    test('an original camera-only host keeps expanded commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'map#bounds') {
          return {'north': 49.0, 'south': 47.0, 'east': 4.0, 'west': 1.0};
        }
        return call.method == bootstrapMethod ? cameraBootstrap : null;
      });
      await mockPigeon('getBounds', (_) {
        throw Exception('bounds route must never activate');
      });
      await mockPigeon('configureZoom', (_) {
        throw Exception('zoom configuration route must never activate');
      });
      await mockPigeon('getZoom', (_) {
        invocations.add('pigeon:getZoom');
        return pigeonReply(14.0);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      // Opt-in accepted: the original camera surface activates, but the
      // expanded commands negotiate separately and stay on legacy because
      // the host never advertised camera.config.
      await osm.attachCameraRoute(7, optIn: true);

      // The original surface routes generated on the same host.
      final zoom = await osm.getZoom(7);
      expect(zoom, 14.0);

      final bounds = await osm.getBounds(7);
      expect(bounds, isA<BoundingBox>());
      await osm.zoomToBoundingBox(
        7,
        BoundingBox(north: 49, south: 47, east: 4, west: 1),
      );
      await osm.limitArea(
        7,
        BoundingBox(north: 49, south: 47, east: 4, west: 1),
      );
      await osm.removeLimitArea(7);
      await (osm as MethodChannelOSM).configureZoomMap(7, 8, 2, 19, 1);

      expect(
        invocations,
        containsAll([
          'legacy:map#bounds',
          'legacy:zoomToRegion',
          'legacy:limitArea',
          'legacy:remove#limitArea',
          'legacy:config#Zoom',
        ]),
      );
      expect(
        invocations.where(
          (m) =>
              m.startsWith('pigeon:') && !m.startsWith('pigeon:getZoom'),
        ),
        isEmpty,
      );
      // The original camera surface still activates on the same host.
      expect(invocations, contains('pigeon:getZoom'));
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
