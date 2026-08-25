import 'dart:async';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Command/event boundary used by the opt-in Android controller.
///
/// Backend selection is final after [attach]. Stateful commands are never
/// replayed through another transport after initialization begins.
abstract interface class AndroidMapTransport {
  AndroidMapBackend get backend;

  Stream<AndroidMapEvent> get events;

  Future<void> attach(int viewId);

  Future<void> initialize({required GeoPoint initialPosition});

  Future<void> moveTo(GeoPoint position, {required bool animated});

  Future<void> setZoom(double zoom);

  Future<double> getZoom();

  Future<void> setRotation(double angle, {required bool animated});

  Future<void> addMarker(MarkerId markerId, GeoPoint position);

  Future<void> removeMarker(MarkerId markerId);

  Future<void> close();
}

typedef AndroidMapTransportFactory = AndroidMapTransport Function(
  AndroidMapBackend backend,
);
