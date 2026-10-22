/// AI 分析的执行层：客户端实例、模型拉取、连通性测试与一次分析的状态机。
///
/// 上一轮这里什么都没有——「分析一个域名」直接弹一份写死的对话框。现在：
///
/// - 上下文来自真实日志表（`agent_analysis.dart`）；
/// - 请求真发给用户配置的厂商（`AgentApiClient`）；
/// - 四种结果分开呈现：未配置 / 进行中 / 成功（含 token 用量）/ 失败（含原因）。
///
/// 失败原因必须落地成一句话。旧版把 OkHttp 的异常 `message` 直接抛给界面，
/// 常见表现是 `null` 或一行 `CLEARTEXT communication not permitted`——用户
/// 既不知道是哪一步错，也不知道该改哪里。
library;

import 'package:diting/data/agent/agent_analysis.dart';
import 'package:diting/data/agent/agent_api_client.dart';
import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 真实的 OpenAI 兼容客户端；测试用 `overrideWithValue` 注入指向本地假服务的实例。
final agentApiClientProvider = Provider<AgentApiClient>(
  (ref) => const AgentApiClient(),
);

/// 当前生效厂商 → [AgentChatConfig]。未配置密钥时为 null。
final agentChatConfigProvider = Provider<AgentChatConfig?>((ref) {
  final state = ref.watch(agentApiProvider);
  final provider = state.activeProvider;
  if (provider == null) return null;
  return AgentChatConfig(
    baseUrl: provider.baseUrl,
    apiKey: provider.apiKey,
    model: provider.model,
    temperature: state.temperature,
    systemPrompt: state.systemPrompt,
  );
});

/// 一次分析的状态。
class AgentAnalysisState {
  const AgentAnalysisState({
    this.target,
    this.running = false,
    this.result,
    this.error,
    this.summary,
    this.startedAt,
  });

  final AgentAnalysisTarget? target;
  final bool running;
  final AgentChatResult? result;
  final String? error;

  /// 送进提示词的摘要（流量分析才有）。页面上要能对照「模型看到的是什么」，
  /// 否则用户无法判断它说的对不对。
  final RecentTrafficSummary? summary;
  final DateTime? startedAt;

  bool get idle => target == null && !running && result == null && error == null;

  AgentAnalysisState copyWith({
    AgentAnalysisTarget? target,
    bool? running,
    AgentChatResult? result,
    String? error,
    RecentTrafficSummary? summary,
    DateTime? startedAt,
    bool clearResult = false,
    bool clearError = false,
  }) => AgentAnalysisState(
    target: target ?? this.target,
    running: running ?? this.running,
    result: clearResult ? null : (result ?? this.result),
    error: clearError ? null : (error ?? this.error),
    summary: summary ?? this.summary,
    startedAt: startedAt ?? this.startedAt,
  );
}

/// 分析执行器。
class AgentAnalysisNotifier extends Notifier<AgentAnalysisState> {
  @override
  AgentAnalysisState build() => const AgentAnalysisState();

  /// 发一次分析。
  ///
  /// [extraContext] 用于调用方已经拿到的上下文（例如规则页把拦截记录带进来）。
  Future<void> run(
    AgentAnalysisTarget target, {
    List<String> extraContext = const [],
  }) async {
    if (state.running) return;
    final config = ref.read(agentChatConfigProvider);
    if (config == null || !config.hasKey) {
      state = AgentAnalysisState(
        target: target,
        error: '尚未配置可用的 API Key，请先在「AI 厂商管理」里填写并选中该厂商。',
        startedAt: DateTime.now(),
      );
      return;
    }
    state = AgentAnalysisState(
      target: target,
      running: true,
      startedAt: DateTime.now(),
    );
    try {
      final request = await _buildRequest(target, config, extraContext);
      final result = await ref
          .read(agentApiClientProvider)
          .chat(config, [
            AgentChatMessage(role: 'system', content: request.systemPrompt),
            AgentChatMessage(role: 'user', content: request.userPrompt),
          ]);
      state = state.copyWith(
        running: false,
        result: result,
        clearError: true,
      );
    } on AgentApiException catch (error) {
      state = state.copyWith(running: false, error: error.message);
    } on Object catch (error) {
      // 兜底：未知异常也要变成一句人话，不能让页面停在转圈上。
      state = state.copyWith(running: false, error: '分析失败：$error');
    }
  }

  void clear() => state = const AgentAnalysisState();

  Future<AgentAnalysisRequest> _buildRequest(
    AgentAnalysisTarget target,
    AgentChatConfig config,
    List<String> extraContext,
  ) async {
    final db = await ref.read(activeLogDatabaseProvider.future);
    final express = ref.read(workModeProvider) == AppWorkMode.express;
    switch (target) {
      case AgentDomainTarget(:final domain, :final contextLogs):
        final logs = <String>[...contextLogs, ...extraContext];
        if (db != null) {
          final recent = await DnsLogRepository(db).recent(limit: 200);
          final lowered = domain.toLowerCase();
          for (final row in recent) {
            if (logs.length >= 8) break;
            if (!row.domain.toLowerCase().contains(lowered)) continue;
            final message = row.message;
            logs.add(
              'DNS: ${row.domain} -> ${row.result}'
              '${message == null || message.isEmpty ? '（无附加信息）' : '（$message）'}',
            );
          }
        }
        return buildDomainAnalysisRequest(
          domain: domain,
          systemPrompt: config.systemPrompt,
          context: logs.isEmpty ? null : logs.join('\n'),
        );
      case AgentTrafficTarget():
        if (db == null) {
          // 没有旧库时不能假装「没有流量」：那是「这一面不可用」。
          throw const AgentApiException(
            '未找到旧版数据库，无法读取 DNS 与 HTTPS 日志；请先启动一次服务。',
          );
        }
        final summary = await summarizeRecentTraffic(
          dnsRepository: DnsLogRepository(db),
          httpRepository: express ? null : HttpRequestRepository(db),
          httpUnavailableReason: express
              ? '极速模式只做窄路由 DNS 加速，不产生 HTTPS 检查记录'
              : null,
        );
        state = state.copyWith(summary: summary);
        return buildTrafficAnalysisRequest(
          summary: summary,
          systemPrompt: config.systemPrompt,
        );
    }
  }
}

final agentAnalysisProvider =
    NotifierProvider<AgentAnalysisNotifier, AgentAnalysisState>(
      AgentAnalysisNotifier.new,
    );

/// 拉取模型列表的动作（页面直接用，不进 provider：一次性的用户操作，
/// 结果只属于当前对话框）。
Future<List<String>> fetchAgentModels(
  WidgetRef ref, {
  required String baseUrl,
  required String apiKey,
}) => ref.read(agentApiClientProvider).fetchModels(
  baseUrl: baseUrl,
  apiKey: apiKey,
);

/// 连通性测试。
Future<AgentChatResult> testAgentConnection(
  WidgetRef ref,
  AgentChatConfig config,
) => ref.read(agentApiClientProvider).testConnection(config);
