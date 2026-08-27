import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidMapController', () {
    test('attaches, initializes, and completes ready from the selected map',
        () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 48.85, longitude: 2.35),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      final observed = <AndroidMapEvent>[];
      final subscription = controller.events.listen(observed.add);

      await controller.attachAndroidMap(42);
      var isReady = false;
      controller.ready.then((_) => isReady = true);
      transport.emit(const AndroidMapReady(viewId: 42, isReady: false));
      await Future<void>.delayed(Duration.zero);
      expect(isReady, isFalse);
      transport.emit(const AndroidMapReady(viewId: 42, isReady: true));
      await controller.ready;

      expect(transport.attachedViewId, 42);
      expect(transport.initialPosition?.latitude, 48.85);
      expect(controller.activeBackend, AndroidMapBackend.methodChannel);
      expect(observed, hasLength(2));

      await subscription.cancel();
      await controller.dispose();
      expect(transport.closeCount, 1);
    });

    test('auto falls back only when JNI attach fails', () async {
      final jni = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
        attachError: StateError('JNI map sessions unavailable'),
      );
      final methodChannel = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        transportFactory: (backend) => switch (backend) {
          AndroidMapBackend.jni => jni,
          AndroidMapBackend.methodChannel => methodChannel,
          AndroidMapBackend.auto => throw StateError('unresolved auto'),
        },
      );

      await controller.attachAndroidMap(8);

      expect(jni.attachCount, 1);
      expect(jni.closeCount, 1);
      expect(methodChannel.attachCount, 1);
      expect(methodChannel.initializeCount, 1);
      expect(controller.activeBackend, AndroidMapBackend.methodChannel);

      methodChannel.emit(const AndroidMapReady(viewId: 8, isReady: true));
      await controller.ready;
      await controller.dispose();
    });

    test('does not replay initialization through fallback', () async {
      final jni = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
        initializeError: StateError('initialization failed'),
      );
      final methodChannel = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        transportFactory: (backend) => switch (backend) {
          AndroidMapBackend.jni => jni,
          AndroidMapBackend.methodChannel => methodChannel,
          AndroidMapBackend.auto => throw StateError('unresolved auto'),
        },
      );

      await expectLater(
        controller.attachAndroidMap(9),
        throwsA(isA<AndroidMapException>()),
      );

      expect(jni.initializeCount, 1);
      expect(methodChannel.attachCount, 0);
      await expectLater(controller.ready, throwsA(isA<AndroidMapException>()));
      await controller.dispose();
    });

    test('does not allow reattach after attach failure', () async {
      final failedTransport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
        attachError: StateError('attach failed'),
      );
      var factoryCalls = 0;
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) {
          factoryCalls += 1;
          return failedTransport;
        },
      );

      await expectLater(
        controller.attachAndroidMap(10),
        throwsA(isA<AndroidMapException>()),
      );
      await expectLater(
        controller.attachAndroidMap(11),
        throwsA(isA<AndroidMapException>()),
      );

      expect(factoryCalls, 1);
      expect(failedTransport.attachCount, 1);
      await controller.dispose();
    });

    test('filters events belonging to another platform view', () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      final observed = <AndroidMapEvent>[];
      final subscription = controller.events.listen(observed.add);
      await controller.attachAndroidMap(11);

      transport.emit(const AndroidMapReady(viewId: 12, isReady: true));
      transport.emit(const AndroidMapReady(viewId: 11, isReady: true));
      await controller.ready;

      expect(observed, hasLength(1));
      expect(observed.single, isA<AndroidMapReady>());

      await subscription.cancel();
      await controller.dispose();
    });

    test('routes camera and stable marker commands through selected backend',
        () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.jni,
        transportFactory: (_) => transport,
      );
      await controller.attachAndroidMap(21);
      transport.emit(const AndroidMapReady(viewId: 21, isReady: true));
      await controller.ready;

      final destination = GeoPoint(latitude: 48.85, longitude: 2.35);
      await controller.camera.moveTo(destination, animated: true);
      await controller.camera.setZoom(14);
      expect(await controller.camera.getZoom(), 14);
      await controller.camera.setRotation(0.5, animated: false);
      final markerId = await controller.markers.add(destination);

      expect(transport.movedPosition, destination);
      expect(transport.zoom, 14);
      expect(transport.rotation, 0.5);
      expect(markerId.value, startsWith('android-21-'));
      expect(transport.markers[markerId], destination);

      await controller.markers.remove(markerId);
      expect(transport.markers, isEmpty);
      await controller.dispose();
    });

    test('routes Phase 4 overlays, bytes, layers, and bulk commands', () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.jni,
        transportFactory: (_) => transport,
      );
      await controller.attachAndroidMap(24);
      transport.emit(const AndroidMapReady(viewId: 24, isReady: true));
      await controller.ready;

      final firstPosition = GeoPoint(latitude: 48.85, longitude: 2.35);
      final marker = await controller.markers.add(
        firstPosition,
        iconBytes: Uint8List.fromList([1, 2, 3]),
      );
      await controller.markers.updateIcon(
        marker,
        Uint8List.fromList([4, 5, 6]),
      );
      final bulkMarkers = await controller.markers.addAll([
        GeoPoint(latitude: 48.86, longitude: 2.36),
        GeoPoint(latitude: 48.87, longitude: 2.37),
      ]);
      expect(transport.markers, hasLength(3));
      expect(transport.markerIcons[marker], [4, 5, 6]);
      await controller.markers.removeAll(bulkMarkers);

      final circle = await controller.shapes.addCircle(
        center: firstPosition,
        radius: 25,
        color: Colors.blue,
      );
      final rectangle = await controller.shapes.addRectangle(
        center: firstPosition,
        distance: 40,
        color: Colors.green,
      );
      expect(transport.shapes, {circle, rectangle});
      await controller.shapes.remove(circle);

      final staticGroup = await controller.staticPositions.set([
        firstPosition,
        GeoPoint(latitude: 48.88, longitude: 2.38),
      ]);
      expect(transport.staticPositions[staticGroup], hasLength(2));

      final road = await controller.roads.draw([
        firstPosition,
        GeoPoint(latitude: 48.89, longitude: 2.39),
      ]);
      expect(transport.roads[road], hasLength(2));

      final tile = CustomTile.satellite();
      await controller.layers.setTile(tile);
      await controller.layers.setOverlaysVisible(false);
      expect(transport.tile, same(tile));
      expect(transport.overlaysVisible, isFalse);

      await controller.staticPositions.remove(staticGroup);
      await controller.roads.clear();
      await controller.shapes.clear();
      await controller.markers.remove(marker);
      expect(transport.staticPositions, isEmpty);
      expect(transport.roads, isEmpty);
      expect(transport.shapes, isEmpty);
      expect(transport.markers, isEmpty);

      await controller.dispose();
    });

    test('validates Phase 4 geometry and duplicate stable IDs', () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      await controller.attachAndroidMap(25);
      transport.emit(const AndroidMapReady(viewId: 25, isReady: true));
      await controller.ready;

      const shapeId = ShapeId('shape');
      await controller.shapes.addCircle(
        center: GeoPoint(latitude: 1, longitude: 2),
        radius: 10,
        color: Colors.red,
        shapeId: shapeId,
      );
      await expectLater(
        controller.shapes.addCircle(
          center: GeoPoint(latitude: 1, longitude: 2),
          radius: 10,
          color: Colors.red,
          shapeId: shapeId,
        ),
        throwsA(isA<AndroidMapException>()),
      );
      await expectLater(
        controller.roads.draw([GeoPoint(latitude: 1, longitude: 2)]),
        throwsA(isA<AndroidMapException>()),
      );
      await expectLater(
        controller.staticPositions.set(const []),
        throwsA(isA<AndroidMapException>()),
      );

      await controller.dispose();
    });

    test('dispose during attach prevents fallback and initialization',
        () async {
      final attachGate = Completer<void>();
      final jni = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
        attachGate: attachGate,
      );
      final methodChannel = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        transportFactory: (backend) => switch (backend) {
          AndroidMapBackend.jni => jni,
          AndroidMapBackend.methodChannel => methodChannel,
          AndroidMapBackend.auto => throw StateError('unresolved auto'),
        },
      );

      final attaching = controller.attachAndroidMap(13);
      await Future<void>.delayed(Duration.zero);
      final disposing = controller.dispose();
      attachGate.complete();

      await expectLater(attaching, throwsA(isA<AndroidMapException>()));
      await disposing;
      expect(jni.initializeCount, 0);
      expect(methodChannel.attachCount, 0);
    });

    test('dispose fails pending readiness and closes once', () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      await controller.attachAndroidMap(13);

      final ready = expectLater(
        controller.ready,
        throwsA(isA<AndroidMapException>()),
      );
      await controller.dispose();
      await ready;
      await controller.dispose();

      expect(transport.closeCount, 1);
    });
  });
}

