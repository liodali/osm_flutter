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
