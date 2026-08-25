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
 * `lateinit`-view behavior and gives the JNI bridge one lookup point.
 */
class MapSessionRegistry {
    companion object {
        private val exposedRegistries = ConcurrentHashMap.newKeySet<MapSessionRegistry>()

        internal fun expose(registry: MapSessionRegistry) {
            exposedRegistries.add(registry)
        }

        internal fun hide(registry: MapSessionRegistry) {
            exposedRegistries.remove(registry)
        }

        /**
         * Resolves a JNI view ID only when exactly one Flutter engine owns it.
         * This fails closed instead of routing a command across engines whose
         * platform-view ID sequences happen to overlap.
         */
        internal fun resolve(viewId: Int): MapSession? {
            var match: MapSession? = null
            for (registry in exposedRegistries) {
                val candidate = registry.get(viewId) ?: continue
                if (match != null && match !== candidate) return null
                match = candidate
            }
            return match
        }
    }

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
