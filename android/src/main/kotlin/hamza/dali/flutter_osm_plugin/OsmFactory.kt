package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Context
import hamza.dali.flutter_osm_plugin.models.CustomTile
import hamza.dali.flutter_osm_plugin.models.fromMapToCustomTile
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

open class OsmFactory(
    private val binaryMessenger: BinaryMessenger,
    private val provider: ProviderLifecycle,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private lateinit var osmFlutterView: FlutterOsmView

    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    override fun create(
        context: Context?,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val keyUUID = (args as HashMap<*, *>)["uuid"] as String
        var customTile: CustomTile? = null
        var enableRotationGesture = false
        if ((args).containsKey("customTile")) {
            customTile = CustomTile.fromMap(args["customTile"] as HashMap<String, Any>)
        }
        if ((args).containsKey("enableRotationGesture")) {
            enableRotationGesture = args["enableRotationGesture"] as Boolean
        }
        osmFlutterView = FlutterOsmView(
            requireNotNull(context),
            binaryMessenger,
            viewId,
            provider,
            keyUUID,
            customTile = customTile,
            isEnabledRotationGesture = enableRotationGesture
        )
        return osmFlutterView
    }

    fun setActRefInView(activity: Activity) {
        osmFlutterView.setActivity(activity)
    }

    fun setBindingActivity(binding: ActivityPluginBinding) {
        this.binding!!.addActivityResultListener(osmFlutterView)
    }

}
