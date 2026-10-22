/// 单行规则解析：cosmetic / URL / 修饰符 / 域名（1.4.3
/// `AdblockRuleLineParser` 的移植）。
///
/// 判定顺序是语义的一部分，不能重排：
/// 1. cosmetic 分隔符先探测（`#$@#` 必须早于 `#$#`）；
/// 2. 再切尾部 `#` 注释（但正则可含 `#`）；
/// 3. 再抽 `$` 修饰符；
/// 4. 再判 URL/路径规则；
/// 5. 最后当域名规则。
library;

import 'package:diting/data/rules/rule_domain_utils.dart';
import 'package:diting/data/rules/rule_models.dart';

/// 元素隐藏分隔符，长的在前：`#$@#` 是 `#$#` 的例外形式，先匹配短会把
/// `example.com#$@#selector` 整条降级成整域拦截。
const _cosmeticDelimiters = ['#\$@#', '#@#', '##', '#?#', '#\$#'];

/// 该行是否使用元素隐藏分隔符。
///
/// 以 `#` 开头的行既可能是注释也可能是通用 cosmetic 规则（`##.ad`），所以这条
/// 判定必须先于注释过滤执行。
bool isCosmeticRuleLine(String line) =>
    _cosmeticDelimiters.any(line.contains);

/// 尾部 `#` 注释可能的起点。
///
/// 正则可含 `#`（`/foo#bar/`），扫描从正则字面量闭合的 `/` 之后开始；因此
/// 紧跟其后的注释仍能被找到。非正则行返回 0，等价于从头扫。
int _commentSearchStart(String line, bool allow) {
  final offset = (allow && line.startsWith('@@')) ? 2 : 0;
  if (line.length <= offset + 1 || line[offset] != '/') {
    return 0;
  }
  var tokenEnd = offset + 1;
  while (tokenEnd < line.length && line[tokenEnd].trim().isNotEmpty) {
    tokenEnd++;
  }
  final closing = line.lastIndexOf('/', tokenEnd - 1);
  return closing <= offset ? 0 : closing + 1;
}

