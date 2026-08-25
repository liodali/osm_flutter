package hamza.dali.flutter_osm_plugin.jni

import android.os.Handler
import android.os.Looper
import androidx.annotation.Keep
import hamza.dali.flutter_osm_plugin.MapSessionRegistry
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import java.util.concurrent.ConcurrentHashMap

/**
 * Small JNIgen-facing façade for the typed Android command plane.
 *
 * Mapscore objects never cross JNI. Mutations are accepted on the calling
 * thread, executed on Android's main thread, and completed through the existing
 * per-view MethodChannel event sink.
 */
@Keep
class OsmAndroidBridge {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val attachedSessions = ConcurrentHashMap<Int, MapSession>()

    /** Returns a stable probe value used by the Android JNI smoke test. */
    fun ping(): String = "osm-jni-ok"

    /** Verifies primitive argument/return-value marshalling. */
    fun add(left: Int, right: Int): Int = left + right

    /** Verifies that calls enter the JVM and reports the current thread. */
    fun currentThreadName(): String = Thread.currentThread().name

    /** Reports whether a JNI call arrived on Android's main thread. */
    fun isMainThread(): Boolean = Looper.myLooper() == Looper.getMainLooper()

    /** Selects one native map session before any state-changing command. */
    fun attach(viewId: Int): Boolean {
        val session = MapSessionRegistry.resolve(viewId) ?: return false
        val previous = attachedSessions.putIfAbsent(viewId, session)
        return previous == null || previous === session
    }

    fun initialize(
        viewId: Int,
        latitude: Double,
        longitude: Double,
        requestId: String,
    ): Boolean = queueCommand(
        viewId = viewId,
        requestId = requestId,
        operation = "initialize",
        command = { it.initialize(latitude, longitude) },
        afterAcknowledgement = { it.emitReady(true) },
    )

    fun moveTo(
        viewId: Int,
        latitude: Double,
        longitude: Double,
        animated: Boolean,
        requestId: String,
    ): Boolean = queueCommand(viewId, requestId, "moveTo") {
        it.moveTo(latitude, longitude, animated)
    }

    fun setZoom(viewId: Int, zoom: Double, requestId: String): Boolean =
        queueCommand(viewId, requestId, "setZoom") {
            it.setZoom(zoomLevel = zoom)
        }

    /** Returns a thread-safe snapshot; NaN means no camera value is available. */
    fun getZoom(viewId: Int): Double =
        attachedSession(viewId)?.getZoomSnapshot() ?: Double.NaN

    fun setRotation(
        viewId: Int,
        angle: Double,
        animated: Boolean,
        requestId: String,
    ): Boolean = queueCommand(viewId, requestId, "setRotation") {
        it.setRotation(angle, animated)
    }

    fun addMarker(
        viewId: Int,
        markerId: String,
        latitude: Double,
        longitude: Double,
        requestId: String,
    ): Boolean = queueCommand(viewId, requestId, "addMarker") {
        it.addMarker(markerId, latitude, longitude)
    }

    fun removeMarker(viewId: Int, markerId: String, requestId: String): Boolean =
        queueCommand(viewId, requestId, "removeMarker") {
            it.removeMarker(markerId)
        }

    /** Detaches this bridge instance without disposing the platform view. */
    fun close(viewId: Int): Boolean = attachedSessions.remove(viewId) != null

    private fun attachedSession(viewId: Int): MapSession? {
        val attached = attachedSessions[viewId] ?: return null
        return if (MapSessionRegistry.resolve(viewId) === attached) attached else null
    }

    private fun queueCommand(
        viewId: Int,
        requestId: String,
        operation: String,
        afterAcknowledgement: (MapSession) -> Unit = {},
        command: (MapSession) -> Boolean,
    ): Boolean {
        val session = attachedSession(viewId) ?: return false
        return mainHandler.post {
            if (attachedSession(viewId) !== session) return@post
            try {
                if (!command(session)) {
                    session.emitError(
                        requestId,
                        operation,
                        "command_rejected",
                        "The map session rejected $operation",
                    )
                    return@post
                }
                session.emitAcknowledgement(requestId, operation)
                afterAcknowledgement(session)
            } catch (error: Throwable) {
                session.emitError(
                    requestId,
                    operation,
                    "native_error",
                    error.message,
                )
            }
        }
    }
}
