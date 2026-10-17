package com.haoze.diting.data.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * An element-hiding CSS cosmetic rule evaluated during HTTP(S) inspection.
 *
 * @param domain target domain (e.g. "example.com"), empty for global rules
 * @param selector CSS selector (e.g. ".ad-container", "[class*=\"ad-\"]")
 * @param rawLine original rule line, kept for display and diagnostics
 * @param addedAt timestamp when rule was added
 * @param enabled whether the rule is active
 * @param isException whether this is a `#@#` exception that un-hides the selector
 *   on the matching domain instead of hiding it
 */
@Entity(
    tableName = "cosmetic_rule",
    indices = [Index(value = ["domain", "selector", "isException"], unique = true)]
)
data class CosmeticRuleEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val domain: String,
    val selector: String,
    val rawLine: String,
    val addedAt: Long,
    val enabled: Boolean = true,
    val isException: Boolean = false
)
