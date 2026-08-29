package hamza.dali.flutter_osm_plugin.mapscore

import hamza.dali.flutter_osm_plugin.mapscore.utilities.MapscoreConstants

internal data class LocationActivityRequestCodes(
    val getUserLocation: Int,
    val currentUserLocation: Int,
) {
    companion object {
        fun forViewId(viewId: Int): LocationActivityRequestCodes {
            val offset = (viewId and 0x3fff) * 2
            return LocationActivityRequestCodes(
                getUserLocation = MapscoreConstants.getUserLocationReqCode + offset,
                currentUserLocation = MapscoreConstants.currentUserLocationReqCode + offset,
            )
        }
    }
}
