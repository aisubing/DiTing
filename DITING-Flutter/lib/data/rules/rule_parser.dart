/// 整份规则文本的解析入口（1.4.3 `AdGuardRuleParser` 的 `parseCategorized` /
/// `parseCategorizedLine` / `extractBadfilterKeys` 移植）。
library;

import 'package:diting/data/rules/adblock_line_parser.dart';
import 'package:diting/data/rules/hosts_parser.dart';
import 'package:diting/data/rules/rule_models.dart';

/// 解析一行，不做跨行状态（流式导入用）。
CategorizedLine parseCategorizedLine(String originalLine) {
  final line = originalLine.trim().replaceFirst(RegExp('^\uFEFF'), '');
  if (line.isEmpty ||
      line.startsWith('!') ||
      _isCommentLine(line) ||
      (line.startsWith('[') && line.endsWith(']'))) {
    return const CategorizedLine(ignoredCount: 1);
  }

  // 1. dnsmasq：address=/domain/ip 或 server=/domain/ip
  if (line.startsWith('address=/') || line.startsWith('server=/')) {
    return parseDnsmasqLine(line, originalLine);
  }

  // 2. hosts：IP domain1 [domain2 ...]
  final hosts = parseHostsLineDetailed(line, originalLine);
  if (hosts != null) {
    return hosts;
  }

  // 3. AdGuard / ABP / 裸域名 / cosmetic / URL
  final allow = line.startsWith('@@');
  return parseAdblockOrDomainLine(line, originalLine, allow);
}

/// 以 `#` 开头的行只有在**不是**元素隐藏规则时才是注释。
///
/// 通用规则（`##.ad`、`#@#.ad`）同样以 `#` 开头，所以必须先识别 cosmetic
/// 分隔符再判注释。
bool _isCommentLine(String line) =>
    line.startsWith('#') && !isCosmeticRuleLine(line);

/// 扫描全文收集 `$badfilter` 去重键。
///
/// 必须先扫一遍全文：`$badfilter` 的作用是「关掉同键的规则」，且不保证出现在
/// 目标规则之后，单趟流式处理会漏掉反向顺序。
Set<String> extractBadfilterKeys(String text) {
  final keys = <String>{};
  for (final line in text.split('\n')) {
    if (!line.toLowerCase().contains('badfilter')) {
      continue;
    }
    keys.addAll(parseCategorizedLine(line).badfilterKeys);
  }
  return keys;
}

/// 解析整份文本，按族归类并按去重键去重（后出现的重复行计入 duplicate）。
///
/// [badfilterKeys] 传入时会剔除命中的规则；不传则内部先扫一遍全文。
CategorizedRules parseCategorized(
  String text, {
  Set<String>? badfilterKeys,
}) {
  final keys = badfilterKeys ?? extractBadfilterKeys(text);
  final blockRules = <String, ParsedRule>{};
  final allowRules = <String, ParsedRule>{};
  final rewriteRules = <String, ParsedRewriteRule>{};
  final urlBlockRules = <String, ParsedUrlRule>{};
  final urlAllowRules = <String, ParsedUrlRule>{};
  final cosmeticRules = <String, ParsedCosmeticRule>{};
  var duplicates = 0;
  var invalid = 0;
  var unsupported = 0;
  var ignored = 0;
  var total = 0;

  for (final originalLine in text.split('\n')) {
    total++;
    final lineResult = parseCategorizedLine(originalLine);
    invalid += lineResult.invalidCount;
    unsupported += lineResult.unsupportedCount;
    ignored += lineResult.ignoredCount;

    for (final rule in lineResult.blockRules) {
      duplicates += _addUnique(blockRules, blockKeyOf(rule), rule);
    }
    for (final rule in lineResult.allowRules) {
      duplicates += _addUnique(allowRules, allowKeyOf(rule), rule);
    }
    for (final rule in lineResult.rewriteRules) {
      duplicates += _addUnique(rewriteRules, rewriteKeyOf(rule), rule);
    }
    for (final rule in lineResult.urlBlockRules) {
      final key = 'url_block:${rule.pattern}:${rule.appScope}';
      duplicates += _addUnique(urlBlockRules, key, rule);
    }
    for (final rule in lineResult.urlAllowRules) {
      final key = 'url_allow:${rule.pattern}:${rule.appScope}';
      duplicates += _addUnique(urlAllowRules, key, rule);
    }
    for (final rule in lineResult.cosmeticRules) {
      final key = 'cosmetic:${rule.domain}:${rule.selector}:${rule.isException}';
      duplicates += _addUnique(cosmeticRules, key, rule);
    }
  }

  var badfilteredCount = 0;
  if (keys.isNotEmpty) {
    badfilteredCount += _removeKeys(blockRules, keys);
    badfilteredCount += _removeKeys(allowRules, keys);
    badfilteredCount += _removeKeys(rewriteRules, keys);
  }

  return CategorizedRules(
    blockRules: blockRules.values.toList(),
    allowRules: allowRules.values.toList(),
    rewriteRules: rewriteRules.values.toList(),
    urlBlockRules: urlBlockRules.values.toList(),
    urlAllowRules: urlAllowRules.values.toList(),
    cosmeticRules: cosmeticRules.values.toList(),
    duplicateCount: duplicates,
    invalidCount: invalid,
    unsupportedCount: unsupported,
    ignoredCount: ignored,
    badfilteredCount: badfilteredCount,
    totalLines: total,
  );
}

/// 首次出现返回 0，重复返回 1（用于累计 duplicateCount）。
int _addUnique<T>(Map<String, T> map, String key, T value) {
  if (map.containsKey(key)) {
    return 1;
  }
  map[key] = value;
  return 0;
}

int _removeKeys<T>(Map<String, T> map, Set<String> keys) {
  var removed = 0;
  for (final key in keys) {
    if (map.remove(key) != null) {
      removed++;
    }
  }
  return removed;
}

/// 解析单条规则（用户手工添加用）。非 allow 时拒绝 `@@` 行。
ParsedRule? parseRule(String line) {
  final trimmed = line.trim().replaceFirst(RegExp('^\uFEFF'), '');
  if (trimmed.startsWith('@@')) {
    return null;
  }
  return parseCategorizedLine(line).blockRules.firstOrNull;
}

/// 解析单条放行规则。裸域名（不带 `@@`）也接受，等价于手填白名单。
ParsedRule? parseAllowRule(String line) {
  final trimmed = line.trim().replaceFirst(RegExp('^\uFEFF'), '');
  if (!trimmed.startsWith('@@')) {
    final cat = parseAdblockOrDomainLine(trimmed, line, true);
    return cat.allowRules.firstOrNull;
  }
  return parseCategorizedLine(line).allowRules.firstOrNull;
}
