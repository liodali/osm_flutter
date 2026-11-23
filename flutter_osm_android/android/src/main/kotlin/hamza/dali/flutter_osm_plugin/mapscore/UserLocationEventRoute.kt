package hamza.dali.flutter_osm_plugin.mapscore

/**
 * One user-location fix as the host reported it: raw doubles with full
 * precision, unchanged from the location manager's values.
 */
internal class UserLocationFix(
    val latitude: Double,
    val longitude: Double,
    val heading: Double,
) {
    /** The legacy `receiveUserLocation` payload shape, unchanged. */
    fun toLegacyPayload(): Map<String, Any> = hashMapOf(
        "lat" to latitude,
        "lon" to longitude,
        "heading" to heading,
    )
}

/**
 * Frozen user-location delivery route for one attachment.
 *
 * Location fixes are rate-limited by the session's [MapEventCoalescer]
 * (`receiveUserLocation` interval: first fix immediately, then the newest
 * payload per interval) BEFORE they reach this class, so both delivery
 * routes observe the same platform rate and coalescing state; this class
 * only decides where a flushed fix goes, and it goes to exactly one route.
 *
 * The default keeps the legacy `receiveUserLocation` event plane (the only
 * route JNI attachments ever use); the validated pre-initialization
 * selection switches fixes to the generated Pigeon callback. Location
 * flows only after initialization, so no pre-selection buffering is
 * needed (unlike the lifecycle route).
 */
internal class UserLocationEventRoute(
    private val emitLegacy: (UserLocationFix) -> Unit,
    private val emitTyped: (UserLocationFix) -> Unit,
) {
    /** True once the attachment selected the generated Pigeon route. */
    @Volatile var usePigeon: Boolean = false
        private set

    /** Freezes the delivery route for this attachment. */
    fun select(usePigeon: Boolean) {
        this.usePigeon = usePigeon
    }

    /** Delivers one coalesced fix on the frozen route. */
    fun emit(fix: UserLocationFix) {
        if (usePigeon) emitTyped(fix) else emitLegacy(fix)
    }
}
