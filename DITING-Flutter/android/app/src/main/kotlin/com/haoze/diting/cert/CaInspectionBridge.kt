package com.haoze.diting.cert

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import com.haoze.diting.platform.ChannelResults
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.concurrent.Executors
import tunnel.Engine

/// The MITM root CA; `installed` = SHA-256 match in the `user:` store, the only writable one.
class CaInspectionBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/https_inspection"

        const val EXPORTED_CERTIFICATE_NAME = "谛听-HTTPS-Inspection-Root-CA.crt"

        /// Engine() is too slow for the platform thread; a failed dlopen must surface
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "diting-ca").apply { isDaemon = true }
        }

        private const val MITM_DIR = "go-mitm"
        private const val CA_CERT_FILE = "ca.crt"
        private const val CA_KEY_FILE = "ca.key"
        private const val MITM_BLACKLIST_FILE = "mitm_blacklist.txt"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspectCa" -> {
                val regenerate = call.argument<Boolean>("regenerate") ?: false
                worker.execute {
                    val value = runCatching { inspect(regenerate) }
                    ChannelResults.ship(result, value, "ca_inspect_failed")
                }
            }
            "exportCa" -> {
                val uri = call.argument<String>("uri").orEmpty()
                worker.execute {
                    val value = runCatching { export(Uri.parse(uri)) }
                    ChannelResults.ship(result, value, "ca_export_failed")
                }
            }
            "openCaInstallSettings" -> result.success(openInstallSettings())
            else -> result.notImplemented()
        }
    }

    private fun inspect(regenerate: Boolean): Map<String, Any?> {
        if (regenerate) reset()

        // Engine() must be stopped: its DNS cache cleaner goroutine only exits via stop().
        val pem = runCatching {
            val engine = Engine()
            try {
                engine.startStackMitm(certificateDirectory().absolutePath)
            } finally {
                runCatching { engine.stopStackMitm() }
                runCatching { engine.stop() }
            }
        }.getOrElse { error ->
            // ABI mismatch (arm64-only libgojni.so on x86_64) shows up here and must be reported.
            return mapOf(
                "available" to false,
                "installed" to false,
                "fingerprintSha256" to null,
                "pem" to null,
                "error" to describe(error),
            )
        }

        if (pem.isEmpty()) {
            return mapOf(
                "available" to false,
                "installed" to false,
                "fingerprintSha256" to null,
                "pem" to null,
                "error" to "证书引擎未返回根证书",
            )
        }

        val fingerprint = runCatching { fingerprintOfPem(pem) }.getOrNull()
        return mapOf(
            "available" to true,
            "installed" to (fingerprint != null && isInstalled(fingerprint)),
            "fingerprintSha256" to fingerprint,
            "pem" to pem,
            // Present but unparsable: something this device's CertificateFactory rejects.
            "error" to if (fingerprint == null) "根证书无法解析" else null,
        )
    }

    private fun export(uri: Uri) {
        val pem = runCatching {
            val engine = Engine()
            try {
                engine.startStackMitm(certificateDirectory().absolutePath)
            } finally {
                runCatching { engine.stopStackMitm() }
                runCatching { engine.stop() }
            }
        }.getOrNull().orEmpty()
        require(pem.isNotEmpty()) { "证书引擎未返回根证书" }

        val stream = context.contentResolver.openOutputStream(uri, "w")
            ?: error("无法写入所选位置")
        stream.use { it.write(pem.toByteArray(Charsets.UTF_8)) }
    }

    /// Opens the security settings only; NEW_TASK is needed from applicationContext.
    private fun openInstallSettings(): Boolean = runCatching {
        context.startActivity(
            Intent(Settings.ACTION_SECURITY_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    }.getOrDefault(false)

    private fun reset() {
        certificateDirectory().listFiles()?.forEach { file ->
            if (file.name == CA_CERT_FILE ||
                file.name == CA_KEY_FILE ||
                file.name == MITM_BLACKLIST_FILE
            ) {
                runCatching { file.delete() }
            }
        }
    }

    private fun certificateDirectory(): File =
        File(context.filesDir, MITM_DIR).apply { mkdirs() }

    
    private fun isInstalled(fingerprint: String): Boolean = runCatching {
        val store = KeyStore.getInstance("AndroidCAStore").apply { load(null) }
        store.aliases().asSequence()
            .filter { it.startsWith("user:") }
            .mapNotNull { store.getCertificate(it) as? X509Certificate }
            .any { certificate -> fingerprintOfBytes(certificate.encoded) == fingerprint }
    }.getOrDefault(false)

    private fun fingerprintOfPem(pem: String): String {
        val certificate = CertificateFactory.getInstance("X.509")
            .generateCertificate(pem.byteInputStream()) as X509Certificate
        return fingerprintOfBytes(certificate.encoded)
    }

    /// Colon-separated uppercase hex, as displayed verbatim
    private fun fingerprintOfBytes(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString(":") { "%02X".format(it) }

    private fun describe(error: Throwable): String {
        val message = error.message.orEmpty()
        // UnsatisfiedLinkError's message is the only real diagnostic, so pass it through.
        
        return when {
            error is UnsatisfiedLinkError -> "证书引擎加载失败：$message"
            message.isEmpty() -> error.javaClass.simpleName
            else -> message
        }
    }
}
