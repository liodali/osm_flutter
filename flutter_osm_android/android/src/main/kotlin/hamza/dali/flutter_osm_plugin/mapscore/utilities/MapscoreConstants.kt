package hamza.dali.flutter_osm_plugin.mapscore.utilities

import io.openmobilemaps.mapscore.shared.graphics.common.Color
import kotlin.math.roundToInt

/**
 * Constants and conversion helpers for the mapscore-based implementation.
 *
 * mapscore (openmobilemaps) uses a discrete set of zoom levels. The table below
 * mirrors the one in the Swift OSMTileConfiguration so the Android camera zoom
 * values match the iOS layer zoom values exactly. osmdroid fractional zoom levels
 * are snapped to the nearest table identifier.
 */
object MapscoreConstants {
    const val shapesNames: String = "static_shapes"
    const val roadName: String = "Dynamic-Road"
    const val markerNameOverlay: String = "Markers"
    const val latLabel: String = "lat"
    const val lonLabel: String = "lon"
    const val zoomMyLocation: Double = 15.0
    const val stepZoom: Double = 1.0
    const val unavailableAddress = "unvailable addresse"
    const val STARTPOSITIONROAD = "START"
    const val MIDDLEPOSITIONROAD = "MIDDLE"
    const val ENDPOSITIONROAD = "END"
    const val nameFolderStatic = "staticPositionGeoPoint"

    const val getUserLocationReqCode = 200
    const val currentUserLocationReqCode = 201

    // Discrete zoom table matching the Swift OSMTileConfiguration.getZoomLevelInfos()
    // mapscore zoom values for OSM zoom identifiers 0..19.
    private val ZOOM_LEVELS = listOf(
        559082264.029,
        279541132.015,
        139770566.007,
        69885283.0036,
        34942641.5018,
        17471320.7509,
        8735660.37545,
        4367830.18773,
        2183915.09386,
        1091957.54693,
        545978.773466,
        272989.386733,
        136494.693366,
        68247.3466832,
        34123.6733416,
        17061.8366708,
        8530.91833540,
        4265.45916770,
        2132.72958385,
        1066.36479193,
    )

    enum class PositionMarker { START, MIDDLE, END }

    /** Convert an osmdroid fractional zoom level to a mapscore camera zoom value. */
    fun osmZoomToMapscore(osmZoom: Double): Double {
        val index = osmZoom.roundToInt().coerceIn(0, ZOOM_LEVELS.size - 1)
        return ZOOM_LEVELS[index]
    }

    /** Convert a mapscore camera zoom value back to an osmdroid zoom level identifier. */
    fun mapscoreToOsmZoom(zoom: Double): Double {
        if (zoom <= 0.0) return ZOOM_LEVELS.size - 1.0
        val identifiers = ZOOM_LEVELS
            .mapIndexedNotNull { index, levelZoom ->
                if (zoom >= levelZoom) index else null
            }
        return (identifiers.minOrNull() ?: ZOOM_LEVELS.size - 1).toDouble()
    }

    /** Convert an Android ARGB int color to a mapscore [Color] (0..1 floats). */
    fun intToColor(argb: Int): Color {
        val a = ((argb shr 24) and 0xFF) / 255.0f
        val r = ((argb shr 16) and 0xFF) / 255.0f
        val g = ((argb shr 8) and 0xFF) / 255.0f
        val b = (argb and 0xFF) / 255.0f
        return Color(r, g, b, a)
    }
}
