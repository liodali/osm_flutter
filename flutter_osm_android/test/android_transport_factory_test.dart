import 'package:flutter_osm_android/flutter_osm_android.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Android package bundles only the MethodChannel transport', () {
    expect(
      createDefaultAndroidMapTransport(AndroidMapBackend.methodChannel),
      isA<MethodChannelAndroidMapTransport>(),
    );
    expect(
      () => createDefaultAndroidMapTransport(AndroidMapBackend.jni),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => createDefaultAndroidMapTransport(AndroidMapBackend.auto),
      throwsA(isA<ArgumentError>()),
    );
  });
}
