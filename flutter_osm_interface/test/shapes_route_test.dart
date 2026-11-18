// Shapes-family routing tests: the frozen routing decision (opt-in x host
// capability), the circle/rectangle wire form (ids, coordinate precision,
// packed ARGB colors, widths), replace semantics, removal/clear routing and
// the facade error mapping.
//
// The probe runs on the legacy method-channel fixture; generated shapes
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
import 'package:flutter_osm_interface/src/channel/pigeon/native_shapes_client.dart';

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapShapesApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

/// Host advertising the shapes capability alongside the camera families.
final Map<Object?, Object?> shapesBootstrap = {
  'revision': 1,
  'schemaId': 'flutter_osm.native.camera.v1',
  'capabilities': ['camera', 'markers', 'shapes'],
  'sessionToken': 'token-7',
  'generation': 0,
};

/// Original camera-only host: shapes commands must stay legacy.
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
/// shapes DTO (137 NativeShapeStyle) in the pigeon wire form.
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is generated.NativeShapeStyle) {
      buffer.putUint8(137);
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
    if (type == 137) {
      return generated.NativeShapeStyle.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

CircleOSM sampleCircle() => CircleOSM(
      key: 'circle-1',
      centerPoint: GeoPoint(latitude: 47.376912345, longitude: 8.541712345),
      radius: 250.5,
      color: const Color(0x8E24AAFF),
      borderColor: const Color(0xFF00D2FF),
      strokeWidth: 3.5,
    );

RectOSM sampleRect() => RectOSM(
      key: 'rect-1',
      centerPoint: GeoPoint(latitude: -33.865143, longitude: 151.209900),
      distance: 1200.25,
      color: const Color(0x22004488),
      strokeWidth: 1.0,
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
    for (final method in [
      'addCircle',
      'addRectangle',
      'removeShape',
      'removeCircles',
      'removeRectangles',
      'clearShapes',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(pigeonChannel(method), null);
    }
  });

  group('attachShapesRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachShapesRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
    });

    test('shapes host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('removeCircles', (_) {
        invocations.add('pigeon:removeCircles');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachShapesRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);

      await osm.removeAllCircle(7);
      expect(invocations, ['pigeon:removeCircles']);
    });

    test('original camera-only host keeps shapes commands on legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'remove#circle') {
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      await mockPigeon('removeCircles', (_) {
        throw Exception('shapes route must never activate');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachShapesRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);

      await osm.removeAllCircle(7);
      expect(
        invocations.where((m) => m.startsWith('pigeon:')),
        isEmpty,
      );
      expect(invocations, contains('legacy:remove#circle'));
    });

    test('the routing decision is frozen after attachment', () async {
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('removeCircles', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);
      await mockLegacy(
        (call) async => throw Exception('probe must not rerun'),
      );
      final selection = await osm.attachShapesRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.generated);
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('removeCircles', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);
      expect(osm.shapesClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.shapesClientFor(7), isNull);

      await osm.init(7);
      final selection = await osm.attachShapesRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.shapesClientFor(7), isNull);
    });
  });

  group('generated shapes wire form', () {
    test('addCircle carries id, precision, packed colors and width',
        () async {
      generated.NativeShapeStyle? wireStyle;
      List<Object?>? wireArgs;
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('addCircle', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        wireArgs = args;
        wireStyle = args[5] as generated.NativeShapeStyle?;
        invocations.add('pigeon:addCircle');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      final circle = sampleCircle();
      await osm.drawCircle(7, circle);
      expect(invocations, ['pigeon:addCircle']);

      // args[0] = session, 1 = id, 2 = lat, 3 = lon, 4 = radius, 5 = style.
      expect(wireArgs![1], 'circle-1');
      expect(wireArgs![2], 47.376912345);
      expect(wireArgs![3], 8.541712345);
      expect(wireArgs![4], 250.5);

      final style = wireStyle!;
      expect(style.fillColorArgb, 0x8E24AAFF);
      expect(style.borderColorArgb, 0xFF00D2FF);
      expect(style.strokeWidth, 3.5);
    });

    test('addRectangle carries the distance field', () async {
      List<Object?>? wireArgs;
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('addRectangle', (message) {
        wireArgs =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await osm.drawRect(7, sampleRect());
      // args[0] = session, 1 = id, 2 = lat, 3 = lon, 4 = distance, 5 = style.
      expect(wireArgs![1], 'rect-1');
      expect(wireArgs![2], -33.865143);
      expect(wireArgs![3], 151.2099);
      expect(wireArgs![4], 1200.25);
      expect((wireArgs![5] as generated.NativeShapeStyle).fillColorArgb,
          0x22004488);
      // No border configured: null crosses the wire (host falls back to
      // the fill color, matching its legacy decoder default).
      expect((wireArgs![5] as generated.NativeShapeStyle).borderColorArgb,
          isNull);
    });

    test('replace re-issues the add for the same id', () async {
      final addedIds = <Object?>[];
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('addCircle', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        addedIds.add(args[1]);
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      final circle = sampleCircle();
      await osm.drawCircle(7, circle);
      await osm.drawCircle(
        7,
        CircleOSM(
          key: circle.key,
          centerPoint: GeoPoint(latitude: 47.1, longitude: 8.1),
          radius: 200,
          color: const Color(0xFF111111),
          strokeWidth: 2,
        ),
      );

      expect(addedIds, ['circle-1', 'circle-1']);
    });

    test('removeAllShapes routes through clearShapes on the generated route',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? shapesBootstrap : null;
      });
      await mockPigeon('clearShapes', (_) {
        invocations.add('pigeon:clearShapes');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await osm.removeAllShapes(7);
      expect(invocations, contains('pigeon:clearShapes'));
      expect(invocations.where((m) => m.contains('clear#shapes')), isEmpty);
    });

    test('removeAllShapes keeps the legacy route without the capability',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });
      await mockPigeon('clearShapes', (_) {
        throw Exception('clear route must never activate');
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await osm.removeAllShapes(7);
      expect(invocations, ['legacy:map#bootstrap#protocol', 'legacy:clear#shapes']);
    });

    test('removal by id, kind clears and full clear route generated',
        () async {
      final routed = <String>[];
      await mockLegacy((call) async => shapesBootstrap);
      for (final method in ['removeShape', 'removeCircles', 'removeRectangles']) {
        await mockPigeon(method, (message) {
          routed.add(method);
          return pigeonReply(null);
        });
      }

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await osm.removeCircle(7, 'circle-1');
      await osm.removeRect(7, 'rect-1');
      await osm.removeAllCircle(7);
      await osm.removeAllRect(7);

      expect(routed, ['removeShape', 'removeShape', 'removeCircles', 'removeRectangles']);
    });
  });

  group('facade error mapping', () {
    test('stale_session maps to StaleMapSessionException', () async {
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('addCircle', (_) => pigeonError('stale_session'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await expectLater(
        osm.drawCircle(7, sampleCircle()),
        throwsA(isA<StaleMapSessionException>()),
      );
    });

    test('shapes_not_ready maps to ShapesNotReadyException', () async {
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('addCircle', (_) => pigeonError('shapes_not_ready'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await expectLater(
        osm.drawCircle(7, sampleCircle()),
        throwsA(isA<ShapesNotReadyException>()),
      );
    });

    test('unknown codes rethrow as PlatformException', () async {
      await mockLegacy((call) async => shapesBootstrap);
      await mockPigeon('addCircle', (_) => pigeonError('boom'));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await expectLater(
        osm.drawCircle(7, sampleCircle()),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('legacy route', () {
    test('circle draw keeps the legacy map payload byte-for-byte', () async {
      Object? legacyArgs;
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == 'draw#circle') {
          legacyArgs = call.arguments;
          return null;
        }
        return call.method == bootstrapMethod ? cameraOnlyBootstrap : null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachShapesRoute(7, optIn: true);

      await osm.drawCircle(7, sampleCircle());
      expect(invocations, contains('legacy:draw#circle'));
      final map = legacyArgs as Map<dynamic, dynamic>;
      expect(map['key'], 'circle-1');
      expect(map['lat'], 47.376912345);
      expect(map['lon'], 8.541712345);
      expect(map['radius'], 250.5);
      // Legacy color list order: [red, blue, green, alpha].
      expect(map['color'], [0x24, 0xFF, 0xAA, 0x8E]);
      expect(map['colorBorder'], [0x00, 0xFF, 0xD2, 0xFF]);
      expect(map['strokeWidth'], 3.5);
    });
  });
}
