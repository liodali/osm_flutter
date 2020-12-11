package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.app.Application
import android.content.Context
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.atomic.AtomicInteger

open class OsmFactory(
        val state: AtomicInteger,
        val binaryMessenger: BinaryMessenger,
        val application: Application?,
        val lifecycle: Lifecycle?,
        val activity: Activity?,
        val activityHashCode: Int,
        val register: PluginRegistry.Registrar?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
            context: Context?,
            viewId: Int,
            args: Any?,
    ): PlatformView {
        val flutterOSMView = FlutterOsmView(context, register,
                binaryMessenger, viewId, state, application, activity, lifecycle, activityHashCode)
        flutterOSMView.init()
        return flutterOSMView
    }
}