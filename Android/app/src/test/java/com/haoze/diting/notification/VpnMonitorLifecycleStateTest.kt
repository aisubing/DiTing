package com.haoze.diting.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 锁定本次冷启动崩溃（ForegroundServiceDidNotStartInTimeException）的修复不变量。
 *
 * 崩溃链路（AOSP ActiveServices）：`startForegroundService()` 在服务记录上挂起
 * `fgRequired=true`；在成功 `startForeground()` 之前若拆除该记录，`bringDownServiceLocked()`
 * 会立刻发出 `SERVICE_FOREGROUND_CRASH_MSG`（无延迟）杀掉进程。
 */
class VpnMonitorLifecycleStateTest {

    private fun newState() = VpnMonitorLifecycleState(inFlightTimeoutMs = 10_000L)

    @Test
    fun `stop is refused while a start foreground obligation is outstanding`() {
        val state = newState()
        assertTrue(state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L))
        assertTrue(state.startInFlight)

        // 关键不变量：义务未兑现时必须拒绝 stopService()。
        assertFalse(state.requestStop(0L))
        assertTrue(state.stopRequested)
    }

    @Test
    fun `stop becomes safe after the service reports promotion`() {
        val state = newState()
        state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L)
        assertFalse(state.requestStop(0L))

        state.onPromoted()
        assertFalse(state.startInFlight)
        assertTrue(state.requestStop(0L))
    }

    @Test
    fun `stop is safe when the service instance is already alive`() {
        val state = newState()
        // 服务已存在（onCreate 跑过）时无需再下发启动，停止始终安全。
        assertFalse(state.requestStart(isServiceAlive = true, nowUptimeMillis = 0L))
        assertFalse(state.startInFlight)
        assertTrue(state.requestStop(0L))
    }

    @Test
    fun `duplicate start requests are collapsed while a start is in flight`() {
        val state = newState()
        assertTrue(state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L))
        // 冷启动时 MainActivity.onCreate 与 onResume 会连续调用 sync()，
        // 重复下发会反复把 AMS 的 fgRequired 置位，只会扩大崩溃窗口。
        assertFalse(state.requestStart(isServiceAlive = false, nowUptimeMillis = 10L))
        assertFalse(state.requestStart(isServiceAlive = false, nowUptimeMillis = 5_000L))
        assertTrue(state.startInFlight)
    }

    @Test
    fun `a stale in flight start is allowed to retry after the timeout`() {
        val state = newState()
        assertTrue(state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L))
        // 超过超时仍未见服务实例：视为上一次启动已失败，允许重新下发。
        assertTrue(state.requestStart(isServiceAlive = false, nowUptimeMillis = 10_001L))
    }

    @Test
    fun `start failure rolls back the in flight marker`() {
        val state = newState()
        assertTrue(state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L))
        state.onStartFailed()
        assertFalse(state.startInFlight)
        // 回滚后停止是安全的，且允许再次尝试启动。
        assertTrue(state.requestStop(0L))
        assertTrue(state.requestStart(isServiceAlive = false, nowUptimeMillis = 20L))
    }

    @Test
    fun `service destruction clears the in flight marker`() {
        val state = newState()
        state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L)
        state.onServiceDestroyed()
        assertFalse(state.startInFlight)
        assertTrue(state.requestStop(0L))
    }

    @Test
    fun `stop unblocks once the in flight start is provably stale`() {
        val state = newState()
        state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L)
        // 义务未兑现期间必须拦截停止。
        assertFalse(state.requestStop(0L))

        // 超过超时仍未收到 onPromoted/onServiceDestroyed：那次启动已被系统丢弃，
        // 停止请求不能被永久拦截。
        assertTrue(state.requestStop(10_000L))
        assertFalse(state.startInFlight)
    }

    @Test
    fun `sync after stop clears the stop request`() {
        val state = newState()
        state.requestStart(isServiceAlive = false, nowUptimeMillis = 0L)
        state.requestStop(0L)
        assertTrue(state.stopRequested)

        // 新一轮 sync 重新表达「应当运行」，服务不应自停。
        state.requestStart(isServiceAlive = false, nowUptimeMillis = 11_000L)
        assertFalse(state.stopRequested)
        assertFalse(state.startInFlight && state.stopRequested)
    }
}
