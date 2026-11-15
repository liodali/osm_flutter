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
  }) {
    return _guard(
      () => _api.addMarker(_wireSession, markerId, latitude, longitude, iconBytes),
    );
  }

  Future<void> addMarkers(
    List<String> markerIds,
    Float64List coordinates,
  ) {
    return _guard(() => _api.addMarkers(_wireSession, markerIds, coordinates));
  }

  Future<void> updateMarkerIcon(String markerId, Uint8List iconBytes) {
    return _guard(() => _api.updateMarkerIcon(_wireSession, markerId, iconBytes));
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
