package hamza.dali.flutter_osm_plugin.mapscore

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The legacy `trackMe` anchor slot: an omitted anchor must stay "no
 * override" so the pivots the icon route applied (typed icons + legacy
 * tracking) are never re-centered by the historical default.
 */
class LegacyTrackMeArgumentsTest {

    @Test
    fun `an omitted anchor means no override`() {
        assertNull(LegacyTrackMeArguments.anchor(listOf(true, false, true, null)))
        // Older payloads with a short list keep the legacy protocol shape.
        assertNull(LegacyTrackMeArguments.anchor(listOf(true, false, true)))
        assertNull(LegacyTrackMeArguments.anchor(emptyList<Any?>()))
    }

    @Test
    fun `a supplied anchor is decoded`() {
        assertEquals(
            listOf(0.5, 1.0),
            LegacyTrackMeArguments.anchor(listOf(false, false, true, listOf(0.5, 1.0))),
        )
    }

    @Test
    fun `malformed anchors fall back to no override`() {
        assertNull(LegacyTrackMeArguments.anchor(listOf(false, false, true, "center")))
        assertNull(LegacyTrackMeArguments.anchor(listOf(false, false, true, listOf(0.5))))
        assertNull(LegacyTrackMeArguments.anchor(listOf(false, false, true, listOf("a", "b"))))
    }
}
