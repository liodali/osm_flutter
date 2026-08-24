package hamza.dali.flutter_osm_plugin.mapscore

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LegacyMapCommandTest {
    @Test
    fun `preserves legacy method names`() {
        val expectedNames = setOf(
            "change#tile",
            "use#visiblityInfoWindow",
            "config#Zoom",
            "Zoom",
            "get#Zoom",
            "change#stepZoom",
            "zoomToRegion",
            "showZoomController",
            "currentLocation",
            "initMap",
            "limitArea",
            "remove#limitArea",
            "changePosition",
            "trackMe",
            "deactivateTrackMe",
            "startLocationUpdating",
            "stopLocationUpdating",
            "map#center",
            "map#bounds",
            "user#position",
            "moveTo#position",
            "user#removeMarkerPosition",
            "delete#road",
            "draw#multi#road",
            "clear#roads",
            "marker#icon",
            "drawRoad#manually",
            "staticPosition",
            "staticPosition#IconMarker",
            "draw#circle",
            "draw#rect",
            "remove#circle",
            "remove#rect",
            "clear#shapes",
            "map#orientation",
            "user#locationMarkers",
            "add#Marker",
            "update#Marker",
            "change#Marker",
            "get#geopoints",
            "delete#markers",
            "toggle#Alllayer",
        )

        assertEquals(expectedNames, LegacyMapCommand.values().map { it.methodName }.toSet())
        expectedNames.forEach { methodName ->
            assertEquals(methodName, LegacyMapCommand.fromMethodName(methodName)?.methodName)
        }
    }

    @Test
    fun `does not decode unknown methods`() {
        assertNull(LegacyMapCommand.fromMethodName("unknown#method"))
    }
}
