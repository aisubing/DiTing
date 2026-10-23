/// AI analysis layer: client, model listing, connectivity test and the state machine for one run.
library;

import 'package:diting/data/agent/agent_analysis.dart';
import 'package:diting/data/agent/agent_api_client.dart';
import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real OpenAI-compatible client; tests inject a fake via `overrideWithValue`. Rebuilds when the
/// `/config/user-agents` selection changes, so a gateway that filters on UA sees the chosen one.
final agentApiClientProvider = Provider<AgentApiClient>(
  (ref) => AgentApiClient(userAgent: ref.watch(requestUserAgentProvider)),
);

/// Active provider as [AgentChatConfig]; null when no key is configured.
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

  /// Prompt summary (traffic analysis only). Shown so users can check what the model actually saw.
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

class AgentAnalysisNotifier extends Notifier<AgentAnalysisState> {
  @override
  AgentAnalysisState build() => const AgentAnalysisState();

  /// Runs one analysis. [extraContext] carries context the caller already has, e.g. blocking
  /// records.
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
      // Never leave the UI spinning: turn unknown errors into a readable message.
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
          // Without the legacy DB this feature is unavailable, not "no traffic".
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

/// Fetches the model list for the current dialog; one-shot user action, so it stays out of a
/// provider.
Future<List<String>> fetchAgentModels(
  WidgetRef ref, {
  required String baseUrl,
  required String apiKey,
}) => ref.read(agentApiClientProvider).fetchModels(
  baseUrl: baseUrl,
  apiKey: apiKey,
);


Future<AgentChatResult> testAgentConnection(
  WidgetRef ref,
  AgentChatConfig config,
) => ref.read(agentApiClientProvider).testConnection(config);
