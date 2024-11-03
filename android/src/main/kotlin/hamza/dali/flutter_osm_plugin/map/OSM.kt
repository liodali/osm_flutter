package hamza.dali.flutter_osm_plugin.map

import android.app.Activity
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView

 sealed interface OSM : PlatformView, PluginRegistry.ActivityResultListener {
    fun setActivity(activity: Activity)
}