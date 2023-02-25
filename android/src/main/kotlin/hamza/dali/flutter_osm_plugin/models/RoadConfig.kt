package hamza.dali.flutter_osm_plugin.models

import android.graphics.Color
import hamza.dali.flutter_osm_plugin.utilities.toRGB
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.util.GeoPoint

data class RoadConfig(
    val wayPoints: List<GeoPoint>,
    val interestPoints: List<GeoPoint>,
    val meanUrl: String = OSRMRoadManager.MEAN_BY_CAR,
    val roadOption: RoadOption,
    val roadID: String,
)

data class RoadOption(
    val roadColor: Int? = null,
    val roadWidth: Float = 5f,
    val roadBorderWidth: Float = 5f,
    val roadBorderColor: Int? = null,
)

fun HashMap<String, Any>.toRoadOption(): RoadOption {
    val roadColor = when(this.containsKey("roadColor")){
        true -> (this["roadColor"] as List<Int>).toRGB()
        else ->  Color.BLUE
    }
    val roadWidth = when ( this.containsKey("roadWidth")){
        true -> (this["roadWidth"] as Double).toFloat()
        else ->  5f
    }
    val roadBorderWidth = when ( this.containsKey("roadBorderWidth")){
        true -> (this["roadBorderWidth"] as Double).toFloat()
        else -> 0f
    }
    val roadBorderColor = when ( this.containsKey("roadBorderColor")){
        true -> (this["roadBorderColor"] as List<Int>).toRGB()
        else -> null
    }
    return RoadOption(
        roadColor = roadColor,
        roadWidth = roadWidth,
        roadBorderWidth = roadBorderWidth,
        roadBorderColor = roadBorderColor,
    )
}

fun HashMap<String, Any>.toRoadConfig(): RoadConfig {
    val roadId = when (this.containsKey("key")) {
        true -> this["key"] as String
        else -> ""
    }
    return RoadConfig(
        roadID = roadId,
        roadOption = this.toRoadOption(),
        wayPoints = when {
            this.containsKey("wayPoints") -> (this["wayPoints"] as List<HashMap<String, Double>>)
                .map { g ->
                    GeoPoint(g["lat"]!!, g["lon"]!!)
                }.toList()
            this.containsKey("road") -> PolylineEncoder.decode(
                (this["road"] as String),
                10,
                false
            )
            else -> emptyList()
        },
        interestPoints = when {
            this.containsKey("middlePoints") -> (this["middlePoints"] as List<HashMap<String, Double>>)
                .map { g ->
                    GeoPoint(g["lat"]!!, g["lon"]!!)
                }.toList()
            else -> emptyList()
        },
    )
}
