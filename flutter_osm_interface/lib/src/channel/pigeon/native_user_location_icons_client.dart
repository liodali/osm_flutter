// Handwritten support facade over the generated user-location icon channel.
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachUserLocationIconsRoute`) and only exists when the host negotiated
// the `location.icons` capability — older hosts keep icon replacement on
// their legacy `user#locationMarkers` route.
//
// Flutter widget rendering stays asynchronous on the Dart side: the
// application's person/direction widgets are rendered by the caller and only
// the prepared PNG bytes plus logical dimensions and anchors reach this
// facade.
//
// Completion contract (carried from the schema): the call only swaps the
// layer icons. It never starts, stops or restarts the location subscription,
// so follow-me tracking, continuous updates and pending one-shot fixes keep
// running untouched and no permission flow is triggered. A null
// configuration restores the platform default icons.
import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_map_camera.g.dart' as generated;

/// Selected generated user-location icon route for one map attachment.
class PigeonUserLocationIconsClient {
  final generated.NativeMapUserLocationIconsApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonUserLocationIconsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapUserLocationIconsApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Replaces the person and direction icons of the my-location layer.
  ///
  /// A null [icons] restores the platform default icons and center anchor,
  /// mirroring the reset semantics of the typed layers route.
  Future<void> setUserLocationIcons(generated.NativeUserLocationIcons? icons) {
    return _guard(() => _api.setUserLocationIcons(_wireSession, icons));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
        case 'disposed':
          throw const StaleMapSessionException();
      }
      rethrow;
    }
  }
}
