import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeAndroidMapEvent', () {
    test('decodes command acknowledgements', () {
      final event = decodeAndroidMapEvent(
        7,
        const MethodCall('android#event', {
          'version': 1,
          'type': 'ack',
          'requestId': '7-1',
          'payload': {'operation': 'moveTo'},
        }),
      );

      expect(event, isA<AndroidMapAcknowledgement>());
      final acknowledgement = event! as AndroidMapAcknowledgement;
      expect(acknowledgement.viewId, 7);
      expect(acknowledgement.requestId, '7-1');
      expect(acknowledgement.operation, 'moveTo');
    });

    test('decodes native errors with request context', () {
      final event = decodeAndroidMapEvent(
        8,
        const MethodCall('android#event', {
          'version': 1,
          'type': 'error',
          'requestId': '8-2',
          'payload': {
            'operation': 'addMarker',
            'code': 'command_rejected',
            'message': 'duplicate marker',
          },
        }),
      );

      final error = event! as AndroidMapError;
      expect(error.requestId, '8-2');
      expect(error.error.operation, 'addMarker');
      expect(error.error.code, 'command_rejected');
      expect(error.error.viewId, 8);
    });

    test('decodes stable marker identity', () {
      final event = decodeAndroidMapEvent(
        9,
        const MethodCall('android#event', {
          'version': 1,
          'type': 'markerTap',
          'payload': {
            'markerId': 'marker-1',
            'lat': 48.85,
            'lon': 2.35,
          },
        }),
      );

      final markerTap = event! as AndroidMarkerTap;
      expect(markerTap.markerId, const MarkerId('marker-1'));
      expect(markerTap.position.latitude, 48.85);
      expect(markerTap.position.longitude, 2.35);
    });

    test('decodes foreground user-location events', () {
      final event = decodeAndroidMapEvent(
        10,
        const MethodCall('receiveUserLocation', {
          'lat': 48.85,
          'lon': 2.35,
          'heading': 90.0,
        }),
      );

      final location = event! as AndroidUserLocationChanged;
      expect(location.viewId, 10);
      expect(location.location.latitude, 48.85);
      expect(location.location.longitude, 2.35);
      expect(location.location.angle, 90.0);
    });

    test('drops malformed callbacks instead of throwing', () {
      expect(
        decodeAndroidMapEvent(
          11,
          const MethodCall('receiveRegionIsChanging', {'center': null}),
        ),
        isNull,
      );
      expect(
        decodeAndroidMapEvent(
          11,
          const MethodCall('android#event', {
            'version': 1,
            'type': 'markerTap',
            'payload': {'markerId': 'marker', 'lat': 'bad', 'lon': 2},
          }),
        ),
        isNull,
      );
      expect(
        decodeAndroidMapEvent(
          11,
          const MethodCall('receiveUserLocation', {
            'lat': 48.85,
            'lon': null,
            'heading': 'north',
          }),
        ),
        isNull,
      );
    });

    test('ignores unsupported envelope versions', () {
      final event = decodeAndroidMapEvent(
        10,
        const MethodCall('android#event', {
          'version': 2,
          'type': 'ack',
          'requestId': '10-1',
          'payload': {'operation': 'moveTo'},
        }),
      );

      expect(event, isNull);
    });
  });
}
