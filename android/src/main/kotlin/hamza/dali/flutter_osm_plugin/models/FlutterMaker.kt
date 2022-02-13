package hamza.dali.flutter_osm_plugin.models

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.view.LayoutInflater
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.BlendModeColorFilterCompat
import androidx.core.graphics.BlendModeCompat
import hamza.dali.flutter_osm_plugin.R
import kotlinx.coroutines.CoroutineScope
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.infowindow.MarkerInfoWindow

typealias LongClickHandler = (marker: Marker) -> Boolean

open class FlutterMarker(private var mapView: MapView, var scope: CoroutineScope?) :
    Marker(mapView),
    Marker.OnMarkerClickListener {
    private lateinit var context: Context
    private var canvas: Canvas? = null
    var longPress: LongClickHandler? = null
        set(longPress) {
            if (longPress != null) field = longPress
        }
    var onClickListener: OnMarkerClickListener? = null
        set(listener) {
            if (listener != null) field = listener
        }

    private var infoWindow: View? = null
        set(infoWindow) {
            setInfoWindow(FlutterInfoWindow(mapView, infoWindow!!, this.mPosition))
            field = infoWindow
        }

    constructor(
        context: Context,
        mapView: MapView,
        scope: CoroutineScope? = null
    ) : this(mapView = mapView, scope) {
        this.context = context
        this.setOnMarkerClickListener { marker, map ->
            onMarkerClick(marker, map)
        }
        initInfoWindow()
    }

    constructor(
        context: Context,
        mapView: MapView,
        point: GeoPoint,
        scope: CoroutineScope? = null
    ) : this(mapView = mapView, scope = scope) {
        this.context = context
        this.mPosition = point
        this.setOnMarkerClickListener { marker, map ->
            onMarkerClick(marker, map)
        }
        initInfoWindow()

    }

    constructor(
        mapView: MapView,
        infoWindow: View,
        scope: CoroutineScope? = null
    ) : this(
        mapView,
        scope
    ) {
        this.context = mapView.context
        this.infoWindow = infoWindow
        initInfoWindow()
    }

    private fun initInfoWindow() {
        createWindowInfoView()
        mInfoWindow = FlutterInfoWindow(
            infoView = infoWindow!!,
            mapView = mapView,
            point = mPosition
        )
    }


    override fun onMarkerClick(marker: Marker?, mapView: MapView?): Boolean {
        showInfoWindow()
        return onClickListener?.onMarkerClick(this, mapView) ?: true
    }


//    override fun onLongPress(event: MotionEvent?, mapView: MapView?): Boolean {
//        longPress?.let { it(this) }
//        return super.onLongPress(event, mapView)
//    }

    fun setIconMaker(color: Int?, bitmap: Bitmap?, angle: Double = 0.0) {
        getDefaultIconDrawable(color, bitmap, angle).also {
            icon = it
        }
    }

    fun defaultInfoWindow() {

        setInfoWindow(
            FlutterInfoWindow(
                infoView = infoWindow
                    ?: createWindowInfoView(), mapView = mapView, point = this.mPosition,
                scope = scope
            )
        )
    }


    private fun getDefaultIconDrawable(
        color: Int?,
        bitmap: Bitmap?,
        angle: Double = 0.0
    ): Drawable {
        var iconDrawable: Drawable? = null
        bitmap?.let { b ->
            iconDrawable = when (angle > 0.0) {
                true -> BitmapDrawable(mapView.resources, rotateMarker(b, angle))
                false -> BitmapDrawable(mapView.resources, b)
            }
            iconDrawable = iconDrawable.apply {
                color?.let { c ->
                    this?.colorFilter = BlendModeColorFilterCompat.createBlendModeColorFilterCompat(
                        c,
                        BlendModeCompat.SRC_OVER
                    )
                }
            }

        } ?: run {
            iconDrawable =
                ContextCompat.getDrawable(context, R.drawable.ic_location_on_red_24dp)!!
        }
        return iconDrawable!!

    }

    private fun rotateMarker(bitmap: Bitmap, angle: Double): Bitmap {
        val matrix = Matrix()
        matrix.postRotate(angle.toFloat())
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun createWindowInfoView(): View {
        val inflater =
            context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
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
}