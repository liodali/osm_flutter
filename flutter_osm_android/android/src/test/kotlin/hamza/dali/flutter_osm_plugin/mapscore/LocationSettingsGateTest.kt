package hamza.dali.flutter_osm_plugin.mapscore

import hamza.dali.flutter_osm_plugin.mapscore.MapSession.LocationFixListener
import hamza.dali.flutter_osm_plugin.mapscore.MapSession.LocationFixOutcome
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Ownership lifecycle of the settings round trip gate: acquire → deadline
 * (draining) → detach (draining survives configuration changes) → retry
 * (rejected) → old result drains → retry succeeds.
 */
class LocationSettingsGateTest {

    private fun listener(name: String): Pair<LocationFixListener, MutableList<String>> {
        val outcomes = mutableListOf<String>()
        return LocationFixListener { outcome ->
            when (outcome) {
                is LocationFixOutcome.Fixed -> outcomes.add("$name:fixed")
                is LocationFixOutcome.Failed -> outcomes.add("$name:${outcome.code}")
            }
        } to outcomes
    }

    @Test
    fun `request detach reattach retry old result drains and frees the gate`() {
        val gate = LocationSettingsGate()
        val (a, aOutcomes) = listener("a")
        val (b, bOutcomes) = listener("b")

        // Request A acquires the gate.
        assertTrue(gate.acquire(a))
        assertTrue(gate.occupied)
        assertSame(a, gate.current())

        // Deadline expiry: A fails but ownership keeps draining.
        val drainedA = gate.markDraining()
        assertEquals(a, drainedA)
        assertTrue(gate.occupied)
        aOutcomes += "not-fired"

        // Detach: draining ownership survives configuration changes.
        val detached = gate.detach()
        assertNull(detached)
        assertTrue(gate.occupied)

        // Reattach + retry B: rejected while the stale result is in flight.
        assertFalse(gate.acquire(b))
        assertTrue(gate.occupied)

        // The old result arrives: it drains and must not consume B.
        assertTrue(gate.drain())
        assertFalse(gate.occupied)
        assertEquals(0, bOutcomes.size)

        // Retry B now succeeds.
        assertTrue(gate.acquire(b))
        assertSame(b, gate.current())
    }

    @Test
    fun `detaching an active request fails it and keeps draining ownership`() {
        val gate = LocationSettingsGate()
        val (a, aOutcomes) = listener("a")
        val (b, bOutcomes) = listener("b")
        assertTrue(gate.acquire(a))

        // Detach during the settings round trip: A fails, but occupancy
        // keeps draining - the settings screen A opened is still out there
        // and its late result must not be consumed by a newer request.
        val detached = gate.detach()
        assertEquals(a, detached)
        assertTrue(gate.occupied)
        assertNull(gate.current())

        // Retry B during draining: rejected.
        assertFalse(gate.acquire(b))
        assertTrue(gate.occupied)

        // A's late result drains; B can then retry and succeed.
        assertTrue(gate.drain())
        assertFalse(gate.occupied)
        assertTrue(gate.acquire(b))
        assertSame(b, gate.current())
        assertEquals(0, bOutcomes.size)
    }

    @Test
    fun `double drain is a no-op`() {
        val gate = LocationSettingsGate()
        val (a, _) = listener("a")
        gate.acquire(a)
        assertNotNull(gate.markDraining())
        assertTrue(gate.drain())
        assertFalse(gate.drain())
        assertFalse(gate.occupied)
    }

    @Test
    fun `release resets draining occupancy outright`() {
        val gate = LocationSettingsGate()
        val (a, _) = listener("a")
        gate.acquire(a)
        assertNotNull(gate.markDraining())
        gate.release()
        assertFalse(gate.occupied)
        assertTrue(gate.acquire(a))
    }

    @Test
    fun `acquiring while occupied is rejected and leaves the holder intact`() {
        val gate = LocationSettingsGate()
        val (a, _) = listener("a")
        val (b, bOutcomes) = listener("b")
        assertTrue(gate.acquire(a))
        assertFalse(gate.acquire(b))
        assertSame(a, gate.current())
        assertEquals(0, bOutcomes.size)
    }
}
