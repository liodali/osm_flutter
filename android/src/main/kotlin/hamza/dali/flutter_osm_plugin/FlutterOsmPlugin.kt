package hamza.dali.flutter_osm_plugin

import android.app.Activity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.preference.PreferenceManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.PluginRegistry
import org.osmdroid.config.Configuration
import java.util.concurrent.atomic.AtomicInteger


class FlutterOsmPlugin() :
        FlutterPlugin, ActivityAware {
    constructor(activity: Activity) : this() {
        registrarActivityHashCode = activity.hashCode()
        this.activity = activity

    }

    private var activity: Activity? = null


    companion object {

        var state = AtomicInteger(0)
        var registrarActivityHashCode = 0
        var pluginBinding: FlutterPluginBinding? = null
        var lifecycle: Lifecycle? = null
        var register: PluginRegistry.Registrar? = null
        const val VIEW_TYPE = "plugins.dali.hamza/osmview"
        const val CREATED = 1
        const val STARTED = 2
        const val RESUMED = 3
        const val PAUSED = 4
        const val STOPPED = 5
        const val DESTROYED = 6

        @JvmStatic
        fun registerWith(register: PluginRegistry.Registrar) {

            if (register.activity() == null) {
                return
            }
            this.register = register

            val flutterOsmView = FlutterOsmPlugin(register.activity())
            //register.activity().application.registerActivityLifecycleCallbacks(flutterOsmView)
            register.platformViewRegistry().registerViewFactory(
                    VIEW_TYPE,
                    OsmFactory(
                            register.messenger(),
                            flutterOsmView.activity?.application,
                            null,
                            flutterOsmView.activity,
                    ),
            )
        }
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        pluginBinding = binding

        Configuration.getInstance().load(pluginBinding!!.applicationContext,
                PreferenceManager.getDefaultSharedPreferences(pluginBinding!!.applicationContext))
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        activity = null
        // lifecycle?.removeObserver(this)
        lifecycle = null
    }


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
        //lifecycle?.addObserver(this)
        activity = binding.activity


        pluginBinding!!.platformViewRegistry.registerViewFactory(
                VIEW_TYPE,
                OsmFactory(
                        pluginBinding!!.binaryMessenger,
                        activity!!.application,
                        lifecycle,
                        activity,
                ),
        )
    }

    override fun onDetachedFromActivityForConfigChanges() {
        //  this.onDetachedFromActivity()
        activity = null
       // lifecycle?.removeObserver(this)
        lifecycle = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)

        //lifecycle?.addObserver(this)
        /*activity = binding.activity
        activity!!.application.registerActivityLifecycleCallbacks(this)

        configuration = Configuration.getInstance()
        configuration!!.load(pluginBinding!!.applicationContext,//.application,
                PreferenceManager.getDefaultSharedPreferences(pluginBinding!!.applicationContext))

        pluginBinding!!.platformViewRegistry.registerViewFactory(VIEW_TYPE,
                OsmFactory(
                        pluginBinding!!.binaryMessenger,
                        activity!!.application,
                        lifecycle,
                        activity, register))*/

    }

    override fun onDetachedFromActivity() {
        //lifecycle?.removeObserver(this)
        Configuration.getInstance().osmdroidTileCache.delete()
        activity = null
        lifecycle = null
        pluginBinding = null

    }
//
//    override fun onCreate(owner: LifecycleOwner) {
//        state.set(CREATED)
//    }
//
//    override fun onStart(owner: LifecycleOwner) {
//        state.set(STARTED)
//    }
//
//    override fun onResume(owner: LifecycleOwner) {
//        state.set(RESUMED)
//    }
//
//    override fun onPause(owner: LifecycleOwner) {
//        state.set(PAUSED)
//    }
//
//    override fun onStop(owner: LifecycleOwner) {
//        state.set(STOPPED)
//    }
//
//    override fun onDestroy(owner: LifecycleOwner) {
//        state.set(DESTROYED)
//    }

}