/// 把「日志里的真实数据」整理成给模型看的上下文与提示词。
///
/// 照抄 1.4.3 `AgentAnalysisSheet.kt` 的两个分支：
/// - 域名分析：先查该域名的最近 5 条 `dns_log` 当上下文；
/// - 流量分析：取最近 40 条 `dns_log` + 30 条 `http_request_log`，统计总数、
///   拦截/覆写/缓存命中、高频域名，再拼成摘要正文。
///
/// ## 为什么上下文必须来自真实表
///
/// 上一轮这两个入口弹的是一份写死的研判（「风险等级：中」）。让模型对着**真实**
/// 日志下结论，用户才能验证它说得对不对；对着编出来的摘要，模型再对也只是把假话
/// 复述一遍。所以这里的 `summary` 一个字都不编：表为空就明确写「没有记录」，
/// 由提示词要求模型说明「样本不足」。
library;

import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';

/// 分析对象。
sealed class AgentAnalysisTarget {
  const AgentAnalysisTarget();

  /// 标题（旧版 `AnalysisTarget` 的界面文案）。
  String get title;
}

/// 分析一个域名；[contextLogs] 是调用方已经拿到的额外上下文（可选）。
class AgentDomainTarget extends AgentAnalysisTarget {
  const AgentDomainTarget(this.domain, {this.contextLogs = const []});

  final String domain;
  final List<String> contextLogs;

  @override
  String get title => '域名安全分析';
}

/// 分析最近流量。
class AgentTrafficTarget extends AgentAnalysisTarget {
  const AgentTrafficTarget();

  @override
  String get title => '网络流量分析';
}

/// 一次分析的输入：系统提示词 + 用户提示词。
class AgentAnalysisRequest {
  const AgentAnalysisRequest({required this.systemPrompt, required this.userPrompt});

  final String systemPrompt;
  final String userPrompt;
}

/// 默认系统提示词（旧版 `AgentApiClient.analyzeDomain` 里的兜底值）。
const defaultAgentSystemPrompt =
    '你是一名资深网络安全与 DNS 分析专家。你的任务是对用户给定的域名进行客观、'
    '准确、深入的安全分析。';

/// 汇总最近日志，供流量分析使用。
class RecentTrafficSummary {
  const RecentTrafficSummary({
    required this.dnsSamples,
    required this.blockedDns,
    required this.rewrittenDns,
    required this.cachedDns,
    required this.topDomains,
    required this.httpSamples,
    required this.blockedHttp,
    required this.bypassedHttp,
    this.unavailableReason,
  });

  final int dnsSamples;
  final int blockedDns;
  final int rewrittenDns;
  final int cachedDns;

  /// 按请求次数降序的前 8 个域名。
  final List<({String domain, int count})> topDomains;

  final int httpSamples;
  final int blockedHttp;
  final int bypassedHttp;

  /// 表不可用（极速库没有 `http_request_log` 等）时的原因；只影响 HTTPS 段。
  final String? unavailableReason;

  bool get isEmpty => dnsSamples == 0 && httpSamples == 0;

  /// 给模型看的正文。空数据时明说「没有记录」而不是省略这一段——
  /// 省略会让模型以为「没提就是没问题」。
  String render() {
    final buffer = StringBuffer()
      ..writeln('【近期 DNS 监控统计】')
      ..writeln('- 采样数量: $dnsSamples 条')
      ..writeln(
        '- 规则拦截: $blockedDns 条, 规则覆写: $rewrittenDns 条, '
        '缓存命中: $cachedDns 条',
      );
    if (topDomains.isEmpty) {
      buffer.writeln('- 高频请求域名: 采样窗口内没有任何 DNS 记录');
    } else {
      buffer.writeln('- 高频请求域名:');
      for (final entry in topDomains) {
        buffer.writeln('  * ${entry.domain} (请求 ${entry.count} 次)');
      }
    }
    buffer
      ..writeln()
      ..writeln('【近期 HTTP/HTTPS 流量统计】');
    if (unavailableReason != null) {
      buffer.writeln('- 本工作模式没有 HTTPS 检查面：$unavailableReason');
    } else if (httpSamples == 0) {
      buffer.writeln('- 采样数量: 0 条（未装/未信任 CA 时不产生此类记录）');
    } else {
      buffer.writeln(
        '- 采样数量: $httpSamples 条, 拦截数: $blockedHttp, '
        '旁路直连数: $bypassedHttp',
      );
    }
    return buffer.toString().trimRight();
  }
}

