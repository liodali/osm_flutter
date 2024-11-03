package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Context
import hamza.dali.flutter_osm_plugin.map.FlutterMapLibreView
import hamza.dali.flutter_osm_plugin.map.FlutterOsmView
import hamza.dali.flutter_osm_plugin.map.OSM
import hamza.dali.flutter_osm_plugin.models.CustomTile
import hamza.dali.flutter_osm_plugin.models.OSMTile
import hamza.dali.flutter_osm_plugin.models.VectorOSMTile
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

open class OsmFactory(
    private val binaryMessenger: BinaryMessenger,
    private val provider: ProviderLifecycle,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private lateinit var osmFlutterView: OSM

    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    override fun create(
        context: Context?,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val keyUUID = (args as HashMap<*, *>)["uuid"] as String
        var customTile: OSMTile? = null
        var enableRotationGesture = false
        var isVector = false
        val staticMap = when {
            args.containsKey("isStaticMap") -> args["isStaticMap"] as Boolean
            else -> false
        }
        if (args.containsKey("isVectorTile")) {
            isVector = args["isVectorTile"] as Boolean? == true
        }
        customTile = when {
            args.containsKey("customTile") && !isVector -> CustomTile.fromMap(args["customTile"] as HashMap<String, Any>)
            args.containsKey("customTile") && isVector -> VectorOSMTile((args["customTile"] as HashMap<String, *>)["serverStyleUrl"] as String)
            else -> null
        }
        if (args.containsKey("enableRotationGesture")) {
            enableRotationGesture = args["enableRotationGesture"] as Boolean
        }
        osmFlutterView = when (isVector) {
            true -> FlutterMapLibreView(
                requireNotNull(context),
                binaryMessenger,
                viewId,
                provider,
                keyUUID,
                customTile = customTile,
                isEnabledRotationGesture = enableRotationGesture,
                isStaticMap = staticMap
            )

            else -> FlutterOsmView(
                requireNotNull(context),
                binaryMessenger,
                viewId,
                provider,
                keyUUID,
                customTile = customTile as CustomTile,
                isEnabledRotationGesture = enableRotationGesture,
                isStaticMap = staticMap
            )
        }

        return osmFlutterView
    }

    fun setActRefInView(activity: Activity) {
        osmFlutterView.setActivity(activity)
    }

    fun setBindingActivity(binding: ActivityPluginBinding) {
        this.binding!!.addActivityResultListener(osmFlutterView)
    }

}
