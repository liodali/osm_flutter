package hamza.dali.flutter_osm_plugin.models

import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import org.osmdroid.bonuspack.routing.RoadNode
import org.osmdroid.util.GeoPoint

data class RoadGeoPointInstruction(
    val instruction: String,
    val geoPoint: GeoPoint
)

fun RoadGeoPointInstruction.toMap(): HashMap<String, Any> {
    val map = HashMap<String, Any>()
    map["instruction"] = instruction
    map["geoPoint"] = geoPoint.toHashMap()
    return map
}

fun List<RoadGeoPointInstruction>.toMap(): List<HashMap<String, Any>> {
    return this.map {
        it.toMap()
    }
}

fun RoadNode.toInstruction(): RoadGeoPointInstruction = RoadGeoPointInstruction(
    instruction = mInstructions,
    geoPoint = mLocation
)

fun List<RoadNode>.toRoadInstruction(): List<RoadGeoPointInstruction> {
    return this.filter { node ->
        node.mInstructions != null
    }.map { node ->
        node.toInstruction()
    }
}