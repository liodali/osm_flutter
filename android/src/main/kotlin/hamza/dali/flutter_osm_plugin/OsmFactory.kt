package hamza.dali.flutter_osm_plugin

import android.content.Context
import hamza.dali.flutter_osm_plugin.mapscore.MapscoreFlutterOsmView
import hamza.dali.flutter_osm_plugin.models.CustomTile
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

open class OsmFactory(
    private val binaryMessenger: BinaryMessenger,
    private val provider: ProviderLifecycle,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val sessions = MapSessionRegistry()

    override fun create(
        context: Context?,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val params = args as? HashMap<*, *>
            ?: throw IllegalArgumentException("Map creation arguments must be a map")
        val keyUUID = params["uuid"] as? String ?: viewId.toString()
        val customTile = params["customTile"]?.let {
            @Suppress("UNCHECKED_CAST")
            CustomTile.fromMap(it as HashMap<String, Any>)
        }
        val enableRotationGesture = params["enableRotationGesture"] as? Boolean ?: false
        val staticMap = params["isStaticMap"] as? Boolean ?: false

        val view = MapscoreFlutterOsmView(
            context = requireNotNull(context),
            binaryMessenger = binaryMessenger,
            id = viewId,
            providerLifecycle = provider,
            keyArgMapSnapShot = keyUUID,
            customTile = customTile,
            isEnabledRotationGesture = enableRotationGesture,
            isStaticMap = staticMap,
            onDisposed = { disposedViewId -> sessions.unregister(disposedViewId) },
        )
        sessions.register(view)
        return view
    }

    fun attachActivity(binding: ActivityPluginBinding) {
        sessions.attachActivity(binding)
    }

    fun detachActivity() {
        sessions.detachActivity()
    }

    fun dispose() {
        sessions.clear()
    }

    internal fun sessionCount(): Int = sessions.size
}
