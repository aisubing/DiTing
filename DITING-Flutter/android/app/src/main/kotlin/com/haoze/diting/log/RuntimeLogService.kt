package com.haoze.diting.log

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Process
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.haoze.diting.MainActivity
import com.haoze.diting.R
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.util.concurrent.atomic.AtomicLong

/// Manual runtime-log capture: while it runs, `logcat` output for this app's own process is
/// appended to [RuntimeLogStore]. It is a foreground service because a backgrounded app may not
/// keep a plain thread alive, and the persistent notification doubles as the "recording" state the
/// user can stop from outside the app. Nothing survives the user turning it off.
class RuntimeLogService : Service() {

    private val generation = AtomicLong(0)

    @Volatile
    private var worker: Thread? = null

    /// Written and read across threads; `generation` is what actually cancels a stale loop.
    @Volatile
    private var capturing = false

    override fun onBind(intent: Intent?): android.os.IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopCapture()
            return START_NOT_STICKY
        }
        promoteToForeground()
        if (capturing) {
            Log.i(TAG, "capture already running; ignoring duplicate start")
            return START_NOT_STICKY
        }
        capturing = true
        captureActive = true
        val token = generation.incrementAndGet()
        val thread = Thread({ captureLoop(token) }, "diting-runtime-log")
        worker = thread
        thread.start()
        return START_NOT_STICKY
    }

    /// Reads until the user stops it or the file fills up; a rotated file restarts the read, so one
    /// long session never unbounded-grows a single file.
    private fun captureLoop(token: Long) {
        while (capturing && generation.get() == token) {
            val file = RuntimeLogStore.newFile(this)
            RuntimeLogStore.trim(this)
            var process: java.lang.Process? = null
            var writer: PrintWriter? = null
            try {
                writer = PrintWriter(file.bufferedWriter(), true)
                process = launchLogcat()
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                var written = 0L
                while (capturing && generation.get() == token) {
                    val line = reader.readLine() ?: break
                    writer.println(line)
                    written += line.length.toLong() + 1
                    if (written >= RuntimeLogStore.MAX_FILE_BYTES) break
                }
            } catch (t: Throwable) {
                Log.w(TAG, "logcat capture stopped", t)
                // An exec failure would otherwise spin: back off, then retry while still on.
                runCatching { Thread.sleep(1000) }
            } finally {
                runCatching { process?.destroy() }
                runCatching { writer?.close() }
            }
        }
    }

    /// `--pid` keeps the capture to this app: less noise for the developer and a lower cost for the
    /// user, which is what the confirmation dialog promises.
    private fun launchLogcat(): java.lang.Process {
        val attempts = listOf(
            arrayOf("logcat", "-v", "time", "--pid", Process.myPid().toString()),
            arrayOf("logcat", "-v", "time"),
        )
        var last: Throwable? = null
        for (command in attempts) {
            try {
                return ProcessBuilder(*command).redirectErrorStream(true).start()
            } catch (t: Throwable) {
                last = t
            }
        }
        throw last ?: IllegalStateException("无法启动 logcat")
    }

    private fun stopCapture() {
        capturing = false
        captureActive = false
        generation.incrementAndGet()
        val thread = worker
        worker = null
        runCatching { thread?.interrupt() }
        stopForegroundCompat()
        stopSelf()
    }

    override fun onDestroy() {
        capturing = false
        captureActive = false
        generation.incrementAndGet()
        runCatching { worker?.interrupt() }
        worker = null
        super.onDestroy()
    }

    private fun promoteToForeground() {
        val notification = buildNotification()
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure { Log.e(TAG, "startForeground failed", it) }
    }

    private fun stopForegroundCompat() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, RuntimeLogService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("正在抓取运行日志")
            .setContentText("仅记录谛听自身的运行日志，关闭后立即停止")
            .setContentIntent(openIntent)
            .addAction(0, "停止", stopIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "运行日志抓取",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "手动开启的运行日志抓取期间显示，关闭后自动消失"
                setShowBadge(false)
            },
        )
    }

    companion object {
        private const val TAG = "RuntimeLogService"
        private const val CHANNEL_ID = "channel_runtime_log"
        private const val NOTIFICATION_ID = 2003
        private const val ACTION_STOP = "com.haoze.diting.action.STOP_RUNTIME_LOG"

        /// Process-local truth: the service shares this process, so the page and the bridge agree.
        @Volatile
        var captureActive: Boolean = false
            private set

        fun start(context: Context) {
            captureActive = true
            val intent = Intent(context, RuntimeLogService::class.java)
            runCatching { ContextCompat.startForegroundService(context, intent) }
                .onFailure {
                    captureActive = false
                    Log.e(TAG, "start failed", it)
                }
        }

        fun stop(context: Context) {
            captureActive = false
            val intent = Intent(context, RuntimeLogService::class.java).setAction(ACTION_STOP)
            runCatching { ContextCompat.startForegroundService(context, intent) }
        }
    }
}
