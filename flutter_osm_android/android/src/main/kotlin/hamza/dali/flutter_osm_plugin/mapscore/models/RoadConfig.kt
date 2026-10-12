package hamza.dali.flutter_osm_plugin.mapscore.models

import android.graphics.Color
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toRGB

enum class MeanOfTransport(val profile: String) {
    CAR("driving"),
    BIKE("cycling"),
    FOOT("foot");

    companion object {
        fun fromKey(key: String): MeanOfTransport = when (key) {
            "car" -> CAR
            "bike" -> BIKE
            "foot" -> FOOT
            else -> CAR
        }
    }
}

data class RoadConfig(
    val wayPoints: List<Pair<Double, Double>>,
    val interestPoints: List<Pair<Double, Double>>,
    val mean: MeanOfTransport = MeanOfTransport.CAR,
    val roadOption: RoadOption,
    val roadID: String,
)

data class RoadOption(
    val roadColor: Int? = null,
    val roadWidth: Float = 5f,
    val roadBorderWidth: Float = 5f,
    val roadBorderColor: Int? = null,
    val isDotted: Boolean = false,
)

fun HashMap<String, Any>.toRoadOptionMapscore(): RoadOption {
    val roadColor = if (containsKey("roadColor")) {
        (this["roadColor"] as List<*>).filterIsInstance<Int>().toRGB()
    } else {
        Color.BLUE
    }
    val roadWidth = if (containsKey("roadWidth")) (this["roadWidth"] as Double).toFloat() else 5f
    val roadBorderWidth = if (containsKey("roadBorderWidth")) (this["roadBorderWidth"] as Double).toFloat() else 0f
    val roadBorderColor = if (containsKey("roadBorderColor")) {
        (this["roadBorderColor"] as List<*>).filterIsInstance<Int>().toRGB()
    } else {
        null
    }
    val isDotted = if (containsKey("isDotted")) this["isDotted"] as Boolean else false
    return RoadOption(
        roadColor = roadColor,
        roadWidth = roadWidth,
        roadBorderWidth = roadBorderWidth,
        roadBorderColor = roadBorderColor,
        isDotted = isDotted,
    )
}

fun HashMap<String, Any>.toRoadConfigMapscore(): RoadConfig {
    val roadId = if (containsKey("key")) this["key"] as String else ""
    return RoadConfig(
        roadID = roadId,
        roadOption = toRoadOptionMapscore(),
        wayPoints = if (containsKey("wayPoints")) {
            (this["wayPoints"] as List<HashMap<String, Double>>).map { it["lat"]!! to it["lon"]!! }
        } else {
            emptyList()
        },
        interestPoints = if (containsKey("middlePoints")) {
            (this["middlePoints"] as List<HashMap<String, Double>>).map { it["lat"]!! to it["lon"]!! }
        } else {
            emptyList()
        },
    )
}
