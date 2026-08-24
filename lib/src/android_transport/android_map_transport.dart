import 'dart:async';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Command/event boundary used by the opt-in Android controller.
///
/// Phase 2 limits this contract to attach, initial position, readiness, and
/// disposal. Camera and marker commands are added as JNI vertical slices in
/// Phase 3 so attach fallback cannot accidentally replay state changes.
abstract interface class AndroidMapTransport {
  AndroidMapBackend get backend;

  Stream<AndroidMapEvent> get events;

  Future<void> attach(int viewId);

  Future<void> initialize({required GeoPoint initialPosition});

  Future<void> close();
}

typedef AndroidMapTransportFactory = AndroidMapTransport Function(
  AndroidMapBackend backend,
);
