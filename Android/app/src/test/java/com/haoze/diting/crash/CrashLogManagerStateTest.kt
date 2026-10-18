package com.haoze.diting.crash

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-055 / O-123 / O-124: the consecutive-crash streak and the native-crash
 * waterline were maintained with unlocked, batch-delayed read-modify-writes.
 *
 * - A-055: the waterline was persisted only after the whole replay loop, so a
 *   process death in the middle re-collected every already-recorded exit on the
 *   next launch, inflating the streak (and, past the threshold, exporting
 *   duplicate backups).
 * - O-123: [CrashLogManager.clearCrashLogs] wrote the wall clock into the
 *   waterline; after the user's clock moves backwards every later native exit
 *   timestamp filters out and native crashes stop being collected.
 * - O-124: the crash handler and the native replay could interleave their
 *   counters; one increment was lost, so the auto-backup threshold fired late.
 */
class CrashLogManagerStateTest {

    private fun crashLogManagerSource(): String {
        val candidates = listOf(
            java.io.File("src/main/java/com/haoze/diting/crash/CrashLogManager.kt"),
            java.io.File("app/src/main/java/com/haoze/diting/crash/CrashLogManager.kt"),
            java.io.File("Android/app/src/main/java/com/haoze/diting/crash/CrashLogManager.kt")
        )
        return candidates.firstOrNull { it.exists() }?.readText().orEmpty()
    }

    // ------------------------------------------------------------------ A-055/O-124

    @Test
    fun crashInsideTheWindowIncrementsTheStreak() {
        assertEquals(
            2,
            CrashLogManager.nextConsecutiveCount(
                currentCount = 1,
                lastCrashTime = 1_000L,
                now = 2_000L
            )
        )
    }

    @Test
    fun crashOutsideTheWindowStartsANewStreak() {
        val oneDay = 24 * 60 * 60 * 1000L
        assertEquals(
            1,
            CrashLogManager.nextConsecutiveCount(
                currentCount = 7,
                lastCrashTime = 0L,
                now = oneDay + 1
            )
        )
    }

    @Test
    fun crashExactlyAtTheWindowEdgeStillCounts() {
        // The comparison is strict (`>`), so a crash exactly CONSECUTIVE_EXPIRY_MS
        // after the previous one belongs to the same streak.
        assertEquals(
            4,
            CrashLogManager.nextConsecutiveCount(
                currentCount = 3,
                lastCrashTime = 0L,
                now = 24 * 60 * 60 * 1000L
            )
        )
    }

    @Test
    fun firstEverCrashStartsAtOne() {
        assertEquals(1, CrashLogManager.nextConsecutiveCount(currentCount = 0, lastCrashTime = 0L, now = 5_000L))
    }

    /*
     * O-124 / A-055 atomicity itself is `Context`-bound (SharedPreferences), so it
     * cannot be exercised on the JVM. These two tests pin the structure that makes
     * the atomicity hold: the streak read-modify-write and the per-record waterline
     * write must stay where they are. They are *not* a substitute for the runtime
     * concurrency argument, which rests on `synchronized(stateLock)` plus the
     * ordering of the two statements in `checkAndCollectNativeCrashes`.
     */

    @Test
    fun theStreakUpdateIsSerializedByTheStateLock() {
        val source = crashLogManagerSource()
        if (source.isBlank()) return

        val handler = source.substringAfter("fun onCrashOccurred(", "")
        val counterWrite = handler.indexOf("KEY_CONSECUTIVE_CRASH_COUNT, next")
        assertTrue("the streak must still be written in the crash handler", counterWrite >= 0)

        val lockStart = handler.lastIndexOf("synchronized(stateLock)", counterWrite)
        assertTrue(
            "the streak read-modify-write must run inside synchronized(stateLock)",
            lockStart in 0 until counterWrite
        )
        // The read of the previous values must happen under the same lock.
        val lockBody = handler.substring(lockStart, counterWrite)
        assertTrue("the previous count must be read under the lock", lockBody.contains("KEY_CONSECUTIVE_CRASH_COUNT"))
        assertTrue("the previous timestamp must be read under the lock", lockBody.contains("KEY_LAST_CRASH_TIME"))
    }

    @Test
    fun theWaterlineIsPersistedBeforeEachStreakIncrement() {
        val source = crashLogManagerSource()
        if (source.isBlank()) return

        val body = source.substringAfter("val nativeCrashes = exitInfos", "")
        val waterlineWrite = body.indexOf("KEY_LAST_RECORDED_NATIVE_EXIT_TIME, maxTimestamp")
        val streakIncrement = body.indexOf("onCrashOccurred(context)")
        assertTrue("the waterline must be persisted inside the replay loop", waterlineWrite >= 0)
        assertTrue("the streak must still be incremented per collected exit", streakIncrement >= 0)
        assertTrue(
            "the waterline must be written before onCrashOccurred, so a death inside the " +
                "streak update cannot double-count the same exit",
            waterlineWrite < streakIncrement
        )
    }

    // ---------------------------------------------------------------------- O-123

    @Test
    fun clearKeepsTheWaterlineOnTheSystemReportedClock() {
        // The exits the system still reports were recorded before the user
        // cleared the logs: the waterline must move up to them (so they are not
        // re-collected) but must NOT jump to the wall clock, which may be ahead
        // of every future exit timestamp after a backwards clock change.
        val reported = listOf(1_000L, 2_500L, 2_000L)

        assertEquals(
            2_500L,
            CrashLogManager.waterlineAfterClear(currentWaterline = 500L, historicalTimestamps = reported)
        )
    }

    @Test
    fun clearNeverLowersAnExistingWaterline() {
        assertEquals(
            9_000L,
            CrashLogManager.waterlineAfterClear(currentWaterline = 9_000L, historicalTimestamps = listOf(1_000L))
        )
    }

    @Test
    fun clearWithoutHistoricalRecordsKeepsTheWaterline() {
        // No exit records (API < 30, empty history, or a thrown exception):
        // clearing logs must not invent a new watermark out of thin air.
        assertEquals(
            4_200L,
            CrashLogManager.waterlineAfterClear(currentWaterline = 4_200L, historicalTimestamps = emptyList())
        )
    }

    @Test
    fun clearWithNoWaterlineAndNoRecordsStaysAtZero() {
        // Zero means "collect everything", which is correct for a fresh install.
        assertEquals(
            0L,
            CrashLogManager.waterlineAfterClear(currentWaterline = 0L, historicalTimestamps = emptyList())
        )
    }

    // ---------------------------------------------------------------------- O-125

    @Test
    fun privateDownloadFallbackDirectoryIsMappedForFileProvider() {
        // O-125: the fallback target File(filesDir, CrashLogManager.PRIVATE_DOWNLOAD_DIR_NAME)
        // needs a matching <files-path> entry, otherwise FileProvider.getUriForFile
        // throws and the successfully written backup is reported as a failure and
        // left orphaned in filesDir forever.
        val resources = java.io.File("src/main/res/xml/file_paths.xml")
        if (!resources.exists()) return // path differs when run from another root
        val xml = resources.readText()
        assertEquals("downloads", CrashLogManager.PRIVATE_DOWNLOAD_DIR_NAME)
        assertTrue(
            "the fallback directory must have a files-path FileProvider mapping",
            xml.contains("crash_export_private") && xml.contains("""path="downloads/"""")
        )
        assertTrue(
            "the external-files mapping for the primary target must stay",
            xml.contains("crash_export") && xml.contains("""path="Download/"""")
        )
    }
}
