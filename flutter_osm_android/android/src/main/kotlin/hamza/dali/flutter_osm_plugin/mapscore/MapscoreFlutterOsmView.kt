package hamza.dali.flutter_osm_plugin.mapscore

import android.os.Bundle
import android.view.View
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import hamza.dali.flutter_osm_plugin.ProviderLifecycle
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.platform.PlatformView

/**
 * Thin Android platform-view wrapper around one [MapscoreMapSession].
 *
 * This class owns Flutter view embedding and lifecycle observation only. Map
 * state, commands, events, and activity results belong to [session].
 */
internal class MapscoreFlutterOsmView(
    internal val session: MapscoreMapSession,
    providerLifecycle: ProviderLifecycle,
) : OnSaveInstanceStateListener, PlatformView, DefaultLifecycleObserver {
    private val lifecycle = providerLifecycle.getOSMLifecycle()
    private var released = false

    init {
        lifecycle?.addObserver(this)
    }

    override fun getView(): View = session.view

    override fun dispose() {
        release()
    }

    private fun release() {
        if (released) return
        released = true
        lifecycle?.removeObserver(this)
        session.dispose()
    }

    override fun onFlutterViewAttached(flutterView: View) {
        session.onFlutterViewAttached(flutterView)
    }

    override fun onFlutterViewDetached() {
        session.onFlutterViewDetached()
    }

    override fun onSaveInstanceState(bundle: Bundle) {
        session.onSaveInstanceState(bundle)
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        session.onRestoreInstanceState(bundle)
    }

    override fun onCreate(owner: LifecycleOwner) {
        super.onCreate(owner)
        session.onCreate(owner)
    }

    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        session.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        session.onPause()
        super.onPause(owner)
    }

    override fun onStop(owner: LifecycleOwner) {
        session.onStop()
        super.onStop(owner)
    }

    override fun onDestroy(owner: LifecycleOwner) {
        release()
        super.onDestroy(owner)
    }
}