/// 从两张真实日志表汇总最近一段窗口。
///
/// [httpRepository] 为 null 表示该工作模式没有 HTTPS 检查面（极速模式明确排除
/// `http_request_log`），这一步不能当成失败——首页与仪表盘也是这么处理的。
Future<RecentTrafficSummary> summarizeRecentTraffic({
  required DnsLogRepository dnsRepository,
  HttpRequestRepository? httpRepository,
  int dnsLimit = 40,
  int httpLimit = 30,
  String? httpUnavailableReason,
}) async {
  final dnsRows = await dnsRepository.recent(limit: dnsLimit);
  final counts = <String, int>{};
  var blocked = 0;
  var rewritten = 0;
  var cached = 0;
  for (final row in dnsRows) {
    counts[row.domain] = (counts[row.domain] ?? 0) + 1;
    final result = row.result.toUpperCase();
    if (result == 'BLOCKED') blocked++;
    if (result == 'REWRITTEN') rewritten++;
    if (row.cached) cached++;
  }
  final top =
      counts.entries.toList()..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

  var httpSamples = 0;
  var blockedHttp = 0;
  var bypassedHttp = 0;
  var unavailable = httpUnavailableReason;
  if (httpRepository != null && unavailable == null) {
    try {
      final rows = await httpRepository.recent(limit: httpLimit);
      httpSamples = rows.length;
      for (final row in rows) {
        final outcome = row.outcome.toLowerCase();
        if (outcome == 'blocked') blockedHttp++;
        if (outcome == 'passthrough' || outcome == 'bypassed') bypassedHttp++;
      }
    } on Object catch (error) {
      // 极速库没有这张表时抛 `no such table`；那说明「这一面不存在」，
      // 而不是「没有流量」，两者在提示词里必须分开说。
      unavailable = '$error';
    }
  }

  return RecentTrafficSummary(
    dnsSamples: dnsRows.length,
    blockedDns: blocked,
    rewrittenDns: rewritten,
    cachedDns: cached,
    topDomains: [
      for (final entry in top.take(8))
        (domain: entry.key, count: entry.value),
    ],
    httpSamples: httpSamples,
    blockedHttp: blockedHttp,
    bypassedHttp: bypassedHttp,
    unavailableReason: unavailable,
  );
}

/// 拼出一次分析请求。提示词的四个小节照抄旧版，因为下游用户已经习惯了那份结构
/// （域名归属 / 风险评估 / 处置建议 / 简要总结）。
AgentAnalysisRequest buildDomainAnalysisRequest({
  required String domain,
  required String systemPrompt,
  String? context,
}) {
  final buffer = StringBuffer()
    ..writeln('请对以下目标域名进行网络安全与解析特征分析：')
    ..writeln('目标域名：$domain');
  if (context != null && context.trim().isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('【近期设备请求与命中上下文】：')
      ..writeln(context.trim());
  }
  buffer
    ..writeln()
    ..writeln('请按以下结构输出分析报告（使用 Markdown 标题与要点列表，保持清晰明确）：')
    ..writeln('### 1. 域名归属与服务画像')
    ..writeln(
      '说明该域名所属厂商、业务分类（例如：核心云服务/CDN节点/常规业务/'
      '广告追踪/数据遥测/异常外联等）。',
    )
    ..writeln('### 2. 安全与风险评估')
    ..writeln(
      '明确给出风险评级：【安全】、【低风险】、【中风险】或【高危】，'
      '并说明原因（是否存在恶意挖矿、C2控制、钓鱼欺诈、隐私追踪等特征）。',
    )
    ..writeln('### 3. 处置建议')
    ..writeln(
      '给出具体处置建议：【建议正常放行】、【建议加入白名单】、'
      '【建议加入屏蔽规则】或【建议旁路直连】，并说明理由。',
    )
    ..writeln('### 4. 简要总结')
    ..writeln('用 1~2 句话概括最终结论。');
  return AgentAnalysisRequest(
    systemPrompt: systemPrompt.trim().isEmpty
        ? defaultAgentSystemPrompt
        : systemPrompt.trim(),
    userPrompt: buffer.toString().trimRight(),
  );
}

/// 拼出流量分析请求。
AgentAnalysisRequest buildTrafficAnalysisRequest({
  required RecentTrafficSummary summary,
  required String systemPrompt,
}) {
  final buffer = StringBuffer()
    ..writeln('以下是当前设备近期产生的网络请求与 DNS 解析监控统计数据：')
    ..writeln('---')
    ..writeln(summary.render())
    ..writeln('---')
    ..writeln();
  if (summary.isEmpty) {
    // 空样本必须显式要求模型别编：这是唯一能让模型诚实回答的办法。
    buffer.writeln(
      '注意：以上采样窗口内没有任何记录。请明确说明「样本不足，无法研判」，'
      '不要编造域名或请求特征。',
    );
  } else {
    buffer
      ..writeln('请根据以上流量数据，生成一份网络安全分析报告（使用 Markdown 格式）：')
      ..writeln('### 1. 总体网络安全状况')
      ..writeln(
        '评估当前网络健康度等级（【健康良好】/【存在一般隐患】/【高风险可疑】），'
        '总结当前网络请求的总体特征。',
      )
      ..writeln('### 2. 关键与异常请求分析')
      ..writeln('指出数据中高频请求、被频繁拦截、具有潜在数据遥测或可疑外联行为的域名与协议。')
      ..writeln('### 3. 防护效果评估')
      ..writeln('分析当前软件规则拦截率是否处于合理区间，是否存在策略过度或防护盲区。')
      ..writeln('### 4. 优化建议')
      ..writeln('列举建议加入黑名单屏蔽的风险域名，以及可能误拦截建议加入白名单的业务域名。');
  }
  return AgentAnalysisRequest(
    systemPrompt: systemPrompt.trim().isEmpty
        ? '你是一名网络安全与 DNS 流量分析专家，精通 DNS 协议、网络威胁防御和隐私保护。'
        : systemPrompt.trim(),
    userPrompt: buffer.toString().trimRight(),
  );
}
