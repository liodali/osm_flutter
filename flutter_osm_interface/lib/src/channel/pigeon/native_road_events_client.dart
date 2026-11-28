// Handwritten support facade over the generated native-to-Dart road tap
// event channel.
//
// Mirrors the interaction family facade: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachRoadEventsRoute`), before initialization, and only exists when the
// host negotiated the `events.roads` capability and accepted the
// `map#events#roads#route` selection. Exactly one delivery route is active
// per attachment: while this client is registered, the host emits road taps
// only through this callback and the platform channel drops legacy
// `receiveRoad` messages for the map.
//
// Delivery contract (carried from the schema): the callback carries the
// session identity and the tapped road's payload — key, optional
// distance/duration, optional encoded route polyline and optional
// turn-by-turn instructions — mirroring the legacy `receiveRoad` payload so
// the public road tap event decodes identically on either route.
// Callbacks whose token/generation does not match this attachment are stale
// (replaced or disposed view) and are dropped. Road taps are discrete
// events: each occurrence is forwarded once and repeats are never
// coalesced.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';

/// Thrown when the road event route negotiation ends in an uncertain state:
/// the selection timed out and a rollback to the legacy route could not be
/// confirmed. The host may already have switched to the generated route, so
/// silently falling back to legacy would unregister the callbacks and lose
/// every road tap event. Attachment is aborted instead; the caller may
/// retry, which re-negotiates from a clean state.
class RoadRouteUncertainException extends RouteSelectionUncertainException {
  const RoadRouteUncertainException();

  @override
  String toString() => 'RoadRouteUncertainException: '
      'the road event route could not be negotiated safely; '
      'attachment was aborted rather than risking lost road tap events';
}

/// Selected generated road-event route for one map attachment.
///
/// Registers the generated FlutterApi handler for the map's per-view channel
/// suffix and forwards validated callbacks through [onRoadTap] with the
/// tapped road's full payload. [dispose] removes the handler; late messages
/// then find no handler and are discarded by the engine.
class PigeonRoadEventsClient implements generated.NativeMapRoadEventsApi {
  /// Currently registered client per channel suffix. A stale client whose
  /// attachment was replaced must not unregister the replacement's handlers
  /// when its late teardown runs, so disposal is identity-checked.
  static final Map<String, PigeonRoadEventsClient> _registered = {};

  final NativeProtocolBootstrap _bootstrap;
  final BinaryMessenger? _binaryMessenger;
  final String _channelSuffix;
  final void Function(generated.NativeTappedRoad road) _onRoadTap;

  bool _disposed = false;

  PigeonRoadEventsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
    required void Function(generated.NativeTappedRoad road) onRoadTap,
  })  : _bootstrap = bootstrap,
        _binaryMessenger = binaryMessenger,
        _channelSuffix = nativeChannelSuffix(viewId),
        _onRoadTap = onRoadTap {
    generated.NativeMapRoadEventsApi.setUp(
      this,
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: _channelSuffix,
    );
    _registered[_channelSuffix] = this;
  }

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  /// True while this client's handlers are registered for the attachment.
  bool get isActive => !_disposed;

  @override
  void onRoadTap(
    generated.NativeCameraSession session,
    generated.NativeTappedRoad road,
  ) {
    if (_disposed || !_matchesSession(session)) return;
    _onRoadTap(road);
  }

  bool _matchesSession(generated.NativeCameraSession session) =>
      session.sessionToken == _bootstrap.sessionToken &&
      session.generation == _bootstrap.generation;

  /// Removes this attachment's handlers. Must run before a replacement
  /// attachment registers its own client on the same per-view channels;
  /// when a replacement already registered, this only marks the stale
  /// client inactive and leaves the live handlers untouched.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(_registered[_channelSuffix], this)) {
      _registered.remove(_channelSuffix);
      generated.NativeMapRoadEventsApi.setUp(
        null,
        binaryMessenger: _binaryMessenger,
        messageChannelSuffix: _channelSuffix,
      );
    }
  }
}
