/// AdGuard / ABP / hosts / dnsmasq 规则的逐行解析（1.4.3
/// `AdGuardRuleParser` + `AdblockRuleLineParser` + `HostsAndDnsmasqParser` +
/// `AdGuardDomainUtils` 的合并移植）。
///
/// ## 为什么要有这个文件
/// 上一轮订阅更新只做「下载 + 数行数」：正文拉下来就地丢弃，一条规则都没进
/// 规则库，于是用户订阅了几万条广告域名，拦截行为却毫无变化，而界面还显示
/// 「已更新」。这是整个订阅功能最实质的缺失，不是文案问题。
///
/// ## 与旧版的结构差异
/// 旧版拆成四个 object 是为了 Kotlin 的可见性控制；Dart 里没有等价收益，故合并
/// 成一个库，但**逐条保留**判定顺序与返回值形态：判定顺序决定结果（例如
/// `#$@#` 必须先于 `#$#` 探测，否则异常规则会被当成普通 `#$#` 规则）。
///
/// ## 不支持的族
/// 元素隐藏（cosmetic）规则会解析出来，但**不入库**：本仓的 Go 引擎没有 cosmetic
/// 注入通道，写进表里只会让「已导入 N 条」虚高。调用方按
/// [CategorizedLine.cosmeticRules] 计数并如实说明未生效。
library;

/// `RewriteTargetType`：逐字照抄 `RewriteRuleEntity.kt`，直接写进数据库。
class RewriteTargetType {
  const RewriteTargetType._();

  static const ipv4 = 'IPv4';
  static const ipv6 = 'IPv6';
  static const cname = 'CNAME';
}

/// 解析后的一条域名拦截 / 放行规则（`ParsedRule`）。
class ParsedRule {
  const ParsedRule({
    required this.pattern,
    required this.rawLine,
    this.important = false,
    this.appScope,
    this.appInverted = false,
    this.isWildcard = false,
    this.denyallow,
    this.isRegex = false,
    this.dnsType,
  });

  final String pattern;
  final String rawLine;
  final bool important;
  final String? appScope;
  final bool appInverted;
  final bool isWildcard;
  final String? denyallow;
  final bool isRegex;
  final String? dnsType;
}

/// 解析后的一条 URL / 路径拦截规则（`ParsedUrlRule`）。
class ParsedUrlRule {
  const ParsedUrlRule({
    required this.pattern,
    required this.rawLine,
    this.isAllow = false,
    this.appScope,
    this.important = false,
  });

  final String pattern;
  final String rawLine;
  final bool isAllow;
  final String? appScope;
  final bool important;
}

/// 解析后的一条元素隐藏规则（`ParsedCosmeticRule`）。
class ParsedCosmeticRule {
  const ParsedCosmeticRule({
    required this.domain,
    required this.selector,
    required this.rawLine,
    this.isException = false,
  });

  final String domain;
  final String selector;
  final String rawLine;
  final bool isException;

  String toCss() => '$selector { display: none !important; }';
}

/// 解析后的一条 DNS 覆写规则（`RewriteRule`）。
class ParsedRewriteRule {
  const ParsedRewriteRule({
    required this.pattern,
    required this.targetType,
    required this.targetValue,
    required this.rawLine,
  });

  final String pattern;
  final String targetType;
  final String targetValue;
  final String rawLine;
}

/// 单行的解析结果（`CategorizedLine`）。一行可能展开成多条规则——hosts 与
/// dnsmasq 的一行就带多个域名。
class CategorizedLine {
  const CategorizedLine({
    this.blockRules = const [],
    this.allowRules = const [],
    this.rewriteRules = const [],
    this.urlBlockRules = const [],
    this.urlAllowRules = const [],
    this.cosmeticRules = const [],
    this.badfilterKeys = const {},
    this.invalidCount = 0,
    this.unsupportedCount = 0,
    this.ignoredCount = 0,
  });

  final List<ParsedRule> blockRules;
  final List<ParsedRule> allowRules;
  final List<ParsedRewriteRule> rewriteRules;
  final List<ParsedUrlRule> urlBlockRules;
  final List<ParsedUrlRule> urlAllowRules;
  final List<ParsedCosmeticRule> cosmeticRules;
  final Set<String> badfilterKeys;
  final int invalidCount;
  final int unsupportedCount;
  final int ignoredCount;

  bool get isEmpty =>
      blockRules.isEmpty &&
      allowRules.isEmpty &&
      rewriteRules.isEmpty &&
      urlBlockRules.isEmpty &&
      urlAllowRules.isEmpty &&
      cosmeticRules.isEmpty;
}

/// 一份规则的完整解析结果（`CategorizedRules`）。
class CategorizedRules {
  const CategorizedRules({
    this.blockRules = const [],
    this.allowRules = const [],
    this.rewriteRules = const [],
    this.urlBlockRules = const [],
    this.urlAllowRules = const [],
    this.cosmeticRules = const [],
    this.duplicateCount = 0,
    this.invalidCount = 0,
    this.unsupportedCount = 0,
    this.ignoredCount = 0,
    this.badfilteredCount = 0,
    this.totalLines = 0,
  });

  final List<ParsedRule> blockRules;
  final List<ParsedRule> allowRules;
  final List<ParsedRewriteRule> rewriteRules;
  final List<ParsedUrlRule> urlBlockRules;
  final List<ParsedUrlRule> urlAllowRules;
  final List<ParsedCosmeticRule> cosmeticRules;
  final int duplicateCount;
  final int invalidCount;
  final int unsupportedCount;
  final int ignoredCount;
  final int badfilteredCount;
  final int totalLines;

  int get size =>
      blockRules.length +
      allowRules.length +
      rewriteRules.length +
      urlBlockRules.length +
      urlAllowRules.length +
      cosmeticRules.length;

  int get skippedCount => invalidCount + unsupportedCount;

  bool get isEmpty => size == 0;
}
