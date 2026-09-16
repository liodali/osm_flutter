package hamza.dali.flutter_osm_plugin.mapscore.overlays

/**
 * Separates caller intent from Activity visibility so location updates restart
 * after resume only when they were explicitly requested before the pause.
 */
internal class ResumableLocationSubscription(
    private val startUpdates: () -> Unit,
    private val stopUpdates: () -> Unit,
) {
    var isRequested: Boolean = false
        private set

    var isActive: Boolean = false
        private set

    private var isResumed = true
    private var closed = false

    fun start() {
        check(!closed) { "Location subscription is closed" }
        isRequested = true
        reconcile()
    }

    fun stop() {
        if (closed) return
        isRequested = false
        reconcile()
    }

    fun onResume() {
        if (closed) return
        isResumed = true
        reconcile()
    }

    fun onPause() {
        if (closed) return
        isResumed = false
        reconcile()
    }

    fun close() {
        if (closed) return
        closed = true
        isRequested = false
        if (isActive) {
            stopUpdates()
            isActive = false
        }
    }

    private fun reconcile() {
        val shouldBeActive = isRequested && isResumed
        if (shouldBeActive == isActive) return
        if (shouldBeActive) {
            try {
                startUpdates()
                isActive = true
            } catch (error: Throwable) {
                isRequested = false
                throw error
            }
        } else {
            stopUpdates()
            isActive = false
        }
    }
}
