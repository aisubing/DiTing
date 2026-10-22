/// IP 质量检测：并发查询多个公开 IP 情报源，合并出一份可判读的报告。
///
/// ## 上一轮是什么
///
/// `IpQualityNotifier.detect()` 是 `await Future.delayed(1000ms)`，报告本身来自
/// `mockIpQualityReport`（写死的 `203.0.113.24` / `AS64500` / 「风险」）。页面顶部有
/// `DemoPageNotice` 如实说明，但「重新检测」按钮点下去**只有 loading 动画在动**——
/// 数字、机构、ASN、命中情况全是常量。
///
/// ## 设计取舍
///
/// 1. **多源并发、逐源独立记账**。任何一个源超时/限流都不该让整次检测失败：
///    报告的用途是「看这个 IP 在各家眼里像什么」，缺一家只是少一行，不是没有结论。
/// 2. **不猜结论**。汇总级别只根据真正拿到的数据推断；一个源都没通就报失败，
///    而不是回落到「优秀」。
/// 3. **超时短**（6 秒）。这是辅助工具，用户等 30 秒会以为卡死。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 单个情报源的结果。
class IpSourceResult {
  const IpSourceResult({
    required this.name,
    required this.status,
    this.ipType,
    this.latencyMs,
    this.detail,
    this.organization,
    this.asn,
  });

  final String name;

  /// 「命中」/「超时」/「限流」/「失败」/「IP 不一致」。
  final String status;

  /// 该源给出的类型判断（住宅 / 移动 / 商业 / 机房），拿不到为 null。
  final String? ipType;
  final int? latencyMs;

  /// 失败时的原因；成功时可为空。
  final String? detail;

  /// 该源给出的组织名称。
  final String? organization;

  /// 该源给出的 ASN，形如 `AS15169`。
  final String? asn;

  bool get isHit => status == '命中';
}

/// 一次检测的完整结果。
class IpQualityReport {
  const IpQualityReport({
    required this.ip,
    required this.ipType,
    required this.level,
    required this.organization,
    required this.asn,
    required this.sources,
  });

  final String ip;
  final String ipType;

  /// 优秀 / 一般 / 风险。只在至少一个源命中时有意义。
  final String level;
  final String organization;
  final String asn;
  final List<IpSourceResult> sources;

  int get hitCount => sources.where((s) => s.isHit).length;
}

/// 检测失败的原因。
class IpQualityFailure {
  const IpQualityFailure(this.message);

  final String message;
}

/// 检测结果：报告或失败，二者取一。
sealed class IpQualityOutcome {
  const IpQualityOutcome();
}

class IpQualitySuccess extends IpQualityOutcome {
  const IpQualitySuccess(this.report);

  final IpQualityReport report;
}

class IpQualityError extends IpQualityOutcome {
  const IpQualityError(this.failure);

  final IpQualityFailure failure;
}

/// 多源 IP 质量检测器。
class IpQualityChecker {
  const IpQualityChecker({
    this.timeout = const Duration(seconds: 6),
    this.probeUrls = const [
      'https://api64.ipify.org?format=json',
      'https://api.ip.sb/ip',
      'https://ifconfig.me/ip',
    ],
    this.ipApiUrl = 'http://ip-api.com/json',
    this.ipWhoIsUrl = 'https://ipwho.is',
    this.ipInfoUrl = 'https://ipinfo.io',
  });

  final Duration timeout;

  /// 先问「我现在的出口 IP 是多少」，按顺序逐个试。
  ///
  /// 必须实测而不是读本机网卡：用户关心的是翻墙后的出口，而网卡地址是内网。
  ///
  /// **这是一条回退链而不是一个地址**，因为实测（emulator-5554）上
  /// `api.ipify.org` 直接 `curl` 返回 `000`（连接被重置），而 `api64.ipify.org`
  /// 同一个服务是 200。单端点实现会把「一个探测域名在你网络里不通」变成「IP 质量
  /// 检测不可用」，而用户看到的只是一句「网络不可达」——他会去查自己的网络，实际上
  /// 网络是好的。
  final List<String> probeUrls;

  /// 三个情报源的基地址。
  ///
  /// 做成可覆盖有正当用途：单元测试要对着本地假服务器验证「一个源挂了不影响
  /// 其余源」「全部源挂了要明确报错」这些分支，而真实源既慢又限流。
  final String ipApiUrl;
  final String ipWhoIsUrl;
  final String ipInfoUrl;

