package hamza.dali.flutter_osm_plugin.mapscore

/**
 * Frozen delivery route for one coalesced native-to-Dart event family
 * (user-location fixes, visible-region changes).
 *
 * Events are rate-limited by the session's [MapEventCoalescer] (first event
 * immediately, then the newest payload per interval) BEFORE they reach this
 * class, so both delivery routes observe the same platform rate and
 * coalescing state; this class only decides where a flushed payload goes,
 * and it goes to exactly one route.
 *
 * The default keeps the family's legacy event plane (the only route JNI
 * attachments ever use); the validated pre-initialization selection switches
 * delivery to the generated Pigeon callback. Both families flow only after
 * initialization, so no pre-selection buffering is needed (unlike the
 * lifecycle route).
 */
internal class CoalescedEventRoute<Payload>(
    private val emitLegacy: (Payload) -> Unit,
    private val emitTyped: (Payload) -> Unit,
) {
    /** True once the attachment selected the generated Pigeon route. */
    @Volatile var usePigeon: Boolean = false
        private set

    /** Freezes the delivery route for this attachment. */
    fun select(usePigeon: Boolean) {
        this.usePigeon = usePigeon
    }

    /** Delivers one coalesced payload on the frozen route. */
    fun emit(payload: Payload) {
        if (usePigeon) emitTyped(payload) else emitLegacy(payload)
    }
}
