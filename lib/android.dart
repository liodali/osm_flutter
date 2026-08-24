/// Android-only APIs for the JNI-backed controller migration.
///
/// This entry point is intentionally separate from `flutter_osm_plugin.dart`
/// so existing iOS and web imports do not initialize Android JNI bindings.
library flutter_osm_plugin_android;

export 'src/android_jni/probe.dart'
    show AndroidJniProbeResult, runAndroidJniProbe;
