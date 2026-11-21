// C3 markers-family slice: capability-gated attach, wire assertions through
// the generated channel, and typed-transport delegation (non-marker commands
// never leave the selected base transport).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/android/android_map_id.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_bootstrap.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;
import 'package:flutter_osm_interface/src/channel/pigeon/native_markers_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_markers_transport.dart';
import 'package:flutter_osm_interface/src/types/types.dart';

const legacyChannelName = 'plugins.dali.hamza/osmview_9';

String pigeonMarkersChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapMarkersApi.'
    '$method.view_9';

ByteData? pigeonReply(Object? value) =>
    const StandardMessageCodec().encodeMessage(<Object?>[value]);

/// Test replica of the generated private codec (session marker 129).
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    if (type == 129) {
      return generated.NativeCameraSession.decode(readValue(buffer)!);
    }
    if (type == 131) {
      return generated.NativeMarkerAnchor.decode(readValue(buffer)!);
    }
    if (type == 132) {
      return generated.NativeMarkerSize.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

Map<Object?, Object?> bootstrapWith(List<String> capabilities) => {
      'revision': 1,
      'schemaId': 'flutter_osm.native.camera.v1',
      'capabilities': capabilities,
      'sessionToken': 'token-9',
      'generation': 0,
    };

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

  Future<void> mockMarkers(
    String method,
    ByteData? Function(ByteData? message) respond,
  ) async {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger.setMockMessageHandler(
      pigeonMarkersChannel(method),
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
      'addMarker',
      'addMarkers',
      'updateMarkerIcon',
      'moveMarker',
      'rotateMarker',
      'setMarkerAnchor',
      'setStaticPositions',
      'removeStaticPositions',
      'removeMarker',
      'removeMarkers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonMarkersChannel(method), null);
    }
  });

  group('attachMarkersRoute', () {
    test('host without the markers capability keeps the legacy route',
        () async {
      await mockLegacy((call) async =>
          call.method == 'map#bootstrap#protocol'
              ? bootstrapWith(['camera'])
              : null);
      await mockMarkers('addMarker',
          (_) => throw Exception('markers route must never activate'));

      final osm = MethodChannelOSM();
      await osm.init(9);
      final selection = await osm.attachMarkersRoute(9, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('host advertising markers activates the generated route', () async {
      await mockLegacy((call) async =>
          call.method == 'map#bootstrap#protocol'
              ? bootstrapWith(['camera', 'markers'])
              : null);
      await mockMarkers('addMarker', (message) {
        invocations.add('pigeon:addMarker');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(9);
      final selection = await osm.attachMarkersRoute(9, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.markersClientFor(9)!.addMarker(
            'm1',
            48.85,
            2.35,
            iconBytes: Uint8List.fromList([1, 2, 3]),
          );
      expect(invocations, ['pigeon:addMarker']);
    });

    test('camera and markers attach calls probe independently', () async {
      var probes = 0;
      await mockLegacy((call) async {
        if (call.method == 'map#bootstrap#protocol') {
          probes += 1;
          return bootstrapWith(['camera', 'markers']);
        }
        return null;
      });

      final osm = MethodChannelOSM();
      await osm.init(9);
      expect(await osm.attachCameraRoute(9, optIn: true),
          CameraRouteSelection.generated);
      expect(await osm.attachMarkersRoute(9, optIn: true),
          CameraRouteSelection.generated);
      expect(osm.cameraClientFor(9), isNotNull);
      expect(osm.markersClientFor(9), isNotNull);
      // Two family decisions, each probing the host itself.
      expect(probes, 2);
    });

    test('close clears the frozen markers decision', () async {
      await mockLegacy((call) async =>
          call.method == 'map#bootstrap#protocol'
              ? bootstrapWith(['camera', 'markers'])
              : null);
      final osm = MethodChannelOSM();
      await osm.init(9);
      await osm.attachMarkersRoute(9, optIn: true);
      osm.close(9);
      final selection = await osm.attachMarkersRoute(9, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });
  });

  group('PigeonMarkersTransport delegation', () {
    test('marker commands go through the generated channel with session',
        () async {
      final codec = const _TestPigeonCodec();
      Object? decodedSession;
      Object? decodedId;
      double? decodedLat;
      double? decodedLon;
      Uint8List? decodedIcon;
      await mockMarkers('addMarker', (message) {
        invocations.add('pigeon:addMarker');
        final args = codec.decodeMessage(message)! as List<Object?>;
        decodedSession = args[0];
        decodedId = args[1];
        decodedLat = args[2] as double;
        decodedLon = args[3] as double;
        decodedIcon = args[4] as Uint8List?;
        return pigeonReply(null);
      });

      final client = PigeonMarkersClient(
        viewId: 9,
        bootstrap: NativeProtocolBootstrap(
          revision: 1,
          schemaId: 'flutter_osm.native.camera.v1',
          capabilities: const ['markers'],
          sessionToken: 'token-9',
          generation: 0,
        ),
      );
      final transport = PigeonMarkersTransport(
        base: _RecordingBaseTransport(invocations),
        markersClient: client,
      );

      await transport.addMarker(
        const MarkerId('m-42'),
        GeoPoint(latitude: 48.8566, longitude: 2.3522),
        iconBytes: Uint8List.fromList([9, 8, 7]),
      );

      expect(invocations, ['pigeon:addMarker']);
      expect(decodedSession, isA<generated.NativeCameraSession>());
      expect(
        (decodedSession as generated.NativeCameraSession).sessionToken,
        'token-9',
      );
      expect(decodedId, 'm-42');
      expect(decodedLat, 48.8566);
      expect(decodedLon, 2.3522);
      expect(decodedIcon, [9, 8, 7]);
    });

    test('non-marker commands stay on the base transport', () async {
      await mockMarkers(
        'removeMarker',
        (_) => throw Exception('non-marker commands must not use markers'),
      );
      final transport = PigeonMarkersTransport(
        base: _RecordingBaseTransport(invocations),
        markersClient: PigeonMarkersClient(
          viewId: 9,
          bootstrap: NativeProtocolBootstrap(
            revision: 1,
            schemaId: 'flutter_osm.native.camera.v1',
            capabilities: const ['markers'],
            sessionToken: 'token-9',
            generation: 0,
          ),
        ),
      );

      await transport.setZoom(14.0);
      await transport.clearRoads();
      expect(invocations, ['base:setZoom', 'base:clearRoads']);
      expect(transport.backend, AndroidMapBackend.methodChannel);
    });
  });

  group('typed movement, rotation, anchors, and static groups', () {
    PigeonMarkersClient client() => PigeonMarkersClient(
          viewId: 9,
          bootstrap: NativeProtocolBootstrap(
            revision: 1,
            schemaId: 'flutter_osm.native.camera.v1',
            capabilities: const ['markers'],
            sessionToken: 'token-9',
            generation: 0,
          ),
        );

    test('move and rotate cross the generated channel with the session',
        () async {
      final codec = const _TestPigeonCodec();
      final captured = <String, List<Object?>>{};
      await mockMarkers('moveMarker', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        captured['moveMarker'] = args.sublist(1);
        return pigeonReply(null);
      });
      await mockMarkers('rotateMarker', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        captured['rotateMarker'] = args.sublist(1);
        return pigeonReply(null);
      });

      await client().moveMarker('m-1', 48.11, 2.22);
      await client().rotateMarker('m-1', 45.5);

      expect(captured['moveMarker'], ['m-1', 48.11, 2.22]);
      expect(captured['rotateMarker'], ['m-1', 45.5]);
    });

    test('anchor crossing keeps normalized x/y pairs', () async {
      final codec = const _TestPigeonCodec();
      Object? decodedAnchor;
      await mockMarkers('setMarkerAnchor', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        decodedAnchor = args[2];
        return pigeonReply(null);
      });

      await client().setMarkerAnchor(
        'm-1',
        IconAnchor(anchor: Anchor.bottom).toGenerated(),
      );

      expect(decodedAnchor, isA<generated.NativeMarkerAnchor>());
      final anchor = decodedAnchor as generated.NativeMarkerAnchor;
      expect(anchor.x, 0.5);
      expect(anchor.y, 0.0);
    });

    test('add marker carries icon bytes, degrees, anchor, and logical size',
        () async {
      final codec = const _TestPigeonCodec();
      Object? decodedIcon;
      Object? decodedAngle;
      Object? decodedAnchor;
      Object? decodedSize;
      await mockMarkers('addMarker', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        decodedIcon = args[4];
        decodedAngle = args[5];
        decodedAnchor = args[6];
        decodedSize = args[7];
        return pigeonReply(null);
      });

      await client().addMarker(
        'm-1',
        48.85,
        2.35,
        iconBytes: Uint8List.fromList([1, 2, 3, 4]),
        angleDegrees: 90,
        anchor: IconAnchor(anchor: Anchor.bottom).toGenerated(),
        iconLogicalSize: [32, 48],
      );

      expect(decodedIcon, [1, 2, 3, 4]);
      expect(decodedAngle, 90.0);
      expect((decodedAnchor as generated.NativeMarkerAnchor).y, 0.0);
      expect(decodedSize, isA<generated.NativeMarkerSize>());
      expect((decodedSize as generated.NativeMarkerSize).width, 32);
      expect((decodedSize as generated.NativeMarkerSize).height, 48);
    });

    test('anchor offsets fold into the generated coordinates', () {
      final wire = IconAnchor(
        anchor: Anchor.bottom,
        offset: (x: 0.25, y: -0.5),
      ).toGenerated();

      // Legacy Darwin applies anchor + offset on the native side; the wire
      // pair must carry the combined pivot.
      expect(wire.x, 0.75);
      expect(wire.y, -0.5);
    });

    test('icon update carries logical dimensions', () async {
      final codec = const _TestPigeonCodec();
      Object? decodedSize;
      await mockMarkers('updateMarkerIcon', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        decodedSize = args[3];
        return pigeonReply(null);
      });

      await client().updateMarkerIcon(
        'm-1',
        Uint8List.fromList([9, 9]),
        iconLogicalSize: [16, 24],
      );

      expect(decodedSize, isA<generated.NativeMarkerSize>());
      expect((decodedSize as generated.NativeMarkerSize).height, 24);
    });

    test('static groups send degree triples and shared icon bytes', () async {
      final codec = const _TestPigeonCodec();
      final captured = <String, List<Object?>>{};
      await mockMarkers('setStaticPositions', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        captured['setStaticPositions'] = args.sublist(1);
        return pigeonReply(null);
      });
      await mockMarkers('removeStaticPositions', (message) {
        final args = codec.decodeMessage(message)! as List<Object?>;
        captured['removeStaticPositions'] = args.sublist(1);
        return pigeonReply(null);
      });

      await client().setStaticPositions(
        'group-1',
        Float64List.fromList([48.1, 2.2, 30, 48.3, 2.4, 60]),
        iconBytes: Uint8List.fromList([5, 6]),
        iconLogicalSize: [12, 20],
      );
      await client().removeStaticPositions('group-1');

      expect(captured['setStaticPositions'], [
        'group-1',
        [48.1, 2.2, 30.0, 48.3, 2.4, 60.0],
        [5, 6],
        isA<generated.NativeMarkerSize>(),
      ]);
      expect(captured['removeStaticPositions'], ['group-1']);
    });

    test('transport routes static groups and movement through the markers',
        () async {
      await mockMarkers('moveMarker', (_) {
        invocations.add('pigeon:moveMarker');
        return pigeonReply(null);
      });
      await mockMarkers('setStaticPositions', (_) {
        invocations.add('pigeon:setStaticPositions');
        return pigeonReply(null);
      });
      await mockMarkers('removeStaticPositions', (_) {
        invocations.add('pigeon:removeStaticPositions');
        return pigeonReply(null);
      });

      final transport = PigeonMarkersTransport(
        base: _RecordingBaseTransport(invocations),
        markersClient: client(),
      );

      await transport.moveMarker(
        const MarkerId('m-1'),
        GeoPoint(latitude: 1, longitude: 2),
      );
      await transport.setStaticPositions(
        const StaticPositionId('group-1'),
        [
          GeoPointWithOrientation(
            angle: 180,
            latitude: 48.1,
            longitude: 2.2,
          ),
        ],
      );
      await transport.removeStaticPositions(const StaticPositionId('group-1'));

      expect(invocations, [
        'pigeon:moveMarker',
        'pigeon:setStaticPositions',
        'pigeon:removeStaticPositions',
      ]);
    });
  });

  group('default controller marker routing', () {
    Future<MethodChannelOSM> attachedGenerated() async {
      await mockLegacy((call) async =>
          call.method == 'map#bootstrap#protocol'
              ? bootstrapWith(['camera', 'markers'])
              : null);
      final osm = MethodChannelOSM();
      await osm.init(9);
      final selection = await osm.attachMarkersRoute(9, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      return osm;
    }

    test('addMarker without icon mints a stable id on the typed route',
        () async {
      final osm = await attachedGenerated();
      Object? decodedId;
      Object? decodedLat;
      await mockMarkers('addMarker', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        decodedId = args[1];
        decodedLat = args[2] as double;
        return pigeonReply(null);
      });
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });

      await osm.addMarker(9, GeoPoint(latitude: 48.85, longitude: 2.35));

      expect(decodedId, 'osm-9-0');
      expect(decodedLat, 48.85);
      expect(invocations, isEmpty);
    });

    testWidgets('addMarker captures widget bytes asynchronously',
        (tester) async {
      final osm = await attachedGenerated();
      final iconKey = GlobalKey();
      Object? decodedIcon;
      await mockMarkers('addMarker', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        decodedIcon = args[4];
        return pigeonReply(null);
      });

      await tester.pumpWidget(
        RepaintBoundary(
          key: iconKey,
          child: const ColoredBox(color: Color(0xFF00FF00), child: SizedBox()),
        ),
      );
      await tester.runAsync(() async {
        await osm.addMarker(
          9,
          GeoPoint(latitude: 48.85, longitude: 2.35),
          globalKeyIcon: iconKey,
        );
      });

      expect(decodedIcon, isA<Uint8List>());
      expect((decodedIcon as Uint8List).isNotEmpty, isTrue);
    });

    testWidgets('changeMarker decomposes into move, icon, rotate, anchor',
        (tester) async {
      final osm = await attachedGenerated();
      final iconKey = GlobalKey();
      final calls = <Map<String, Object?>>[];
      ByteData? Function(ByteData?) record(String method) =>
          (ByteData? message) {
            final args =
                const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
            calls.add({method: args.sublist(1)});
            return pigeonReply(null);
          };
      await mockMarkers('moveMarker', record('moveMarker'));
      await mockMarkers('updateMarkerIcon', record('updateMarkerIcon'));
      await mockMarkers('rotateMarker', record('rotateMarker'));
      await mockMarkers('setMarkerAnchor', record('setMarkerAnchor'));

      await tester.pumpWidget(
        RepaintBoundary(
          key: iconKey,
          child: const ColoredBox(color: Color(0xFF0000FF), child: SizedBox()),
        ),
      );
      // First add on the typed route so the position table knows the id.
      await tester.runAsync(() async {
        await mockMarkers('addMarker', (message) {
          return pigeonReply(null);
        });
        await osm.addMarker(
          9,
          GeoPoint(latitude: 1, longitude: 2),
          globalKeyIcon: iconKey,
        );
      });
      calls.clear();

      await tester.runAsync(() async {
        await osm.changeMarker(
          9,
          GeoPoint(latitude: 1, longitude: 2),
          GeoPoint(latitude: 3, longitude: 4),
          globalKeyIcon: iconKey,
          angle: math.pi / 2,
          iconAnchor: IconAnchor(anchor: Anchor.left),
        );
      });

      expect(calls, hasLength(4));
      expect(calls[0], containsPair('moveMarker', ['osm-9-0', 3.0, 4.0]));
      expect(calls[1]['updateMarkerIcon'], hasLength(3));
      expect(
        (calls[1]['updateMarkerIcon'] as List<Object?>)[2],
        isA<generated.NativeMarkerSize>(),
      );
      expect(calls[2]['rotateMarker'], ['osm-9-0', 90.0]);
      final anchor = (calls[3]['setMarkerAnchor'] as List<Object?>)[1]
          as generated.NativeMarkerAnchor;
      expect(anchor.x, 1.0);
    });

    test('removeMarkers resolves typed ids for known positions', () async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));
      await osm.addMarker(9, GeoPoint(latitude: 3, longitude: 4));
      Object? decodedIds;
      await mockMarkers('removeMarkers', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        decodedIds = args[1];
        return pigeonReply(null);
      });

      await osm.removeMarkers(9, [
        GeoPoint(latitude: 1, longitude: 2),
        GeoPoint(latitude: 3, longitude: 4),
      ]);

      expect(decodedIds, ['osm-9-0', 'osm-9-1']);
    });

    test('unknown positions fall back to the legacy marker plane', () async {
      final osm = await attachedGenerated();
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });

      await osm.removeMarkers(
        9,
        [GeoPoint(latitude: 1, longitude: 2)],
      );

      expect(invocations, ['legacy:delete#markers']);
    });

    test('duplicate coordinates track every id and remove them together',
        () async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));

      Object? decodedIds;
      await mockMarkers('removeMarkers', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        decodedIds = args[1];
        return pigeonReply(null);
      });
      await osm.removeMarkers(9, [GeoPoint(latitude: 1, longitude: 2)]);

      // Legacy coordinate removal deletes every marker at the position.
      expect(decodedIds, ['osm-9-0', 'osm-9-1']);
    });

    testWidgets('icon updates target the first marker at duplicates',
        (tester) async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));

      Object? decodedId;
      await mockMarkers('updateMarkerIcon', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        decodedId = args[1];
        return pigeonReply(null);
      });

      final iconKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: iconKey,
          child: const ColoredBox(color: Color(0xFFFF0000), child: SizedBox()),
        ),
      );
      await tester.runAsync(() async {
        await osm.setIconMarker(9, GeoPoint(latitude: 1, longitude: 2), iconKey);
      });

      // Legacy icon updates resolve the first marker at the position.
      expect(decodedId, 'osm-9-0');
    });

    test('movement updates identity before icon work is attempted', () async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));
      invocations.clear();
      await mockMarkers('moveMarker', (_) {
        invocations.add('pigeon:moveMarker');
        return pigeonReply(null);
      });

      // A context-less key makes the icon capture throw after the movement
      // succeeded — the identity table must already reflect the new position.
      final staleKey = GlobalKey();
      await expectLater(
        osm.changeMarker(
          9,
          GeoPoint(latitude: 1, longitude: 2),
          GeoPoint(latitude: 3, longitude: 4),
          globalKeyIcon: staleKey,
        ),
        throwsA(isA<Exception>()),
      );
      expect(invocations, ['pigeon:moveMarker']);

      // The new position is typed; the old one is forgotten.
      invocations.clear();
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });
      await mockMarkers('removeMarkers', (_) => pigeonReply(null));
      await osm.removeMarkers(9, [GeoPoint(latitude: 3, longitude: 4)]);
      expect(invocations, isEmpty);
      invocations.clear();
      await osm.removeMarkers(9, [GeoPoint(latitude: 1, longitude: 2)]);
      expect(invocations, ['legacy:delete#markers']);
    });

    test('removal completing after close does not crash on the table',
        () async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));

      await mockMarkers('removeMarkers', (message) {
        // close() clears the identity table while the command is in flight.
        osm.close(9);
        return pigeonReply(null);
      });
      await osm.removePosition(9, GeoPoint(latitude: 1, longitude: 2));
    });

    test('add completing after close does not resurrect the table', () async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (message) {
        osm.close(9);
        return pigeonReply(null);
      });

      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));

      // The next decision for the map must start from a clean state.
      await mockLegacy((call) async =>
          call.method == 'map#bootstrap#protocol'
              ? bootstrapWith(['camera'])
              : null);
      await osm.init(9);
      expect(
        await osm.attachMarkersRoute(9, optIn: true),
        CameraRouteSelection.legacy,
      );
    });

    test('staticPosition carries cached group icons without legacy calls',
        () async {
      final osm = await attachedGenerated();
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });
      await mockMarkers('setStaticPositions', (_) => pigeonReply(null));

      await osm.staticPosition(9, [
        GeoPoint(latitude: 1, longitude: 2),
        GeoPoint(latitude: 3, longitude: 4),
      ], 'group-1');

      expect(invocations, isEmpty);
    });

    testWidgets('apple captures send raw bytes with logical size, not the'
        ' legacy size map', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final osm = await attachedGenerated();
      final iconKey = GlobalKey();
      final captured = <Object?>[];
      await mockMarkers('addMarker', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        captured.addAll(args.sublist(4));
        return pigeonReply(null);
      });
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });

      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: iconKey,
            child: const ColoredBox(
              color: Color(0xFFFF0000),
              child: SizedBox(width: 40, height: 24),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await osm.addMarker(
          9,
          GeoPoint(latitude: 48.85, longitude: 2.35),
          globalKeyIcon: iconKey,
        );
      });

      // Raw PNG bytes (Apple captures at 5x) plus logical dimensions cross
      // the typed route; the legacy {icon, size} map must not.
      expect(captured[0], isA<Uint8List>());
      final bytes = captured[0] as Uint8List;
      expect(bytes.length, greaterThan(4));
      expect(bytes.sublist(0, 4), [137, 80, 78, 71]); // PNG magic
      final size = captured[3] as generated.NativeMarkerSize;
      expect(size.width, 40);
      expect(size.height, 24);
      expect(invocations, isEmpty);
    });

    testWidgets('legacy serialization keeps the apple base64 size map',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await mockLegacy((call) async =>
          call.method == 'map#bootstrap#protocol'
              ? bootstrapWith(['camera'])
              : null);
      final osm = MethodChannelOSM();
      await osm.init(9);
      await osm.attachMarkersRoute(9, optIn: false);
      expect(osm.markersClientFor(9), isNull);

      final iconKey = GlobalKey();
      Map<String, dynamic>? legacyArgs;
      await mockLegacy((call) async {
        if (call.method == 'add#Marker') {
          legacyArgs = (call.arguments as Map).cast<String, dynamic>();
          return null;
        }
        return call.method == 'map#bootstrap#protocol'
            ? bootstrapWith(['camera'])
            : null;
      });

      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: iconKey,
            child: const ColoredBox(
              color: Color(0xFF00FF00),
              child: SizedBox(width: 30, height: 30),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await osm.addMarker(
          9,
          GeoPoint(latitude: 48.85, longitude: 2.35),
          globalKeyIcon: iconKey,
        );
      });

      // The legacy contract keeps the {icon, size} serialization.
      expect(legacyArgs, isNotNull);
      expect(legacyArgs!['icon'], isA<Map<dynamic, dynamic>>());
      final iconPayload =
          (legacyArgs!['icon'] as Map<dynamic, dynamic>)['icon'];
      expect(iconPayload, isA<String>());
      expect((legacyArgs!['icon'] as Map)['size'], [30, 30]);
    });

    testWidgets('empty clears keep the configured icon and repeat safely',
        (tester) async {
      final osm = await attachedGenerated();
      final wireCalls = <String>[]; // method:payload summary per call
      Object? firstIconBytes;
      await mockMarkers('setStaticPositions', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        final icon = args[3];
        wireCalls.add('set:${icon == null ? 'default' : 'icon'}');
        firstIconBytes ??= icon;
        return pigeonReply(null);
      });
      await mockMarkers('removeStaticPositions', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireCalls.add('remove:${args[1]}');
        return pigeonReply(null);
      });

      final iconKey = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: iconKey,
            child: const ColoredBox(
              color: Color(0xFF00FF00),
              child: SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      // Configure the icon, set positions, then clear with an empty list.
      await tester.runAsync(() async {
        await osm.customMarkerStaticPosition(9, iconKey, 'group-1');
        await osm.staticPosition(
          9,
          [GeoPoint(latitude: 1, longitude: 2)],
          'group-1',
        );
        await osm.staticPosition(9, [], 'group-1');
        // Repeated clearing succeeds as well (idempotent host contract).
        await osm.staticPosition(9, [], 'group-1');
      });

      // Icon-only configuration caches without sending (no group exists
      // yet); positions then carry the icon; both clears route removals.
      expect(wireCalls, [
        'set:icon',
        'remove:group-1',
        'remove:group-1',
      ]);

      // Refilling replays the preserved icon configuration.
      await tester.runAsync(() async {
        await osm.staticPosition(
          9,
          [GeoPoint(latitude: 3, longitude: 4)],
          'group-1',
        );
      });
      expect(wireCalls.last, 'set:icon');
      expect(firstIconBytes, isA<Uint8List>());
    });

    testWidgets('moves onto occupied coordinates keep native ordering',
        (tester) async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      final wireCalls = <String>[];
      await mockMarkers('moveMarker', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireCalls.add(args[1] as String);
        return pigeonReply(null);
      });
      await mockMarkers('updateMarkerIcon', (_) => pigeonReply(null));
      await mockMarkers('rotateMarker', (_) => pigeonReply(null));
      await mockMarkers('setMarkerAnchor', (_) => pigeonReply(null));

      final iconKey = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: iconKey,
            child: const ColoredBox(
              color: Color(0xFF0000FF),
              child: SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      // Oldest marker at P1; two newer markers share P2.
      await tester.runAsync(() async {
        await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));
        await osm.addMarker(9, GeoPoint(latitude: 3, longitude: 4));
        await osm.addMarker(9, GeoPoint(latitude: 3, longitude: 4));
      });
      wireCalls.clear();

      // Move the oldest marker onto the occupied coordinate: Darwin keeps
      // its original array index, so it stays the native first-match there.
      await tester.runAsync(() async {
        await osm.changeMarker(
          9,
          GeoPoint(latitude: 1, longitude: 2),
          GeoPoint(latitude: 3, longitude: 4),
        );
      });

      // A coordinate-based update on the occupied coordinate must resolve
      // the same primary the native layer would pick.
      await tester.runAsync(() async {
        await osm.changeMarker(
          9,
          GeoPoint(latitude: 3, longitude: 4),
          GeoPoint(latitude: 5, longitude: 6),
          globalKeyIcon: iconKey,
        );
      });

      expect(wireCalls, ['osm-9-0', 'osm-9-0']);
    });

    test('close drops the position table so a reattach starts fresh',
        () async {
      final osm = await attachedGenerated();
      await mockMarkers('addMarker', (_) => pigeonReply(null));
      await osm.addMarker(9, GeoPoint(latitude: 1, longitude: 2));

      osm.close(9);
      invocations.clear();
      await mockLegacy((call) async {
        if (call.method == 'map#bootstrap#protocol') {
          return bootstrapWith(['camera', 'markers']);
        }
        invocations.add('legacy:${call.method}');
        return null;
      });
      await osm.init(9);
      // Replacement attachment decides freshly and stays legacy.
      expect(
        await osm.attachMarkersRoute(9, optIn: false),
        CameraRouteSelection.legacy,
      );

      await osm.removeMarkers(
        9,
        [GeoPoint(latitude: 1, longitude: 2)],
      );

      expect(invocations, ['legacy:delete#markers']);
    });
  });
}

