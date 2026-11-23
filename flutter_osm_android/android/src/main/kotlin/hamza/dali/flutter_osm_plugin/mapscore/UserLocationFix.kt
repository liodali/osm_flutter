package hamza.dali.flutter_osm_plugin.mapscore

/**
 * One user-location fix as the host reported it: raw doubles with full
 * precision, unchanged from the location manager's values.
 */
internal class UserLocationFix(
    val latitude: Double,
    val longitude: Double,
    val heading: Double,
) {
    /** The legacy `receiveUserLocation` payload shape, unchanged. */
    fun toLegacyPayload(): Map<String, Any> = hashMapOf(
        "lat" to latitude,
        "lon" to longitude,
        "heading" to heading,
    )
}
