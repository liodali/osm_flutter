package hamza.dali.flutter_osm_plugin.mapscore.models

/**
 * mapscore counterpart of [hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint].
 *
 * Stores a geographic position as plain lat/lon (independent of any map engine) plus
 * the rendering metadata (angle, anchor, icon bytes) that the marker layer needs.
 */
data class MapscoreGeoPoint(
    val lat: Double,
    val lon: Double,
    val angle: Double = 0.0,
    val anchor: Anchor? = null,
    val icon: ByteArray? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as MapscoreGeoPoint
        return lat == other.lat && lon == other.lon
    }

    override fun hashCode(): Int {
        var result = lat.hashCode()
        result = 31 * result + lon.hashCode()
        return result
    }
}