/// Minimal base-transport double recording delegated commands.
class _RecordingBaseTransport implements AndroidMapTransport {
  _RecordingBaseTransport(this.invocations);

  final List<String> invocations;

  @override
  AndroidMapBackend get backend => AndroidMapBackend.methodChannel;

  @override
  Stream<AndroidMapEvent> get events => const Stream.empty();

  @override
  Future<void> attach(int viewId) async {
    invocations.add('base:attach');
  }

  @override
  Future<void> initialize({required GeoPoint initialPosition}) async {
    invocations.add('base:initialize');
  }

  @override
  Future<void> moveTo(GeoPoint position, {required bool animated}) async {
    invocations.add('base:moveTo');
  }

  @override
  Future<void> setZoom(double zoom) async {
    invocations.add('base:setZoom');
  }

  @override
  Future<double> getZoom() async => 1.0;

  @override
  Future<void> setRotation(double angle, {required bool animated}) async {
    invocations.add('base:setRotation');
  }

  @override
  Future<void> addMarker(
    MarkerId markerId,
    GeoPoint position, {
    Uint8List? iconBytes,
    double angleDegrees = 0,
    IconAnchor? anchor,
  }) async {
    invocations.add('base:addMarker');
  }

  @override
  Future<void> addMarkers(Map<MarkerId, GeoPoint> markers) async {
    invocations.add('base:addMarkers');
  }

