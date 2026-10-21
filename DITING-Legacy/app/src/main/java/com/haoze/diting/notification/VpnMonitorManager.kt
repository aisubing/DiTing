package com.haoze.diting.notification

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import androidx.core.content.ContextCompat
import com.haoze.diting.core.VpnStateRegistry
import com.haoze.diting.ui.mode.AppWorkMode
import com.haoze.diting.ui.mode.WorkModeStore

/**
 * 常驻监控服务的「启动义务」状态机（纯 Kotlin，可在 JVM 单测里直接驱动）。
 *
 * Android 12+ 的 AMS 对 `startForegroundService()` 有硬契约：服务必须在
 * `onStartCommand()` 里成功调用 `startForeground()`。在义务兑现之前，只要该服务记录被
 * 拆除（`stopService()` / `stopSelf()`），`ActiveServices.bringDownServiceLocked()`
 * 就会立刻发出 `SERVICE_FOREGROUND_CRASH_MSG`（无延迟），进程在数毫秒内以
 * `ForegroundServiceDidNotStartInTimeException` 崩溃。
 *
 * 本次冷启动崩溃正是这条链路：主线程仍在 `MainActivity.onCreate` 里时，
 * `startForegroundService()` 已经把义务挂在该服务记录上（`ActiveServices:1196`），
 * 而服务进程已就绪的路径**不会**把记录放进 `mPendingServices`（`bringUpServiceInnerLocked`
 * 在 `r.app != null && isThreadReady` 时直接 `sendServiceArgsLocked` 并返回），
 * 于是后续的 `stopService()` 一路走到 `bringDownServiceIfNeededLocked` → 校验
 * `r.fgRequired` 仍为 true → 立即崩溃。
 *
 * 所以本状态机只回答一个问题：**当前是否还欠着一次 `startForeground()`**。
 * 欠着的时候禁止调用 `stopService()`，改由服务在 `startForeground()` 之后自行
 * `stopSelf()`；该顺序安全，因为成功的 `startForeground()` 会在返回前同步清除
 * AMS 侧的 `fgRequired`（`ActiveServices:2238-2246`）。
 */
internal class VpnMonitorLifecycleState(
    private val inFlightTimeoutMs: Long = START_IN_FLIGHT_TIMEOUT_MS
) {

    /** 已下发 `startForegroundService()`，但服务尚未成功 `startForeground()`。 */
    @Volatile
    var startInFlight: Boolean = false
        private set

    /** 显式停止请求。服务在 `onStartCommand()` 里据此决定是否 `stopSelf()`。 */
    @Volatile
    var stopRequested: Boolean = false
        private set

    private var startIssuedAtUptime: Long = 0L

    /**
     * 记录一次「应当运行」的期望。
     *
     * @return 是否真的需要下发一次 `startForegroundService()`。
     */
    @Synchronized
    fun requestStart(isServiceAlive: Boolean, nowUptimeMillis: Long): Boolean {
        stopRequested = false
        // 服务实例已存在（onCreate 已跑过）时无需再下发。
        // 注意：这里**不**清 startInFlight——服务可能刚 onCreate、还没执行到
        // onStartCommand 里的 startForeground()，此刻 fgRequired 仍在 AMS 上挂着。
        // 义务只由服务自己的 onPromoted()/onStartFailed()/onServiceDestroyed() 解除。
        if (isServiceAlive) return false
        if (startInFlight && nowUptimeMillis - startIssuedAtUptime < inFlightTimeoutMs) {
            // 已有一次启动在途，重复下发只会再次把 AMS 侧的 fgRequired 置为 true。
            return false
        }
        // 首次下发，或上一次启动明显已失败（超时仍未见服务实例）后重试。
        startInFlight = true
        startIssuedAtUptime = nowUptimeMillis
        return true
    }

    /**
     * 记录一次「应当停止」的期望。
     *
     * @return 此刻是否可以安全调用 `stopService()`
     *         （false 表示还欠着 `startForeground()`，只能延后到服务自停）。
     */
    @Synchronized
    fun requestStop(nowUptimeMillis: Long): Boolean {
        stopRequested = true
        // 在途标记超过超时仍未被服务解除，说明那次启动已被系统丢弃（服务不会再来
        // 兑现义务，AMS 侧也不会再有 fgRequired 记录需要保护），此时必须放行停止，
        // 否则停止请求会被永久拦截。
        if (startInFlight && nowUptimeMillis - startIssuedAtUptime >= inFlightTimeoutMs) {
            startInFlight = false
        }
        return !startInFlight
    }

    /** 服务成功 `startForeground()` 后调用，解除启动义务。 */
    @Synchronized
    fun onPromoted() {
        startInFlight = false
    }

    /** `startForegroundService()` 抛异常时回滚在途标记。 */
    @Synchronized
    fun onStartFailed() {
        startInFlight = false
    }

    /** 服务实例销毁后调用，避免在途标记残留在已拆除的记录上。 */
    @Synchronized
    fun onServiceDestroyed() {
        startInFlight = false
    }

    companion object {
        /** 超过该时长仍未见服务实例，视为上一次启动已失败，允许重新下发。 */
        const val START_IN_FLIGHT_TIMEOUT_MS = 10_000L
    }
}

