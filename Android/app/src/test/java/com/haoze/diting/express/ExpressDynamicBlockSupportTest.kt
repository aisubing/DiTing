package com.haoze.diting.express

import com.haoze.diting.core.rule.DynamicBlockResponseConfig
import com.haoze.diting.data.RuleDataset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for A-081: Express mode stores and renders the dynamic
 * block-response setting, but its pure Kotlin engine has no escalation path.
 * The UI must report the behaviour actually in force instead of echoing the
 * stored flag.
 */
class ExpressDynamicBlockSupportTest {

    private val enabledConfig = DynamicBlockResponseConfig(enabled = true)
    private val disabledConfig = DynamicBlockResponseConfig(enabled = false)

    @Test
    fun `escalation is never applied in express mode`() {
        assertFalse(ExpressDynamicBlockSupport.isEscalationApplied(RuleDataset.EXPRESS))
    }

    @Test
    fun `escalation is applied everywhere except express mode`() {
        // NORMAL feeds `dynamicResponse` via normal/HttpsDnsConfigSnapshot.kt;
        // DNS mode feeds it via DnsDynamicBlockJson, which DnsServerEngine's
        // applyDnsConfig() now includes; both run the Go tracker.
        assertTrue(ExpressDynamicBlockSupport.isEscalationApplied(RuleDataset.NORMAL))
        assertTrue(ExpressDynamicBlockSupport.isEscalationApplied(RuleDataset.DNS_MODE))
        // Express runs the pure Kotlin engine, which has no tracker at all.
        assertFalse(ExpressDynamicBlockSupport.isEscalationApplied(RuleDataset.EXPRESS))
    }

    @Test
    fun `an enabled config is misleading only in express mode`() {
        assertTrue(ExpressDynamicBlockSupport.isMisleadingFor(RuleDataset.EXPRESS, enabledConfig))
        assertFalse(ExpressDynamicBlockSupport.isMisleadingFor(RuleDataset.NORMAL, enabledConfig))
        assertFalse(ExpressDynamicBlockSupport.isMisleadingFor(RuleDataset.DNS_MODE, enabledConfig))
        // A disabled config claims nothing, so it is never misleading.
        assertFalse(ExpressDynamicBlockSupport.isMisleadingFor(RuleDataset.EXPRESS, disabledConfig))
    }

    @Test
    fun `express subtitle reports the fixed policy instead of the stored dynamic flag`() {
        val subtitle = ExpressDynamicBlockSupport.blockResponseSubtitle(
            dataset = RuleDataset.EXPRESS,
            config = enabledConfig,
            blockResponseModeDisplayName = "NXDOMAIN"
        )
        assertTrue("must not promise the inactive dynamic policy", !subtitle.contains("动态策略"))
        assertTrue("must state the policy actually in force", subtitle.contains("NXDOMAIN"))
        assertTrue(subtitle.contains("极速模式"))
    }

    @Test
    fun `normal dataset keeps the existing dynamic subtitle`() {
        assertEquals(
            "动态策略：先 NODATA，高频请求后 NXDOMAIN",
            ExpressDynamicBlockSupport.blockResponseSubtitle(
                dataset = RuleDataset.NORMAL,
                config = enabledConfig,
                blockResponseModeDisplayName = "NXDOMAIN"
            )
        )
    }

    @Test
    fun `dns mode now reports the live dynamic policy like normal mode`() {
        // With the DNS mode snapshot carrying `dynamicResponse`, DNS mode really
        // escalates, so it must show the same truthful subtitle as NORMAL and
        // must not be labelled as express.
        assertEquals(
            "动态策略：先 NODATA，高频请求后 NXDOMAIN",
            ExpressDynamicBlockSupport.blockResponseSubtitle(
                dataset = RuleDataset.DNS_MODE,
                config = enabledConfig,
                blockResponseModeDisplayName = "NODATA"
            )
        )
    }

    @Test
    fun `disabled config shows the fixed block response mode`() {
        assertEquals(
            "当前：NXDOMAIN",
            ExpressDynamicBlockSupport.blockResponseSubtitle(
                dataset = RuleDataset.EXPRESS,
                config = disabledConfig,
                blockResponseModeDisplayName = "NXDOMAIN"
            )
        )
        assertEquals(
            "当前：NODATA",
            ExpressDynamicBlockSupport.blockResponseSubtitle(
                dataset = RuleDataset.NORMAL,
                config = disabledConfig,
                blockResponseModeDisplayName = "NODATA"
            )
        )
    }
}
