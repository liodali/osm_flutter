package hamza.dali.flutter_osm_plugin.jni

import android.os.Looper
import androidx.annotation.Keep

/**
 * Small JNIgen-facing façade.
 *
 * This intentionally does not expose Mapscore objects. The first implementation
 * only proves that Dart can resolve and call a plugin-owned JVM class. Map session
 * operations will be added after the JNI feasibility spike passes.
 */
@Keep
class OsmAndroidBridge {
    /** Returns a stable probe value used by the Android JNI smoke test. */
    fun ping(): String = "osm-jni-ok"

    /** Verifies primitive argument/return-value marshalling. */
    fun add(left: Int, right: Int): Int = left + right

    /** Verifies that calls enter the JVM and reports the current thread. */
    fun currentThreadName(): String = Thread.currentThread().name

    /** Used to validate Android main-thread dispatch in the next phase. */
    fun isMainThread(): Boolean = Looper.myLooper() == Looper.getMainLooper()
}
