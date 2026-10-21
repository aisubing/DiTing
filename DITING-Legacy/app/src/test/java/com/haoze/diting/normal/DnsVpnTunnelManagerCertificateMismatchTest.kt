package com.haoze.diting.normal

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-077: the MITM decision for a VPN session comes from the *cached*
 * `isHttpsInspectionReady` flag. The real certificate check runs asynchronously
 * afterwards and used to only write prefs — the running tunnel was never
 * touched, so a stale cache (user uninstalled the CA, or installed it while the
 * app believed otherwise) silently disabled/enabled inspection for the whole
 * session. When the real result disagrees with the value the session was built
 * with, the tunnel now has to restart.
 */
class DnsVpnTunnelManagerCertificateMismatchTest {

    @Test
    fun sessionAssumedInstalledButActuallyMissingRequiresRestart() {
        assertTrue(
            DnsVpnTunnelManager.shouldRestartForCertificateStateMismatch(
                stateUsedForSession = true,
                actualInstalled = false
            )
        )
    }

    @Test
    fun sessionAssumedMissingButActuallyInstalledRequiresRestart() {
        assertTrue(
            DnsVpnTunnelManager.shouldRestartForCertificateStateMismatch(
                stateUsedForSession = false,
                actualInstalled = true
            )
        )
    }

    @Test
    fun matchingStatesDoNotRestart() {
        assertFalse(
            DnsVpnTunnelManager.shouldRestartForCertificateStateMismatch(
                stateUsedForSession = true,
                actualInstalled = true
            )
        )
        assertFalse(
            DnsVpnTunnelManager.shouldRestartForCertificateStateMismatch(
                stateUsedForSession = false,
                actualInstalled = false
            )
        )
    }
}
