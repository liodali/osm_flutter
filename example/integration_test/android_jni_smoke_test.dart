import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calls the plugin-owned Kotlin façade through JNI', (
    tester,
  ) async {
    final result = runAndroidJniProbe();

    expect(result.ping, 'osm-jni-ok');
    expect(result.sum, 42);
    expect(result.threadName, isNotEmpty);
    expect(result.isMainThread, isA<bool>());
  });
}
