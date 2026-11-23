package hamza.dali.flutter_osm_plugin.mapscore

/**
 * Deterministic [MapEventScheduler] + clock for coalescer-driven tests:
 * scheduled flushes run when the virtual clock passes their due time.
 */
internal class FakeMapEventScheduler : MapEventScheduler {
    private data class Task(
        val dueAt: Long,
        val block: () -> Unit,
        var cancelled: Boolean = false,
    )

    private var currentTime = 0L
    private val tasks = mutableListOf<Task>()

    fun now(): Long = currentTime

    override fun schedule(
        delayMillis: Long,
        block: () -> Unit,
    ): CancellableMapEventTask {
        val task = Task(currentTime + delayMillis, block)
        tasks += task
        return CancellableMapEventTask { task.cancelled = true }
    }

    fun advanceBy(milliseconds: Long) {
        currentTime += milliseconds
        while (true) {
            val task = tasks
                .filterNot(Task::cancelled)
                .filter { it.dueAt <= currentTime }
                .minByOrNull(Task::dueAt)
                ?: return
            tasks.remove(task)
            task.block()
        }
    }
}
