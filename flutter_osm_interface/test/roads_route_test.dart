// Roads-family routing tests: the frozen routing decision (opt-in x host
// capability), the manual-drawing wire form (road key, flat coordinate
// precision, packed ARGB colors, widths, dotted, zoom-to-route), replace
// semantics, removal/clear routing and the facade error mapping.
//
// The probe runs on the legacy method-channel fixture; generated roads
// channels are BasicMessageChannels speaking the pigeon wire envelope
// (StandardMessageCodec list-of-one success / [code, message, details] error).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;
import 'package:flutter_osm_interface/src/channel/pigeon/native_roads_client.dart';

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapRoadsApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

/// Host advertising the roads capability alongside the camera families.
final Map<Object?, Object?> roadsBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'markers', 'roads'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: road commands must stay legacy.
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
/// roads DTO (138 NativeRoadStyle) in the pigeon wire form.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeRoadStyle) {
      buffer.putUint8(138);
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
    if (type == 138) {
      return generated.NativeRoadStyle.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

final List<GeoPoint> sampleRoad = [
  GeoPoint(latitude: 47.376912345, longitude: 8.541712345),
  GeoPoint(latitude: 47.1, longitude: 8.2),
  GeoPoint(latitude: 47.0, longitude: 8.0),
];

RoadOption sampleOption() => const RoadOption(
      roadColor: Color(0xFF4CAF50),
      roadWidth: 5,
      roadBorderColor: Color(0xFFFFFFFF),
      roadBorderWidth: 2,
      zoomInto: true,
      isDotted: false,
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
    for (final method in ['drawRoad', 'removeRoad', 'clearRoads']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachRoadsRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachRoadsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('roads host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('clearRoads', (_) {
        invocations.add('pigeon:clearRoads');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachRoadsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.clearAllRoads(7);
      expect(invocations, contains('pigeon:clearRoads'));
    });

    test('original camera-only host keeps road commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'clear#roads') {
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      await mockPigeon('clearRoads', (_) {
        throw Exception('roads route must never activate');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachRoadsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await osm.clearAllRoads(7);
      expect(
        invocations.where((m) => m.startsWith('pigeon:')),
        isEmpty,
      );
      expect(invocations, contains('legacy:clear#roads'));
    });

    test('the routing decision is frozen after attachment', () async {
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('clearRoads', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);
      await mockLegacy(
        (call) async => throw Exception('probe must not rerun'),
      );
      final selection = await osm.attachRoadsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.generated);
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('clearRoads', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);
      expect(osm.roadsClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.roadsClientFor(7), isNull);

      await osm.init(7);
      final selection = await osm.attachRoadsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.roadsClientFor(7), isNull);
    });

    test('families are isolated: roads attach does not touch shapes',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? roadsBootstrap : null;
      });
      await mockPigeon('clearShapes', (_) {
        throw Exception('shapes route must not activate from roads attach');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      // The shapes family keeps its own frozen decision (absent → legacy).
      expect(osm.shapesClientFor(7), isNull);
      await osm.removeAllShapes(7);
      expect(invocations.where((m) => m.startsWith('pigeon:')), isEmpty);
      expect(invocations, contains('legacy:clear#shapes'));
    });
  });

  group('generated road wire form', () {
    test('drawRoad carries key, flat precision coordinates and styling',
        () async {
      List<Object?>? wireArgs;
      generated.NativeRoadStyle? wireStyle;
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('drawRoad', (message) {
        wireArgs =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireStyle = wireArgs![3] as generated.NativeRoadStyle?;
        invocations.add('pigeon:drawRoad');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await osm.drawRoadManually(7, 'route-1', sampleRoad, sampleOption());
      expect(invocations, ['pigeon:drawRoad']);

      // args[0]=session, 1=id, 2=flat coordinates, 3=style, 4=zoomInto.
      expect(wireArgs![1], 'route-1');
      final flat = wireArgs![2] as Float64List;
      expect(flat, [
        47.376912345, 8.541712345, //
        47.1, 8.2, //
        47.0, 8.0,
      ]);
      expect(wireArgs![4], isTrue);

      final style = wireStyle!;
      expect(style.roadColorArgb, 0xFF4CAF50);
      expect(style.roadWidth, 5.0);
      expect(style.borderColorArgb, 0xFFFFFFFF);
      expect(style.borderWidth, 2.0);
      expect(style.dotted, isFalse);
    });

    test('dotted roads without borders cross the wire intact', () async {
      List<Object?>? wireArgs;
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('drawRoad', (message) {
        wireArgs =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await osm.drawRoadManually(
        7,
        'route-2',
        sampleRoad,
        const RoadOption(roadColor: Color(0xFF2196F3), isDotted: true),
      );

      final style = wireArgs![3] as generated.NativeRoadStyle;
      expect(style.borderColorArgb, isNull);
      expect(style.borderWidth, isNull);
      expect(style.dotted, isTrue);
      expect(wireArgs![4], isTrue); // zoomInto defaults true in RoadOption
    });

    test('replacement re-issues draw for the same key', () async {
      final drawnKeys = <Object?>[];
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('drawRoad', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        drawnKeys.add(args[1]);
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await osm.drawRoadManually(7, 'route-1', sampleRoad, sampleOption());
      await osm.drawRoadManually(
        7,
        'route-1',
        sampleRoad.reversed.toList(),
        sampleOption(),
      );

      expect(drawnKeys, ['route-1', 'route-1']);
    });

    test('removal by key and clearing route generated', () async {
      final routed = <String>[];
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('removeRoad', (_) {
        routed.add('removeRoad');
        return pigeonReply(null);
      });
      await mockPigeon('clearRoads', (_) {
        routed.add('clearRoads');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await osm.removeRoad(7, 'route-1');
      await osm.clearAllRoads(7);

      expect(routed, ['removeRoad', 'clearRoads']);
    });
  });

  group('facade error mapping', () {
    test('stale_session maps to StaleMapSessionException', () async {
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('drawRoad', (_) => pigeonError('stale_session'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await expectLater(
        osm.drawRoadManually(7, 'route-1', sampleRoad, sampleOption()),
        throwsA(isA<StaleMapSessionException>()),
      );
    });

    test('roads_not_ready maps to RoadsNotReadyException', () async {
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('drawRoad', (_) => pigeonError('roads_not_ready'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await expectLater(
        osm.drawRoadManually(7, 'route-1', sampleRoad, sampleOption()),
        throwsA(isA<RoadsNotReadyException>()),
      );
    });

    test('unknown codes rethrow as PlatformException', () async {
      await mockLegacy((call) async => roadsBootstrap);
      await mockPigeon('drawRoad', (_) => pigeonError('boom'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await expectLater(
        osm.drawRoadManually(7, 'route-1', sampleRoad, sampleOption()),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('legacy route', () {
    test('manual drawing keeps the legacy encoded payload', () async {
      Object? legacyArgs;
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'drawRoad#manually') {
          legacyArgs = call.arguments;
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachRoadsRoute(7, optIn: true);

      await osm.drawRoadManually(7, 'route-1', sampleRoad, sampleOption());
      expect(invocations, contains('legacy:drawRoad#manually'));
      final map = legacyArgs as Map<dynamic, dynamic>;
      expect(map['key'], 'route-1');
      // Polyline-encoded coordinates, matching the legacy contract.
      expect(map['road'], isA<String>());
      expect(map['roadWidth'], 5.0);
      expect(map['isDotted'], isFalse);
      expect(map['zoomIntoRegion'], isTrue);
      expect(map['roadColor'], isA<List<dynamic>>());
    });
  });
}