/// 解析一行 AdGuard / ABP / 裸域名 / cosmetic / URL 规则。
CategorizedLine parseAdblockOrDomainLine(
  String line,
  String originalLine,
  bool allow,
) {
  // 1. 元素隐藏（cosmetic）
  final cosmetic = _parseCosmeticLine(line, originalLine);
  if (cosmetic != null) {
    return cosmetic;
  }

  // 只有「起始尾部注释」的 `#` 可以被丢弃。粘在 pattern 上的 `#` 是本解析器
  // 不认识的标记或畸形规则，在这里截断会静默把它放宽成整域拦截，因此按
  // unsupported 处理。正则可以合法携带 `#`，扫描从字面量之后开始。
  final hashIndex = line.indexOf('#', _commentSearchStart(line, allow));
  var value = hashIndex < 0 ? line.trim() : '';
  if (hashIndex >= 0) {
    final before = line.substring(0, hashIndex);
    if (before.isEmpty || before[before.length - 1].trim().isEmpty) {
      value = before.trim();
    } else {
      return const CategorizedLine(unsupportedCount: 1);
    }
  }
  if (value.isEmpty) {
    return const CategorizedLine(invalidCount: 1);
  }
  if (allow) {
    value = value.startsWith('@@') ? value.substring(2) : value;
  }

  // 2. 正则语法
  var isRegex = false;
  String? regexPattern;
  String? modifiersStr;

  if (value.startsWith('/')) {
    final lastSlash = value.lastIndexOf('/');
    if (lastSlash <= 0) {
      return const CategorizedLine(invalidCount: 1);
    }
    final extractedRegex = value.substring(1, lastSlash).trim();
    if (extractedRegex.isEmpty) {
      return const CategorizedLine(invalidCount: 1);
    }
    if (!_isValidRegex(extractedRegex)) {
      return const CategorizedLine(invalidCount: 1);
    }
    isRegex = true;
    regexPattern = extractedRegex;
    final tail = value.substring(lastSlash + 1).trim();
    if (tail.isNotEmpty) {
      if (!tail.startsWith(r'$')) {
        return const CategorizedLine(invalidCount: 1);
      }
      modifiersStr = tail.substring(1);
    }
    value = '';
  }

  if (!isRegex) {
    final modifierIndex = value.indexOf(r'$');
    if (modifierIndex >= 0) {
      modifiersStr = value.substring(modifierIndex + 1);
      value = value.substring(0, modifierIndex).trim();
    }
  }

  // 3. 修饰符
  var important = false;
  String? appScope;
  var appInverted = false;
  String? dnsrewriteTargetType;
  String? dnsrewriteTargetValue;
  var dnsrewriteIsBlock = false;
  var isBadfilter = false;
  String? denyallow;
  String? dnsType;

  if (modifiersStr != null && modifiersStr.isNotEmpty) {
    final modifiers = modifiersStr
        .split(',')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty);
    for (final token in modifiers) {
      final lower = token.toLowerCase();
      if (lower == 'important') {
        important = true;
      } else if (lower.startsWith('~denyallow=')) {
        // `~denyallow=` 没有可反转的语义（该修饰符本身已是排除表），丢弃修饰符
        // 但保留规则——与桌面版解析器一致。当成普通 denyallow 处理会把那些域名
        // 变成活跃拦截规则的例外，规则就一条都拦不住了。
        continue;
      } else if (lower.startsWith('app=') || lower.startsWith('~app=')) {
        final isNegativePrefix = lower.startsWith('~app=');
        final appValue = isNegativePrefix
            ? token.substring(5).trim()
            : token.substring(4).trim();
        if (appValue.isEmpty) {
          return const CategorizedLine(unsupportedCount: 1);
        }
        final pkgs = appValue
            .split('|')
            .map((pkg) => pkg.trim())
            .where((pkg) => pkg.isNotEmpty)
            .toList();
        if (pkgs.isEmpty) {
          return const CategorizedLine(unsupportedCount: 1);
        }
        final hasInverted =
            isNegativePrefix || pkgs.any((pkg) => pkg.startsWith('~'));
        final cleanPkgs = pkgs
            .map(
              (pkg) => (pkg.startsWith('~') ? pkg.substring(1) : pkg)
                  .trim()
                  .toLowerCase(),
            )
            .where((pkg) => pkg.isNotEmpty)
            .toList();
        if (cleanPkgs.isEmpty) {
          return const CategorizedLine(unsupportedCount: 1);
        }
        appInverted = hasInverted;
        appScope = cleanPkgs.join('|');
      } else if (lower.startsWith('denyallow=')) {
        final rawSpec = token.substring(10).trim();
        if (rawSpec.isEmpty) {
          return const CategorizedLine(invalidCount: 1);
        }
        final rawDomains = rawSpec
            .split('|')
            .map((domain) => domain.trim().toLowerCase())
            .where((domain) => domain.isNotEmpty)
            .toList();
        if (rawDomains.isEmpty) {
          return const CategorizedLine(invalidCount: 1);
        }
        final cleanDomains = <String>[];
        for (final domain in rawDomains) {
          var clean = domain.startsWith('||') ? domain.substring(2) : domain;
          clean = clean.replaceFirst(RegExp(r'\^+$'), '');
          clean = clean.replaceFirst(RegExp(r'\.+$'), '');
          final normalized = normalizeDomain(clean);
          if (normalized == null) {
            return const CategorizedLine(invalidCount: 1);
          }
          cleanDomains.add(normalized);
        }
        denyallow = cleanDomains.join('|');
      } else if (lower.startsWith('dnstype=') || lower.startsWith('~dnstype=')) {
        final isNegative = lower.startsWith('~dnstype=');
        final rawSpec = (isNegative ? token.substring(9) : token.substring(8))
            .trim();
        if (rawSpec.isEmpty) {
          return const CategorizedLine(unsupportedCount: 1);
        }
        final rawTypes = rawSpec
            .split('|')
            .map((type) => type.trim().toUpperCase())
            .where((type) => type.isNotEmpty)
            .toList();
        if (rawTypes.isEmpty) {
          return const CategorizedLine(unsupportedCount: 1);
        }
        final cleanTypes = <String>[];
        for (final type in rawTypes) {
          final actual = type.startsWith('~') ? type.substring(1) : type;
          if (!validDnsTypes.contains(actual)) {
            return const CategorizedLine(unsupportedCount: 1);
          }
          cleanTypes.add(actual);
        }
        dnsType = (isNegative || rawTypes.any((type) => type.startsWith('~')))
            ? '~${cleanTypes.join('|')}'
            : cleanTypes.join('|');
      } else if (lower.startsWith('dnsrewrite=')) {
        final rawSpec = token.substring(11).trim();
        if (rawSpec.isEmpty) {
          return const CategorizedLine(invalidCount: 1);
        }
        final targetSpec = rawSpec.contains(';')
            ? _dnsrewriteLastPart(rawSpec)
            : rawSpec;
        final upper = targetSpec.toUpperCase();
        final lowerTarget = targetSpec.toLowerCase();
        if (upper == 'NXDOMAIN' ||
            upper == 'REFUSED' ||
            upper == 'SERVFAIL' ||
            sinkholeAddresses.contains(lowerTarget)) {
          dnsrewriteIsBlock = true;
        } else if (looksLikeLiteralIp(targetSpec)) {
          final address = InternetAddressParse.numeric(targetSpec);
          if (address == null) {
            return const CategorizedLine(invalidCount: 1);
          }
          dnsrewriteTargetType = address.contains(':')
              ? RewriteTargetType.ipv6
              : RewriteTargetType.ipv4;
          dnsrewriteTargetValue = address;
        } else {
          final cname = normalizeDomain(targetSpec);
          if (cname == null) {
            return const CategorizedLine(invalidCount: 1);
          }
          dnsrewriteTargetType = RewriteTargetType.cname;
          dnsrewriteTargetValue = cname;
        }
      } else if (lower == 'badfilter') {
        isBadfilter = true;
      } else if (isWebOnlyModifier(lower)) {
        return const CategorizedLine(ignoredCount: 1);
      } else if (lower == 'all' || lower == 'empty') {
        // `$all` 匹配全部内容类型，对 DNS 层等价于「无附加约束」。
      } else {
        return const CategorizedLine(unsupportedCount: 1);
      }
    }
  }

  // 4. URL / 路径拦截规则
  if (!isRegex && _isUrlOrPathRule(value)) {
    final cleanPattern = _cleanUrlPattern(value);
    if (cleanPattern.isNotEmpty) {
      if (isBadfilter) {
        final key = allow
            ? 'url_allow:$cleanPattern:$appScope'
            : 'url_block:$cleanPattern:$appScope';
        return CategorizedLine(badfilterKeys: {key});
      }
      final urlRule = ParsedUrlRule(
        pattern: cleanPattern,
        rawLine: originalLine,
        isAllow: allow,
        appScope: appScope,
        important: important,
      );
      return allow
          ? CategorizedLine(urlAllowRules: [urlRule])
          : CategorizedLine(urlBlockRules: [urlRule]);
    }
  }

  // 5. 普通域名规则
  final String domain;
  final bool isWildcard;
  if (isRegex) {
    domain = regexPattern!;
    isWildcard = false;
  } else {
    if (value.startsWith('||')) {
      value = value.replaceFirst(RegExp(r'\^+$'), '').substring(2);
    } else if (value.startsWith('|') || value.endsWith('|')) {
      return const CategorizedLine(unsupportedCount: 1);
    } else {
      value = value.replaceFirst(RegExp(r'\^+$'), '');
    }
    isWildcard = value.contains('*');
    final normalized = isWildcard
        ? normalizeWildcardDomain(value)
        : normalizeDomain(value);
    if (normalized == null) {
      return const CategorizedLine(invalidCount: 1);
    }
    domain = normalized;
  }

  if (isBadfilter) {
    final String key;
    if (dnsrewriteTargetType != null && dnsrewriteTargetValue != null) {
      key = rewriteRuleKey(
        domain,
        dnsrewriteTargetType,
        dnsrewriteTargetValue,
      );
    } else if (dnsrewriteIsBlock || !allow) {
      key = blockRuleKey(
        domain,
        important: important,
        appScope: appScope,
        appInverted: appInverted,
        denyallow: denyallow,
        isRegex: isRegex,
        dnsType: dnsType,
      );
    } else {
      key = allowRuleKey(
        domain,
        important: important,
        appScope: appScope,
        appInverted: appInverted,
        denyallow: denyallow,
        isRegex: isRegex,
        dnsType: dnsType,
      );
    }
    return CategorizedLine(badfilterKeys: {key});
  }

  if (dnsrewriteTargetType != null && dnsrewriteTargetValue != null) {
    return CategorizedLine(
      rewriteRules: [
        ParsedRewriteRule(
          pattern: domain,
          targetType: dnsrewriteTargetType,
          targetValue: dnsrewriteTargetValue,
          rawLine: originalLine,
        ),
      ],
    );
  }

  final rule = ParsedRule(
    pattern: domain,
    rawLine: originalLine,
    important: important,
    appScope: appScope,
    appInverted: appInverted,
    isWildcard: isWildcard,
    denyallow: denyallow,
    isRegex: isRegex,
    dnsType: dnsType,
  );
  if (dnsrewriteIsBlock) {
    return CategorizedLine(blockRules: [rule]);
  }
  return allow
      ? CategorizedLine(allowRules: [rule])
      : CategorizedLine(blockRules: [rule]);
}

