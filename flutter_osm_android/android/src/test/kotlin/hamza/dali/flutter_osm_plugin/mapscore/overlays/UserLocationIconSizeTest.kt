package hamza.dali.flutter_osm_plugin.mapscore.overlays

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Display-size resolution for the user-location icons: the Dart capture is
 * logical (pre-scale), so the host must multiply it by the display density
 * instead of drawing the raw PNG pixels — otherwise a device-pixel-ratio
 * capture renders oversized.
 */
class UserLocationIconSizeTest {
    @Test
    fun `logical sizes scale with the display density`() {
        assertEquals(36 to 60, CustomLocationManager.targetIconSize(listOf(12, 20), 3f))
        assertEquals(24 to 40, CustomLocationManager.targetIconSize(listOf(12, 20), 2f))
        assertEquals(12 to 20, CustomLocationManager.targetIconSize(listOf(12, 20), 1f))
    }

    @Test
    fun `fractional densities round to whole pixels`() {
        assertEquals(33 to 55, CustomLocationManager.targetIconSize(listOf(12, 20), 2.75f))
    }

    @Test
    fun `absent or unusable sizes keep the bitmap pixels`() {
        assertNull(CustomLocationManager.targetIconSize(null, 3f))
        assertNull(CustomLocationManager.targetIconSize(listOf(12), 3f))
        assertNull(CustomLocationManager.targetIconSize(emptyList(), 3f))
        assertNull(CustomLocationManager.targetIconSize(listOf(0, 20), 3f))
        assertNull(CustomLocationManager.targetIconSize(listOf(12, 0), 3f))
        assertNull(CustomLocationManager.targetIconSize(listOf(-4, 20), 3f))
        assertNull(CustomLocationManager.targetIconSize(listOf(12, 20), 0f))
    }
}
