import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Command/event boundary used by the opt-in Android controller.
///
/// Backend selection is final after [attach]. Stateful commands are never
/// replayed through another transport after initialization begins.
abstract interface class AndroidMapTransport {
  AndroidMapBackend get backend;

  Stream<AndroidMapEvent> get events;

  Future<void> attach(int viewId);

  Future<void> initialize({required GeoPoint initialPosition});

  Future<void> moveTo(GeoPoint position, {required bool animated});

  Future<void> setZoom(double zoom);

  Future<double> getZoom();

  Future<void> setRotation(double angle, {required bool animated});

  Future<void> addMarker(
    MarkerId markerId,
    GeoPoint position, {
    Uint8List? iconBytes,
  });

  Future<void> addMarkers(Map<MarkerId, GeoPoint> markers);

  Future<void> updateMarkerIcon(MarkerId markerId, Uint8List iconBytes);

  Future<void> removeMarker(MarkerId markerId);

  Future<void> removeMarkers(Iterable<MarkerId> markerIds);

  Future<void> addCircle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double radius,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  });

  Future<void> addRectangle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double distance,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  });

  Future<void> removeShape(ShapeId shapeId);

  Future<void> clearShapes();

  Future<void> setStaticPositions(
    StaticPositionId groupId,
    List<GeoPoint> positions, {
    Uint8List? iconBytes,
  });

  Future<void> removeStaticPositions(StaticPositionId groupId);

  Future<void> drawRoad(
    RoadId roadId,
    List<GeoPoint> geometry,
    RoadOption option,
  );

  Future<void> removeRoad(RoadId roadId);

  Future<void> clearRoads();

  Future<void> setTile(CustomTile? tile);

  Future<void> setOverlaysVisible(bool visible);

  Future<void> close();
}

typedef AndroidMapTransportFactory = AndroidMapTransport Function(
  AndroidMapBackend backend,
);