/// `dnsrewrite=a;b;c` 取最后一段；但首段是 NXDOMAIN/REFUSED/SERVFAIL 时按
/// 黑洞处理（旧版 `targetSpec` 的取值规则）。
String _dnsrewriteLastPart(String rawSpec) {
  final parts = rawSpec
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return rawSpec;
  }
  final first = parts.first.toUpperCase();
  if (first == 'NXDOMAIN' || first == 'REFUSED' || first == 'SERVFAIL') {
    return 'NXDOMAIN';
  }
  return parts.last;
}

CategorizedLine? _parseCosmeticLine(String line, String originalLine) {
  // `#$@#` 是 `#$#` 的例外形式，必须先于更短的标记探测。
  final isException = line.contains('#@#') || line.contains(r'#$@#');
  final String delimiter;
  if (line.contains(r'#$@#')) {
    delimiter = r'#$@#';
  } else if (line.contains('#@#')) {
    delimiter = '#@#';
  } else if (line.contains('##')) {
    delimiter = '##';
  } else if (line.contains('#?#')) {
    delimiter = '#?#';
  } else if (line.contains(r'#$#')) {
    delimiter = r'#$#';
  } else {
    return null;
  }

  final index = line.indexOf(delimiter);
  final domainPart = line.substring(0, index).trim();
  final selectorPart = line.substring(index + delimiter.length).trim();
  if (selectorPart.isEmpty) {
    return const CategorizedLine(invalidCount: 1);
  }
  final domains = domainPart.isEmpty
      ? ['']
      : domainPart
            .split(',')
            .map((domain) => domain.trim())
            .where((domain) => domain.isNotEmpty)
            .toList();
  if (domains.isEmpty) {
    return const CategorizedLine(invalidCount: 1);
  }
  return CategorizedLine(
    cosmeticRules: [
      for (final domain in domains)
        ParsedCosmeticRule(
          domain: domain,
          selector: selectorPart,
          rawLine: originalLine,
          isException: isException,
        ),
    ],
  );
}

