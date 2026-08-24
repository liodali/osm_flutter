package hamza.dali.flutter_osm_plugin

import android.app.Activity
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.util.concurrent.ConcurrentHashMap

/**
 * Owns Android map views by Flutter's platform-view ID.
 *
 * Platform views may coexist, and activity recreation must update every live
 * view. Keeping this ownership in the factory avoids the old single
 * `lateinit`-view behavior and gives the future JNI bridge one lookup point.
 */
class MapSessionRegistry {
    private val sessions = ConcurrentHashMap<Int, MapSession>()
    private var activityBinding: ActivityPluginBinding? = null

    fun register(view: MapSession) {
        check(sessions.putIfAbsent(view.viewId, view) == null) {
            "A map session is already registered for view ${view.viewId}"
        }
        activityBinding?.let { binding ->
            view.setActivity(binding.activity)
            binding.addActivityResultListener(view)
        }
    }

    fun get(viewId: Int): MapSession? = sessions[viewId]

    fun unregister(viewId: Int, session: MapSession) {
        if (sessions[viewId] === session && sessions.remove(viewId, session)) {
            activityBinding?.removeActivityResultListener(session)
            session.setActivity(null)
        }
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
        detachActivity()
        sessions.values.toList().forEach { it.dispose() }
        sessions.clear()
    }

    val size: Int
        get() = sessions.size
}
