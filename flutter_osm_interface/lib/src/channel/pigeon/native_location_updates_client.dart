// Handwritten support facade over the generated continuous-updates
// channel.
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachLocationUpdatesRoute`) and only exists when the host negotiated
// the `location.updates` capability — older hosts keep start/stop on
// their legacy routes.
//
// Completion contract (carried from the schema): start is idempotent and
// completes exactly once with `permission_denied` or
// `location_service_disabled` on platform-reported denial; stop is
// idempotent, never prompts, never fails, and preserves pending one-shot
// fixes and other location consumers. Location events keep flowing on
// the existing event channel.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_location_client.dart';

/// Selected generated continuous-updates route for one map attachment.
class PigeonLocationUpdatesClient {
  final generated.NativeMapLocationUpdatesApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonLocationUpdatesClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapLocationUpdatesApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Starts continuous user-location updates without follow control;
  /// idempotent.
  Future<void> startLocationUpdates() {
    return _guard(() => _api.startLocationUpdates(_wireSession));
  }

  /// Ends the updates consumer without touching pending one-shot fixes or
  /// tracking; idempotent, never prompts.
  Future<void> stopLocationUpdates() {
    return _guard(() => _api.stopLocationUpdates(_wireSession));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
        case 'disposed':
          throw const StaleMapSessionException();
        case 'permission_denied':
          throw LocationPermissionDeniedException();
        case 'location_service_disabled':
          throw LocationUnavailableException(error.code);
      }
      rethrow;
    }
  }
}
