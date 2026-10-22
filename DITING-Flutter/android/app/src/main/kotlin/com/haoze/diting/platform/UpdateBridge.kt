package com.haoze.diting.platform

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * 应用更新的原生半边：下载安装包 + 调起系统安装器。
 *
 * 1.4.3 的 `AppUpdateManager` 把 APK 下到 `filesDir/app-update/update-<ver>.apk`，
 * 再用 `FileProvider` 生成一个 `content://` URI，通过 `ACTION_VIEW` +
 * `application/vnd.android.package-archive` 交给系统安装器。这两步都没有 Dart
 * 等价物（Dart 无法写应用私有目录后授予别的应用读取权，也无法直接拉起安装器），
 * 因此单独一条通道。
 *
 * 为什么另开 `com.haoze.diting/update` 而不是塞进 `PlatformBridge`：
 * `PlatformBridge` 已经 542 行、接近 600 行上限；下载与安装的生命周期（后台线程、
 * 进度回推）也和那四个「一次性系统调用」不同，混在一起会让两件事都难读。
 *
 * ## 进度回推
 *
 * 下载在后台线程跑，通过同一条通道反向 `invokeMethod("progress", …)` 把
 * `{downloaded, total}` 推给 Dart。`MethodChannel.invokeMethod` 必须在主线程调用，
 * 所以每次 `activity.runOnUiThread`。Dart 侧用 `setMethodCallHandler` 接这两类事件。
 */
class UpdateBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/update"

        /** 1.4.3 `AppUpdateManager.UPDATE_DIRECTORY`（与本包清理逻辑同口径）。 */
        private const val UPDATE_DIR = "app-update"

        /** 连接/读取超时：GitHub 资产走 CDN，给宽松一点但仍会失败退出。 */
        private const val CONNECT_TIMEOUT_MS = 20_000
        private const val READ_TIMEOUT_MS = 30_000
    }

    private val context: Activity get() = activity
    private var channel: MethodChannel? = null

    /** 同一时刻只允许一个下载，避免两个线程写同一个 `.part` 文件。 */
    @Volatile
    private var downloading = false

    fun register(messenger: BinaryMessenger) {
        val methodChannel = MethodChannel(messenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "download" -> download(call, result)
            "install" -> install(call, result)
            else -> result.notImplemented()
        }
    }

    // --------------------------------------------------------------- 下载

    /**
     * 下载 [url] 到 `filesDir/app-update/update-<version>.apk`，完成后把绝对路径
     * 作为结果返回。
     *
     * 先写 `.part` 临时文件再改名：下载中断时不会留下一个「看起来完整」的 APK，
     * 否则用户点安装会得到「解析包出错」而不是重下。
     */
    private fun download(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")?.trim().orEmpty()
        val version = call.argument<String>("version")?.trim().orEmpty()
        if (url.isEmpty()) {
            result.error("invalid_url", "下载地址为空", null)
            return
        }
        if (downloading) {
            result.error("busy", "另一个更新正在下载", null)
            return
        }
        downloading = true
        val dir = File(context.filesDir, UPDATE_DIR).apply { mkdirs() }
        val safeVersion = version.ifEmpty { "latest" }.replace(Regex("[^0-9A-Za-z._-]"), "_")
        val finalFile = File(dir, "update-$safeVersion.apk")
        val tempFile = File(dir, ".update-$safeVersion.apk.part")
        finalFile.delete()
        tempFile.delete()

        Thread {
            var connection: HttpURLConnection? = null
            try {
                connection = (URL(url).openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = true
                    connectTimeout = CONNECT_TIMEOUT_MS
                    readTimeout = READ_TIMEOUT_MS
                    setRequestProperty("User-Agent", "DITING-Android")
                }
                val code = connection.responseCode
                if (code !in 200..299) {
                    failDownload(result, "下载更新失败：服务器返回 $code")
                    return@Thread
                }
                val total = connection.contentLengthLong.takeIf { it > 0L } ?: -1L
                var downloaded = 0L
                connection.inputStream.use { input ->
                    tempFile.outputStream().buffered().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var lastReported = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            downloaded += read
                            // 每 ~256KB 或到末尾推一次进度：太密会在主线程堆消息。
                            if (downloaded - lastReported >= 256 * 1024) {
                                lastReported = downloaded
                                emitProgress(downloaded, total)
                            }
                        }
                    }
                }
                if (!tempFile.renameTo(finalFile)) {
                    // 某些机型 rename 跨目录失败：退回复制。
                    tempFile.copyTo(finalFile, overwrite = true)
                    tempFile.delete()
                }
                emitProgress(downloaded, total)
                downloading = false
                activity.runOnUiThread { result.success(finalFile.absolutePath) }
            } catch (error: Exception) {
                runCatching { tempFile.delete() }
                failDownload(result, "下载更新失败：${error.message ?: error.javaClass.simpleName}")
            } finally {
                runCatching { connection?.disconnect() }
            }
        }.start()
    }

    private fun failDownload(result: MethodChannel.Result, message: String) {
        downloading = false
        activity.runOnUiThread { result.error("download_failed", message, null) }
    }

    private fun emitProgress(downloaded: Long, total: Long) {
        activity.runOnUiThread {
            channel?.invokeMethod(
                "progress",
                mapOf("downloaded" to downloaded, "total" to total),
            )
        }
    }

    // --------------------------------------------------------------- 安装

    /**
     * 调起系统安装器。
     *
     * 传的是下载得到的**绝对路径**（不是 URI）：FileProvider 的 authority 必须由
     * 原生侧按包名拼，Dart 拿不到也不知道。
     *
     * 未授予「安装未知应用」权限时，安装器会自己弹出授权引导——不预先拦截，
     * 那样会把用户挡在一次系统弹窗之外。
     */
    private fun install(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")?.trim().orEmpty()
        if (path.isEmpty()) {
            result.error("invalid_path", "安装包路径为空", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("missing_file", "安装包不存在，请重新下载", null)
            return
        }
        val ok = runCatching {
            val uri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }.isSuccess
        if (ok) {
            result.success(true)
        } else {
            result.error("install_failed", "无法调起系统安装器", null)
        }
    }

    /** 让系统在 Android 8+ 上识别到「安装未知应用」的授权入口所需（manifest 已声明）。 */
    @Suppress("unused")
    private fun needsInstallPermission(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
}
