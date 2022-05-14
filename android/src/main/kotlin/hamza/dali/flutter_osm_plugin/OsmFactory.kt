package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Context
import androidx.preference.PreferenceManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.osmdroid.config.Configuration
import org.osmdroid.views.MapView

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
        Configuration.getInstance().load(
            requireNotNull(context),
            PreferenceManager.getDefaultSharedPreferences(context)
        )
        osmFlutterView = FlutterOsmView(
            requireNotNull(context),
            binaryMessenger,
            viewId,
            provider,
            args as String
        )
        osmFlutterView.activity = this.activity
        binding!!.addActivityResultListener(osmFlutterView)
        return osmFlutterView
    }

    fun setActRefInView(activity: Activity) {
        this.activity = activity
    }

    fun setBindingActivity(binding: ActivityPluginBinding) {
        this.binding = binding
    }

}
