package hamza.dali.flutter_osm_plugin

import android.content.Context
import androidx.preference.PreferenceManager
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
    override fun create(
            context: Context,
            viewId: Int,
            args: Any?,
    ): PlatformView {
        Configuration.getInstance().load(
                context,
                PreferenceManager.getDefaultSharedPreferences(context)
        )
        return FlutterOsmView(
                context,
                binaryMessenger,
                viewId,
                provider,
                MapView(context),
                args as String
        )
    }

}