  /// 依次：取出口 IP → 并发查各源 → 汇总。
  Future<IpQualityOutcome> detect() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final probe = await _myIp(client);
      if (probe == null) {
        return const IpQualityError(
          IpQualityFailure('无法获取当前出口 IP：网络不可达或探测服务超时'),
        );
      }
      final sources = await _querySources(client, probe);
      if (sources.every((source) => !source.isHit)) {
        // 一个源都没通：明确失败，而不是编一份「优秀」。
        return const IpQualityError(
          IpQualityFailure('所有 IP 情报源均未返回结果，请检查网络后重试'),
        );
      }
      return IpQualitySuccess(_summarize(probe, sources));
    } finally {
      client.close(force: true);
    }
  }

  /// 取出口 IP：按 [probeUrls] 顺序试，第一个给出合法 IP 的胜出。
  Future<String?> _myIp(HttpClient client) async {
    for (final url in probeUrls) {
      final ip = await _fetchIp(client, url);
      if (ip != null) return ip;
    }
    return null;
  }

  Future<String?> _fetchIp(HttpClient client, String url) async {
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'DITING-Android');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      if (response.statusCode != 200) return null;
      final raw = body.trim();
      // `{"ip":"1.2.3.4"}` 与纯文本 `1.2.3.4` 两种形态都要认。
      if (raw.startsWith('{')) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['ip'] is String) {
          final ip = (decoded['ip'] as String).trim();
          return _isIpLike(ip) ? ip : null;
        }
        return null;
      }
      return _isIpLike(raw) ? raw : null;
    } on Object {
      return null;
    }
  }

  /// 只接受「像 IP 的字符串」。
  ///
  /// 有的探测端点会回一段 HTML（门户劫持、运营商插播、限流页），把整段 HTML
  /// 当出口 IP 拿去查三个情报源，结果是一屏「失败」而没有一句能读懂的原因。
  static bool _isIpLike(String value) {
    if (value.isEmpty || value.length > 45) return false;
    return RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(value);
  }

  /// 并发查各源；每个源各自失败、各自记一行。
  Future<List<IpSourceResult>> _querySources(HttpClient client, String ip) async {
    final probes = <Future<IpSourceResult>>[
      _ipApi(client, ip),
      _ipWhoIs(client, ip),
      _ipInfo(client, ip),
    ];
    return Future.wait(probes);
  }

  /// `ip-api.com`：免费、无需 key，HTTP 明文（该服务的 TLS 是付费功能）。
  Future<IpSourceResult> _ipApi(HttpClient client, String ip) async {
    final watch = Stopwatch()..start();
    return _get(client, 'ip-api.com', '$ipApiUrl/$ip?fields=status,message,as,isp,org', (
      body,
    ) {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['status'] != 'success') {
        // 该服务用 `{"status":"fail","message":"private range"}` 表达失败，
        // `message` 就是唯一有价值的信息（例如「私有地址」）。
        return _ProbeOutcome(
          status: '失败',
          detail: decoded is Map ? '${decoded['message'] ?? ''}' : null,
        );
      }
      return _ProbeOutcome(
        status: '命中',
        ipType: _classify('${decoded['as'] ?? ''} ${decoded['isp'] ?? ''} ${decoded['org'] ?? ''}'),
        organization: '${decoded['isp'] ?? decoded['org'] ?? ''}',
        asn: _asnOf('${decoded['as'] ?? ''}'),
      );
    }, watch);
  }

  /// `ipwho.is`：免费、HTTPS、支持 IPv6。
  Future<IpSourceResult> _ipWhoIs(HttpClient client, String ip) async {
    final watch = Stopwatch()..start();
    return _get(client, 'ipwho.is', '$ipWhoIsUrl/$ip', (body) {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['success'] == false) {
        return _ProbeOutcome(
          status: '失败',
          detail: decoded is Map ? '${decoded['message'] ?? ''}' : null,
        );
      }
      // 上面已排除非 Map，所以这里直接取。
      final connection = decoded['connection'];
      final asnText = connection is Map ? '${connection['asn'] ?? ''}' : '';
      return _ProbeOutcome(
        status: '命中',
        ipType: _classify(
          connection is Map
              ? '${connection['isp'] ?? ''} ${connection['org'] ?? ''} ${connection['domain'] ?? ''}'
              : '',
        ),
        organization: connection is Map ? '${connection['isp'] ?? connection['org'] ?? ''}' : '',
        asn: asnText.isEmpty ? '' : 'AS$asnText',
      );
    }, watch);
  }

  /// `ipinfo.io`：免费额度有限，`org` 形如 `AS15169 Google LLC`。
  Future<IpSourceResult> _ipInfo(HttpClient client, String ip) async {
    final watch = Stopwatch()..start();
    return _get(client, 'ipinfo.io', '$ipInfoUrl/$ip/json', (body) {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const _ProbeOutcome(status: '失败');
      }
      // 免费额度用尽时返回 `{"error": {...}}` 而不是 4xx。
      if (decoded['error'] != null) {
        return _ProbeOutcome(
          status: '限流',
          detail: decoded['error'] is Map
              ? '${(decoded['error'] as Map)['message'] ?? ''}'
              : null,
        );
      }
      final org = '${decoded['org'] ?? ''}';
      return _ProbeOutcome(
        status: '命中',
        ipType: _classify(org),
        organization: _orgNameOf(org),
        asn: _asnOf(org),
      );
    }, watch);
  }

  /// 统一的一次 GET + 解析 + 错误归类。
  Future<IpSourceResult> _get(
    HttpClient client,
    String name,
    String url,
    _ProbeOutcome Function(String body) parse,
    Stopwatch watch,
  ) async {
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'DITING-Android');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      watch.stop();
      if (response.statusCode == 429) {
        return IpSourceResult(
          name: name,
          status: '限流',
          latencyMs: watch.elapsedMilliseconds,
        );
      }
      if (response.statusCode != 200) {
        return IpSourceResult(
          name: name,
          status: '失败',
          latencyMs: watch.elapsedMilliseconds,
          detail: 'HTTP ${response.statusCode}',
        );
      }
      final outcome = parse(body);
      return IpSourceResult(
        name: name,
        status: outcome.status,
        ipType: outcome.ipType,
        latencyMs: watch.elapsedMilliseconds,
        detail: outcome.detail,
        organization: outcome.organization,
        asn: outcome.asn,
      );
    } on TimeoutException {
      return IpSourceResult(name: name, status: '超时');
    } on SocketException {
      return IpSourceResult(name: name, status: '超时', detail: '无法连接');
    } on FormatException {
      return IpSourceResult(name: name, status: '失败', detail: '响应不是合法 JSON');
    } on Object catch (error) {
      return IpSourceResult(name: name, status: '失败', detail: '$error');
    }
  }

  /// 从组织/ISP 文本推断类型。
  ///
  /// 关键词表而不是机器学习：这份报告只是给用户一个方向，写死几个最常见的
  /// IDC / 移动运营商关键词已经能覆盖绝大多数误判，而不会把「Cloudflare」判成住宅。
  static String _classify(String text) {
    final lower = text.toLowerCase();
    const datacenter = [
      'hosting', 'datacenter', 'data center', 'cloud', 'server', 'vps',
      'amazon', 'aws', 'google', 'microsoft', 'azure', 'digitalocean',
      'linode', 'vultr', 'ovh', 'hetzner', 'cloudflare', 'alibaba', 'tencent',
      'leaseweb', 'contabo', 'oracle',
    ];
    const mobile = [
      'mobile', 'wireless', 'cellular', 'china mobile', '中国移动',
      'china unicom', '中国联通', 'china telecom', '中国电信', '4g', '5g',
    ];
    for (final keyword in mobile) {
      if (lower.contains(keyword)) return '移动';
    }
    for (final keyword in datacenter) {
      if (lower.contains(keyword)) return '机房';
    }
    if (lower.contains('university') || lower.contains('college')) return '商业';
    // 兜底用「商业」而不是「住宅」：把机房误标成住宅会让用户以为 IP 很干净。
    return '商业';
  }

  /// `AS15169 Google LLC` → `AS15169`。
  static String _asnOf(String org) {
    final match = RegExp(r'AS\d+').firstMatch(org);
    return match?.group(0) ?? '';
  }

  /// `AS15169 Google LLC` → `Google LLC`。
  static String _orgNameOf(String org) {
    return org.replaceFirst(RegExp(r'^AS\d+\s*'), '').trim();
  }

  /// 汇总：类型取「命中源里出现最多的」，级别按类型与命中数。
  static IpQualityReport _summarize(String ip, List<IpSourceResult> sources) {
    final hits = sources.where((s) => s.isHit).toList();
    final typeCounts = <String, int>{};
    for (final hit in hits) {
      final type = hit.ipType;
      if (type == null || type.isEmpty) continue;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    var ipType = '商业';
    if (typeCounts.isNotEmpty) {
      // 票数相同时取「更保守」的那个：机房 > 商业 > 移动，避免把机房说成住宅。
      const severity = {'机房': 3, '商业': 2, '移动': 1};
      final sorted = typeCounts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return (severity[b.key] ?? 0).compareTo(severity[a.key] ?? 0);
        });
      ipType = sorted.first.key;
    }

    // 级别：机房 = 风险（多数流媒体/银行会拦）；移动 = 优秀；商业 = 一般。
    final level = switch (ipType) {
      '机房' => '风险',
      '移动' => '优秀',
      _ => '一般',
    };

    // 组织与 ASN 取第一个非空值：多源给出的名称常有细微差异，混起来更误导。
    return IpQualityReport(
      ip: ip,
      ipType: ipType,
      level: level,
      organization: _firstOf(hits.map((s) => s.organization)) ?? '',
      asn: _firstOf(hits.map((s) => s.asn)) ?? '',
      sources: sources,
    );
  }

  /// 命中源里第一个非空字段。
  static String? _firstOf(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

/// 单个源解析后的中间结果。
class _ProbeOutcome {
  const _ProbeOutcome({
    required this.status,
    this.ipType,
    this.organization,
    this.asn,
    this.detail,
  });

  final String status;
  final String? ipType;
  final String? organization;
  final String? asn;
  final String? detail;
}
