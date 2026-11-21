// Handwritten support facade over the generated roads channel.
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachRoadsRoute`) and only exists when the host negotiated the `roads`
// capability — older hosts keep road drawing, removal and clearing on
// their legacy routes. Route fetching/calculation stays asynchronous in
// Dart; only the drawing of an already-computed polyline crosses this
// channel, as flat full-precision coordinates (no polyline encoding).
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_map_camera.g.dart' as generated;

/// Typed error thrown when the native engine cannot accept a road command
/// yet (road line layer missing or the engine rejected the geometry/style).
class RoadsNotReadyException implements Exception {
  const RoadsNotReadyException();

  @override
  String toString() =>
      'RoadsNotReadyException: the native road layer is not ready for this operation';
}

/// Selected generated-roads route for one map attachment.
class PigeonRoadsClient {
  final generated.NativeMapRoadsApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonRoadsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapRoadsApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Draws (or replaces) one road from flat [lat, lon, ...] coordinates.
  /// `zoomInto` fits the camera to the road.
  Future<void> drawRoad(
    String roadId,
    Float64List coordinates,
    generated.NativeRoadStyle style, {
    bool zoomInto = false,
  }) {
    return _guard(
      () => _api.drawRoad(_wireSession, roadId, coordinates, style, zoomInto),
    );
  }

  /// Removes one road by id; unknown ids succeed without effect.
  Future<void> removeRoad(String roadId) {
    return _guard(() => _api.removeRoad(_wireSession, roadId));
  }

  /// Removes every road.
  Future<void> clearRoads() {
    return _guard(() => _api.clearRoads(_wireSession));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
          throw const StaleMapSessionException();
        case 'roads_not_ready':
          throw const RoadsNotReadyException();
        case 'disposed':
          throw const StaleMapSessionException();
      }
      rethrow;
    }
  }
}
