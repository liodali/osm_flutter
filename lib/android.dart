/// Android-only APIs for the JNI-backed controller migration.
///
/// This entry point is intentionally separate from `flutter_osm_plugin.dart`
/// so existing iOS and web imports do not initialize Android JNI bindings.
library flutter_osm_plugin_android;

export 'package:flutter_osm_interface/flutter_osm_interface.dart'
    show
        AndroidMapAcknowledgement,
        AndroidMapBackend,
        AndroidMapError,
        AndroidMapEvent,
        AndroidMapException,
        AndroidMapPlatform,
        AndroidMapReady,
        AndroidMapTap,
        AndroidMapTapKind,
        AndroidMarkerTap,
        AndroidRegionChanged,
        MarkerId;
export 'src/android_jni/probe.dart'
    show AndroidJniProbeResult, runAndroidJniProbe;
export 'src/android_transport/android_map_transport.dart'
    show AndroidMapTransport, AndroidMapTransportFactory;
export 'src/android_transport/jni_android_map_transport.dart'
    show JniAndroidMapTransport;
export 'src/android_transport/method_channel_android_map_transport.dart'
    show MethodChannelAndroidMapTransport;
export 'src/controller/android_map_controller.dart' show AndroidMapController;
