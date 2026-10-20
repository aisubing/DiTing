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

/**
 * Native side of `com.haoze.diting/https_inspection`: the MITM root CA.
 *
 * 1.4.3 drove `GoInspectionCaManager` (the engine mints `ca.crt` / `ca.key` under
 * `filesDir/go-mitm`); the Flutter port hardcoded a fingerprint, so the page could
 * not tell "not generated yet" from "generated but not trusted by Android".
 *
 * Two facts are reported separately on purpose:
 * - `available`: the engine produced a certificate (PEM readable, fingerprint
 *   computable). Without it HTTPS inspection cannot work at all.
 * - `installed`: that certificate's SHA-256 matches an entry in `AndroidCAStore`
 *   under `user:`. Only the *user* store counts — an app cannot write the system
 *   store, and the legacy manager filtered on the `user:` prefix for exactly this
 *   reason. Claiming `installed` from any other source would let the UI enable
 *   inspection that will fail on every handshake.
 *
 * Contract frozen by `lib/data/native/ca_bridge.dart`:
 * - `inspectCa(regenerate)` -> `{available,installed,fingerprintSha256,pem,error}`
 * - `exportCa(uri)` -> null
 * - `openCaInstallSettings` -> Boolean
 */
class CaInspectionBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.haoze.diting/https_inspection"

        /** Same file name 1.4.3 offered in the system "save document" picker. */
        const val EXPORTED_CERTIFICATE_NAME = "谛听-HTTPS-Inspection-Root-CA.crt"

        /**
         * `Engine()` loads the Go shared library and allocates a DNS cache; both
         * are far too slow for the platform thread, and a failed `dlopen` must be
         * reported as `error` instead of crashing the app.
         */
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

        // A throwaway Engine is the only way to materialise the CA; it *must* be
        // torn down. 1.4.3's comment is explicit: Engine() allocates a DNS cache
        // whose cleaner goroutine only stops via stop(), so leaking the instance
        // leaked a goroutine per call.
        val pem = runCatching {
            val engine = Engine()
            try {
                engine.startStackMitm(certificateDirectory().absolutePath)
            } finally {
                runCatching { engine.stopStackMitm() }
                runCatching { engine.stop() }
            }
        }.getOrElse { error ->
            // ABI mismatch (`libgojni.so` not found on an x86_64 emulator running
            // an arm64-only AAR) surfaces here; the page must show it, not die.
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
            // The certificate exists but cannot be parsed: the engine wrote
            // something this device's CertificateFactory rejects.
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

    /**
     * Android gives an app no way to install a CA silently. This only navigates
     * to the security settings screen, matching 1.4.3's flow: the user saves the
     * exported file, then installs it from "install from storage".
     *
     * `FLAG_ACTIVITY_NEW_TASK` is required because this runs from a non-Activity
     * context (`applicationContext` in MainActivity), and starting an activity
     * from one without the flag throws `AndroidRuntimeException`.
     */
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

    /** True when [fingerprint] appears in the *user* trust store. */
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

    /** Colon-separated uppercase hex — the format 1.4.3 displayed verbatim. */
    private fun fingerprintOfBytes(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString(":") { "%02X".format(it) }

    private fun describe(error: Throwable): String {
        val message = error.message.orEmpty()
        // UnsatisfiedLinkError's message is the only diagnostic the user can act
        // on ("install an ABI-matching build"), so it is passed through with a
        // human prefix instead of a generic failure.
        return when {
            error is UnsatisfiedLinkError -> "证书引擎加载失败：$message"
            message.isEmpty() -> error.javaClass.simpleName
            else -> message
        }
    }
}
