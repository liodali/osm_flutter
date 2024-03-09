package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.util.ArrayMap
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.preference.PreferenceManager
import hamza.dali.flutter_osm_plugin.utilities.MapSnapShot
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.PluginRegistry
import org.osmdroid.config.Configuration
import java.util.concurrent.atomic.AtomicInteger


class FlutterOsmPlugin :
    FlutterPlugin, ActivityAware {
    private var factory: OsmFactory? = null
    companion object {
        var mapSnapShots = ArrayMap<String, MapSnapShot>()
        var lastKeysRestarted: ArrayMap<String, Boolean>? = ArrayMap()
        var state = AtomicInteger(0)
        var pluginBinding: ActivityPluginBinding? = null
        var lifecycle: Lifecycle? = null
        //private var register: PluginRegistry.Registrar? = null
        const val VIEW_TYPE = "plugins.dali.hamza/osmview"
        const val CREATED = 1
        const val STARTED = 2
        const val RESUMED = 3
        const val PAUSED = 4
        const val STOPPED = 5
        const val DESTROYED = 6

        /*@JvmStatic
        fun registerWith(register: PluginRegistry.Registrar) {
            val registerActivity: Activity = register.activity() ?: return
            this.register = register

            val flutterOsmView = FlutterOsmPlugin()
            //register.activity()?.application?.registerActivityLifecycleCallbacks(flutterOsmView.)
            register.platformViewRegistry().registerViewFactory(
                VIEW_TYPE,
                OsmFactory(
                    register.messenger(),
                    object : ProviderLifecycle {
                        override fun getLifecyle(): Lifecycle =
                            ProxyLifecycleProvider(activity = registerActivity).lifecycle
                    },
                ),
            )
        }*/
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        Configuration.getInstance().load(
            requireNotNull(binding.applicationContext),
            PreferenceManager.getDefaultSharedPreferences(binding.applicationContext)
        )
        factory = OsmFactory(
            binding.binaryMessenger,
            object : ProviderLifecycle {
                override fun getOSMLifecycle(): Lifecycle? = lifecycle
            },
        )
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            factory!!
        )
    }


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)

        pluginBinding = binding

    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        // lifecycle?.removeObserver(this)
        factory = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.e("osm", "detached activity")
        //  this.onDetachedFromActivity()
        // lifecycle?.removeObserver(this)
        // lifecycle = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.e("osm", "reAttached activity for changes")
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
        factory!!.setActRefInView(binding.activity)
    }

    override fun onDetachedFromActivity() {
        //lifecycle?.removeObserver(this)
        lifecycle = null
        pluginBinding = null
        mapSnapShots.clear()
    }

}

interface ProviderLifecycle {
    fun getOSMLifecycle(): Lifecycle?
}

private class ProxyLifecycleProvider constructor(
    activity: Activity
) : Application.ActivityLifecycleCallbacks, LifecycleOwner, ProviderLifecycle {

    override val lifecycle: LifecycleRegistry = LifecycleRegistry(this)
    var registrarActivityHashCode: Int = activity.hashCode()

    init {
        activity.application.registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return
        }
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    override fun onActivityStarted(activity: Activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return
        }
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_START)
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return
        }
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return
        }
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    }

    override fun onActivityStopped(activity: Activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return
        }
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    override fun onActivityDestroyed(activity: Activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return
        }
        lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    }


    override fun getOSMLifecycle(): Lifecycle = lifecycle

}