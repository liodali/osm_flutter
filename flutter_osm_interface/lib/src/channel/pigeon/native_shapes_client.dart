// Handwritten support facade over the generated shapes channel.
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachShapesRoute`) and only exists when the host negotiated the
// `shapes` capability — older hosts keep circle and rectangle commands on
// their legacy routes.
import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_map_camera.g.dart' as generated;

/// Typed error thrown when the native engine cannot accept a shape command
/// yet (polygon layer missing or the engine rejected the geometry/style).
class ShapesNotReadyException implements Exception {
  const ShapesNotReadyException();

  @override
  String toString() =>
      'ShapesNotReadyException: the native shape layer is not ready for this operation';
}

/// Selected generated-shapes route for one map attachment.
class PigeonShapesClient {
  final generated.NativeMapShapesApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonShapesClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapShapesApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Draws (or replaces) one circle around the coordinate.
  Future<void> addCircle(
    String shapeId,
    double latitude,
    double longitude,
    double radius,
    generated.NativeShapeStyle style,
  ) {
    return _guard(
      () => _api.addCircle(_wireSession, shapeId, latitude, longitude, radius, style),
    );
  }

  /// Draws (or replaces) one rectangle centered on the coordinate.
  Future<void> addRectangle(
    String shapeId,
    double latitude,
    double longitude,
    double distance,
    generated.NativeShapeStyle style,
  ) {
    return _guard(
      () => _api.addRectangle(_wireSession, shapeId, latitude, longitude, distance, style),
    );
  }

  /// Removes one shape by id; unknown ids succeed without effect.
  Future<void> removeShape(String shapeId) {
    return _guard(() => _api.removeShape(_wireSession, shapeId));
  }

  /// Removes every circle.
  Future<void> removeCircles() {
    return _guard(() => _api.removeCircles(_wireSession));
  }

  /// Removes every rectangle.
  Future<void> removeRectangles() {
    return _guard(() => _api.removeRectangles(_wireSession));
  }

  /// Removes every shape of any kind.
  Future<void> clearShapes() {
    return _guard(() => _api.clearShapes(_wireSession));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
          throw const StaleMapSessionException();
        case 'shapes_not_ready':
          throw const ShapesNotReadyException();
        case 'disposed':
          throw const StaleMapSessionException();
      }
      rethrow;
    }
  }
}
