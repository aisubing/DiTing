package com.haoze.diting.crash

import android.content.Context
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.system.exitProcess

/**
 * Global uncaught-exception handler. Registered via
 * [Thread.setDefaultUncaughtExceptionHandler]; on a crash it collects detailed
 * diagnostics to disk, then safely hands the exception over to the system's
 * original handler.
 */
class CrashHandler private constructor(
    private val appContext: Context,
    private val defaultHandler: Thread.UncaughtExceptionHandler?
) : Thread.UncaughtExceptionHandler {

    private val isHandling = AtomicBoolean(false)

    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        if (!isHandling.compareAndSet(false, true)) {
            // Guard against an infinite loop if crash collection itself throws
            // another uncaught exception.
            defaultHandler?.uncaughtException(thread, throwable) ?: exitProcess(2)
            return
        }

        try {
            CrashBreadcrumbs.record(
                tag = "CRASH",
                message = "Uncaught exception in [${thread.name}]: ${throwable.javaClass.name}: ${throwable.message}",
                level = "FATAL"
            )

            // Fast path: capture only cheap diagnostics and persist them with a
            // synchronous fsync. This must complete before the process dies, and
            // is deliberately small so it still succeeds under OOM / a wedged
            // runtime, where the full report below would itself fail.
            val minimal = CrashCollector.collectMinimalReport(
                thread = thread,
                throwable = throwable,
                topActivityName = currentActivityName,
                isForeground = isAppForeground
            )
            val file = CrashLogManager.saveCrashReport(appContext, minimal)
            Log.e(TAG, "DITING Crash detected! Minimal report saved to: ${file?.absolutePath}")

            // Slow path: the expensive diagnostics (logcat fork, all-live-thread
            // dump, binder-backed device/network queries) and the crash bookkeeping
            // (sync prefs commit + possible Downloads export) run on a detached
            // thread so they never block the crashing thread.
            val saved = file
            Thread({
                runCatching {
                    val full = CrashCollector.collectReport(
                        context = appContext,
                        thread = thread,
                        throwable = throwable,
                        topActivityName = currentActivityName,
                        isForeground = isAppForeground
                    )
                    if (saved != null) {
                        CrashLogManager.replaceCrashReport(appContext, saved, full)
                        Log.i(TAG, "Enriched crash report at ${saved.absolutePath}")
                    } else {
                        CrashLogManager.saveCrashReport(appContext, full)
                    }
                    CrashLogManager.onCrashOccurred(appContext)
                }.onFailure { e ->
                    Log.e(TAG, "Fatal error while enriching crash report", e)
                    runCatching { CrashLogManager.onCrashOccurred(appContext) }
                }
            }, "CrashEnricher").start()
        } catch (e: Throwable) {
            Log.e(TAG, "Fatal error while capturing crash report", e)
        } finally {
            if (defaultHandler != null) {
                defaultHandler.uncaughtException(thread, throwable)
            } else {
                exitProcess(2)
            }
        }
    }

    companion object {
        private const val TAG = "CrashHandler"

        @Volatile
        var currentActivityName: String? = null

        @Volatile
        var isAppForeground: Boolean = false

        private var installed = false

        @Synchronized
        fun install(context: Context) {
            if (installed) return
            val appContext = context.applicationContext ?: context
            val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
            val handler = CrashHandler(appContext, defaultHandler)
            Thread.setDefaultUncaughtExceptionHandler(handler)
            installed = true
            Log.i(TAG, "Global UncaughtExceptionHandler installed successfully")
        }
    }
}
