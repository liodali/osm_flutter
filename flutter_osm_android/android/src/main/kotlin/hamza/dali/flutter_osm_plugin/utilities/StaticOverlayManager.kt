package hamza.dali.flutter_osm_plugin.utilities

import android.view.KeyEvent
import android.view.MotionEvent
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.DefaultOverlayManager
import org.osmdroid.views.overlay.TilesOverlay

class StaticOverlayManager(private val tilesOverlay: TilesOverlay):DefaultOverlayManager(tilesOverlay) {

    override fun onKeyDown(keyCode: Int, event: KeyEvent?, pMapView: MapView?): Boolean {
        return false
    }
    override fun onTouchEvent(event: MotionEvent?, pMapView: MapView?): Boolean {
        return false
    }

    override fun onScroll(
        pEvent1: MotionEvent?,
        pEvent2: MotionEvent?,
        pDistanceX: Float,
        pDistanceY: Float,
        pMapView: MapView?
    ): Boolean {
        return false
    }

    override fun onFling(
        pEvent1: MotionEvent?,
        pEvent2: MotionEvent?,
        pVelocityX: Float,
        pVelocityY: Float,
        pMapView: MapView?
    ): Boolean {
        return false
    }
}