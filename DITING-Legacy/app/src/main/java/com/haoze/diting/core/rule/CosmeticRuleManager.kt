package com.haoze.diting.core.rule

import android.content.Context
import com.haoze.diting.data.AppDatabase
import com.haoze.diting.data.dao.CosmeticRuleDao
import com.haoze.diting.data.entity.CosmeticRuleEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

/**
 * Manages cosmetic element-hiding rules and compiles them into CSS
 * for injection by the Go MITM engine.
 */
class CosmeticRuleManager(
    private val cosmeticRuleDao: CosmeticRuleDao
) {
    companion object {
        @Volatile
        private var instance: CosmeticRuleManager? = null

        fun getInstance(context: Context): CosmeticRuleManager {
            return instance ?: synchronized(this) {
                instance ?: CosmeticRuleManager(
                    AppDatabase.getInstance(context.applicationContext).cosmeticRuleDao()
                ).also { instance = it }
            }
        }

        /**
         * Builds the scoped stylesheet/exception JSON pushed to the Go engine.
         * Kept free of Android dependencies so it can be unit tested.
         */
        internal fun buildScopedCssJson(rules: List<CosmeticRuleEntity>): String {
            val globalHide = LinkedHashSet<String>()
            val globalException = LinkedHashSet<String>()
            val scopedHide = LinkedHashMap<String, LinkedHashSet<String>>()
            val scopedException = LinkedHashMap<String, LinkedHashSet<String>>()

            for (rule in rules) {
                val selector = rule.selector.trim()
                if (selector.isEmpty()) continue
                val domain = rule.domain.trim().trimEnd('.').lowercase()
                when {
                    domain.isEmpty() && rule.isException -> globalException.add(selector)
                    domain.isEmpty() -> globalHide.add(selector)
                    rule.isException ->
                        scopedException.getOrPut(domain) { LinkedHashSet() }.add(selector)
                    else -> scopedHide.getOrPut(domain) { LinkedHashSet() }.add(selector)
                }
            }

            // A global hide already covers every domain, so a scoped hide for the
            // same selector adds nothing; dropping it keeps the per-request CSS
            // small for large subscriptions.
            val domains = (scopedHide.keys + scopedException.keys).sorted()
            val root = org.json.JSONObject()
            root.put("globalHide", org.json.JSONArray(globalHide.toList()))
            root.put("globalException", org.json.JSONArray(globalException.toList()))
            val domainsObj = org.json.JSONObject()
            for (domain in domains) {
                val entry = org.json.JSONObject()
                val hide = scopedHide[domain].orEmpty().filterNot { it in globalHide }
                entry.put("hide", org.json.JSONArray(hide))
                entry.put("exception", org.json.JSONArray(scopedException[domain].orEmpty().toList()))
                domainsObj.put(domain, entry)
            }
            root.put("domains", domainsObj)
            return root.toString()
        }
    }

    /**
     * Compiles every active rule into the scoped JSON consumed by the Go
     * engine, which narrows rules by the hostname being inspected.
     */
    suspend fun compileScopedCss(): String = withContext(Dispatchers.IO) {
        val rules = cosmeticRuleDao.enabledRules()
        if (rules.isEmpty()) return@withContext ""
        buildScopedCssJson(rules)
    }

    /**
     * Compiles all active cosmetic rules to a flat, domain-agnostic stylesheet.
     * Only useful for diagnostics; the Go engine receives [compileScopedCss].
     */
    suspend fun compileAllToCss(): String = withContext(Dispatchers.IO) {
        val rules = cosmeticRuleDao.enabledRules()
        if (rules.isEmpty()) return@withContext ""

        val sb = StringBuilder()
        val emitted = mutableSetOf<String>()

        for (rule in rules) {
            if (!rule.isException && emitted.add(rule.selector)) {
                sb.append(rule.selector).append(" { display: none !important; }\n")
            }
        }

        sb.toString()
    }

    fun compileAllToCssBlocking(): String = runBlocking(Dispatchers.IO) {
        compileAllToCss()
    }
}
