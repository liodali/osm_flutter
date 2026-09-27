import 'package:flutter_osm_android/src/android_transport/method_channel_android_map_transport.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Creates the transport bundled with the endorsed Android implementation.
///
/// JNI is supplied by the optional `flutter_osm_android_jni` package. Compose
/// its factory with this one when opting into [AndroidMapBackend.jni].
AndroidMapTransport createDefaultAndroidMapTransport(
  AndroidMapBackend backend,
) {
  return switch (backend) {
    AndroidMapBackend.methodChannel => MethodChannelAndroidMapTransport(),
    AndroidMapBackend.jni => throw UnsupportedError(
        'The JNI transport is not bundled with flutter_osm_android. Add '
        'flutter_osm_android_jni and provide its transport factory.',
      ),
    AndroidMapBackend.auto => throw ArgumentError.value(
        backend,
        'backend',
        'Resolve auto before creating a transport.',
      ),
  };
}
