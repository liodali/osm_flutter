package hamza.dali.flutter_osm_plugin.mapscore

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Lifecycle route resolution and restoration buffering: restoration can
 * arrive before the attach-time route selection (activity recreation races
 * view creation), and JNI/opt-out attachments never negotiate at all. Held
 * restoration is delivered exactly once on the resolved typed route; the
 * legacy plane keeps its historical no-restoration behavior.
 */
class LifecycleEventRouteTest {

    private class Recorder {
        var emissions = 0
        val route = LifecycleEventRoute { emissions++ }
    }

    @Test
    fun `restoration before pigeon selection is delivered once on selection`() {
        val recorder = Recorder()
        recorder.route.restored()
        assertEquals(0, recorder.emissions)

        recorder.route.select(usePigeon = true)
        assertEquals(1, recorder.emissions)
        assertTrue(recorder.route.usePigeon)

        // The held restoration was consumed: later readiness never re-emits.
        recorder.route.notifyReadiness()
        assertEquals(1, recorder.emissions)
    }

    @Test
    fun `restoration before legacy selection is dropped (legacy parity)`() {
        val recorder = Recorder()
        recorder.route.restored()
        recorder.route.select(usePigeon = false)
        assertEquals(0, recorder.emissions)
        assertFalse(recorder.route.usePigeon)
    }

    @Test
    fun `first readiness resolves the implicit legacy route for never-negotiating attachments`() {
        val recorder = Recorder()
        recorder.route.restored()
        // JNI/opt-out attachments never select: readiness resolves legacy.
        recorder.route.notifyReadiness()
        assertEquals(0, recorder.emissions)

        // Restoration after resolution stays on the (legacy) route: dropped.
        recorder.route.restored()
        assertEquals(0, recorder.emissions)
    }

    @Test
    fun `restoration after pigeon selection delivers immediately`() {
        val recorder = Recorder()
        recorder.route.select(usePigeon = true)
        assertEquals(0, recorder.emissions)

        recorder.route.restored()
        assertEquals(1, recorder.emissions)
        recorder.route.restored()
        assertEquals(2, recorder.emissions)
    }

    @Test
    fun `repeated pre-negotiation restoration coalesces to one delivery`() {
        val recorder = Recorder()
        recorder.route.restored()
        recorder.route.restored()
        recorder.route.restored()
        recorder.route.select(usePigeon = true)
        assertEquals(1, recorder.emissions)
    }

    @Test
    fun `readiness without held restoration never emits`() {
        val recorder = Recorder()
        recorder.route.notifyReadiness()
        recorder.route.select(usePigeon = true)
        recorder.route.notifyReadiness()
        assertEquals(0, recorder.emissions)
    }

    @Test
    fun `late pigeon selection after implicit legacy resolution switches the route`() {
        val recorder = Recorder()
        recorder.route.restored()
        recorder.route.notifyReadiness() // implicit legacy: held restore dropped
        assertEquals(0, recorder.emissions)

        // A late selection still switches delivery (defined behavior), but
        // the consumed restoration is not replayed.
        recorder.route.select(usePigeon = true)
        assertEquals(0, recorder.emissions)
        recorder.route.restored()
        assertEquals(1, recorder.emissions)
    }
}
