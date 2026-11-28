package hamza.dali.flutter_osm_plugin.mapscore

/**
 * One visible-region change as the host reported it: the already converted
 * bounding box and center maps (the exact legacy payload objects) plus the
 * zoom level in the camera family's `getZoom` units. The center is null
 * only when the camera could not provide one, which the legacy plane
 * carried as a null `center` and the typed route cannot express.
 */
internal class RegionChange(
    val bounding: Map<String, Double>,
    val center: Map<String, Double>?,
    val zoom: Double,
) {
    /** The legacy `receiveRegionIsChanging` payload shape, unchanged. */
    fun toLegacyPayload(): Map<String, Any?> = hashMapOf(
        "bounding" to bounding,
        "center" to center,
    )
}
