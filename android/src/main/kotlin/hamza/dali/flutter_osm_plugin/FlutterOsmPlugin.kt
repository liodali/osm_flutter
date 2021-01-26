package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.preference.PreferenceManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import org.osmdroid.config.Configuration
import org.osmdroid.config.IConfigurationProvider
import java.util.concurrent.atomic.AtomicInteger
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter


class FlutterOsmPlugin() :
        FlutterPlugin, ActivityAware, DefaultLifecycleObserver {
    constructor(activity: Activity) : this() {
        registrarActivityHashCode = activity.hashCode()
        this.activity = activity
    }

    private var activity: Activity? = null
    private var configuration: IConfigurationProvider? = null


    companion object {

        var state = AtomicInteger(0)
        var registrarActivityHashCode = 0
        var pluginBinding: FlutterPluginBinding? = null
        var lifecycle: Lifecycle? = null
        var register: PluginRegistry.Registrar? = null
        val VIEW_TYPE = "plugins.dali.hamza/osmview"
        val CREATED = 1
        val STARTED = 2
        val RESUMED = 3
        val PAUSED = 4
        val STOPPED = 5
        val DESTROYED = 6

        @JvmStatic
        fun registerWith(register: PluginRegistry.Registrar) {

            if (register.activity() == null) {
                return
            }
            this.register = register

            val flutterOsmView = FlutterOsmPlugin(register.activity())
            //register.activity().application.registerActivityLifecycleCallbacks(flutterOsmView)
            register.platformViewRegistry().registerViewFactory(VIEW_TYPE,
                    OsmFactory(
                            register.messenger(),
                            null,
                            null,
                            null,
                            register))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        pluginBinding = binding


    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        
    }


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
        lifecycle?.addObserver(this)
        activity = binding.activity

        configuration = Configuration.getInstance()
        configuration!!.load(pluginBinding!!.applicationContext,//.application,
                PreferenceManager.getDefaultSharedPreferences(pluginBinding!!.applicationContext))

        pluginBinding!!.platformViewRegistry.registerViewFactory(
                VIEW_TYPE,
                OsmFactory(
                        pluginBinding!!.binaryMessenger,
                        activity!!.application,
                        lifecycle,
                        activity,
                        register,
                ),
        )
    }

    override fun onDetachedFromActivityForConfigChanges() {
        //  this.onDetachedFromActivity()
        configuration!!.osmdroidTileCache.delete()
        configuration = null

        activity = null
        lifecycle?.removeObserver(this)
        lifecycle = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)

        lifecycle?.addObserver(this)
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
        lifecycle?.removeObserver(this)
        Configuration.getInstance().osmdroidTileCache.delete()
        activity = null
        lifecycle = null
        pluginBinding = null

    }

    override fun onCreate(owner: LifecycleOwner) {
        state.set(CREATED)
    }

    override fun onStart(owner: LifecycleOwner) {
        state.set(STARTED)
    }

    override fun onResume(owner: LifecycleOwner) {
        state.set(RESUMED)
    }

    override fun onPause(owner: LifecycleOwner) {
        state.set(PAUSED)
    }

    override fun onStop(owner: LifecycleOwner) {
        state.set(STOPPED)
    }

    override fun onDestroy(owner: LifecycleOwner) {
        state.set(DESTROYED)
    }

}