/**
 * 安全地调度 [VpnMonitorService] 的启停，保证任意调用顺序都不会把
 * 「已 startForegroundService、尚未 startForeground」的服务记录拆掉。
 */
object VpnMonitorManager {

    private const val TAG = "VpnMonitorManager"

    private val lock = Any()
    private val lifecycle = VpnMonitorLifecycleState()

    /**
     * 检查是否有任一 VPN 服务（普通模式或畅连模式）正在运行。
     */
    fun isVpnRunning(context: Context): Boolean {
        val appContext = context.applicationContext
        return VpnStateRegistry.isAnyVpnRunning(appContext)
    }

    /** 当前是否被显式要求停止（服务据此决定是否自停）。 */
    fun isStopRequested(): Boolean = lifecycle.stopRequested

    /** 由 [VpnMonitorService] 在成功 `startForeground()` 后回调。 */
    internal fun onServicePromoted() {
        lifecycle.onPromoted()
    }

    /** 由 [VpnMonitorService.onDestroy] 回调。 */
    internal fun onServiceDestroyed() {
        lifecycle.onServiceDestroyed()
    }

    /**
     * 让常驻监控服务与用户设置、系统权限、VPN 运行状态保持一致。
     */
    fun sync(context: Context) {
        val appContext = context.applicationContext
        if (shouldMonitorBeStopped(appContext)) {
            stop(appContext)
            return
        }

        val needStart = synchronized(lock) {
            lifecycle.requestStart(VpnMonitorService.isServiceAlive, android.os.SystemClock.uptimeMillis())
        }
        if (!needStart) return

        try {
            ContextCompat.startForegroundService(appContext, VpnMonitorService.startIntent(appContext))
        } catch (e: Exception) {
            synchronized(lock) { lifecycle.onStartFailed() }
            Log.w(TAG, "Failed to start VpnMonitorService", e)
        }
    }

    /**
     * 停止常驻监控服务并立即取消其通知。
     *
     * 若此刻仍欠着一次 `startForeground()`（`startForegroundService()` 已下发但服务实例
     * 尚未创建/未完成提升），**不能**调用 `stopService()`：那会让 AMS 立即抛出
     * `ForegroundServiceDidNotStartInTimeException` 杀掉进程。此时只记录停止期望并取消
     * 通知，服务会在 `startForeground()` 成功后自行 `stopSelf()`。
     */
    fun stop(context: Context) {
        val appContext = context.applicationContext
        val canStopSafely = synchronized(lock) {
            lifecycle.requestStop(android.os.SystemClock.uptimeMillis())
        }

        if (canStopSafely) {
            runCatching {
                appContext.stopService(VpnMonitorService.stopIntent(appContext))
            }.onFailure { e ->
                Log.w(TAG, "Failed to stop VpnMonitorService", e)
            }
        } else {
            Log.i(TAG, "Deferring monitor stop until startForeground() completes")
        }

        runCatching {
            val notificationManager = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(VpnMonitorService.NOTIFICATION_ID_VPN_MONITOR)
        }.onFailure { e ->
            Log.w(TAG, "Failed to cancel monitor notification", e)
        }
    }

    /**
     * 检查监控服务当前是否存活。
     */
    fun isMonitorAlive(): Boolean = VpnMonitorService.isServiceAlive

    /**
     * VPN 启动时的钩子：此时不需要常驻「未连接」通知。
     */
    fun onVpnStarted(context: Context) {
        stop(context)
    }

    /**
     * VPN 停止时的钩子：恢复常驻「未连接」通知。
     */
    fun onVpnStopped(context: Context) {
        sync(context)
    }

    private fun shouldMonitorBeStopped(appContext: Context): Boolean {
        return WorkModeStore.getAppWorkMode(appContext) == AppWorkMode.DNS ||
            !NotificationSettingsStore.isPersistentNotificationEnabled(appContext) ||
            !NotificationPermissionHelper.hasPermission(appContext) ||
            isVpnRunning(appContext)
    }
}
