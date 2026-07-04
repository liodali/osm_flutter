package hamza.dali.flutter_osm_plugin.mapscore.utilities

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.drawable.Drawable
import android.provider.Settings
import androidx.core.graphics.drawable.toDrawable
import io.openmobilemaps.mapscore.shared.map.coordinates.CoordinateConversionHelperInterface
import io.openmobilemaps.mapscore.shared.map.coordinates.CoordinateSystemIdentifiers
import io.openmobilemaps.mapscore.shared.map.coordinates.Coord
import io.openmobilemaps.mapscore.shared.map.coordinates.RectCoord
import java.io.ByteArrayOutputStream

/** Build a WGS84 (EPSG:4326) coord. mapscore stores lon in x and lat in y. */
fun latLonToCoord(lat: Double, lon: Double): Coord =
    Coord(CoordinateSystemIdentifiers.EPSG4326(), lon, lat, 0.0)

/** Convert a lat/lon pair into the map render system (EPSG:3857) using the map helper. */
fun latLonToRender(helper: CoordinateConversionHelperInterface, lat: Double, lon: Double): Coord =
    helper.convertToRenderSystem(latLonToCoord(lat, lon))

/** Convert a render-system coord back to (lat, lon). */
fun Coord.toLatLon(helper: CoordinateConversionHelperInterface): Pair<Double, Double> {
    val c = helper.convert(CoordinateSystemIdentifiers.EPSG4326(), this)
    return c.y to c.x
}

fun Coord.toHashMap(helper: CoordinateConversionHelperInterface): HashMap<String, Double> {
    val (lat, lon) = toLatLon(helper)
    return HashMap<String, Double>().apply {
        this[MapscoreConstants.latLabel] = lat
        this[MapscoreConstants.lonLabel] = lon
    }
}

fun Coord.eq(other: Coord): Boolean = this.x == other.x && this.y == other.y && this.systemIdentifier == other.systemIdentifier

fun HashMap<String, Double>.toLatLon(): Pair<Double, Double> {
    if (containsKey("lat") && containsKey("lon")) {
        return this["lat"]!! to this["lon"]!!
    }
    throw IllegalArgumentException("cannot map this hashMap to lat/lon")
}

/** RectCoord (render system) -> {north,east,south,west} in lat/lon. */
fun RectCoord.toHashMap(helper: CoordinateConversionHelperInterface): HashMap<String, Double> {
    val (nLat, wLon) = topLeft.toLatLon(helper)
    val (sLat, eLon) = bottomRight.toLatLon(helper)
    return HashMap<String, Double>().apply {
        this["north"] = maxOf(nLat, sLat)
        this["south"] = minOf(nLat, sLat)
        this["east"] = maxOf(eLon, wLon)
        this["west"] = minOf(eLon, wLon)
    }
}

fun openSettingLocation(requestCode: Int, activity: Activity?) {
    val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
    activity?.startActivityForResult(intent, requestCode)
}

fun List<Int>.toRGB(): Int = Color.rgb(first(), last(), this[1])

fun ByteArray.toBitmap(): Bitmap = BitmapFactory.decodeByteArray(this, 0, this.size)

fun Bitmap?.toByteArray(): ByteArray? {
    if (this == null) return null
    val stream = ByteArrayOutputStream()
    this.compress(Bitmap.CompressFormat.PNG, 100, stream)
    return stream.toByteArray()
}

fun Bitmap.rotate(angleDeg: Float): Bitmap {
    val matrix = Matrix()
    matrix.postRotate(angleDeg)
    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
}

fun Bitmap.scaleBy(density: Float): Bitmap {
    val matrix = Matrix()
    matrix.postScale(density, density)
    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, false)
}

fun Bitmap.toDrawableCompat(resources: android.content.res.Resources): Drawable = this.toDrawable(resources)

fun screenDensity(context: android.content.Context): Float =
    context.resources.displayMetrics.density

/**
 * Decode an encoded polyline (Google polyline algorithm) into a list of [Double] pairs
 * (lat, lon). [precision] is the coordinate precision (5 for the standard Google/OSRM
 * `polyline` format, 6 for `polyline6`).
 */
fun decodePolyline(encoded: String, precision: Int): List<Pair<Double, Double>> {
    val result = ArrayList<Pair<Double, Double>>()
    val factor = Math.pow(10.0, precision.toDouble())
    var index = 0
    var lat = 0
    var lng = 0
    while (index < encoded.length) {
        var b: Int
        var shift = 0
        var resultLat = 0
        do {
            b = encoded[index++].code - 63
            resultLat = resultLat or ((b and 0x1f) shl shift)
            shift += 5
        } while (b >= 0x20)
        val dLat = if ((resultLat and 1) == 1) (resultLat shr 1).inv() else resultLat shr 1
        lat += dLat

        shift = 0
        var resultLng = 0
        do {
            b = encoded[index++].code - 63
            resultLng = resultLng or ((b and 0x1f) shl shift)
            shift += 5
        } while (b >= 0x20)
        val dLng = if ((resultLng and 1) == 1) (resultLng shr 1).inv() else resultLng shr 1
        lng += dLng

        result.add(lat / factor to lng / factor)
    }
    return result
}
