package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Intent
import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test

class MapSessionRegistryTest {
    @Test
    fun `routes typed commands to the requested map only`() {
        val first = FakeMapSession(viewId = 1)
        val second = FakeMapSession(viewId = 2)
        val registry = MapSessionRegistry()
        registry.register(first)
        registry.register(second)

        registry.get(1)?.moveTo(latitude = 48.85, longitude = 2.35, animate = true)
        registry.get(2)?.addMarker(
            markerId = "marker-2",
            latitude = 40.71,
            longitude = -74.0,
        )

        assertEquals(48.85, requireNotNull(first.lastLatitude), 0.0)
        assertNull(first.lastMarkerId)
        assertEquals("marker-2", second.lastMarkerId)
        assertNull(second.lastMoveAnimation)
    }

    @Test
    fun `stale disposal cannot unregister a replacement session`() {
        val stale = FakeMapSession(viewId = 7)
        val replacement = FakeMapSession(viewId = 7)
        val registry = MapSessionRegistry()

        registry.register(stale)
        registry.unregister(stale.viewId, stale)
        registry.register(replacement)
        registry.unregister(stale.viewId, stale)

        assertSame(replacement, registry.get(replacement.viewId))
    }

    @Test
    fun `duplicate IDs do not replace the live session`() {
        val live = FakeMapSession(viewId = 3)
        val duplicate = FakeMapSession(viewId = 3)
        val registry = MapSessionRegistry()
        registry.register(live)

        assertThrows(IllegalStateException::class.java) {
            registry.register(duplicate)
        }

        assertSame(live, registry.get(live.viewId))
    }

    @Test
    fun `clear disposes every session once`() {
        val first = FakeMapSession(viewId = 1)
        val second = FakeMapSession(viewId = 2)
        val registry = MapSessionRegistry()
        registry.register(first)
        registry.register(second)

        registry.clear()

        assertEquals(1, first.disposeCount)
        assertEquals(1, second.disposeCount)
        assertEquals(0, registry.size)
    }
}

private class FakeMapSession(
    override val viewId: Int,
) : MapSession {
    var lastLatitude: Double? = null
    var lastMoveAnimation: Boolean? = null
    var lastMarkerId: String? = null
    var disposeCount = 0

    override fun setActivity(activity: Activity?) = Unit

    override fun setEventSink(sink: MapEventSink) = Unit

    override fun setZoom(zoomLevel: Double?, stepZoom: Double?) = Unit

    override fun getZoom(): Double? = null

    override fun moveTo(latitude: Double, longitude: Double, animate: Boolean) {
        lastLatitude = latitude
        lastMoveAnimation = animate
    }

    override fun addMarker(
        markerId: String,
        latitude: Double,
        longitude: Double,
        icon: ByteArray?,
    ): Boolean {
        lastMarkerId = markerId
        return true
    }

    override fun removeMarker(markerId: String): Boolean = false

    override fun dispose() {
        disposeCount += 1
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false
}
