package com.haoze.diting.platform

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * 软件背景的原生半边：选图 + 把系统 `content://` 图缓存成本地文件。
 *
 * 为什么必须在原生：
 * - **选图** 是 `ACTION_OPEN_DOCUMENT`，需要一个 `Activity` 和 `onActivityResult`
 *   往返；
 * - **解码** 用 `BitmapFactory` 采样，才能在不 OOM 的前提下把大图缩到屏幕尺寸，
 *   并把 HEIC 这类 Flutter 解不了的格式统一转成 PNG。缓存成普通文件后 Dart 侧
 *   用 `Image.file` 即可，无需每次都跨 Binder 读 `content://`。
 *
 * 缓存文件按 URI 的 SHA-1 命名，放在 `filesDir/background/`。与 1.4.3
 * `CustomBackgroundManager` 的单文件缓存不同：旧版只缓存「当前哪张」，切换时覆盖；
 * 这里按 URI 分文件，设置页的多张缩略图才不必反复解码。
 */
class BackgroundBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/background"

        /** 与 VPN / 文档选择器的请求码都不同。 */
        private const val REQUEST_PICK_IMAGE = 0x5703

        /** 缓存目录名（不是清理逻辑里的 `custom_background_cached.png`）。 */
        private const val CACHE_DIR = "background"

        /** 解码后最长边上限；越大越清晰，但内存与磁盘占用同步上升。 */
        private const val MAX_DIMENSION = 2048
    }

    private val context: Activity get() = activity
    private var pendingPickResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "resolve" -> resolve(call, result)
            "release" -> release(call, result)
            else -> result.notImplemented()
        }
    }

    // --------------------------------------------------------------- 选图

    private fun pick(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("picker_busy", "另一个图片选择器仍在打开", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_PICK_IMAGE) }
            .onFailure {
                pendingPickResult = null
                result.error("picker_failed", it.message, null)
            }
    }

    /** 由 `MainActivity.onActivityResult` 调用；返回 true 表示这是本 bridge 的请求。 */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_IMAGE) return false
        val pending = pendingPickResult ?: return true
        pendingPickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(mapOf("cancelled" to true))
            return true
        }
        Thread {
            runCatching {
                // 之后重建缓存时要能重新读取这张 content:// 图。
                activity.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            val path = runCatching { cacheImage(uri) }.getOrNull()
            activity.runOnUiThread {
                if (path == null) {
                    pending.error("decode_failed", "无法读取所选图片", null)
                } else {
                    pending.success(
                        mapOf(
                            "cancelled" to false,
                            "uri" to uri.toString(),
                            "path" to path,
                        ),
                    )
                }
            }
        }.start()
        return true
    }

    // --------------------------------------------------------------- 缓存

    /** 返回某个 URI 的本地缓存路径；不存在就现解一次。 */
    private fun resolve(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.trim().orEmpty()
        if (uri.isEmpty()) {
            result.success(null)
            return
        }
        val cached = cacheFileFor(uri)
        if (cached.exists() && cached.length() > 0) {
            result.success(cached.absolutePath)
            return
        }
        Thread {
            val path = runCatching { cacheImage(Uri.parse(uri)) }.getOrNull()
            activity.runOnUiThread { result.success(path) }
        }.start()
    }

    private fun release(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.trim().orEmpty()
        if (uri.isEmpty()) {
            result.success(true)
            return
        }
        result.success(runCatching { cacheFileFor(uri).delete() }.getOrDefault(false))
    }

    private fun cacheDir(): File = File(context.filesDir, CACHE_DIR).apply { mkdirs() }

    private fun cacheFileFor(uri: String): File =
        File(cacheDir(), "bg_" + sha1(uri).take(20) + ".png")

    private fun sha1(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-1").digest(value.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * 采样解码后写成 PNG。返回缓存文件的绝对路径。
     *
     * 采样上限 [MAX_DIMENSION]：壁纸最终只铺满一个屏幕，超过就纯属浪费内存。
     * 统一转 PNG 是为了顺带兼容 Flutter `Image` 不支持、但系统能解的格式（HEIC）。
     */
    private fun cacheImage(uri: Uri): String? {
        val resolver = activity.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, MAX_DIMENSION)
        }
        val bitmap = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        } ?: return null

        val target = cacheFileFor(uri.toString())
        val temp = File(target.parentFile, target.name + ".part")
        val ok = runCatching {
            temp.outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
        }.isSuccess
        bitmap.recycle()
        if (!ok) {
            temp.delete()
            return null
        }
        if (target.exists()) target.delete()
        return if (temp.renameTo(target)) target.absolutePath else null
    }

    private fun sampleSize(width: Int, height: Int, max: Int): Int {
        var size = 1
        while (width / (size * 2) >= max && height / (size * 2) >= max) {
            size *= 2
        }
        return size
    }
}
