package com.haoze.diting.proxy

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * AES-GCM wrapper for the outbound-proxy credentials, byte-compatible with
 * 1.4.3's `OutboundProxySettingsStore.encryptProxySecret` / `decryptProxySecret`.
 *
 * The on-disk format is `Base64(iv + ciphertext)` with a 12-byte IV and a
 * 128-bit tag, produced by the AndroidKeyStore key `diting_outbound_proxy`.
 * Reproducing it exactly is not cosmetic: an upgrade install must be able to
 * decrypt the credentials the user already saved. A different alias, IV length,
 * or padding would silently yield an empty password and every proxied request
 * would start failing with a 407.
 *
 * Every failure path collapses to "" (`decrypt`) or "" (`encrypt`), matching the
 * legacy `runCatching { ... }.getOrDefault("")`: a bricked keystore (device
 * restore, key invalidation) must not crash the settings page.
 */
internal object ProxySecretCodec {

    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "diting_outbound_proxy"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val IV_LENGTH = 12
    private const val TAG_BITS = 128

    fun encrypt(value: String): String {
        if (value.isEmpty()) return ""
        return runCatching {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            val payload = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            Base64.encodeToString(payload, Base64.NO_WRAP)
        }.getOrDefault("")
    }

    fun decrypt(value: String?): String {
        if (value.isNullOrEmpty()) return ""
        return runCatching {
            val payload = Base64.decode(value, Base64.NO_WRAP)
            // A truncated payload would throw on copyOfRange; the range check
            // keeps the failure inside runCatching instead of an IndexOutOfBounds.
            require(payload.size > IV_LENGTH) { "payload too short" }
            val iv = payload.copyOfRange(0, IV_LENGTH)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(TAG_BITS, iv))
            String(cipher.doFinal(payload.copyOfRange(IV_LENGTH, payload.size)), Charsets.UTF_8)
        }.getOrDefault("")
    }

    /** Loads the existing key, creating it on first use. */
    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }
}