final class FakeAndroidMapTransport implements AndroidMapTransport {
  FakeAndroidMapTransport({
    required this.backend,
    this.attachError,
    this.initializeError,
    this.attachGate,
  });

  @override
  final AndroidMapBackend backend;
  final Object? attachError;
  final Object? initializeError;
  final Completer<void>? attachGate;
  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);

  int attachCount = 0;
  int initializeCount = 0;
  int closeCount = 0;
  int? attachedViewId;
  GeoPoint? initialPosition;
  GeoPoint? movedPosition;
  double? zoom;
  double? rotation;
  final Map<MarkerId, GeoPoint> markers = {};
  final Map<MarkerId, Uint8List> markerIcons = {};
  final Set<ShapeId> shapes = {};
  final Map<StaticPositionId, List<GeoPoint>> staticPositions = {};
  final Map<RoadId, List<GeoPoint>> roads = {};
  CustomTile? tile;
  bool overlaysVisible = true;
  bool _closed = false;

  @override
  Stream<AndroidMapEvent> get events => _events.stream;

  @override
  Future<void> attach(int viewId) async {
    attachCount += 1;
    final error = attachError;
    if (error != null) throw error;
    await attachGate?.future;
    attachedViewId = viewId;
  }

  @override
  Future<void> initialize({required GeoPoint initialPosition}) async {
    initializeCount += 1;
    final error = initializeError;
    if (error != null) throw error;
    this.initialPosition = initialPosition;
  }

  void emit(AndroidMapEvent event) {
    _events.add(event);
  }

  @override
  Future<void> moveTo(GeoPoint position, {required bool animated}) async {
    movedPosition = position;
  }

  @override
  Future<void> setZoom(double zoom) async {
    this.zoom = zoom;
  }

  @override
  Future<double> getZoom() async => zoom ?? 10;

  @override
  Future<void> setRotation(double angle, {required bool animated}) async {
    rotation = angle;
  }

  @override
  Future<void> addMarker(
    MarkerId markerId,
    GeoPoint position, {
    Uint8List? iconBytes,
  }) async {
    markers[markerId] = position;
    if (iconBytes != null) markerIcons[markerId] = iconBytes;
  }

  @override
  Future<void> addMarkers(Map<MarkerId, GeoPoint> markers) async {
    this.markers.addAll(markers);
  }

  @override
  Future<void> updateMarkerIcon(
    MarkerId markerId,
    Uint8List iconBytes,
  ) async {
    markerIcons[markerId] = iconBytes;
  }

  @override
  Future<void> removeMarker(MarkerId markerId) async {
    markers.remove(markerId);
    markerIcons.remove(markerId);
  }

  @override
  Future<void> removeMarkers(Iterable<MarkerId> markerIds) async {
    for (final markerId in markerIds) {
      markers.remove(markerId);
      markerIcons.remove(markerId);
    }
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
    shapes.add(shapeId);
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
    shapes.add(shapeId);
  }

  @override
  Future<void> removeShape(ShapeId shapeId) async {
    shapes.remove(shapeId);
  }

  @override
  Future<void> clearShapes() async {
    shapes.clear();
  }

  @override
  Future<void> setStaticPositions(
    StaticPositionId groupId,
    List<GeoPoint> positions, {
    Uint8List? iconBytes,
  }) async {
    staticPositions[groupId] = positions;
  }

  @override
  Future<void> removeStaticPositions(StaticPositionId groupId) async {
    staticPositions.remove(groupId);
  }

  @override
  Future<void> drawRoad(
    RoadId roadId,
    List<GeoPoint> geometry,
    RoadOption option,
  ) async {
    roads[roadId] = geometry;
  }

  @override
  Future<void> removeRoad(RoadId roadId) async {
    roads.remove(roadId);
  }

  @override
  Future<void> clearRoads() async {
    roads.clear();
  }

  @override
  Future<void> setTile(CustomTile? tile) async {
    this.tile = tile;
  }

  @override
  Future<void> setOverlaysVisible(bool visible) async {
    overlaysVisible = visible;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    closeCount += 1;
    await _events.close();
  }
}
