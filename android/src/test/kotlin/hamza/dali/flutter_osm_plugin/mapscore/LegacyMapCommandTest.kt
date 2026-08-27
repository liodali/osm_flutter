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
    fun `keeps typed fallback names separate from legacy names`() {
        val expectedNames = setOf(
            "android#camera#zoom",
            "android#camera#rotation",
            "android#marker#add",
            "android#marker#addAll",
            "android#marker#icon",
            "android#marker#remove",
            "android#marker#removeAll",
            "android#shape#circle",
            "android#shape#rectangle",
            "android#shape#remove",
            "android#shape#clear",
            "android#static#set",
            "android#static#remove",
            "android#road#draw",
            "android#road#remove",
            "android#road#clear",
            "android#tile#set",
            "android#layer#visibility",
        )

        assertEquals(expectedNames, TypedMapCommand.values().map { it.methodName }.toSet())
        expectedNames.forEach { methodName ->
            assertEquals(methodName, TypedMapCommand.fromMethodName(methodName)?.methodName)
            assertNull(LegacyMapCommand.fromMethodName(methodName))
        }
    }

    @Test
    fun `does not decode unknown methods`() {
        assertNull(LegacyMapCommand.fromMethodName("unknown#method"))
        assertNull(TypedMapCommand.fromMethodName("unknown#method"))
    }
}
