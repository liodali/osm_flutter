package hamza.dali.flutter_osm_plugin.utilities

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.PathEffect
import android.location.Location
import android.provider.Settings
import hamza.dali.flutter_osm_plugin.map.FlutterOsmView
import hamza.dali.flutter_osm_plugin.models.RoadGeoPointInstruction
import hamza.dali.flutter_osm_plugin.models.toGeoPoints
import hamza.dali.flutter_osm_plugin.models.toMap
import org.maplibre.android.geometry.LatLng
import org.osmdroid.api.IGeoPoint
import org.osmdroid.bonuspack.routing.Road
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.tileprovider.tilesource.ITileSource
import org.osmdroid.tileprovider.tilesource.OnlineTileSourceBase
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.util.MapTileIndex
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Polyline
import org.osmdroid.views.overlay.advancedpolyline.MonochromaticPaintList
import java.io.ByteArrayOutputStream


fun IGeoPoint.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this[Constants.latLabel] = latitude
        this[Constants.lonLabel] = longitude
    }

}

fun GeoPoint.eq(other: GeoPoint): Boolean {
    return this.latitude == other.latitude && this.longitude == other.longitude
}

fun MapView.scaleDensity() = this.context.resources.displayMetrics.density
fun HashMap<String, Double>.toGeoPoint(): GeoPoint {
    if (this.keys.contains("lat") && this.keys.contains("lon")) {
        return GeoPoint(this["lat"]!!, this["lon"]!!)
    }
    throw IllegalArgumentException("cannot map this hashMap to GeoPoint")

}

fun Location.toGeoPoint(): GeoPoint = GeoPoint(latitude, longitude)

fun List<GeoPoint>.containGeoPoint(point: GeoPoint): Boolean {
    return this.firstOrNull { p ->
        p.eq(point)
    } != null
}

fun BoundingBox.isWorld(): Boolean {
    return this.latNorth == 85.0 && this.latSouth == -85.0
            && this.lonEast == 180.0
            && this.lonWest == -180.0
}

fun BoundingBox.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this["north"] = latNorth
        this["east"] = lonEast
        this["south"] = latSouth
        this["west"] = lonWest
    }

}

fun FlutterOsmView.openSettingLocation(requestCode: Int, activity: Activity?) {
    val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
    activity?.startActivityForResult(intent, requestCode)
}

fun MapView.setCustomTile(
    name: String,
    minZoomLvl: Int = 1,
    maxZoomLvl: Int = 19,
    tileSize: Int = 256,
    tileExtensionFile: String = ".png",
    baseURLs: Array<String>,
    api: Pair<String, String>?
) {
    //val imageEndingTile = tileExtensionFile

    val tileSource: ITileSource = object : OnlineTileSourceBase(
        name,
        minZoomLvl,
        maxZoomLvl,
        tileSize,
        tileExtensionFile,
        baseURLs
    ) {
        override fun getTileURLString(pMapTileIndex: Long): String {
            val url = when {
                baseUrl.contains("{x}") && baseUrl.contains("{y}") && baseUrl.contains("{z}") -> {

                    val serverURL = baseUrl.replace(
                        "{x}",
                        MapTileIndex.getX(pMapTileIndex).toString(),
                        true
                    ).replace(
                        "{y}",
                        MapTileIndex.getY(pMapTileIndex).toString(),
                        true
                    ).replace(
                        "{z}",
                        MapTileIndex.getZoom(pMapTileIndex).toString(),
                        true
                    )
                    serverURL + mImageFilenameEnding
                }

                else -> baseUrl + MapTileIndex.getZoom(pMapTileIndex) + "/" + MapTileIndex.getX(
                    pMapTileIndex
                ) + "/" + MapTileIndex.getY(pMapTileIndex) + mImageFilenameEnding
            }
            val key = when {
                api != null -> "?${api.first}=${api.second}"
                else -> ""
            }
            return url + key
        }

    }

    this.setTileSource(tileSource)
}

