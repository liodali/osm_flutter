package hamza.dali.flutter_osm_plugin.mapscore.models

import io.openmobilemaps.mapscore.shared.graphics.common.Color
import io.openmobilemaps.mapscore.shared.map.coordinates.CoordinateConversionHelperInterface
import io.openmobilemaps.mapscore.shared.map.coordinates.Coord
import io.openmobilemaps.mapscore.shared.map.coordinates.PolygonCoord
import io.openmobilemaps.mapscore.shared.map.layers.polygon.PolygonInfo
import io.openmobilemaps.mapscore.shared.map.layers.polygon.PolygonLayerInterface
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

enum class ShapeType { CIRCLE, POLYGON }

object MapscoreColorHelper {
    fun intToColor(argb: Int): Color {
        val a = ((argb shr 24) and 0xFF) / 255.0f
        val r = ((argb shr 16) and 0xFF) / 255.0f
        val g = ((argb shr 8) and 0xFF) / 255.0f
        val b = (argb and 0xFF) / 255.0f
        return Color(r, g, b, a)
    }
}

/**
 * mapscore counterpart of [hamza.dali.flutter_osm_plugin.models.OSMShape].
 *
 * Renders a circle (approximated by a polygon) or a rectangle as a [PolygonInfo]
 * inside a shared [PolygonLayerInterface].
 */
class MapscoreShape(
    val args: HashMap<*, *>,
    private val polygonLayer: PolygonLayerInterface,
    private val helper: CoordinateConversionHelperInterface,
) {
    val key: String = args["key"] as String
    val shape: ShapeType = if (args.containsKey("radius")) ShapeType.CIRCLE else ShapeType.POLYGON
    private var polygonInfo: PolygonInfo? = null

    init {
        val lat = args["lat"]!! as Double
        val lon = args["lon"]!! as Double
        val colorRgb = args["color"] as List<*>
        val colorBorder = if (args.containsKey("colorBorder")) args["colorBorder"] as List<*> else null

        val fillArgb = argb(colorRgb)
        val borderArgb = if (colorBorder != null) argb(colorBorder) else fillArgb

        val positions: List<Coord> = when (shape) {
            ShapeType.POLYGON -> {
                val distance = args["distance"] as Double
                rectAround(lat, lon, distance)
            }
            ShapeType.CIRCLE -> {
                val radius = args["radius"] as Double
                circleAround(lat, lon, radius)
            }
        }

        val holes = ArrayList<ArrayList<Coord>>()
        val polygonCoord = PolygonCoord(ArrayList(positions), holes)
        polygonInfo = PolygonInfo(
            identifier = key,
            coordinates = polygonCoord,
            color = MapscoreColorHelper.intToColor(fillArgb),
            highlightColor = MapscoreColorHelper.intToColor(borderArgb),
        )
        polygonLayer.add(polygonInfo!!)
    }

    fun remove() {
        polygonInfo?.let { polygonLayer.remove(it) }
        polygonInfo = null
    }

    private fun circleAround(lat: Double, lon: Double, radiusMeters: Double): List<Coord> {
        val points = ArrayList<Coord>()
        val numPoints = 64
        val r = radiusMeters / 6378137.0
        val latRad = Math.toRadians(lat)
        for (i in 0 until numPoints) {
            val bearing = 2.0 * PI * i / numPoints
            val pLat = Math.asin(sin(latRad) * cos(r) + cos(latRad) * sin(r) * cos(bearing))
            val pLon = Math.toRadians(lon) + Math.atan2(
                sin(bearing) * sin(r) * cos(latRad),
                cos(r) - sin(latRad) * sin(pLat)
            )
            points.add(hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToRender(helper, Math.toDegrees(pLat), Math.toDegrees(pLon)))
        }
        return points
    }

    private fun rectAround(lat: Double, lon: Double, distanceMeters: Double): List<Coord> {
        val r = distanceMeters / 6378137.0
        val latRad = Math.toRadians(lat)
        val dLat = Math.toDegrees(r)
        val dLon = Math.toDegrees(r / cos(latRad))
        val corners = listOf(
            Pair(lat + dLat, lon - dLon),
            Pair(lat + dLat, lon + dLon),
            Pair(lat - dLat, lon + dLon),
            Pair(lat - dLat, lon - dLon),
        )
        return corners.map { (la, lo) ->
            hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToRender(helper, la, lo)
        }
    }

    private fun argb(rgb: List<*>): Int = android.graphics.Color.argb(
        Integer.parseInt(rgb[3].toString()),
        Integer.parseInt(rgb[0].toString()),
        Integer.parseInt(rgb[1].toString()),
        Integer.parseInt(rgb[2].toString()),
    )
}
