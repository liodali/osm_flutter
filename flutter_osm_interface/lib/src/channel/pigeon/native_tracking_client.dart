// Handwritten support facade over the generated follow-me tracking
// channel.
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachTrackingRoute`) and only exists when the host negotiated the
// `location.tracking` capability — older hosts keep
// `trackMe`/`deactivateTrackMe` on their legacy routes.
//
// Completion contract (carried from the schema): start is idempotent and
// completes exactly once with `permission_denied` or
// `location_service_disabled` on platform-reported denial; stop is
// idempotent, never prompts, never fails, and preserves continuous
// updates and pending one-shot fixes (both consumers share the location
// subscription). Location events keep flowing on the existing event
// channel.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_location_client.dart';

/// Selected generated follow-me tracking route for one map attachment.
class PigeonTrackingClient {
  final generated.NativeMapTrackingApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonTrackingClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapTrackingApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Starts follow-me tracking; idempotent.
  Future<void> enableTracking(generated.NativeTrackingConfiguration configuration) {
    return _guard(() => _api.enableTracking(_wireSession, configuration));
  }

  /// Ends follow-me tracking without touching continuous updates or
  /// pending one-shot fixes; idempotent, never prompts. Awaits the native
  /// completion so stale-session errors flow through the guard.
  Future<void> disableTracking() {
    return _guard(() => _api.disableTracking(_wireSession));
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
