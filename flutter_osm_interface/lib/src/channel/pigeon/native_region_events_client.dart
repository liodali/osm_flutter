// Handwritten support facade over the generated native-to-Dart
// visible-region event channel (center, bounding box and zoom of the
// visible region).
//
// Mirrors the interaction family facade: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachRegionEventsRoute`), before initialization, and only exists when
// the host negotiated the `events.region` capability and accepted the
// `map#events#region#route` selection. Exactly one delivery route is
// active per attachment: while this client is registered, the host emits
// region changes only through this callback and the platform channel drops
// legacy `receiveRegionIsChanging` messages for the map.
//
// Delivery contract (carried from the schema): every callback carries the
// session identity and the region as raw doubles with the host's full
// precision (center, bounding box, zoom in the camera family's units);
// callbacks whose token/generation does not match this attachment are
// stale (replaced or disposed view) and are dropped. The host owns the
// rate: the callback inherits the platform's region-event rate and
// coalescing unchanged, so this facade forwards every validated callback
// once, in order, and never buffers, throttles or coalesces itself.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';

/// Thrown when the visible-region event route negotiation ends in an
/// uncertain state: the selection timed out and a rollback to the legacy
/// route could not be confirmed. The host may already have switched to the
/// generated route, so silently falling back to legacy would unregister the
/// callback and lose every region change. Attachment is aborted instead;
/// the caller may retry, which re-negotiates from a clean state.
class RegionRouteUncertainException
    extends RouteSelectionUncertainException {
  const RegionRouteUncertainException();

  @override
  String toString() => 'RegionRouteUncertainException: '
      'the visible-region event route could not be negotiated safely; '
      'attachment was aborted rather than risking lost region changes';
}

/// Selected generated visible-region event route for one map attachment.
///
/// Registers the generated FlutterApi handler for the map's per-view channel
/// suffix and forwards validated callbacks through [onRegionChanged] with
/// the host's full precision. [dispose] removes the handler; late messages
/// then find no handler and are discarded by the engine.
class PigeonRegionEventsClient
    implements generated.NativeMapRegionEventsApi {
  /// Currently registered client per channel suffix. A stale client whose
  /// attachment was replaced must not unregister the replacement's handler
  /// when its late teardown runs, so disposal is identity-checked.
  static final Map<String, PigeonRegionEventsClient> _registered = {};

  final NativeProtocolBootstrap _bootstrap;
  final BinaryMessenger? _binaryMessenger;
  final String _channelSuffix;
  final void Function(
    double centerLatitude,
    double centerLongitude,
    generated.NativeBounds bounds,
    double zoom,
  ) _onRegionChanged;

  bool _disposed = false;

  PigeonRegionEventsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
    required void Function(
      double centerLatitude,
      double centerLongitude,
      generated.NativeBounds bounds,
      double zoom,
    ) onRegionChanged,
  })  : _bootstrap = bootstrap,
        _binaryMessenger = binaryMessenger,
        _channelSuffix = nativeChannelSuffix(viewId),
        _onRegionChanged = onRegionChanged {
    generated.NativeMapRegionEventsApi.setUp(
      this,
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: _channelSuffix,
    );
    _registered[_channelSuffix] = this;
  }

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  /// True while this client's handler is registered for the attachment.
  bool get isActive => !_disposed;

  @override
  void onRegionChanged(
    generated.NativeCameraSession session,
    double centerLatitude,
    double centerLongitude,
    generated.NativeBounds bounds,
    double zoom,
  ) {
    if (_disposed || !_matchesSession(session)) return;
    _onRegionChanged(centerLatitude, centerLongitude, bounds, zoom);
  }

  bool _matchesSession(generated.NativeCameraSession session) =>
      session.sessionToken == _bootstrap.sessionToken &&
      session.generation == _bootstrap.generation;

  /// Removes this attachment's handler. Must run before a replacement
  /// attachment registers its own client on the same per-view channel;
  /// when a replacement already registered, this only marks the stale
  /// client inactive and leaves the live handler untouched.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(_registered[_channelSuffix], this)) {
      _registered.remove(_channelSuffix);
      generated.NativeMapRegionEventsApi.setUp(
        null,
        binaryMessenger: _binaryMessenger,
        messageChannelSuffix: _channelSuffix,
      );
    }
  }
}