/// 是否把该值当 URL / 路径规则处理（`isUrlOrPathRule`）。
bool _isUrlOrPathRule(String value) {
  final lower = value.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return true;
  }
  if (lower.startsWith('|http://') || lower.startsWith('|https://')) {
    return true;
  }
  // ||domain/path^ 或 ||*/path^
  if (value.startsWith('||') && value.substring(2).contains('/')) {
    return true;
  }
  // 纯路径规则：*/api/... 或 /api/...（排除 /.../ 正则）
  if (value.startsWith('*/') && value.length > 2) {
    return true;
  }
  if (value.startsWith('/') && !value.endsWith('/') && value.length > 2) {
    return true;
  }
  return false;
}

String _cleanUrlPattern(String value) {
  var cleaned = value.startsWith('||') ? value.substring(2) : value;
  if (cleaned.startsWith('|')) {
    cleaned = cleaned.substring(1);
  }
  cleaned = cleaned.replaceFirst(RegExp(r'\^+$'), '');
  return cleaned.trim();
}

/// Dart 的 `RegExp` 没有「只校验不匹配」的构造器；能编译就算合法。
bool _isValidRegex(String pattern) {
  try {
    RegExp(pattern);
    return true;
  } on FormatException {
    return false;
  }
}

/// `$dnsrewrite=` 的目标 IP 归一化：`parseNumericAddressSafe` 的薄封装，
/// 单独提出来是为了让调用点读起来是「这是 IP 分支」。
class InternetAddressParse {
  const InternetAddressParse._();

