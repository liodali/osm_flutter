package hamza.dali.flutter_osm_plugin.models

import org.osmdroid.util.GeoPoint

data class FlutterGeoPoint(
    val geoPoint: GeoPoint,
    val angle: Double = 0.0,
    val anchor: Anchor? = null,
    val icon: ByteArray? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as FlutterGeoPoint

        if (geoPoint != other.geoPoint) return false

        return true
    }

    override fun hashCode(): Int {
        var result = geoPoint.hashCode()
        return result
    }
}