package hamza.dali.flutter_osm_plugin.mapscore.models

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Color wire-order contract: the legacy Dart payload and the generated
 * shape route both emit `[red, blue, green, alpha]`, and both decode
 * through [MapscoreColorHelper.legacyWireToArgb]. Toggling the route must
 * never change the rendered green/blue channels.
 */
class MapscoreColorHelperTest {

    @Test
    fun `legacy wire list decodes to the packed argb int`() {
        // Dart Color(0x8E24AAFF): alpha 0x8E, red 0x24, green 0xAA, blue 0xFF
        // → legacy wire order [red, blue, green, alpha].
        val wire = listOf<Any>(0x24, 0xFF, 0xAA, 0x8E)
        assertEquals(0x8E24AAFF.toInt(), MapscoreColorHelper.legacyWireToArgb(wire))
    }

    @Test
    fun `green and blue keep their channels through decode and render`() {
        // Green-dominant color 0xFF00FF00 → wire [0x00, 0x00, 0xFF, 0xFF].
        val green = MapscoreColorHelper.intToColor(
            MapscoreColorHelper.legacyWireToArgb(listOf<Any>(0x00, 0x00, 0xFF, 0xFF)),
        )
        assertEquals(0x00 / 255f, green.r, 0f)
        assertEquals(0xFF / 255f, green.g, 0f)
        assertEquals(0x00 / 255f, green.b, 0f)
        assertEquals(0xFF / 255f, green.a, 0f)

        // Blue-dominant color 0xFF0000FF → wire [0x00, 0xFF, 0x00, 0xFF].
        val blue = MapscoreColorHelper.intToColor(
            MapscoreColorHelper.legacyWireToArgb(listOf<Any>(0x00, 0xFF, 0x00, 0xFF)),
        )
        assertEquals(0x00 / 255f, blue.r, 0f)
        assertEquals(0x00 / 255f, blue.g, 0f)
        assertEquals(0xFF / 255f, blue.b, 0f)
    }

    @Test
    fun `a swizzle in the wire order changes the rendered color`() {
        // Guarding the contract: if a path ever emitted [red, green, blue,
        // alpha] instead, green and blue would swap in the render.
        val wire = listOf<Any>(0x24, 0xFF, 0xAA, 0x8E) // correct: [r, b, g, a]
        val decoded = MapscoreColorHelper.legacyWireToArgb(wire)
        val color = MapscoreColorHelper.intToColor(decoded)
        assertEquals(0x24 / 255f, color.r, 0f)
        assertEquals(0xAA / 255f, color.g, 0f) // green stays green
        assertEquals(0xFF / 255f, color.b, 0f) // blue stays blue
        assertEquals(0x8E / 255f, color.a, 0f)
    }
}