  @override
  Future<void> updateMarkerIcon(MarkerId markerId, Uint8List iconBytes) async {
    invocations.add('base:updateMarkerIcon');
  }

  @override
  Future<void> moveMarker(MarkerId markerId, GeoPoint position) async {
    invocations.add('base:moveMarker');
  }

  @override
  Future<void> rotateMarker(MarkerId markerId, double angleDegrees) async {
    invocations.add('base:rotateMarker');
  }

  @override
  Future<void> setMarkerAnchor(MarkerId markerId, IconAnchor anchor) async {
    invocations.add('base:setMarkerAnchor');
  }

  @override
  Future<void> removeMarker(MarkerId markerId) async {
    invocations.add('base:removeMarker');
  }

  @override
  Future<void> removeMarkers(Iterable<MarkerId> markerIds) async {
    invocations.add('base:removeMarkers');
  }

  @override
  Future<void> addCircle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double radius,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) async {
    invocations.add('base:addCircle');
  }

  @override
  Future<void> addRectangle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double distance,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) async {
    invocations.add('base:addRectangle');
  }

  @override
  Future<void> removeShape(ShapeId shapeId) async {
    invocations.add('base:removeShape');
  }

  @override
  Future<void> clearShapes() async {
    invocations.add('base:clearShapes');
  }

  @override
  Future<void> setStaticPositions(
    StaticPositionId groupId,
    List<GeoPoint> positions, {
    Uint8List? iconBytes,
  }) async {
    invocations.add('base:setStaticPositions');
  }

  @override
  Future<void> removeStaticPositions(StaticPositionId groupId) async {
    invocations.add('base:removeStaticPositions');
  }

  @override
  Future<void> drawRoad(
    RoadId roadId,
    List<GeoPoint> geometry,
    RoadOption option,
  ) async {
    invocations.add('base:drawRoad');
  }

  @override
  Future<void> removeRoad(RoadId roadId) async {
    invocations.add('base:removeRoad');
  }

  @override
  Future<void> clearRoads() async {
    invocations.add('base:clearRoads');
  }

  @override
  Future<void> setTile(CustomTile? tile) async {
    invocations.add('base:setTile');
  }

  @override
  Future<void> setOverlaysVisible(bool visible) async {
    invocations.add('base:setOverlaysVisible');
  }

  @override
  Future<void> showCurrentLocation() async {
    invocations.add('base:showCurrentLocation');
  }

  @override
  Future<GeoPoint> getCurrentLocation() async {
    invocations.add('base:getCurrentLocation');
    return GeoPoint(latitude: 0, longitude: 0);
  }

  @override
  Future<void> startLocationUpdates() async {
    invocations.add('base:startLocationUpdates');
  }

  @override
  Future<void> stopLocationUpdates() async {
    invocations.add('base:stopLocationUpdates');
  }

  @override
  Future<void> startLocationTracking({
    required bool stopFollowOnDrag,
    required bool disableMarkerRotation,
    required bool useDirectionMarker,
    required Anchor anchor,
  }) async {
    invocations.add('base:startLocationTracking');
  }

  @override
  Future<void> stopLocationTracking() async {
    invocations.add('base:stopLocationTracking');
  }

  @override
  Future<void> close() async {
    invocations.add('base:close');
  }
}
