package hamza.dali.flutter_osm_plugin

import android.app.Activity
import hamza.dali.flutter_osm_plugin.mapscore.MapscoreMapSession
import java.util.concurrent.ConcurrentHashMap
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Owns Android map views by Flutter's platform-view ID.
 *
 * Platform views may coexist, and activity recreation must update every live
 * view. Keeping this ownership in the factory avoids the old single
 * `lateinit`-view behavior and gives the future JNI bridge one lookup point.
 */
class MapSessionRegistry {
    private val sessions = ConcurrentHashMap<Int, MapscoreMapSession>()
    private var activityBinding: ActivityPluginBinding? = null

    fun register(view: MapscoreMapSession) {
        check(sessions.putIfAbsent(view.viewId, view) == null) {
            "A map session is already registered for view ${view.viewId}"
        }
        activityBinding?.let { binding ->
            view.setActivity(binding.activity)
            binding.addActivityResultListener(view)
        }
    }

    fun get(viewId: Int): MapscoreMapSession? = sessions[viewId]

    fun unregister(viewId: Int, view: MapscoreMapSession? = null) {
        val removed = if (view == null) {
            sessions.remove(viewId)
        } else {
            val current = sessions[viewId]
            if (current === view && sessions.remove(viewId, view)) view else null
        }
        removed?.let { activityBinding?.removeActivityResultListener(it) }
    }

    fun attachActivity(binding: ActivityPluginBinding) {
        detachActivity()
        activityBinding = binding
        val activity = binding.activity
        sessions.values.forEach { view ->
            view.setActivity(activity)
            binding.addActivityResultListener(view)
        }
    }

    fun detachActivity() {
        val binding = activityBinding ?: return
        sessions.values.forEach { view ->
            binding.removeActivityResultListener(view)
            view.setActivity(null)
        }
        activityBinding = null
    }

    fun setActivity(activity: Activity?) {
        sessions.values.forEach { it.setActivity(activity) }
    }

    fun clear() {
        sessions.values.toList().forEach { it.dispose() }
        sessions.clear()
        detachActivity()
    }

    val size: Int
        get() = sessions.size
}
