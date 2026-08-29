package hamza.dali.flutter_osm_plugin.mapscore.overlays

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ResumableLocationSubscriptionTest {
    @Test
    fun `requested updates pause and resume once`() {
        var starts = 0
        var stops = 0
        val subscription = ResumableLocationSubscription(
            startUpdates = { starts += 1 },
            stopUpdates = { stops += 1 },
        )

        subscription.start()
        subscription.start()
        subscription.onPause()
        subscription.onPause()
        subscription.onResume()
        subscription.onResume()

        assertTrue(subscription.isRequested)
        assertTrue(subscription.isActive)
        assertEquals(2, starts)
        assertEquals(1, stops)
    }

    @Test
    fun `explicit stop while paused prevents restart`() {
        var starts = 0
        var stops = 0
        val subscription = ResumableLocationSubscription(
            startUpdates = { starts += 1 },
            stopUpdates = { stops += 1 },
        )

        subscription.start()
        subscription.onPause()
        subscription.stop()
        subscription.onResume()

        assertFalse(subscription.isRequested)
        assertFalse(subscription.isActive)
        assertEquals(1, starts)
        assertEquals(1, stops)
    }

    @Test
    fun `failed start clears requested state and remains inactive`() {
        var starts = 0
        var stops = 0
        val subscription = ResumableLocationSubscription(
            startUpdates = {
                starts += 1
                throw IllegalStateException("provider unavailable")
            },
            stopUpdates = { stops += 1 },
        )

        try {
            subscription.start()
            throw AssertionError("start should propagate provider failure")
        } catch (_: IllegalStateException) {
        }

        assertFalse(subscription.isRequested)
        assertFalse(subscription.isActive)
        assertEquals(1, starts)
        assertEquals(0, stops)
    }

    @Test
    fun `close stops active updates and rejects later starts`() {
        var stops = 0
        val subscription = ResumableLocationSubscription(
            startUpdates = {},
            stopUpdates = { stops += 1 },
        )

        subscription.start()
        subscription.close()
        subscription.close()

        assertFalse(subscription.isRequested)
        assertFalse(subscription.isActive)
        assertEquals(1, stops)
        try {
            subscription.start()
            throw AssertionError("start should fail after close")
        } catch (_: IllegalStateException) {
            // Expected.
        }
    }
}
