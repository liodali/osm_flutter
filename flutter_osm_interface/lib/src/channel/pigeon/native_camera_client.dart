// Handwritten support facade over the generated camera channel.
//
// Applications never touch generated types: the public controllers keep
// calling their existing Future-based methods; this client is selected once
// per map during attachment (see `attachCameraRoute`) and translates
// generated values and errors into the documented domain surface.
//
// Completion semantics inherited from the schema: a successful reply means
// the state was applied or the animation accepted by the native engine; it
// does not promise a rendered frame. Relative zoom (`stepZoom`) is not part
// of the generated camera contract and stays on its legacy route.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_map_camera.g.dart' as generated;

/// Typed error thrown when the generated route's session no longer matches
/// the live map view (view replaced or reused id).
class StaleMapSessionException implements Exception {
  const StaleMapSessionException();

  @override
  String toString() => 'StaleMapSessionException: '
      'the camera command targeted a replaced or stale map session';
}

/// Typed error thrown when the native engine cannot accept a camera command
/// yet (map not initialized) or the engine rejected the mutation.
class CameraNotReadyException implements Exception {
  const CameraNotReadyException();

  @override
  String toString() =>
      'CameraNotReadyException: the native camera is not ready for this operation';
}

/// Selected generated-camera route for one map attachment.
class PigeonCameraClient {
  final generated.NativeMapCameraApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonCameraClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapCameraApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  /// Whether the negotiated host implements the expanded camera surface
  /// (bounds queries, zoom-to-bounds, camera limits/reset and zoom
  /// configuration). Original camera.v1 hosts advertise only the base
  /// camera capability; expanded-surface commands route to legacy unless
  /// the host negotiated `camera.config` at attach time.
  bool get supportsBoundsAndZoomConfig =>
      _bootstrap.advertises(kCameraConfigCapability);

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  Future<double> getZoom() {
    return _guard(() => _api.getZoom(_wireSession));
  }

  /// Absolute zoom only; relative steps stay on the legacy route.
  Future<void> setZoom(double zoom, {bool animated = true}) {
    return _guard(() => _api.setZoom(_wireSession, zoom, animated));
  }

  Future<void> moveTo(
    double latitude,
    double longitude, {
    bool animated = false,
  }) {
    return _guard(
      () => _api.moveTo(_wireSession, latitude, longitude, animated),
    );
  }

  Future<void> setRotation(double angle, {bool animated = true}) {
    return _guard(() => _api.setRotation(_wireSession, angle, animated));
  }

  Future<generated.NativeCameraPosition> getCameraPosition() {
    return _guard(() => _api.getCameraPosition(_wireSession));
  }

  /// Visible-region bounding box in degrees.
  Future<generated.NativeBounds> getBounds() {
    return _guard(() => _api.getBounds(_wireSession));
  }

  /// Moves/animates the viewport to fit the bounding box with pixel padding.
  Future<void> zoomToBoundingBox(
    generated.NativeBounds bounds, {
    int paddingInPixel = 0,
  }) {
    return _guard(
      () => _api.zoomToBoundingBox(_wireSession, bounds, paddingInPixel),
    );
  }

  /// Restricts the camera to the bounding box area.
  Future<void> setBoundsLimit(generated.NativeBounds bounds) {
    return _guard(() => _api.setBoundsLimit(_wireSession, bounds));
  }

  /// Removes the camera area limit, restoring the world view.
  Future<void> removeBoundsLimit() {
    return _guard(() => _api.removeBoundsLimit(_wireSession));
  }

  /// Applies the zoom configuration (init/min/max/step).
  Future<void> configureZoom(generated.NativeZoomConfiguration configuration) {
    return _guard(() => _api.configureZoom(_wireSession, configuration));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
          throw const StaleMapSessionException();
        case 'camera_not_ready':
          throw const CameraNotReadyException();
        case 'disposed':
          throw const StaleMapSessionException();
      }
      rethrow;
    }
  }
}

/// Outcome of the attach-time camera-route decision.
enum CameraRouteSelection {
  /// Generated route active for the camera family.
  generated,

  /// Legacy route retained (old host, unsupported revision, no camera
  /// capability, or the application did not opt in).
  legacy,
}