  static String? numeric(String value) => parseNumericAddressSafe(value);
}

/// 规则去重键（`AdGuardRuleParser.blockRuleKey` / `allowRuleKey` /
/// `rewriteRuleKey`）。
///
/// 键必须包含 `important` / `appScope` / `appInverted` 等所有区分维度：只按
/// pattern 去重会把「仅对某 app 生效的重要拦截」和「全局普通拦截」判成同一条，
/// 后者会覆盖前者。
String blockRuleKey(
  String pattern, {
  required bool important,
  String? appScope,
  bool appInverted = false,
  String? denyallow,
  bool isRegex = false,
  String? dnsType,
}) => _ruleKey(
  'block',
  pattern,
  important: important,
  appScope: appScope,
  appInverted: appInverted,
  denyallow: denyallow,
  isRegex: isRegex,
  dnsType: dnsType,
);

String allowRuleKey(
  String pattern, {
  required bool important,
  String? appScope,
  bool appInverted = false,
  String? denyallow,
  bool isRegex = false,
  String? dnsType,
}) => _ruleKey(
  'allow',
  pattern,
  important: important,
  appScope: appScope,
  appInverted: appInverted,
  denyallow: denyallow,
  isRegex: isRegex,
  dnsType: dnsType,
);

String rewriteRuleKey(String pattern, String targetType, String targetValue) =>
    'rewrite:$pattern:$targetType:$targetValue';

String _ruleKey(
  String prefix,
  String pattern, {
  required bool important,
  String? appScope,
  required bool appInverted,
  String? denyallow,
  required bool isRegex,
  String? dnsType,
}) {
  final base = '$prefix:$pattern:$important:$appScope:$appInverted';
  final hasExtra =
      (denyallow != null && denyallow.isNotEmpty) || isRegex ||
      (dnsType != null && dnsType.isNotEmpty);
  if (!hasExtra) {
    return base;
  }
  return '$base:${denyallow ?? ''}:$isRegex:${dnsType ?? ''}';
}

/// `ParsedRule` 的 block 键。
String blockKeyOf(ParsedRule rule) => blockRuleKey(
  rule.pattern,
  important: rule.important,
  appScope: rule.appScope,
  appInverted: rule.appInverted,
  denyallow: rule.denyallow,
  isRegex: rule.isRegex,
  dnsType: rule.dnsType,
);

/// `ParsedRule` 的 allow 键。
String allowKeyOf(ParsedRule rule) => allowRuleKey(
  rule.pattern,
  important: rule.important,
  appScope: rule.appScope,
  appInverted: rule.appInverted,
  denyallow: rule.denyallow,
  isRegex: rule.isRegex,
  dnsType: rule.dnsType,
);

/// `ParsedRewriteRule` 的键。
String rewriteKeyOf(ParsedRewriteRule rule) =>
    rewriteRuleKey(rule.pattern, rule.targetType, rule.targetValue);
