// Handwritten support facade over the generated location channel.
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachLocationRoute`) and only exists when the host negotiated the
// `location` capability — older hosts keep the my-location toggle and
// single-shot fixes on their legacy routes.
//
// Completion contract (carried from the schema): each pending fix
// completes exactly once — on fix, permission denial, timeout, session
// disposal, activity detachment or settings denial. Overlapping requests
// fail immediately; late native callbacks are ignored.
import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_map_camera.g.dart' as generated;

/// Typed failure for location commands. The public facade wraps these into
/// the legacy `GeoPointException`, preserving the existing API contract.
abstract class LocationFailure implements Exception {
  String get message;
}

/// Location permission was denied or restricted. Permission ownership
/// stays with the host application; this only reports the outcome.
class LocationPermissionDeniedException extends LocationFailure {
  @override
  String get message => 'location permission was not granted';
}

/// No fix arrived before the deadline.
class LocationTimeoutException extends LocationFailure {
  @override
  String get message => 'timed out waiting for a location fix';
}

/// Another location request is already pending for this map session.
class LocationRequestInProgressException extends LocationFailure {
  @override
  String get message => 'another location request is already pending';
}

/// The fix could not be produced: location services off after the settings
/// round trip, no foreground activity to open them, or the update start
/// failed.
class LocationUnavailableException extends LocationFailure {
  final String code;
  LocationUnavailableException(this.code);

  @override
  String get message => 'location is unavailable ($code)';
}

/// Selected generated-location route for one map attachment.
class PigeonLocationClient {
  final generated.NativeMapLocationApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonLocationClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapLocationApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Enables the my-location layer, opening the settings round trip when
  /// the provider is off. Completes once the flow is initiated.
  Future<void> showMyLocation() {
    return _guard(() => _api.showMyLocation(_wireSession));
  }

  /// Single-shot current position; completes exactly once.
  Future<generated.NativeLocationFix> getCurrentLocation() {
    return _guard(() => _api.getCurrentLocation(_wireSession));
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
        case 'location_timeout':
          throw LocationTimeoutException();
        case 'location_request_in_progress':
          throw LocationRequestInProgressException();
        case 'location_service_disabled':
        case 'location_start_failed':
        case 'activity_unavailable':
        case 'location_unavailable':
        // Lifecycle cancellations: the host Activity detached or the map
        // session was disposed/replaced before a fix arrived.
        case 'activity_detached':
        case 'location_request_paused':
        case 'location_request_cancelled':
          throw LocationUnavailableException(error.code);
      }
      rethrow;
    }
  }
}
