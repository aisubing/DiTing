package com.haoze.diting.update

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.haoze.diting.BuildConfig
import com.haoze.diting.ui.settings.SystemSettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class AppUpdateInfo(
    val version: String,
    val downloadUrl: String,
    val fileName: String,
    val releaseNotes: String,
)

enum class AppUpdateDownloadStatus {
    Idle,
    Downloading,
    Downloaded,
    Failed,
}

data class AppUpdateDownloadState(
    val version: String = "",
    val localPath: String = "",
    val status: AppUpdateDownloadStatus = AppUpdateDownloadStatus.Idle,
    val downloadedBytes: Long = 0L,
    val totalBytes: Long = -1L,
)

data class AppUpdateUiState(
    val checking: Boolean = false,
    val availableUpdate: AppUpdateInfo? = null,
    val downloadState: AppUpdateDownloadState = AppUpdateDownloadState(),
    val message: String = "",
    val error: String = "",
)

class AppUpdateManager(
    private val context: Context,
    private val httpClient: OkHttpClient = OkHttpClient(),
) {
    private val updateDirectory = File(context.filesDir, UPDATE_DIRECTORY)

    suspend fun checkForUpdate(): AppUpdateInfo? = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(RELEASE_URL)
            .header("Accept", "application/vnd.github+json")
            .header("User-Agent", "DITING-Android")
            .build()
        httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("检查更新失败：GitHub 返回 ${response.code}")
            parseLatestRelease(response.body?.string().orEmpty(), BuildConfig.VERSION_NAME)
        }
    }

    suspend fun download(
        update: AppUpdateInfo,
        onProgress: (downloadedBytes: Long, totalBytes: Long) -> Unit,
    ): AppUpdateDownloadState = withContext(Dispatchers.IO) {
        val existing = refreshDownloadState(update)
        if (existing.status == AppUpdateDownloadStatus.Downloading || existing.status == AppUpdateDownloadStatus.Downloaded) {
            return@withContext existing
        }
        updateDirectory.mkdirs()
        val finalFile = File(updateDirectory, "update-${update.version}.apk")
        val temporaryFile = File(updateDirectory, ".update-${update.version}.apk.part")
        finalFile.delete()
        temporaryFile.delete()
        try {
            val request = Request.Builder()
                .url(update.downloadUrl)
                .header("User-Agent", "DITING-Android")
                .build()
            val downloadState = httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) error("下载更新失败：服务器返回 ${response.code}")
                val body = response.body ?: error("下载更新失败：响应内容为空")
                val totalBytes = body.contentLength().takeIf { it > 0L } ?: -1L
                var downloadedBytes = 0L
                var lastReportedBytes = -1L
                fun reportProgress(force: Boolean = false) {
                    if (force || downloadedBytes - lastReportedBytes >= PROGRESS_UPDATE_BYTES) {
                        onProgress(downloadedBytes, totalBytes)
                        lastReportedBytes = downloadedBytes
                    }
                }
                reportProgress(force = true)
                body.byteStream().use { input ->
                    temporaryFile.outputStream().buffered().use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            currentCoroutineContext().ensureActive()
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            downloadedBytes += read
                            reportProgress()
                        }
                    }
                }
                reportProgress(force = true)
                if (!temporaryFile.renameTo(finalFile)) error("下载更新失败：无法保存安装包")
                SystemSettingsStore.rememberAppUpdateDownload(context, finalFile.absolutePath, update.version)
                AppUpdateDownloadState(
                    version = update.version,
                    localPath = finalFile.absolutePath,
                    status = AppUpdateDownloadStatus.Downloaded,
                    downloadedBytes = downloadedBytes,
                    totalBytes = totalBytes,
                )
            }
            downloadState
        } catch (cancelled: kotlinx.coroutines.CancellationException) {
            temporaryFile.delete()
            throw cancelled
        } catch (_: Throwable) {
            temporaryFile.delete()
            finalFile.delete()
            // Only drop the persisted download record when it belongs to this
            // version: a failed download of a *newer* version must not wipe the
            // already-downloaded older APK's record, which would orphan the file
            // on disk and force a re-download.
            if (shouldClearDownloadRecord(
                    SystemSettingsStore.getAppUpdateDownloadVersion(context),
                    update.version
                )
            ) {
                SystemSettingsStore.clearAppUpdateDownload(context)
            }
            AppUpdateDownloadState(version = update.version, status = AppUpdateDownloadStatus.Failed)
        }
    }

    suspend fun refreshDownloadState(update: AppUpdateInfo): AppUpdateDownloadState = withContext(Dispatchers.IO) {
        val localPath = SystemSettingsStore.getAppUpdateDownloadPath(context)
        if (localPath.isBlank() || SystemSettingsStore.getAppUpdateDownloadVersion(context) != update.version) {
            return@withContext AppUpdateDownloadState(version = update.version)
        }
        if (!File(localPath).isFile || File(localPath).length() <= 0L) {
            SystemSettingsStore.clearAppUpdateDownload(context)
            return@withContext AppUpdateDownloadState(version = update.version)
        }
        AppUpdateDownloadState(
            version = update.version,
            localPath = localPath,
            status = AppUpdateDownloadStatus.Downloaded,
            downloadedBytes = File(localPath).length(),
            totalBytes = File(localPath).length(),
        )
    }

    fun installDownloadedUpdate(update: AppUpdateInfo): Boolean {
        return runCatching {
            val path = SystemSettingsStore.getAppUpdateDownloadPath(context)
            check(path.isNotBlank() && SystemSettingsStore.getAppUpdateDownloadVersion(context) == update.version)
            val apkFile = File(path)
            check(apkFile.isFile && apkFile.length() > 0L)
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", apkFile)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(intent)
        }.isSuccess
    }

    companion object {
        /** 更新安装包的下载目录名，数据清理等外部模块需与之保持一致。 */
        const val UPDATE_DIRECTORY = "app-update"
        private const val RELEASE_URL = "https://api.github.com/repos/haoze-evolluling/DITING/releases/latest"
        private const val PROGRESS_UPDATE_BYTES = 256L * 1024L
    }
}

