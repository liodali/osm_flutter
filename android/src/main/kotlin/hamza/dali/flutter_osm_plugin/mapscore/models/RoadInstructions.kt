package hamza.dali.flutter_osm_plugin.mapscore.models

data class RoadGeoPointInstruction(
    val instruction: String,
    val lat: Double,
    val lon: Double,
)

fun RoadGeoPointInstruction.toMap(): HashMap<String, Any> {
    val map = HashMap<String, Any>()
    map["instruction"] = instruction
    val geo = HashMap<String, Double>()
    geo["lat"] = lat
    geo["lon"] = lon
    map["geoPoint"] = geo
    return map
}

fun List<RoadGeoPointInstruction>.toMap(): List<HashMap<String, Any>> = this.map { it.toMap() }
