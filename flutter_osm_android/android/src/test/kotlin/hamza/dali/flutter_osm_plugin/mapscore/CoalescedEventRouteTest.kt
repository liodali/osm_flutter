package hamza.dali.flutter_osm_plugin.mapscore

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Coalesced event route dispatch behind the event coalescer, driven with
 * user-location fixes: the generated route inherits the legacy plane's
 * rate and newest-wins coalescing (same interval, one coalescing state),
 * every flushed payload goes to exactly one route, and the legacy payload
 * shape is unchanged.
 */
class CoalescedEventRouteTest {

    private val legacy = mutableListOf<Map<String, Any>>()
    private val typed = mutableListOf<UserLocationFix>()
    private val scheduler = FakeMapEventScheduler()

    private fun coalescer(route: CoalescedEventRoute<UserLocationFix>) = MapEventCoalescer(
        intervalsMillis = mapOf("receiveUserLocation" to 1_000L),
        clockMillis = scheduler::now,
        scheduler = scheduler,
        emitter = { _, arguments -> route.emit(arguments as UserLocationFix) },
    )

    private fun route(usePigeon: Boolean = false): CoalescedEventRoute<UserLocationFix> =
        CoalescedEventRoute<UserLocationFix>(
            emitLegacy = { fix -> legacy += fix.toLegacyPayload() },
            emitTyped = { fix -> typed += fix },
        ).apply { select(usePigeon) }

    private fun fix(lat: Double) = UserLocationFix(lat, longitude = -1.0, heading = 90.0)

    @Test
    fun `default route keeps the legacy payload shape`() {
        route().emit(fix(47.5))

        assertEquals(listOf(mapOf("lat" to 47.5, "lon" to -1.0, "heading" to 90.0)), legacy)
        assertTrue(typed.isEmpty())
    }

    @Test
    fun `pigeon route delivers raw fixes to the typed plane only`() {
        route(usePigeon = true).emit(fix(47.218071429999996))

        assertTrue(legacy.isEmpty())
        assertEquals(1, typed.size)
        assertEquals(47.218071429999996, typed.single().latitude, 0.0)
        assertEquals(-1.0, typed.single().longitude, 0.0)
        assertEquals(90.0, typed.single().heading, 0.0)
    }

    @Test
    fun `the typed route sits behind the same coalescer interval`() {
        val coalescer = coalescer(route(usePigeon = true))
        coalescer.emit("receiveUserLocation", fix(1.0))
        scheduler.advanceBy(200)
        coalescer.emit("receiveUserLocation", fix(2.0))
        scheduler.advanceBy(200)
        coalescer.emit("receiveUserLocation", fix(3.0))

        // First immediately, then only the newest payload once the
        // interval elapsed — identical to the legacy plane's behavior.
        assertEquals(listOf(1.0), typed.map(UserLocationFix::latitude))
        scheduler.advanceBy(599)
        assertEquals(listOf(1.0), typed.map(UserLocationFix::latitude))
        scheduler.advanceBy(1)
        assertEquals(listOf(1.0, 3.0), typed.map(UserLocationFix::latitude))
        assertTrue(legacy.isEmpty())
    }

    @Test
    fun `the legacy plane observes the same rate`() {
        val coalescer = coalescer(route())
        coalescer.emit("receiveUserLocation", fix(1.0))
        scheduler.advanceBy(200)
        coalescer.emit("receiveUserLocation", fix(2.0))
        scheduler.advanceBy(800)

        assertEquals(listOf(1.0, 2.0), legacy.map { it["lat"] })
        assertTrue(typed.isEmpty())
    }

    @Test
    fun `every flushed fix goes to exactly one route`() {
        val coalescer = coalescer(route(usePigeon = true))
        val legacyCoalescer = coalescer(route())
        repeat(5) { coalescer.emit("receiveUserLocation", fix(it.toDouble())) }
        repeat(5) { legacyCoalescer.emit("receiveUserLocation", fix(10.0 + it)) }

        assertEquals(1, typed.size)
        assertEquals(1, legacy.size)
        scheduler.advanceBy(1_000)
        assertEquals(listOf(0.0, 4.0), typed.map(UserLocationFix::latitude))
        assertEquals(listOf(10.0, 14.0), legacy.map { it["lat"] })
    }

    @Test
    fun `selection freezes the route and a rollback restores legacy`() {
        val subject = route()
        assertFalse(subject.usePigeon)
        subject.select(usePigeon = true)
        assertTrue(subject.usePigeon)
        subject.emit(fix(1.0))
        subject.select(usePigeon = false)
        subject.emit(fix(2.0))

        assertEquals(listOf(1.0), typed.map(UserLocationFix::latitude))
        assertEquals(listOf(2.0), legacy.map { it["lat"] })
    }
}
