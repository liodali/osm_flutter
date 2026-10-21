import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/src/common/location_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final permission in [
    Permission.locationWhenInUse,
    Permission.locationAlways,
  ]) {
    for (final status in PermissionStatus.values) {
      test('$permission preserves $status through the Android channel',
          () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestPermissions');
          expect(call.arguments, [permission.value]);
          return {permission.value: status.index};
        });

        expect(await requestLocationPermission(permission), status);
      });
    }
  }

  test('missing permission response is denied', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => <int, int>{});

    expect(await requestLocationPermission(Permission.locationWhenInUse),
        PermissionStatus.denied);
  });

  test('native permission errors propagate', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'request_failed');
    });

    await expectLater(
      requestLocationPermission(Permission.locationWhenInUse),
      throwsA(isA<PlatformException>()
          .having((error) => error.code, 'code', 'request_failed')),
    );
  });
}
