/// 域名归一化与字面量 IP 判定（1.4.3 `AdGuardDomainUtils` 的移植）。
///
/// 旧版用 `android.net.InetAddresses` / `java.net.IDN` 做校验，Dart 里对应
/// `InternetAddress.tryParse` 与 `Uri` 的 IDNA 处理。两者的边界不完全相同，
/// 因此这里对**宽松方向**做了取舍：判定不出来的按「非法」处理（返回 null），
/// 让规则被计入 invalid 而不是带着一个坏 pattern 入库——坏 pattern 进了库会
/// 变成引擎侧一条永远匹配不上的规则，比丢弃更难排查。
library;

import 'dart:io';

/// 黑洞地址：这些 hosts 目标表示「拦截」而不是「改写」。
const sinkholeAddresses = {'0', '0.0.0.0', '127.0.0.1', '::', '::1'};

final _domainLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');

/// `$dnstype=` 允许的取值（`AdGuardDomainUtils.VALID_DNS_TYPES`）。
const validDnsTypes = {
  'A',
  'AAAA',
  'CNAME',
  'HTTPS',
  'SVCB',
  'TXT',
  'MX',
  'PTR',
  'SRV',
  'SOA',
  'NS',
  'ANY',
  'CAA',
  'DS',
  'DNSKEY',
};

/// 只对 HTTP(S) 有意义、对 DNS 层没有意义的修饰符前缀。
///
/// 命中这些的行整行忽略（计入 ignored 而不是 unsupported）：它们不是坏规则，
/// 只是本应用（DNS 层）不消费。
const _webOnlyModifierPrefixes = [
  'domain=',
  '~domain=',
  'to=',
  '~to=',
  'method=',
  '~method=',
  'header=',
  '~header=',
  'redirect=',
  'redirect-rule=',
  'removeparam=',
  'removeheader=',
  'replace=',
  'urltransform=',
  'cookie=',
  'csp=',
  'permissions=',
  'jsonprune=',
  'xmlprune=',
  'referrerpolicy=',
  'reason=',
];

const _webOnlyModifierTokens = {
  'third-party',
  '~third-party',
  'strict-third-party',
  'strict-first-party',
  'match-case',
  'network',
  'document',
  '~document',
  'subdocument',
  '~subdocument',
  'script',
  '~script',
  'stylesheet',
  '~stylesheet',
  'image',
  '~image',
  'font',
  '~font',
  'media',
  '~media',
  'object',
  '~object',
  'xmlhttprequest',
  '~xmlhttprequest',
  'websocket',
  '~websocket',
  'ping',
  '~ping',
  'other',
  '~other',
  'popup',
  '~popup',
  'elemhide',
  'ehide',
  'generichide',
  'ghide',
  'specifichide',
  'shide',
  'genericblock',
  'urlblock',
  'content',
  'jsinject',
  'extension',
  'hls',
  'inline-script',
  'inline-font',
};

bool isWebOnlyModifier(String lower) {
  if (_webOnlyModifierTokens.contains(lower)) {
    return true;
  }
  return _webOnlyModifierPrefixes.any(lower.startsWith);
}

/// 是否是字面量 IP（含 `0` 这种黑洞写法）。
bool looksLikeLiteralIp(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 45) {
    return false;
  }
  if (trimmed == '0') {
    return true;
  }
  return InternetAddress.tryParse(trimmed) != null;
}

/// 把字面量 IP 归一成 `hostAddress` 形态（IPv6 会压缩），非 IP 返回 null。
String? parseNumericAddressSafe(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 45) {
    return null;
  }
  final address = InternetAddress.tryParse(trimmed);
  return address?.address;
}

/// 普通域名归一化：拒绝带 `/`、`:`、空格、无点号、字面量 IP、超长与非法标签。
///
/// 返回 null 表示这条规则该被计入 invalid。
String? normalizeDomain(String value) {
  final candidate = value.trim().replaceFirst(RegExp(r'\.+$'), '');
  if (candidate.isEmpty ||
      candidate.contains('/') ||
      candidate.contains(':') ||
      candidate.contains(' ')) {
    return null;
  }
  final ascii = _toAsciiLower(candidate);
  if (ascii == null) {
    return null;
  }
  if (ascii.length > 253 || !ascii.contains('.') || looksLikeLiteralIp(ascii)) {
    return null;
  }
  for (final label in ascii.split('.')) {
    if (label.isEmpty || label.length > 63 || !_domainLabel.hasMatch(label)) {
      return null;
    }
  }
  return ascii;
}

/// 通配域名归一化：额外允许 `*` 与 `_`，且不要求含点号（`*` 单独合法）。
String? normalizeWildcardDomain(String value) {
  final candidate = value.trim().replaceFirst(RegExp(r'\.+$'), '');
  if (candidate.isEmpty ||
      candidate.contains('/') ||
      candidate.contains(':') ||
      candidate.contains(' ')) {
    return null;
  }
  if (candidate == '*') {
    return '*';
  }
  final lower = candidate.toLowerCase();
  if (lower.length > 253) {
    return null;
  }
  for (final label in lower.split('.')) {
    if (label.isEmpty || label.length > 63) {
      return null;
    }
    for (final unit in label.codeUnits) {
      final isLower = unit >= 0x61 && unit <= 0x7a;
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (!isLower && !isDigit && unit != 0x2d && unit != 0x2a && unit != 0x5f) {
        return null;
      }
    }
  }
  return lower;
}

/// 覆写目标归一化：IP 走 IP 归一，其余走域名归一。
String? normalizeDomainForRewrite(String value) {
  final candidate = value.trim().replaceFirst(RegExp(r'\.+$'), '');
  if (candidate.isEmpty) {
    return null;
  }
  if (looksLikeLiteralIp(candidate)) {
    return parseNumericAddressSafe(candidate)?.toLowerCase();
  }
  return normalizeDomain(candidate);
}

/// IDN → ASCII 并小写。非 ASCII 走 `Uri` 的 IDNA 处理。
///
/// 失败返回 null（对应 Kotlin 侧 `IDN.toASCII` 抛 `IllegalArgumentException`）。
String? _toAsciiLower(String value) {
  var isAscii = true;
  for (final unit in value.codeUnits) {
    if (unit > 0x7f) {
      isAscii = false;
      break;
    }
  }
  if (isAscii) {
    // ASCII 域名仍要挡掉 ST3 之外的控制字符与空格（空格已在上面挡过）。
    for (final unit in value.codeUnits) {
      if (unit < 0x21 || unit == 0x7f) {
        return null;
      }
    }
    return value.toLowerCase();
  }
  try {
    // `Uri.parse` 会对非 ASCII 主机做 IDNA 转写；取回 host 即为 punycode。
    final uri = Uri.parse('http://$value/');
    final host = uri.host;
    if (host.isEmpty) {
      return null;
    }
    return host.toLowerCase();
  } on FormatException {
    return null;
  }
}
