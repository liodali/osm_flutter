import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkerId', () {
    test('uses value equality', () {
      expect(const MarkerId('marker-1'), const MarkerId('marker-1'));
      expect(const MarkerId('marker-1'), isNot(const MarkerId('marker-2')));
      final ids = <MarkerId>{const MarkerId('marker-1')};
      expect(ids.add(const MarkerId('marker-1')), isFalse);
      expect(ids, hasLength(1));
    });

    test('rejects an empty value', () {
      expect(() => MarkerId(''), throwsAssertionError);
    });
  });

  test('overlay IDs use value equality and reject empty values', () {
    expect(const RoadId('road-1'), const RoadId('road-1'));
    expect(const ShapeId('shape-1'), const ShapeId('shape-1'));
    expect(
      const StaticPositionId('static-1'),
      const StaticPositionId('static-1'),
    );
    expect(() => RoadId(''), throwsAssertionError);
    expect(() => ShapeId(''), throwsAssertionError);
    expect(() => StaticPositionId(''), throwsAssertionError);
  });

  test('AndroidMapException includes operation context', () {
    const error = AndroidMapException(
      operation: 'attach',
      code: 'jni_unavailable',
      viewId: 42,
      message: 'not available',
    );

    expect(error.toString(), contains('operation: attach'));
    expect(error.toString(), contains('code: jni_unavailable'));
    expect(error.toString(), contains('viewId: 42'));
  });

  test('typed events retain their view and payload', () {
    final position = GeoPoint(latitude: 48.85, longitude: 2.35);
    final markerEvent = AndroidMarkerTap(
      viewId: 7,
      markerId: const MarkerId('marker-7'),
      position: position,
    );
    final location = UserLocation(
      latitude: 48.86,
      longitude: 2.36,
      angle: 0.5,
    );
    final locationEvent = AndroidUserLocationChanged(
      viewId: 7,
      location: location,
    );

    expect(markerEvent.viewId, 7);
    expect(markerEvent.markerId, const MarkerId('marker-7'));
    expect(markerEvent.position, same(position));
    expect(locationEvent.viewId, 7);
    expect(locationEvent.location, same(location));
  });
}
