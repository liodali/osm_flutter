import 'package:flutter_osm_android_jni/flutter_osm_android_jni.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('installs JNI without taking ownership of fallback backends', () {
    final factory = createAndroidJniTransportFactory(
      fallback: (backend) => throw StateError('fallback:$backend'),
    );

    expect(factory(AndroidMapBackend.jni), isA<JniAndroidMapTransport>());
    expect(
      () => factory(AndroidMapBackend.methodChannel),
      throwsA(isA<StateError>()),
    );
    expect(
      () => factory(AndroidMapBackend.auto),
      throwsA(isA<ArgumentError>()),
    );
  });
}
