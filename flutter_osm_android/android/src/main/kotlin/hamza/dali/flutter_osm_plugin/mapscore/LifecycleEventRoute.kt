package hamza.dali.flutter_osm_plugin.mapscore

/**
 * Frozen lifecycle delivery route for one attachment, plus restoration
 * buffering.
 *
 * Activity recreation can deliver restoration before the attach-time route
 * selection — or before any selection at all for JNI/opt-out attachments,
 * which never negotiate. Restoration is held until the route is resolved,
 * then delivered on the typed route. The legacy event plane keeps its
 * historical behavior: it never emitted restoration on Android.
 */
internal class LifecycleEventRoute(
    private val emitTypedRestored: () -> Unit,
) {
    /** True once the attachment selected the generated Pigeon route. */
    var usePigeon: Boolean = false
        private set

    private var resolved = false
    private var pendingRestoration = false

    /**
     * Attach-time route selection: freezes the route and flushes any
     * restoration that arrived before negotiation.
     */
    fun select(usePigeon: Boolean) {
        this.usePigeon = usePigeon
        resolve()
    }

    /**
     * First readiness resolves the implicit legacy route for attachments
     * that never negotiate (JNI, opt-out), flushing held restoration.
     */
    fun notifyReadiness() {
        if (!resolved) resolve()
    }

    /**
     * Saved map state was restored: deliver on the resolved route, or hold
     * until the route is resolved. Repeated pre-resolution restores coalesce
     * into one delivery (one activity restoration).
     */
    fun restored() {
        if (resolved) {
            deliverIfTyped()
        } else {
            pendingRestoration = true
        }
    }

    private fun resolve() {
        resolved = true
        if (pendingRestoration) {
            pendingRestoration = false
            deliverIfTyped()
        }
    }

    private fun deliverIfTyped() {
        if (usePigeon) emitTypedRestored()
    }
}
