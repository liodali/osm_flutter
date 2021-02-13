package hamza.dali.flutter_osm_plugin

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Point
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.BlendModeColorFilterCompat
import androidx.core.graphics.BlendModeCompat
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.infowindow.MarkerInfoWindow

typealias LongClickHandler = (marker: Marker) -> Boolean

open class FlutterMarker(mapView: MapView) : Marker(mapView), Marker.OnMarkerClickListener, (Marker) -> Boolean {
    protected lateinit var application: Application
    private var canvas: Canvas? = null
    var longPress: LongClickHandler? = null
        set(longPress) {
            if (longPress != null) field = longPress
        }
    var onClickListener: OnMarkerClickListener? = null
        set(listener) {
            if (listener != null) field = listener
        }

    private lateinit var mapView: MapView
    private var infoWindow: View? = null
        set(infoWindow) {
            setInfoWindow(FlutterInfoWindow(mapView, infoWindow!!, this.mPosition))
            field = infoWindow
        }

    constructor(application: Application, mapView: MapView) : this(mapView = mapView) {
        this.application = application
        this.mapView = mapView
        this.setOnMarkerClickListener { marker, map ->
            onMarkerClick(marker, map)
        }

    }

    constructor(application: Application, mapView: MapView, point: GeoPoint) : this(mapView = mapView) {
        this.application = application
        this.mapView = mapView
        this.mPosition = point
        this.setOnMarkerClickListener { marker, map ->
            onMarkerClick(marker, map)
        }
        creatWindowInfoView()
        setInfoWindow(FlutterInfoWindow(infoView = infoWindow!!, mapView = mapView, point = mPosition))
    }

    constructor(mapView: MapView, infoWindow: View) : this(mapView) {
        this.mapView = mapView
        this.infoWindow = infoWindow
    }

    override fun onMarkerClick(marker: Marker?, mapView: MapView?): Boolean {
        showInfoWindow()
        return onClickListener?.onMarkerClick(this, mapView) ?: true
    }

    override fun onLongPress(event: MotionEvent?, mapView: MapView?): Boolean {
        longPress?.let { it(this) }
        return super.onLongPress(event, mapView)
    }

    fun setIconMaker(color: Int?, bitmap: Bitmap?) {
        getDefaultIconDrawable(color, bitmap).also {
            icon = it
        }
    }

    fun defaultInfoWindow() {

        setInfoWindow(FlutterInfoWindow(infoView = infoWindow
                ?: creatWindowInfoView(), mapView = mapView, point = this.mPosition))
    }



    private fun getDefaultIconDrawable(color: Int?, bitmap: Bitmap?): Drawable {
        var iconDrawable: Drawable? = null
        bitmap?.let { b ->
            iconDrawable = BitmapDrawable(mapView.resources, b)
            iconDrawable = iconDrawable.apply {
                color?.let { c ->
                    this?.colorFilter = BlendModeColorFilterCompat.createBlendModeColorFilterCompat(c, BlendModeCompat.SRC_OVER)
                }
            }

        } ?: run {
            iconDrawable = ContextCompat.getDrawable(application, R.drawable.ic_location_on_red_24dp)!!
        }
        return iconDrawable!!

    }

    private fun creatWindowInfoView(): View {
        val inflater = application.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        infoWindow = inflater.inflate(R.layout.infowindow, null)
        return infoWindow!!
    }

    override fun setInfoWindow(infoWindow: MarkerInfoWindow?) {
        super.setInfoWindow(infoWindow)
    }

    fun visibilityInfoWindow(visible: Boolean) {
        this.infoWindow?.let { it.visibility = if (visible) View.VISIBLE else View.GONE }
    }

    override fun showInfoWindow() {
        super.showInfoWindow()
    }

    override fun invoke(p1: Marker): Boolean {
        TODO("Not yet implemented")
    }
}