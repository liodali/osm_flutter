import 'package:flutter_osm_interface/src/android/android_map_exception.dart';
import 'package:flutter_osm_interface/src/android/android_map_id.dart';
import 'package:flutter_osm_interface/src/types/types.dart';

/// Typed events emitted by an opt-in Android map session.
sealed class AndroidMapEvent {
  const AndroidMapEvent({required this.viewId, this.requestId});

  final int viewId;
  final String? requestId;
}

final class AndroidMapReady extends AndroidMapEvent {
  const AndroidMapReady({
    required super.viewId,
    required this.isReady,
    super.requestId,
  });

  final bool isReady;
}

final class AndroidMapAcknowledgement extends AndroidMapEvent {
  const AndroidMapAcknowledgement({
    required super.viewId,
    required super.requestId,
    required this.operation,
  });

  final String operation;
}

enum AndroidMapTapKind { single, long }

final class AndroidMapTap extends AndroidMapEvent {
  const AndroidMapTap({
    required super.viewId,
    required this.position,
    required this.kind,
  });

  final GeoPoint position;
  final AndroidMapTapKind kind;
}

final class AndroidMarkerTap extends AndroidMapEvent {
  const AndroidMarkerTap({
    required super.viewId,
    required this.markerId,
    required this.position,
  });

  final MarkerId markerId;
  final GeoPoint position;
}

final class AndroidRegionChanged extends AndroidMapEvent {
  const AndroidRegionChanged({
    required super.viewId,
    required this.region,
  });

  final Region region;
}

final class AndroidMapError extends AndroidMapEvent {
  const AndroidMapError({
    required super.viewId,
    required this.error,
    super.requestId,
  });

  final AndroidMapException error;
}
