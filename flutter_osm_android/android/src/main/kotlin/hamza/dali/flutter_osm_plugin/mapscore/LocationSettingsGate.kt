package hamza.dali.flutter_osm_plugin.mapscore

import hamza.dali.flutter_osm_plugin.mapscore.MapSession

/**
 * Single-owner gate for the settings round trip phase of a location
 * request. A request acquires the gate; the phase deadline moves it to
 * draining (ownership stays closed: activity results carry no request
 * identity, so a newer attempt must not reuse the settings code while a
 * stale result is in flight); the late result drains it.
 *
 * Sessions survive configuration detach/reattach, so draining ownership
 * survives [detach] — only [release] (true disposal) resets it.
 */
internal class LocationSettingsGate {

    private var heldListener: MapSession.LocationFixListener? = null
    private var draining = false

    /** Whether the settings phase owns the map's location request slot. */
    val occupied: Boolean
        get() = heldListener != null || draining

    /** The listener of the active round trip, if one is in flight. */
    fun current(): MapSession.LocationFixListener? = heldListener

    /** Acquires the gate for a new round trip; false while occupied. */
    fun acquire(listener: MapSession.LocationFixListener): Boolean {
        if (occupied) return false
        heldListener = listener
        return true
    }

    /**
     * Deadline expiry: fails the held listener but keeps ownership
     * draining until the late activity result arrives.
     */
    fun markDraining(): MapSession.LocationFixListener? {
        val listener = heldListener ?: return null
        heldListener = null
        draining = true
        return listener
    }

    /** A settings result drained the outstanding attempt; frees the gate. */
    fun drain(): Boolean {
        if (!draining) return false
        draining = false
        return true
    }

    /** Frees the gate outright (round trip consumed, or disposal). */
    fun release() {
        heldListener = null
        draining = false
    }

    /**
     * Activity detachment: the active round trip fails (the wait cannot
     * continue without a foreground Activity) and moves to draining —
     * the settings screen opened before detachment is still out there,
     * so its late result must never be consumed by a newer request, and
     * ownership survives the configuration detach/reattach cycle. Only
     * [release] (true disposal) drops outstanding ownership.
     */
    fun detach(): MapSession.LocationFixListener? {
        val listener = heldListener ?: return null
        heldListener = null
        draining = true
        return listener
    }
}
