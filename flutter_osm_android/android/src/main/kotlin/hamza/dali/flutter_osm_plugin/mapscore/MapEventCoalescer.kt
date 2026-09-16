package hamza.dali.flutter_osm_plugin.mapscore

import android.os.Handler

internal fun interface CancellableMapEventTask {
    fun cancel()
}

internal fun interface MapEventScheduler {
    fun schedule(delayMillis: Long, block: () -> Unit): CancellableMapEventTask
}

internal class HandlerMapEventScheduler(
    private val handler: Handler,
) : MapEventScheduler {
    override fun schedule(delayMillis: Long, block: () -> Unit): CancellableMapEventTask {
        val runnable = Runnable(block)
        handler.postDelayed(runnable, delayMillis)
        return CancellableMapEventTask { handler.removeCallbacks(runnable) }
    }
}

/**
 * Emits the first event immediately and coalesces later events to the newest
 * payload within each method's interval.
 */
internal class MapEventCoalescer(
    private val intervalsMillis: Map<String, Long>,
    private val clockMillis: () -> Long,
    private val scheduler: MapEventScheduler,
    private val emitter: (method: String, arguments: Any?) -> Unit,
) {
    private data class PendingEvent(
        var arguments: Any?,
        var task: CancellableMapEventTask? = null,
    )

    private val lock = Any()
    private val lastEmissionMillis = mutableMapOf<String, Long>()
    private val pendingEvents = mutableMapOf<String, PendingEvent>()
    private var closed = false

    fun emit(method: String, arguments: Any?) {
        var immediateArguments: Any? = null
        var emitImmediately = false
        synchronized(lock) {
            if (closed) return
            val interval = intervalsMillis[method]
            if (interval == null || interval <= 0L) {
                immediateArguments = arguments
                emitImmediately = true
                return@synchronized
            }

            val now = clockMillis()
            val lastEmission = lastEmissionMillis[method]
            if (lastEmission == null || now - lastEmission >= interval) {
                pendingEvents.remove(method)?.task?.cancel()
                lastEmissionMillis[method] = now
                immediateArguments = arguments
                emitImmediately = true
                return@synchronized
            }

            val pending = pendingEvents[method]
            if (pending != null) {
                pending.arguments = arguments
                return@synchronized
            }

            val newPending = PendingEvent(arguments)
            pendingEvents[method] = newPending
            val remaining = (interval - (now - lastEmission)).coerceAtLeast(0L)
            newPending.task = scheduler.schedule(remaining) { flush(method) }
        }
        if (emitImmediately) emitter(method, immediateArguments)
    }

    private fun flush(method: String) {
        var arguments: Any? = null
        var shouldEmit = false
        synchronized(lock) {
            if (closed) return
            val pending = pendingEvents.remove(method) ?: return
            lastEmissionMillis[method] = clockMillis()
            arguments = pending.arguments
            shouldEmit = true
        }
        if (shouldEmit) emitter(method, arguments)
    }

    fun close() {
        val tasks = synchronized(lock) {
            if (closed) return
            closed = true
            val values = pendingEvents.values.mapNotNull(PendingEvent::task)
            pendingEvents.clear()
            lastEmissionMillis.clear()
            values
        }
        tasks.forEach(CancellableMapEventTask::cancel)
    }
}
