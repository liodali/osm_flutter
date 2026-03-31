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
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import org.osmdroid.config.Configuration
import java.util.concurrent.atomic.AtomicInteger


class FlutterOsmPlugin :
    FlutterPlugin, ActivityAware {
    private var factory: OsmFactory? = null
    companion object {

        var lastKeysRestarted: ArrayMap<String, Boolean>? = ArrayMap()
        var state = AtomicInteger(0)
        var pluginBinding: ActivityPluginBinding? = null
        var lifecycle: Lifecycle? = null
        const val VIEW_TYPE = "plugins.dali.hamza/osmview"
        const val CREATED = 1
        const val STARTED = 2
        const val RESUMED = 3
        const val PAUSED = 4
        const val STOPPED = 5
        const val DESTROYED = 6

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
    }

}

interface ProviderLifecycle {
    fun getOSMLifecycle(): Lifecycle?
}
