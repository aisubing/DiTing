package com.haoze.diting.core.rule

import com.haoze.diting.data.RuleDataSources
import com.haoze.diting.data.dao.AllowRuleDao
import com.haoze.diting.data.dao.BlockRuleDao
import com.haoze.diting.data.dao.CosmeticRuleDao
import com.haoze.diting.data.dao.GoUrlRuleDao
import com.haoze.diting.data.dao.MirrorTemplateDao
import com.haoze.diting.data.dao.RewriteRuleDao
import com.haoze.diting.data.dao.SubscriptionAutoUpdateDao
import com.haoze.diting.data.dao.SubscriptionDao
import com.haoze.diting.data.dao.SubscriptionGroupDao
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy

/**
 * A-039: interrupted-import recovery only cleaned the block / allow / rewrite
 * staging rows. A staging import also writes URL and cosmetic rules, and nothing
 * else ever deletes a `staging_sub_<id>` source, so those rows leaked forever.
 */
class SubscriptionImportRecoveryStagingTest {

    private val deletedSources = mutableListOf<String>()

    private fun proxyOf(iface: Class<*>): Any = Proxy.newProxyInstance(
        iface.classLoader,
        arrayOf(iface)
    ) { _, method, args ->
        when (method.name) {
            "deleteBySource" -> {
                deletedSources.add(args[0] as String)
                Unit
            }
            // deleteBySource is a @Transaction default method on the real DAO; the
            // proxy replaces it, so nothing else is reached.
            else -> null
        }
    }

    private fun createSources(): RuleDataSources = object : RuleDataSources {
        override fun blockRuleDao() = proxyOf(BlockRuleDao::class.java) as BlockRuleDao
        override fun allowRuleDao() = proxyOf(AllowRuleDao::class.java) as AllowRuleDao
        override fun rewriteRuleDao() = proxyOf(RewriteRuleDao::class.java) as RewriteRuleDao
        override fun goUrlRuleDao() = proxyOf(GoUrlRuleDao::class.java) as GoUrlRuleDao
        override fun cosmeticRuleDao() = proxyOf(CosmeticRuleDao::class.java) as CosmeticRuleDao
        override fun subscriptionDao(): SubscriptionDao = throw UnsupportedOperationException()
        override fun subscriptionGroupDao(): SubscriptionGroupDao = throw UnsupportedOperationException()
        override fun subscriptionAutoUpdateDao(): SubscriptionAutoUpdateDao = throw UnsupportedOperationException()
        override fun mirrorTemplateDao(): MirrorTemplateDao = throw UnsupportedOperationException()
    }

    @Test
    fun stagingCleanupCoversEveryRuleFamily() = runBlocking {
        deletedSources.clear()
        SubscriptionImportRecovery.deleteSource(createSources(), "staging_sub_42")

        // Exactly one delete per family, all for the requested source. A missing
        // family here is the defect: its staging rows would never be reclaimed.
        assertEquals(5, deletedSources.size)
        assertTrue(deletedSources.all { it == "staging_sub_42" })
    }

    @Test
    fun bothStagingAndCommittedSourcesAreCleaned() = runBlocking {
        deletedSources.clear()
        val sources = createSources()

        SubscriptionImportRecovery.deleteSource(sources, "staging_sub_42")
        SubscriptionImportRecovery.deleteSource(sources, "sub_42")

        assertEquals(10, deletedSources.size)
        assertEquals(5, deletedSources.count { it == "staging_sub_42" })
        assertEquals(5, deletedSources.count { it == "sub_42" })
    }
}
