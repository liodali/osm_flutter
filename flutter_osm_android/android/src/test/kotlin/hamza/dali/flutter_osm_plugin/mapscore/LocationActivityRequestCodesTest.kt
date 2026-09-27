package hamza.dali.flutter_osm_plugin.mapscore

import hamza.dali.flutter_osm_plugin.mapscore.utilities.MapscoreConstants
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationActivityRequestCodesTest {
    @Test
    fun `assigns both legacy base codes to view zero`() {
        val codes = LocationActivityRequestCodes.forViewId(0)

        assertEquals(MapscoreConstants.getUserLocationReqCode, codes.getUserLocation)
        assertEquals(MapscoreConstants.currentUserLocationReqCode, codes.currentUserLocation)
    }

    @Test
    fun `keeps location result ownership isolated by view`() {
        val first = LocationActivityRequestCodes.forViewId(3)
        val second = LocationActivityRequestCodes.forViewId(4)

        assertNotEquals(first.getUserLocation, second.getUserLocation)
        assertNotEquals(first.currentUserLocation, second.currentUserLocation)
        assertNotEquals(first.getUserLocation, second.currentUserLocation)
        assertNotEquals(first.currentUserLocation, second.getUserLocation)
    }

    @Test
    fun `allocates distinct valid codes across encoded view range`() {
        val codes = (0..0x3fff).flatMap { viewId ->
            LocationActivityRequestCodes.forViewId(viewId).let {
                listOf(it.getUserLocation, it.currentUserLocation)
            }
        }

        assertEquals(codes.size, codes.toSet().size)
        assertTrue(codes.all { it in 0..0xffff })
    }
}
