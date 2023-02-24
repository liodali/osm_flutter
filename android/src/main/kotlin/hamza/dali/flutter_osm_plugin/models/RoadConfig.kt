package hamza.dali.flutter_osm_plugin.models

import hamza.dali.flutter_osm_plugin.utilities.toRGB
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.util.GeoPoint

data class RoadConfig(
    val wayPoints: List<GeoPoint>,
    val interestPoints: List<GeoPoint>,
    val meanUrl: String = OSRMRoadManager.MEAN_BY_CAR,
    val roadColor: Int? = null,
    val roadWidth: Float = 5f,
    val roadBorderWidth: Float = 5f,
    val roadBorderColor: Int? = null,
    val roadID: String,
)


fun HashMap<String, Any>.toRoadConfig(): RoadConfig {
    val roadId = this["key"] as String
    val roadColor = (this["roadColor"] as List<Int>).toRGB()
    val roadWidth = (this["roadWidth"] as Double).toFloat()
    val roadBorderWidth = (this["roadBorderWidth"] as Double).toFloat()
    val roadBorderColor = (this["roadBorderColor"] as List<Int>).toRGB()


    return RoadConfig(
        roadID = roadId,
        roadColor = roadColor,
        roadWidth = roadWidth,
        roadBorderWidth = roadBorderWidth,
        roadBorderColor = roadBorderColor,
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
