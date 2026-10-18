package com.haoze.diting.ui.batch

import android.content.Context
import com.haoze.diting.data.RuleDataSources
import com.haoze.diting.data.RuleDataset
import com.haoze.diting.data.entity.RewriteTargetType
import com.haoze.diting.data.entity.RuleScope
import com.haoze.diting.ui.RuntimeDnsSettingsRefresher
import com.haoze.diting.core.rule.AllowListManager
import com.haoze.diting.core.rule.BlockListManager
import com.haoze.diting.core.rule.CosmeticRuleManager
import com.haoze.diting.core.rule.DefaultWhitelistSeeder
import com.haoze.diting.core.rule.GoUrlRuleManager
import com.haoze.diting.core.rule.RewriteRuleManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Validates multiline text input for mixed Blacklist, Whitelist, and Rewrite rules.
 * Handles parsing, duplicate detection, and batch insertion.
 */
class BatchRuleValidator(
    private val database: RuleDataSources,
    private val dataset: RuleDataset,
    private val target: BatchRuleTarget = BatchRuleTarget.BLACKLIST
) {
    private val blockRuleDao = database.blockRuleDao()
    private val allowRuleDao = database.allowRuleDao()
    private val rewriteRuleDao = database.rewriteRuleDao()
    private val goUrlRuleDao = database.goUrlRuleDao()
    private val cosmeticRuleDao = database.cosmeticRuleDao()
    private val blockListManager = BlockListManager(blockRuleDao, scope = RuleScope.DNS)
    private val allowListManager = AllowListManager(allowRuleDao, scope = RuleScope.DNS)
    private val goUrlRuleManager = GoUrlRuleManager(goUrlRuleDao)
    private val rewriteRuleManager = RewriteRuleManager(rewriteRuleDao, scope = RuleScope.DNS)

    suspend fun validate(
        input: String,
        mode: BatchRecognitionMode = BatchRecognitionMode.fromTarget(target)
    ): BatchValidationSummary = withContext(Dispatchers.IO) {
        val lines = input.lines()
        val validItems = mutableListOf<BatchRuleItem>()
        val duplicateItems = mutableListOf<BatchRuleItem.Duplicate>()
        val invalidItems = mutableListOf<BatchRuleItem.Invalid>()
        var ignoredCount = 0

        val seenKeys = mutableSetOf<String>()

        lines.forEachIndexed { index, line ->
            val lineNo = index + 1
            val classifiedList = BatchRuleClassifier.classify(line, mode, dataset)

            for (classified in classifiedList) {
                when (classified) {
                    is ClassifiedLine.Ignored -> {
                        ignoredCount++
                    }
                    is ClassifiedLine.Invalid -> {
                        invalidItems.add(BatchRuleItem.Invalid(lineNo, line.trim(), classified.reason))
                    }
                    is ClassifiedLine.Domain -> {
                        validateDomain(lineNo, line.trim(), classified, seenKeys, validItems, duplicateItems)
                    }
                    is ClassifiedLine.Url -> {
                        validateUrl(lineNo, line.trim(), classified, seenKeys, validItems, duplicateItems)
                    }
                    is ClassifiedLine.Cosmetic -> {
                        validateCosmetic(lineNo, line.trim(), classified, seenKeys, validItems, duplicateItems)
                    }
                    is ClassifiedLine.Rewrite -> {
                        validateRewrite(lineNo, line.trim(), classified, seenKeys, validItems, duplicateItems, invalidItems)
                    }
                }
            }
        }

        BatchValidationSummary(
            target = target,
            mode = mode,
            totalLines = lines.size,
            validItems = validItems,
            duplicateItems = duplicateItems,
            invalidItems = invalidItems,
            ignoredCount = ignoredCount
        )
    }

    private suspend fun validateDomain(
        lineNo: Int,
        raw: String,
        classified: ClassifiedLine.Domain,
        seenKeys: MutableSet<String>,
        validItems: MutableList<BatchRuleItem>,
        duplicateItems: MutableList<BatchRuleItem.Duplicate>
    ) {
        val category = if (classified.isAllow) BatchRuleCategory.ALLOW else BatchRuleCategory.BLOCK
        val prefix = if (classified.isAllow) "allow" else "block"
        val key = "$prefix:${classified.pattern}:${classified.important}:${classified.appScope}:" +
            "${classified.appInverted}:${classified.dnsType}:${classified.denyallow}:${classified.isRegex}"

        if (!seenKeys.add(key)) {
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, "输入中已存在相同规则", category))
            return
        }

        val exists = if (classified.isAllow) {
            allowRuleDao.idByPattern(
                pattern = classified.pattern,
                important = classified.important,
                appScope = classified.appScope,
                appInverted = classified.appInverted,
                dnsType = classified.dnsType,
                isRegex = classified.isRegex
            ) > 0
        } else {
            blockRuleDao.idByPattern(
                pattern = classified.pattern,
                important = classified.important,
                appScope = classified.appScope,
                appInverted = classified.appInverted,
                dnsType = classified.dnsType,
                isRegex = classified.isRegex
            ) > 0
        }

        if (exists) {
            val reason = if (classified.isAllow) "白名单中已存在该规则" else "黑名单中已存在该规则"
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, reason, category))
            return
        }

        validItems.add(
            BatchRuleItem.ValidDomain(
                lineNumber = lineNo,
                rawLine = raw,
                pattern = classified.pattern,
                isAllow = classified.isAllow,
                appScope = classified.appScope,
                appInverted = classified.appInverted,
                important = classified.important,
                isWildcard = classified.isWildcard,
                denyallow = classified.denyallow,
                isRegex = classified.isRegex,
                dnsType = classified.dnsType
            )
        )
    }

    private suspend fun validateUrl(
        lineNo: Int,
        raw: String,
        classified: ClassifiedLine.Url,
        seenKeys: MutableSet<String>,
        validItems: MutableList<BatchRuleItem>,
        duplicateItems: MutableList<BatchRuleItem.Duplicate>
    ) {
        val category = if (classified.isAllow) BatchRuleCategory.ALLOW else BatchRuleCategory.BLOCK
        // Normalize through the same parser the single-rule path uses
        // (GoUrlRuleManager.addRule -> parse). Storing the raw text here made
        // batch-added rules differ from manually added ones (host case, default
        // ports, empty path), so the Go matcher could never match them and a
        // later manual re-add was not recognised as a duplicate.
        val prefix = if (classified.isAllow) "@@" else ""
        val parsed = goUrlRuleManager.parse(prefix + classified.urlPattern)
        if (parsed == null) {
            duplicateItems.add(
                BatchRuleItem.Duplicate(lineNo, raw, "url_invalid:${classified.urlPattern}", "URL 格式无效", category)
            )
            return
        }
        val key = "url:${parsed.kind}:${parsed.pattern}"

        if (!seenKeys.add(key)) {
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, "输入中已存在相同规则", category))
            return
        }

        if (goUrlRuleDao.idByPattern(parsed.pattern, parsed.kind) > 0) {
            val reason = if (classified.isAllow) "白名单中已存在该规则" else "黑名单中已存在该规则"
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, reason, category))
            return
        }

        validItems.add(
            BatchRuleItem.ValidUrl(
                lineNumber = lineNo,
                rawLine = raw,
                urlPattern = parsed.pattern,
                isAllow = classified.isAllow
            )
        )
    }

    private suspend fun validateCosmetic(
        lineNo: Int,
        raw: String,
        classified: ClassifiedLine.Cosmetic,
        seenKeys: MutableSet<String>,
        validItems: MutableList<BatchRuleItem>,
        duplicateItems: MutableList<BatchRuleItem.Duplicate>
    ) {
        val category = if (classified.isException) BatchRuleCategory.ALLOW else BatchRuleCategory.BLOCK
        val key = "cosmetic:${classified.domain}:${classified.selector}:${classified.isException}"

        if (!seenKeys.add(key)) {
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, "输入中已存在相同规则", category))
            return
        }

        if (cosmeticRuleDao.idByDomainAndSelector(
                classified.domain,
                classified.selector,
                classified.isException
            ) > 0
        ) {
            val reason = if (classified.isException) "白名单中已存在该规则" else "黑名单中已存在该规则"
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, reason, category))
            return
        }

        validItems.add(
            BatchRuleItem.ValidCosmetic(
                lineNumber = lineNo,
                rawLine = raw,
                domain = classified.domain,
                selector = classified.selector,
                isException = classified.isException
            )
        )
    }

    private suspend fun validateRewrite(
        lineNo: Int,
        raw: String,
        classified: ClassifiedLine.Rewrite,
        seenKeys: MutableSet<String>,
        validItems: MutableList<BatchRuleItem>,
        duplicateItems: MutableList<BatchRuleItem.Duplicate>,
        invalidItems: MutableList<BatchRuleItem.Invalid>
    ) {
        val domain = classified.domain
        val targetType = classified.targetType
        val targetValue = classified.targetValue
        val isCname = targetType == RewriteTargetType.CNAME

        if (isCname && rewriteRuleDao.countOtherTypes(domain, targetType) > 0) {
            invalidItems.add(BatchRuleItem.Invalid(lineNo, raw, "该域名已存在 IP 覆写规则，不能同时添加 CNAME: $domain"))
            return
        }
        if (!isCname && rewriteRuleDao.countType(domain, RewriteTargetType.CNAME) > 0) {
            invalidItems.add(BatchRuleItem.Invalid(lineNo, raw, "该域名已存在 CNAME 覆写规则，不能同时添加 IP: $domain"))
            return
        }

        val key = "rewrite:$domain:$targetType:$targetValue"
        if (!seenKeys.add(key)) {
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, "输入中已存在相同规则", BatchRuleCategory.REWRITE))
            return
        }

        if (rewriteRuleDao.idByKey(domain, targetType, targetValue) > 0) {
            duplicateItems.add(BatchRuleItem.Duplicate(lineNo, raw, key, "覆写名单中已存在该规则", BatchRuleCategory.REWRITE))
            return
        }

        validItems.add(
            BatchRuleItem.ValidRewrite(
                lineNumber = lineNo,
                rawLine = classified.rawLine,
                domain = domain,
                targetType = targetType,
                targetValue = targetValue
            )
        )
    }

    suspend fun commitDetailed(context: Context, validItems: List<BatchRuleItem>): BatchCommitResult = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        var blockInserted = 0
        var allowInserted = 0
        var rewriteInserted = 0

        val domainBlockItems = validItems.filterIsInstance<BatchRuleItem.ValidDomain>().filter { !it.isAllow }
        val domainAllowItems = validItems.filterIsInstance<BatchRuleItem.ValidDomain>().filter { it.isAllow }
        val urlBlockItems = validItems.filterIsInstance<BatchRuleItem.ValidUrl>().filter { !it.isAllow }
        val urlAllowItems = validItems.filterIsInstance<BatchRuleItem.ValidUrl>().filter { it.isAllow }
        val cosmeticItems = committableCosmeticItems(validItems, dataset)
        val rewriteItems = validItems.filterIsInstance<BatchRuleItem.ValidRewrite>()

        // 1. Commit Blacklist Domain Rules
        if (domainBlockItems.isNotEmpty()) {
            val entities = domainBlockItems.map { it.toBlockEntity(now) }
            blockInserted += blockRuleDao.insertAllForSource(entities, "useradd", sourceEnabled = true)
            domainBlockItems.forEach { blockListManager.syncCachedPattern(it.pattern) }
        }

        // 2. Commit Whitelist Domain Rules
        if (domainAllowItems.isNotEmpty()) {
            val entities = domainAllowItems.map { it.toAllowEntity(now) }
            allowInserted += allowRuleDao.insertAllForSource(
                entities, DefaultWhitelistSeeder.SOURCE_USER, sourceEnabled = true
            )
            domainAllowItems.forEach { allowListManager.syncCachedPattern(it.pattern) }
        }

        // 3. Commit URL Rules
        urlBlockItems.forEach { item ->
            if (goUrlRuleDao.insertForSource(item.toGoUrlEntity(now), "useradd", sourceEnabled = true)) {
                blockInserted++
            }
        }

        urlAllowItems.forEach { item ->
            if (goUrlRuleDao.insertForSource(
                    item.toGoUrlEntity(now), DefaultWhitelistSeeder.SOURCE_USER, sourceEnabled = true
                )
            ) {
                allowInserted++
            }
        }

        // 4. Commit Cosmetic Rules
        cosmeticItems.forEach { item ->
            val src = if (item.isException) DefaultWhitelistSeeder.SOURCE_USER else "useradd"
            if (cosmeticRuleDao.insertForSource(item.toCosmeticEntity(now), src, sourceEnabled = true)) {
                if (item.isException) allowInserted++ else blockInserted++
            }
        }
        if (cosmeticItems.isNotEmpty()) {
            CosmeticRuleManager.getInstance(context).compileScopedCss()
            RuntimeDnsSettingsRefresher.syncHttpsRequestRulesIfRunning(context)
        }

        // 5. Commit Rewrite Rules
        if (rewriteItems.isNotEmpty()) {
            val entities = rewriteItems.map { it.toRewriteEntity(now) }
            rewriteInserted += rewriteRuleDao.insertAllForSource(entities, "useradd", enabled = true)
            rewriteRuleManager.refreshCache(rebuildSubscriptionIndex = false)
        }

        // 6. Refresh runtime DNS indexes for modified rule kinds
        val hasBlock = domainBlockItems.isNotEmpty() || urlBlockItems.isNotEmpty()
        val hasAllow = domainAllowItems.isNotEmpty() || urlAllowItems.isNotEmpty()
        val hasRewrite = rewriteItems.isNotEmpty()

        if (hasBlock || hasAllow || hasRewrite) {
            RuntimeDnsSettingsRefresher.refreshRuleIndexesIfRunning(
                context,
                refreshBlock = hasBlock,
                refreshAllow = hasAllow,
                refreshRewrite = hasRewrite,
                dataset = dataset
            )
        }

        BatchCommitResult(
            blockInserted = blockInserted,
            allowInserted = allowInserted,
            rewriteInserted = rewriteInserted
        )
    }

    suspend fun commit(context: Context, validItems: List<BatchRuleItem>): Int {
        return commitDetailed(context, validItems).totalInserted
    }
}
