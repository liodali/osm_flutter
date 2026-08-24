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
    final event = AndroidMarkerTap(
      viewId: 7,
      markerId: const MarkerId('marker-7'),
      position: position,
    );

    expect(event.viewId, 7);
    expect(event.markerId, const MarkerId('marker-7'));
    expect(event.position, same(position));
  });
}
