import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the main plugin bundles only the MethodChannel transport', () {
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
