// Handwritten support facade over the generated markers channel.
//
// Mirrors the camera facade: applications never touch generated types. The
// Flutter widget→PNG capture pipeline stays fully asynchronous in Dart;
// only the resulting encoded bytes cross the generated channel. Null icon
// bytes mean the native default marker.
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_map_camera.g.dart' as generated;
import 'package:flutter_osm_interface/src/types/types.dart';

/// Typed error thrown when the native engine cannot accept a marker command
/// yet (icon layer not initialized) or the engine rejected the mutation.
class MarkersNotReadyException implements Exception {
  const MarkersNotReadyException();

  @override
  String toString() =>
      'MarkersNotReadyException: the native marker layer is not ready';
}

/// Selected generated-markers route for one map attachment.
class PigeonMarkersClient {
  final generated.NativeMapMarkersApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonMarkersClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapMarkersApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  Future<void> addMarker(
    String markerId,
    double latitude,
    double longitude, {
    Uint8List? iconBytes,
    double angleDegrees = 0,
    generated.NativeMarkerAnchor? anchor,
    List<int>? iconLogicalSize,
  }) {
    return _guard(
      () => _api.addMarker(
        _wireSession,
        markerId,
        latitude,
        longitude,
        iconBytes,
        angleDegrees,
        anchor,
        iconLogicalSize?.toGeneratedSize(),
      ),
    );
  }

  Future<void> addMarkers(
    List<String> markerIds,
    Float64List coordinates,
  ) {
    return _guard(() => _api.addMarkers(_wireSession, markerIds, coordinates));
  }

  Future<void> updateMarkerIcon(
    String markerId,
    Uint8List iconBytes, {
    List<int>? iconLogicalSize,
  }) {
    return _guard(
      () => _api.updateMarkerIcon(
        _wireSession,
        markerId,
        iconBytes,
        iconLogicalSize?.toGeneratedSize(),
      ),
    );
  }

  Future<void> moveMarker(
    String markerId,
    double latitude,
    double longitude,
  ) {
    return _guard(
      () => _api.moveMarker(_wireSession, markerId, latitude, longitude),
    );
  }

  Future<void> rotateMarker(String markerId, double angleDegrees) {
    return _guard(() => _api.rotateMarker(_wireSession, markerId, angleDegrees));
  }

  Future<void> setMarkerAnchor(String markerId, generated.NativeMarkerAnchor anchor) {
    return _guard(() => _api.setMarkerAnchor(_wireSession, markerId, anchor));
  }

  Future<void> setStaticPositions(
    String groupId,
    Float64List coordinates, {
    Uint8List? iconBytes,
    List<int>? iconLogicalSize,
  }) {
    return _guard(
      () => _api.setStaticPositions(
        _wireSession,
        groupId,
        coordinates,
        iconBytes,
        iconLogicalSize?.toGeneratedSize(),
      ),
    );
  }

  Future<void> removeStaticPositions(String groupId) {
    return _guard(() => _api.removeStaticPositions(_wireSession, groupId));
  }

  Future<void> removeMarker(String markerId) {
    return _guard(() => _api.removeMarker(_wireSession, markerId));
  }

  Future<void> removeMarkers(Iterable<String> markerIds) {
    return _guard(
      () => _api.removeMarkers(_wireSession, markerIds.toList(growable: false)),
    );
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
        case 'disposed':
          throw const StaleMapSessionException();
        case 'markers_not_ready':
        case 'camera_not_ready':
          throw const MarkersNotReadyException();
      }
      rethrow;
    }
  }
}

/// Maps the marker-domain anchor to the generated wire pair, applying the
/// optional offset the way the legacy Darwin decoder does (anchor + offset).
extension IconAnchorNativeWire on IconAnchor {
  generated.NativeMarkerAnchor toGenerated() => generated.NativeMarkerAnchor(
        x: anchor.value.$1 + (offset?.x ?? 0),
        y: anchor.value.$2 + (offset?.y ?? 0),
      );
}

/// Maps logical [width, height] widget dimensions to the generated size.
extension IconLogicalSizeNativeWire on List<int> {
  generated.NativeMarkerSize toGeneratedSize() =>
      generated.NativeMarkerSize(width: first, height: last);
}
