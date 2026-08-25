import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Decodes the legacy callback names and the versioned typed event envelope
/// shared by JNI commands and the MethodChannel event plane.
AndroidMapEvent? decodeAndroidMapEvent(int viewId, MethodCall call) {
  switch (call.method) {
    case 'map#init':
      return AndroidMapReady(
        viewId: viewId,
        isReady: call.arguments as bool,
      );
    case 'receiveLongPress':
      return AndroidMapTap(
        viewId: viewId,
        position: GeoPoint.fromMap(call.arguments),
        kind: AndroidMapTapKind.long,
      );
    case 'receiveSinglePress':
      return AndroidMapTap(
        viewId: viewId,
        position: GeoPoint.fromMap(call.arguments),
        kind: AndroidMapTapKind.single,
      );
    case 'receiveRegionIsChanging':
      return AndroidRegionChanged(
        viewId: viewId,
        region: Region.fromMap(call.arguments),
      );
    case 'android#event':
      return _decodeEnvelope(viewId, call.arguments);
  }
  return null;
}

AndroidMapEvent? _decodeEnvelope(int viewId, Object? arguments) {
  if (arguments is! Map || arguments['version'] != 1) return null;
  final type = arguments['type'];
  final requestId = arguments['requestId'] as String?;
  final payload = arguments['payload'];
  if (payload is! Map) return null;

  switch (type) {
    case 'ack':
      if (requestId == null) return null;
      return AndroidMapAcknowledgement(
        viewId: viewId,
        requestId: requestId,
        operation: payload['operation'] as String,
      );
    case 'error':
      final operation = payload['operation'] as String? ?? 'nativeCommand';
      return AndroidMapError(
        viewId: viewId,
        requestId: requestId,
        error: AndroidMapException(
          operation: operation,
          code: payload['code'] as String? ?? 'native_error',
          viewId: viewId,
          message: payload['message'] as String?,
        ),
      );
    case 'markerTap':
      return AndroidMarkerTap(
        viewId: viewId,
        markerId: MarkerId(payload['markerId'] as String),
        position: GeoPoint(
          latitude: payload['lat'] as double,
          longitude: payload['lon'] as double,
        ),
      );
  }
  return null;
}
