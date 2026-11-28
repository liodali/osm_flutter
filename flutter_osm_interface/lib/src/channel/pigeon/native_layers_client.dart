// Handwritten support facade over the generated layers channel.
//
// Mirrors the camera and markers facades: applications never touch
// generated types. The route is selected once per map during attachment
// (see `attachLayersRoute`) and only exists when the host negotiated the
// `layers` capability — older hosts keep tile-source selection and overlay
// visibility on their legacy routes.
import 'package:flutter/services.dart';

import 'native_camera_bootstrap.dart';
import 'native_camera_client.dart';
import 'native_map_camera.g.dart' as generated;

/// Typed error thrown when the native engine cannot accept a layer command
/// yet (tile source not swappable or overlay layers missing) or the engine
/// rejected the mutation.
class LayersNotReadyException implements Exception {
  const LayersNotReadyException();

  @override
  String toString() =>
      'LayersNotReadyException: the native layers are not ready for this operation';
}

/// Selected generated-layers route for one map attachment.
class PigeonLayersClient {
  final generated.NativeMapLayersApi _api;
  final NativeProtocolBootstrap _bootstrap;

  PigeonLayersClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
  })  : _api = generated.NativeMapLayersApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: nativeChannelSuffix(viewId),
        ),
        _bootstrap = bootstrap;

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  generated.NativeCameraSession get _wireSession => generated.NativeCameraSession(
        sessionToken: _bootstrap.sessionToken,
        generation: _bootstrap.generation,
      );

  /// Selects the tile source; a null configuration resets the default OSM
  /// tile layer, mirroring the legacy `change#tile` semantics.
  Future<void> changeTileLayer(generated.NativeTileConfiguration? tile) {
    return _guard(() => _api.changeTileLayer(_wireSession, tile));
  }

  /// Shows or hides the overlay layers.
  Future<void> setOverlaysVisible(bool visible) {
    return _guard(() => _api.setOverlaysVisible(_wireSession, visible));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'stale_session':
          throw const StaleMapSessionException();
        case 'layers_not_ready':
          throw const LayersNotReadyException();
        case 'disposed':
          throw const StaleMapSessionException();
      }
      rethrow;
    }
  }
}
