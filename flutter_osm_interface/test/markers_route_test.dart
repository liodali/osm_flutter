// C3 markers-family slice: capability-gated attach, wire assertions through
// the generated channel, and typed-transport delegation (non-marker commands
// never leave the selected base transport).
import 'dart:typed_data';

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
