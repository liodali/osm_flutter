// Typed-transport wrapper routing the markers family through the generated
// channel while every other command family stays on the selected base
// transport (MethodChannel or JNI). Attach-time selection only: the wrapper
// never re-routes after initialization, and it changes no backend choice.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_osm_interface/src/android/android_map_event.dart';
import 'package:flutter_osm_interface/src/android/android_map_platform.dart';
import 'package:flutter_osm_interface/src/android/android_map_id.dart';
import 'package:flutter_osm_interface/src/android/android_map_transport.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_markers_client.dart';
import 'package:flutter_osm_interface/src/types/types.dart';

/// Delegating transport: marker commands (including static-position groups)
/// go through the generated channel, everything else through [base].
class PigeonMarkersTransport implements AndroidMapTransport {
  final AndroidMapTransport base;
  final PigeonMarkersClient markersClient;

  PigeonMarkersTransport({required this.base, required this.markersClient});

  @override
  AndroidMapBackend get backend => base.backend;

  @override
  Stream<AndroidMapEvent> get events => base.events;

  @override
  Future<void> attach(int viewId) => base.attach(viewId);

  @override
  Future<void> initialize({required GeoPoint initialPosition}) =>
      base.initialize(initialPosition: initialPosition);

  @override
  Future<void> moveTo(GeoPoint position, {required bool animated}) =>
      base.moveTo(position, animated: animated);

  @override
  Future<void> setZoom(double zoom) => base.setZoom(zoom);

  @override
  Future<double> getZoom() => base.getZoom();

  @override
  Future<void> setRotation(double angle, {required bool animated}) =>
      base.setRotation(angle, animated: animated);

  @override
  Future<void> addMarker(
    MarkerId markerId,
    GeoPoint position, {
    Uint8List? iconBytes,
    double angleDegrees = 0,
    IconAnchor? anchor,
  }) {
    return markersClient.addMarker(
      markerId.value,
      position.latitude,
      position.longitude,
      iconBytes: iconBytes,
      angleDegrees: angleDegrees,
      anchor: anchor?.toGenerated(),
    );
  }

  @override
  Future<void> addMarkers(Map<MarkerId, GeoPoint> markers) {
    return markersClient.addMarkers(
      markers.keys.map((id) => id.value).toList(growable: false),
      Float64List.fromList(
        markers.values
            .expand((point) => [point.latitude, point.longitude])
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> updateMarkerIcon(
    MarkerId markerId,
    Uint8List iconBytes, {
    List<int>? iconLogicalSize,
  }) =>
      markersClient.updateMarkerIcon(
        markerId.value,
        iconBytes,
        iconLogicalSize: iconLogicalSize,
      );

  @override
  Future<void> moveMarker(MarkerId markerId, GeoPoint position) =>
      markersClient.moveMarker(
        markerId.value,
        position.latitude,
        position.longitude,
      );

  @override
  Future<void> rotateMarker(MarkerId markerId, double angleDegrees) =>
      markersClient.rotateMarker(markerId.value, angleDegrees);

  @override
  Future<void> setMarkerAnchor(MarkerId markerId, IconAnchor anchor) =>
      markersClient.setMarkerAnchor(markerId.value, anchor.toGenerated());

  @override
  Future<void> removeMarker(MarkerId markerId) =>
      markersClient.removeMarker(markerId.value);

  @override
  Future<void> removeMarkers(Iterable<MarkerId> markerIds) => markersClient
      .removeMarkers(markerIds.map((id) => id.value).toList(growable: false));

  @override
  Future<void> addCircle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double radius,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) =>
      base.addCircle(
        shapeId: shapeId,
        center: center,
        radius: radius,
        fillColor: fillColor,
        borderColor: borderColor,
        strokeWidth: strokeWidth,
      );

  @override
  Future<void> addRectangle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double distance,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) =>
      base.addRectangle(
        shapeId: shapeId,
        center: center,
        distance: distance,
        fillColor: fillColor,
        borderColor: borderColor,
        strokeWidth: strokeWidth,
      );

  @override
  Future<void> removeShape(ShapeId shapeId) => base.removeShape(shapeId);

  @override
  Future<void> clearShapes() => base.clearShapes();

  @override
  Future<void> setStaticPositions(
    StaticPositionId groupId,
    List<GeoPoint> positions, {
    Uint8List? iconBytes,
  }) {
    return markersClient.setStaticPositions(
      groupId.value,
      Float64List.fromList([
        for (final point in positions) ...[
          point.latitude,
          point.longitude,
          // Typed marker contract carries degrees; GeoPointWithOrientation
          // stores radians internally.
          point is GeoPointWithOrientation ? point.angle * 180 / math.pi : 0.0,
        ],
      ]),
      iconBytes: iconBytes,
    );
  }

  @override
  Future<void> removeStaticPositions(StaticPositionId groupId) =>
      markersClient.removeStaticPositions(groupId.value);

  @override
  Future<void> drawRoad(RoadId roadId, List<GeoPoint> geometry, RoadOption option) =>
      base.drawRoad(roadId, geometry, option);

  @override
  Future<void> removeRoad(RoadId roadId) => base.removeRoad(roadId);

  @override
  Future<void> clearRoads() => base.clearRoads();

  @override
  Future<void> setTile(CustomTile? tile) => base.setTile(tile);

  @override
  Future<void> setOverlaysVisible(bool visible) => base.setOverlaysVisible(visible);

  @override
  Future<void> showCurrentLocation() => base.showCurrentLocation();

  @override
  Future<GeoPoint> getCurrentLocation() => base.getCurrentLocation();

  @override
  Future<void> startLocationUpdates() => base.startLocationUpdates();

  @override
  Future<void> stopLocationUpdates() => base.stopLocationUpdates();

  @override
  Future<void> startLocationTracking({
    required bool stopFollowOnDrag,
    required bool disableMarkerRotation,
    required bool useDirectionMarker,
    required Anchor anchor,
  }) =>
      base.startLocationTracking(
        stopFollowOnDrag: stopFollowOnDrag,
        disableMarkerRotation: disableMarkerRotation,
        useDirectionMarker: useDirectionMarker,
        anchor: anchor,
      );

  @override
  Future<void> stopLocationTracking() => base.stopLocationTracking();

  @override
  Future<void> close() => base.close();
}
