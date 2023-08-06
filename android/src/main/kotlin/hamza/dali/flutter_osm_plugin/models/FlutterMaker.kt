package hamza.dali.flutter_osm_plugin.models

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.BlendModeColorFilterCompat
import androidx.core.graphics.BlendModeCompat
import com.squareup.picasso.Callback
import com.squareup.picasso.Picasso
import com.squareup.picasso.Target
import hamza.dali.flutter_osm_plugin.R
import hamza.dali.flutter_osm_plugin.utilities.scaleDensity
import kotlinx.coroutines.CoroutineScope
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.infowindow.MarkerInfoWindow
import kotlin.math.PI
import kotlin.math.absoluteValue
import kotlin.math.sign


typealias LongClickHandler = (marker: Marker) -> Boolean

open class FlutterMarker(private var mapView: MapView, var scope: CoroutineScope?) :
    Marker(mapView),
    Marker.OnMarkerClickListener {
    private lateinit var context: Context
    public var angle = 0.0
        private set
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

    override fun onLongPress(event: MotionEvent?, mapView: MapView?): Boolean {
        if (longPress != null) {
            longPress!!(this)
        }
        return super.onLongPress(event, mapView)
    }

    fun setIconMaker(color: Int? = null, bitmap: Bitmap?, angle: Double? = null) {
        this.angle = angle ?: 0.0
        getDefaultIconDrawable(color, bitmap, this.angle).also {
            icon = it
            setAnchor(0.5f, 0.5f)
        }
    }

    fun setIconMarkerFromURL(imageURL: String, angle: Double = 0.0) {
        Picasso.get()
            .load(imageURL)
            .fetch(object : Callback {
                override fun onSuccess() {
                    Picasso.get()
                        .load(imageURL)
                        .into(object : Target {
                            override fun onBitmapLoaded(
                                bitmapMarker: Bitmap?,
                                from: Picasso.LoadedFrom?
                            ) {

                                setIconMaker(bitmap = bitmapMarker, angle = angle)

                            }

                            override fun onBitmapFailed(
                                e: java.lang.Exception?,
                                errorDrawable: Drawable?
                            ) {
                                setIconMaker(bitmap = null, angle = angle)


                            }

                            override fun onPrepareLoad(placeHolderDrawable: Drawable?) {
                                // marker.icon = ContextCompat.getDrawable(context!!, R.drawable.ic_location_on_red_24dp)
                            }

                        })
                }

                override fun onError(e: java.lang.Exception?) {
                    Log.e("error image", e?.stackTraceToString() ?: "")
                }

            })
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
        val iconBitmap = bitmap?.run {
            val matrix = Matrix()
            matrix.postScale(mapView.scaleDensity(), mapView.scaleDensity())
            val resizedBitmap = Bitmap.createBitmap(
                this, 0, 0, width, height, matrix, false
            )
            resizedBitmap
        }
        iconBitmap?.let { bitmap ->
            iconDrawable = when (angle > 0.0) {
                true -> BitmapDrawable(mapView.resources, rotateMarker(bitmap, angle))
                false -> BitmapDrawable(mapView.resources, bitmap)
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
        matrix.postRotate((angle * (180 / PI)).toFloat())
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    fun updateAnchor(anchor: Anchor) {
        val offsetX = ((anchor.offset()?.first ?: 0.0) / icon.intrinsicWidth).toFloat()
        val offsetY = ((anchor.offset()?.second ?: 0.0) / icon.intrinsicHeight).toFloat()
        val anchorX = when (anchor.x) {
            in 0.0..1.0 -> anchor.x
            else -> anchor.x / icon.intrinsicWidth
        } - when {
            anchor.x < 1 -> {
                val sign = offsetX.sign
                (offsetX.absoluteValue + anchor.x) * sign
            }

            else -> offsetX
        }
        val anchorY = when (anchor.y) {
            in 0.0..1.0 -> anchor.y
            else -> anchor.y / icon.intrinsicHeight
        } + when {
            anchor.y < 1 -> {
                val sign = offsetY.sign
                (offsetY.absoluteValue + anchor.y) * sign
            }

            else -> offsetY
        }
        setAnchor(
            anchorX,
            anchorY
        )
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

    fun getOldAnchor(): Anchor = Anchor(mAnchorU, mAnchorV)

}

data class Anchor(val x: Float, val y: Float) {
    private var offset: Pair<Double, Double>? = null

    constructor(map: HashMap<String, Any>) : this(
        (map["x"]!! as Double).toFloat(),
        (map["y"]!! as Double).toFloat()
    ) {
        if (map.containsKey("offset")) {
            val offsetMap = map["offset"]!! as HashMap<String, Double>
            offset = Pair(offsetMap["x"]!!, offsetMap["y"]!!)
        }
    }

    fun offset() = offset
}