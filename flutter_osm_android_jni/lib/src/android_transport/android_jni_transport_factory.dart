import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_android_jni/src/android_transport/jni_android_map_transport.dart';

/// Adds the optional JNI command transport to an existing Android transport
/// factory.
///
/// The supplied [fallback] remains responsible for non-JNI backends. Backend
/// selection is completed before map initialization, so state-changing
/// commands are never replayed between transports.
AndroidMapTransportFactory createAndroidJniTransportFactory({
  required AndroidMapTransportFactory fallback,
}) {
  return (backend) => switch (backend) {
        AndroidMapBackend.jni => JniAndroidMapTransport(),
        AndroidMapBackend.methodChannel => fallback(backend),
        AndroidMapBackend.auto => throw ArgumentError.value(
            backend,
            'backend',
            'Resolve auto before creating a transport.',
          ),
      };
}
