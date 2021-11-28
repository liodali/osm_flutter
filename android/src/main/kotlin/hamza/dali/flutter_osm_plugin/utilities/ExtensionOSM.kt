package hamza.dali.flutter_osm_plugin.utilities

import hamza.dali.flutter_osm_plugin.Constants
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint

fun GeoPoint.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this[Constants.latLabel] = latitude
        this[Constants.lonLabel] = longitude
    }

}

fun GeoPoint.eq(other: GeoPoint): Boolean {
    return this.latitude == other.latitude && this.longitude == other.longitude
}

fun HashMap<String, Double>.toGeoPoint(): GeoPoint {
    if (this.keys.contains("lat") && this.keys.contains("lon")) {
        return GeoPoint(this["lat"]!!, this["lon"]!!)
    }
    throw IllegalArgumentException("cannot map this hashMap to GeoPoint")

}

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