/**
 * Whether the persisted download record must be dropped after a failed
 * download. A record for a *different* version still points at a valid APK and
 * must be preserved; wiping it would orphan the file and force a re-download.
 */
internal fun shouldClearDownloadRecord(recordedVersion: String?, failedVersion: String): Boolean {
    if (recordedVersion.isNullOrBlank()) return false
    return recordedVersion == failedVersion
}

internal fun parseLatestRelease(payload: String, currentVersion: String): AppUpdateInfo? {
    val release = JSONObject(payload)
    val remoteVersion = release.optString("tag_name").trim()
    if (!isNewerVersion(remoteVersion, currentVersion)) return null
    val assets = release.optJSONArray("assets") ?: JSONArray()
    val asset = (0 until assets.length())
        .mapNotNull { index -> assets.optJSONObject(index) }
        .firstOrNull { it.optString("name").endsWith(".apk", ignoreCase = true) && it.optString("name").contains("arm64-v8a", ignoreCase = true) }
        ?: (0 until assets.length())
            .mapNotNull { index -> assets.optJSONObject(index) }
            .firstOrNull { it.optString("name").endsWith(".apk", ignoreCase = true) }
        ?: error("最新版本未提供 Android APK")
    val downloadUrl = asset.optString("browser_download_url").trim()
    if (downloadUrl.isBlank()) error("更新包下载地址无效")
    return AppUpdateInfo(
        version = remoteVersion.removePrefix("v"),
        downloadUrl = downloadUrl,
        fileName = asset.optString("name").ifBlank { "谛听-$remoteVersion.apk" },
        releaseNotes = release.optString("body").trim(),
    )
}

internal fun isNewerVersion(remote: String, current: String): Boolean {
    fun components(value: String): List<Int>? {
        val normalized = value.trim().removePrefix("v").substringBefore('-')
        if (normalized.isBlank()) return null
        return normalized.split('.').map { part -> part.toIntOrNull() ?: return null }
    }

    val remoteParts = components(remote) ?: return false
    val currentParts = components(current) ?: return false
    val length = maxOf(remoteParts.size, currentParts.size)
    repeat(length) { index ->
        val difference = remoteParts.getOrElse(index) { 0 }.compareTo(currentParts.getOrElse(index) { 0 })
        if (difference != 0) return difference > 0
    }
    return false
}

