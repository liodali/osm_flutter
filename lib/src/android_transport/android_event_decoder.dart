import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Decodes the legacy callback names and the versioned typed event envelope
/// shared by JNI commands and the MethodChannel event plane.
AndroidMapEvent? decodeAndroidMapEvent(int viewId, MethodCall call) {
  try {
    switch (call.method) {
      case 'map#init':
        final isReady = call.arguments;
        if (isReady is! bool) return null;
        return AndroidMapReady(viewId: viewId, isReady: isReady);
      case 'receiveLongPress':
        return AndroidMapTap(
          viewId: viewId,
          position: GeoPoint.fromMap(_requireMap(call.arguments)),
          kind: AndroidMapTapKind.long,
        );
      case 'receiveSinglePress':
        return AndroidMapTap(
          viewId: viewId,
          position: GeoPoint.fromMap(_requireMap(call.arguments)),
          kind: AndroidMapTapKind.single,
        );
      case 'receiveRegionIsChanging':
        return AndroidRegionChanged(
          viewId: viewId,
          region: Region.fromMap(_requireMap(call.arguments)),
        );
      case 'receiveUserLocation':
        return AndroidUserLocationChanged(
          viewId: viewId,
          location: UserLocation.fromMap(_requireMap(call.arguments)),
        );
      case 'android#event':
        return _decodeEnvelope(viewId, call.arguments);
    }
  } on Object {
    // Native callbacks must never fail the MethodChannel handler. Malformed or
    // stale events are ignored instead of terminating the event stream.
    return null;
  }
  return null;
}

AndroidMapEvent? _decodeEnvelope(int viewId, Object? arguments) {
  if (arguments is! Map || arguments['version'] != 1) return null;
  final type = arguments['type'];
  final rawRequestId = arguments['requestId'];
  if (rawRequestId != null && rawRequestId is! String) return null;
  final requestId = rawRequestId as String?;
  final payload = arguments['payload'];
  if (type is! String || payload is! Map) return null;

  switch (type) {
    case 'ack':
      final operation = payload['operation'];
      if (requestId == null || operation is! String) return null;
      return AndroidMapAcknowledgement(
        viewId: viewId,
        requestId: requestId,
        operation: operation,
      );
    case 'error':
      final operation = payload['operation'];
      final code = payload['code'];
      final message = payload['message'];
      if (operation != null && operation is! String ||
          code != null && code is! String ||
          message != null && message is! String) {
        return null;
      }
      return AndroidMapError(
        viewId: viewId,
        requestId: requestId,
        error: AndroidMapException(
          operation: operation as String? ?? 'nativeCommand',
          code: code as String? ?? 'native_error',
          viewId: viewId,
          message: message as String?,
        ),
      );
    case 'markerTap':
      final markerId = payload['markerId'];
      final latitude = _asDouble(payload['lat']);
      final longitude = _asDouble(payload['lon']);
      if (markerId is! String ||
          markerId.isEmpty ||
          latitude == null ||
          longitude == null) {
        return null;
      }
      return AndroidMarkerTap(
        viewId: viewId,
        markerId: MarkerId(markerId),
        position: GeoPoint(latitude: latitude, longitude: longitude),
      );
  }
  return null;
}

Map _requireMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected map payload');
  return value;
}

double? _asDouble(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
