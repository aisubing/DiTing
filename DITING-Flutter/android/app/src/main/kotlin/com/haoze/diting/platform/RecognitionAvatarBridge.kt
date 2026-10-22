package com.haoze.diting.platform

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 赞助 / 共建名单头像的本地磁盘缓存。
 *
 * 头像图片**不随 APK 发布**：名单与头像都以 GitHub 上的
 * `recognition_members.json` + `avatars/` 为准，改完推送即生效。代价是每张头像
 * 都要联网取一次，所以取回来的字节必须落在本地，否则每次冷启动都会重下十几张图。
 *
 * Dart 侧没有 `path_provider` 依赖（本仓不引新依赖），拿不到应用私有目录，因此
 * 磁盘这一层放在原生。取文件走 `Image.memory`（Dart 侧仍有进程内缓存），所以这里
 * 只需要三个动作：查已有、写一张、删一张。
 *
 * 与旧版 `RecognitionAvatarRepository` 对齐：
 * - 目录 `filesDir/recognition_avatars/`；
 * - 先写 `.part` 再 `renameTo`，避免进程被杀时留下半张图；
 * - 文件名按白名单正则校验，杜绝 `../` 之类的路径穿越；
 * - 1MB 上限，异常大图直接拒收。
 */
class RecognitionAvatarBridge(private val context: android.content.Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/recognition"

        private const val DIR = "recognition_avatars"
        private const val MAX_BYTES = 1024 * 1024

        /** 与 `docs/development/recognition-members.md` 的命名规则一致。 */
        private val NAME_PATTERN = Regex("^[a-z0-9_]+_avatar\\.jpg$")
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> read(call, result)
            "write" -> write(call, result)
            "remove" -> remove(call, result)
            "clear" -> clear(result)
            else -> result.notImplemented()
        }
    }

    private fun read(call: MethodCall, result: MethodChannel.Result) {
        val file = fileFor(call.argument<String>("name"))
        if (file == null || !file.isFile || file.length() <= 0L) {
            result.success(null)
            return
        }
        Thread {
            val bytes = runCatching { file.readBytes() }.getOrNull()
            ChannelResults.success(result, bytes)
        }.start()
    }

    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val file = fileFor(call.argument<String>("name"))
        val bytes = call.argument<ByteArray>("bytes")
        if (file == null || bytes == null || bytes.isEmpty() || bytes.size > MAX_BYTES) {
            result.success(null)
            return
        }
        Thread {
            val path = runCatching { writeAtomically(file, bytes) }.getOrNull()
            ChannelResults.success(result, path)
        }.start()
    }

    private fun remove(call: MethodCall, result: MethodChannel.Result) {
        val file = fileFor(call.argument<String>("name"))
        result.success(file != null && runCatching { file.delete() }.getOrDefault(false))
    }

    private fun clear(result: MethodChannel.Result) {
        Thread {
            val removed = runCatching {
                cacheDir().listFiles()?.count { it.isFile && it.delete() } ?: 0
            }.getOrDefault(0)
            ChannelResults.success(result, removed)
        }.start()
    }

    private fun cacheDir(): File = File(context.filesDir, DIR).apply { mkdirs() }

    /** 只接受白名单文件名；其余一律当作「查不到」，不碰文件系统。 */
    private fun fileFor(name: String?): File? {
        val trimmed = name?.trim().orEmpty()
        if (!NAME_PATTERN.matches(trimmed)) return null
        return File(cacheDir(), trimmed)
    }

    private fun writeAtomically(target: File, bytes: ByteArray): String? {
        val temp = File(target.parentFile, target.name + ".part")
        val ok = runCatching { temp.outputStream().use { it.write(bytes) } }.isSuccess
        if (!ok) {
            temp.delete()
            return null
        }
        if (target.exists()) target.delete()
        return if (temp.renameTo(target)) target.absolutePath else null
    }
}
