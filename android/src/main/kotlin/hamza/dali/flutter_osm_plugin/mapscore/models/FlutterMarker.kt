package hamza.dali.flutter_osm_plugin.mapscore.models

import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import com.squareup.picasso3.BitmapTarget
import com.squareup.picasso3.Callback
import com.squareup.picasso3.Picasso
import hamza.dali.flutter_osm_plugin.R
import hamza.dali.flutter_osm_plugin.mapscore.utilities.MapscoreConstants
import hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToRender
import hamza.dali.flutter_osm_plugin.mapscore.utilities.rotate
import hamza.dali.flutter_osm_plugin.mapscore.utilities.scaleBy
import io.openmobilemaps.mapscore.graphics.BitmapTextureHolder
import io.openmobilemaps.mapscore.shared.graphics.common.Vec2F
import io.openmobilemaps.mapscore.shared.graphics.shader.BlendMode
import io.openmobilemaps.mapscore.shared.map.coordinates.CoordinateConversionHelperInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconFactory
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconInfoInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconLayerInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconType
import kotlin.math.PI

/**
 * mapscore counterpart of [hamza.dali.flutter_osm_plugin.models.FlutterMarker].
 *
 * Each marker owns a single [IconInfoInterface] inside a shared [IconLayerInterface].
 * Click/long-press routing is performed by the owning layer (keyed by [identifier]).
 */
class FlutterMarker(
    private val context: Context,
    private val helper: CoordinateConversionHelperInterface,
    private val iconLayer: IconLayerInterface,
    val identifier: String,
    private val density: Float,
) {
    var lat: Double = 0.0
        private set
    var lon: Double = 0.0
        private set
    var angle: Double = 0.0
        private set

    private var anchor: Vec2F = Vec2F(0.5f, 0.5f)
    private var iconBitmap: Bitmap? = null
    var iconInfo: IconInfoInterface? = null
        private set

    var onClickListener: ((FlutterMarker) -> Boolean)? = null
    var longPress: ((FlutterMarker) -> Boolean)? = null

    fun setPosition(lat: Double, lon: Double) {
        this.lat = lat
        this.lon = lon
        iconInfo?.setCoordinate(latLonToRender(helper, lat, lon))
    }

    fun setIconMaker(color: Int? = null, bitmap: Bitmap?, angle: Double? = null) {
        this.angle = angle ?: 0.0
        iconBitmap = bitmap
        applyIcon(color)
    }

    fun setIconMarkerFromURL(imageURL: String, angle: Double = 0.0) {
        Picasso.Builder(context).build().load(imageURL).fetch(object : Callback {
            override fun onError(t: Throwable) {
                Log.e("error image", t.stackTraceToString())
            }

            override fun onSuccess() {
                Picasso.Builder(context).build().load(imageURL)
                    .into(object : BitmapTarget {
                        override fun onBitmapFailed(e: Exception, errorDrawable: Drawable?) {
                            setIconMaker(bitmap = null, angle = angle)
                        }

                        override fun onBitmapLoaded(bitmap: Bitmap, from: Picasso.LoadedFrom) {
                            setIconMaker(bitmap = bitmap, angle = angle)
                        }

                        override fun onPrepareLoad(placeHolderDrawable: Drawable?) {}
                    })
            }
        })
    }

    fun updateAnchor(anchor: Anchor) {
        this.anchor = Vec2F(anchor.x, anchor.y)
        applyIcon(null)
    }

    fun getOldAnchor(): Anchor = Anchor(anchor.x, anchor.y)

    private fun applyIcon(color: Int?) {
        var base: Bitmap? = iconBitmap
        if (base == null) {
            base = ContextCompat.getDrawable(context, R.drawable.ic_location_on_red_24dp)
                ?.toBitmap()
        }
        if (base == null) return

        var bmp = base.scaleBy(density)
        if (angle > 0.0) {
            bmp = bmp.rotate((angle * (180.0 / PI)).toFloat())
        }

        val holder = BitmapTextureHolder(bmp)
        val size = Vec2F(bmp.width.toFloat(), bmp.height.toFloat())

        val old = iconInfo
        iconInfo = IconFactory.createIconWithAnchor(
            identifier = identifier,
            coordinate = latLonToRender(helper, lat, lon),
            texture = holder,
            iconSize = size,
            scaleType = IconType.INVARIANT,
            blendMode = BlendMode.NORMAL,
            iconAnchor = anchor,
        )
        if (old != null) iconLayer.remove(old)
        iconLayer.add(iconInfo!!)
        if (color != null) {
            // mapscore has no per-icon color filter; color tint is applied by swapping the
            // icon bytes upstream (Dart side). Kept for API parity.
        }
    }

    fun remove() {
        iconInfo?.let { iconLayer.remove(it) }
        iconInfo = null
    }

    @Suppress("unused")
    fun visibilityInfoWindow(visible: Boolean) {
        // mapscore has no built-in info windows; kept for API parity with the Dart side.
    }
}
