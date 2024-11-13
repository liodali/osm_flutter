package hamza.dali.flutter_osm_plugin.models

import android.graphics.Color
import hamza.dali.flutter_osm_plugin.utilities.toRGB
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.util.GeoPoint



data class RoadOption(
    val roadColor: Int? = null,
    val roadWidth: Float = 5f,
    val roadBorderWidth: Float = 5f,
    val roadBorderColor: Int? = null,
    val isDotted: Boolean = false,
)

fun HashMap<*, *>.toRoadOption(): RoadOption {
    val roadColor = when (containsKey("roadColor")) {
        true -> (this["roadColor"] as List<*>).map { it as Int }.toRGB()
        else -> Color.BLUE
    }
    val roadWidth = when (containsKey("roadWidth")) {
        true -> (this["roadWidth"] as Double).toFloat()
        else -> 5f
    }
    val roadBorderWidth = when (containsKey("roadBorderWidth")) {
        true -> (this["roadBorderWidth"] as Double).toFloat()
        else -> 0f
    }
    val roadBorderColor = when (containsKey("roadBorderColor")) {
        true -> (this["roadBorderColor"] as List<*>).filterIsInstance<Int>().toRGB()
        else -> null
    }
    val isDotted: Boolean = when (containsKey("isDotted")) {
        true -> this["isDotted"] as Boolean
        else -> false
    }
    return RoadOption(
        roadColor = roadColor,
        roadWidth = roadWidth,
        roadBorderWidth = roadBorderWidth,
        roadBorderColor = roadBorderColor,
        isDotted = isDotted,
    )
}


