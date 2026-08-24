import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_map_transport.dart';
import 'package:flutter_osm_plugin/src/android_transport/jni_android_map_transport.dart';
import 'package:flutter_osm_plugin/src/android_transport/method_channel_android_map_transport.dart';

AndroidMapTransport createAndroidMapTransport(AndroidMapBackend backend) {
  return switch (backend) {
    AndroidMapBackend.jni => JniAndroidMapTransport(),
    AndroidMapBackend.methodChannel => MethodChannelAndroidMapTransport(),
    AndroidMapBackend.auto => throw ArgumentError.value(
        backend,
        'backend',
        'Resolve auto before creating a transport.',
      ),
  };
}
