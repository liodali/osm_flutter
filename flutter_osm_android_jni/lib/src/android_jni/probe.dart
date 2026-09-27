import 'package:jni/jni.dart';

import 'generated.dart';

/// Result of the phase-0 Android JNI bridge smoke test.
///
/// This is intentionally small and will be replaced by the typed map session
/// API once the JNI transport is proven in an Android build.
final class AndroidJniProbeResult {
  const AndroidJniProbeResult({
    required this.ping,
    required this.sum,
    required this.threadName,
    required this.isMainThread,
  });

  final String ping;
  final int sum;
  final String threadName;
  final bool isMainThread;
}

/// Calls the plugin-owned JVM façade through generated JNI bindings.
///
/// This function is Android-only. Do not call it from iOS, web, or desktop.
AndroidJniProbeResult runAndroidJniProbe() {
  final bridge = OsmAndroidBridge();
  try {
    final ping = bridge.ping().toDartString(releaseOriginal: true);
    final threadName =
        bridge.currentThreadName().toDartString(releaseOriginal: true);
    return AndroidJniProbeResult(
      ping: ping,
      sum: bridge.add(20, 22),
      threadName: threadName,
      isMainThread: bridge.isMainThread,
    );
  } finally {
    bridge.release();
  }
}
