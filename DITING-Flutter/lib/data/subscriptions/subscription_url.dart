/// 订阅地址与内容统计的纯函数，转写自 1.4.3
/// `core/rule/SubscriptionUrlHelper.kt`（59 行）。
///
/// 镜像模板的占位符集合、`urlEncoded` 的编码规则、以及「模板必须含占位符且
/// 生成结果是 HTTP(S)」这两条校验都原样保留：1.4.3 已经把这个模板字符串存进了
/// `subscription.mirrorTemplate`，升级用户的行必须能被同一套规则解开。
library;

import 'dart:convert';

/// 模板支持的占位符，与 `SubscriptionUrlHelper.MIRROR_PLACEHOLDERS` 一致。
const mirrorPlaceholders = <String>{
  '{url}',
  '{urlEncoded}',
  '{scheme}',
  '{host}',
  '{path}',
  '{pathAndQuery}',
};

/// 校验并归一化镜像模板（trim，非空，含占位符，能生成合法地址）。
///
/// 返回 null 表示「没有模板」；格式非法时抛 [FormatException]，与上游 `require`
/// 抛 `IllegalArgumentException` 对应——调用方(编辑面板)据此给字段级错误。
String? normalizeMirrorTemplate(String? template) {
  final normalized = template?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (!mirrorPlaceholders.any(normalized.contains)) {
    throw const FormatException(
      '镜像模板必须包含 {url}、{urlEncoded}、{scheme}、{host}、{path} 或 {pathAndQuery}',
    );
  }
  buildMirrorUrl(normalized, 'https://example.com/rules.txt');
  return normalized;
}

/// 按模板生成镜像地址。
///
/// `{urlEncoded}` 用的是 Java `URLEncoder` + `replace("+", "%20")` 的口径，
/// Dart 的 `Uri.encodeComponent` 与它**不等价**（Java 不编码 `*`、把 `~` 编成
/// `%7E`），所以这里手写同一套规则，避免镜像站收到的地址与旧版不同。
String buildMirrorUrl(String template, String originalUrl) {
  final uri = Uri.tryParse(originalUrl);
  if (uri == null) {
    throw const FormatException('原始订阅地址格式无效');
  }
  final path = uri.path.isEmpty ? '/' : uri.path;
  final pathAndQuery = uri.query.isEmpty ? path : '$path?${uri.query}';
  final result = template
      .replaceAll('{urlEncoded}', encodeForJavaUrlEncoder(originalUrl))
      .replaceAll('{url}', originalUrl)
      .replaceAll('{scheme}', uri.scheme)
      .replaceAll('{host}', uri.host)
      .replaceAll('{pathAndQuery}', pathAndQuery)
      .replaceAll('{path}', path);
  if (!result.startsWith('https://') && !result.startsWith('http://')) {
    throw const FormatException('镜像模板生成的地址必须使用 HTTP 或 HTTPS');
  }
  return result;
}

/// `java.net.URLEncoder.encode(value, "UTF-8")` 后把 `+` 换成 `%20`。
///
/// 保留字符集以 `URLEncoder` 为准：`A-Z a-z 0-9` 与 `- _ . *` 原样输出，空格先
/// 变 `+` 再被替换成 `%20`，其余字节按 UTF-8 逐字节 `%XX` 大写十六进制。
String encodeForJavaUrlEncoder(String value) {
  final buffer = StringBuffer();
  for (final byte in utf8BytesOf(value)) {
    final isPlain =
        (byte >= 0x30 && byte <= 0x39) || // 0-9
        (byte >= 0x41 && byte <= 0x5A) || // A-Z
        (byte >= 0x61 && byte <= 0x7A) || // a-z
        byte == 0x2D || // -
        byte == 0x5F || // _
        byte == 0x2E || // .
        byte == 0x2A; // *
    if (isPlain) {
      buffer.writeCharCode(byte);
    } else if (byte == 0x20) {
      // URLEncoder 输出 '+'；上游随后 replace("+", "%20")。
      buffer.write('%20');
    } else {
      buffer.write('%');
      buffer.write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return buffer.toString();
}

/// 从链接里取名（`extractNameFromUrl`）：取路径末段，空则退回主机名。
String extractNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return url;
  }
  final path = uri.path;
  final fileName = path.substring(path.lastIndexOf('/') + 1);
  if (fileName.trim().isNotEmpty) {
    return fileName;
  }
  return uri.host.isNotEmpty ? uri.host : url;
}

/// 订阅内容的「有效行」词法计数（非空、非注释行）。
///
/// **注意口径**：这只是下载层的粗略计数（[SubscriptionFetchResult.lineCount]），
/// **不是**生效规则数。真正的规则条数来自解析 + 入库后的
/// `RuleImportSummary.insertedCount`（见 `lib/data/rules/`），那是 UI 唯一可以当
/// 「已入库 N 条规则」展示的数字。两者可能差很多：`$badfilter`、类型不匹配、
/// 重复行、元素隐藏规则都会被这里的词法计数算进去，却不会入库。
int countEffectiveRuleLines(String content) {
  var count = 0;
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('!') || line.startsWith('#') || line.startsWith('//')) {
      continue;
    }
    count++;
  }
  return count;
}

/// 订阅地址的基本校验：必须是 HTTP(S) 绝对地址且带主机。
///
/// 返回 null 表示通过，否则是可读错误文案（直接上屏）。
String? validateSubscriptionUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return '订阅地址不能为空';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return '订阅地址格式无效';
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return '订阅链接必须使用 HTTP 或 HTTPS';
  }
  if (uri.host.isEmpty) {
    return '订阅地址缺少主机名';
  }
  return null;
}

/// UTF-8 字节序列。`dart:convert` 的 `utf8.encode` 返回 `List<int>`，这里单独
/// 包一层是为了让编码函数不依赖调用方 import `dart:convert`。
List<int> utf8BytesOf(String value) => const Utf8Codec().encode(value);
