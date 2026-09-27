/// Optional Android JNI command transport for `flutter_osm_plugin`.
///
/// The endorsed Android package owns the platform view, native map session,
/// MethodChannel event plane, location, permissions, and lifecycle.
library flutter_osm_android_jni;

export 'src/android_jni/probe.dart'
    show AndroidJniProbeResult, runAndroidJniProbe;
export 'src/android_transport/android_jni_transport_factory.dart'
    show createAndroidJniTransportFactory;
export 'src/android_transport/jni_android_map_transport.dart'
    show JniAndroidMapTransport;