fun MapView.resetTileSource() {
    //val imageEndingTile = tileExtensionFile
    if (tileProvider.tileSource != TileSourceFactory.DEFAULT_TILE_SOURCE) {
        this.setTileSource(TileSourceFactory.DEFAULT_TILE_SOURCE)
    }
}

fun Polyline.setStyle(
    color: Int,
    width: Float,
    borderColor: Int?,
    borderWidth: Float,
    isDottedPolyline: Boolean = false
) {
    outlinePaint.strokeWidth = width
    outlinePaint.style = Paint.Style.FILL_AND_STROKE
    outlinePaint.color = color
    outlinePaint.strokeCap = Paint.Cap.ROUND
    var pathEffect: PathEffect? = null
    if (isDottedPolyline) {
        pathEffect = DashPathEffect(arrayOf(20f, 40f).toFloatArray(), 10f)
    }
    if (borderWidth > 0) {
        val paintBorder = createPaintPolyline(
            color = borderColor ?: Color.BLACK,
            width = borderWidth + width,
            style = Paint.Style.FILL_AND_STROKE,
            pathEffect = when {
                isDottedPolyline -> pathEffect
                else -> null
            }
        )
        val insideBorder = createPaintPolyline(
            color = color,
            width = width,
            style = Paint.Style.FILL,
            pathEffect = when {
                isDottedPolyline -> pathEffect
                else -> null
            }
        )
        this.outlinePaintLists.add(MonochromaticPaintList(paintBorder))
        this.outlinePaintLists.add(MonochromaticPaintList(insideBorder))
    }else {
        outlinePaint.pathEffect = pathEffect
    }

}

fun List<Int>.toRGB(): Int = Color.rgb(first(), last(), this[1])

fun Road.toMap(
    key: String,
    routePointsEncoded: String,
    instructions: List<RoadGeoPointInstruction>
): HashMap<String, Any> {
    return HashMap<String, Any>().apply {
        this["duration"] = mDuration
        this["distance"] = mLength
        this["routePoints"] = routePointsEncoded
        this["key"] = key
        this["instructions"] = when {
            instructions.isNotEmpty() -> instructions.toMap()
            else -> emptyList()
        }
    }
}

fun ByteArray.toBitmap(): Bitmap = BitmapFactory.decodeByteArray(this, 0, this.size)
fun Bitmap.resize(scale: Double): Bitmap = Bitmap.createScaledBitmap(
    this,
    (width * scale).toInt(),
    (height * scale).toInt(),
    false
)

fun Bitmap?.toByteArray(): ByteArray? {
    if (this == null) {
        return null
    }
    val stream = ByteArrayOutputStream()
    this.compress(Bitmap.CompressFormat.PNG, 90, stream)
    return stream.toByteArray()
}

fun createPaintPolyline(
    color: Int,
    width: Float,
    style: Paint.Style,
    pathEffect: PathEffect? = null
): Paint {
    val paint = Paint()
    paint.isAntiAlias = true
    paint.strokeWidth = width
    paint.style = style
    paint.color = color
    paint.strokeCap = Paint.Cap.ROUND
    paint.strokeJoin = Paint.Join.ROUND
    paint.isAntiAlias = true
    if (pathEffect != null) {
        paint.pathEffect = pathEffect
    }

    return paint
}

fun String.toPolyline(): ArrayList<GeoPoint> {
    return PolylineEncoder.decode(this, 10, false)
}

fun List<GeoPoint>.toPolylineEncode(): String {
    return PolylineEncoder.encode(this.toCollection(ArrayList()), 10)
}
fun List<LatLng>.encodePolyline(): String {
    return PolylineEncoder.encode(this.toGeoPoints().toCollection(ArrayList()), 10)
}
fun List<Int>.toARGB():Int = Color.argb(
    Integer.parseInt(this[3].toString()),
    Integer.parseInt(this[0].toString()),
    Integer.parseInt(this[2].toString()),
    Integer.parseInt(this[1].toString()),
)