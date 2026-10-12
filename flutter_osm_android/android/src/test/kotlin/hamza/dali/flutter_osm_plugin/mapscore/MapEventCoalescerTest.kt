package hamza.dali.flutter_osm_plugin.mapscore

import org.junit.Assert.assertEquals
import org.junit.Test

class MapEventCoalescerTest {
    @Test
    fun `emits first event and then the newest payload per interval`() {
        val scheduler = FakeMapEventScheduler()
        val emitted = mutableListOf<Pair<String, Any?>>()
        val coalescer = MapEventCoalescer(
            intervalsMillis = mapOf("region" to 100L),
            clockMillis = scheduler::now,
            scheduler = scheduler,
            emitter = { method, arguments -> emitted += method to arguments },
        )

        coalescer.emit("region", 1)
        scheduler.advanceBy(10)
        coalescer.emit("region", 2)
        scheduler.advanceBy(10)
        coalescer.emit("region", 3)

        assertEquals(listOf("region" to 1), emitted)
        scheduler.advanceBy(79)
        assertEquals(listOf("region" to 1), emitted)
        scheduler.advanceBy(1)
        assertEquals(listOf("region" to 1, "region" to 3), emitted)
    }

    @Test
    fun `tracks each event method independently`() {
        val scheduler = FakeMapEventScheduler()
        val emitted = mutableListOf<Pair<String, Any?>>()
        val coalescer = MapEventCoalescer(
            intervalsMillis = mapOf("region" to 100L, "location" to 1_000L),
            clockMillis = scheduler::now,
            scheduler = scheduler,
            emitter = { method, arguments -> emitted += method to arguments },
        )

        coalescer.emit("region", 1)
        coalescer.emit("location", 2)
        scheduler.advanceBy(10)
        coalescer.emit("region", 3)
        coalescer.emit("location", 4)
        coalescer.emit("ready", 5)
        scheduler.advanceBy(90)

        assertEquals(
            listOf("region" to 1, "location" to 2, "ready" to 5, "region" to 3),
            emitted,
        )
        scheduler.advanceBy(900)
        assertEquals("location" to 4, emitted.last())
    }

    @Test
    fun `close cancels trailing events and blocks late emissions`() {
        val scheduler = FakeMapEventScheduler()
        val emitted = mutableListOf<Any?>()
        val coalescer = MapEventCoalescer(
            intervalsMillis = mapOf("location" to 1_000L),
            clockMillis = scheduler::now,
            scheduler = scheduler,
            emitter = { _, arguments -> emitted += arguments },
        )

        coalescer.emit("location", "first")
        scheduler.advanceBy(5)
        coalescer.emit("location", "pending")
        coalescer.close()
        scheduler.advanceBy(1_000)
        coalescer.emit("location", "late")

        assertEquals(listOf("first"), emitted)
    }

    private class FakeMapEventScheduler : MapEventScheduler {
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
}
