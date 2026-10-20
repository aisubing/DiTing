/// 功能中心内几组需要跨页保留的演示状态。
///
/// 这些页面都是「设置页 → 子选择页 → 返回」的结构；如果全部用页面局部状态，
/// 从目标应用页返回后父页会重置。上游把值存在 SharedPreferences，本阶段按
/// 项目约定只做内存态，但生命周期提升到 Riverpod，保持同样的返回体验。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 需要独立选择应用集合的子页。
enum HubAppPool {
  httpInspection('选择检查应用'),
  outboundProxy('选择代理应用');

  const HubAppPool(this.title);

  final String title;
}

class HubAppSelectionsNotifier extends Notifier<Map<HubAppPool, Set<String>>> {
  @override
  Map<HubAppPool, Set<String>> build() => {
    HubAppPool.httpInspection: {'com.example.browser'},
    HubAppPool.outboundProxy: {'com.example.video'},
  };

  Set<String> read(HubAppPool pool) => state[pool] ?? const {};

  void write(HubAppPool pool, Set<String> packages) {
    state = {...state, pool: {...packages}};
  }

  void toggle(HubAppPool pool, String packageName) {
    final next = {...read(pool)};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    write(pool, next);
  }
}

final hubAppSelectionsProvider =
    NotifierProvider<HubAppSelectionsNotifier, Map<HubAppPool, Set<String>>>(
      HubAppSelectionsNotifier.new,
    );

/// HTTPS 流量检查的演示配置。
class HttpInspectionState {
  const HttpInspectionState({
    this.enabled = false,
    this.urlRules = true,
    this.http3 = true,
    this.encryptedDns = false,
    this.caReady = false,
  });

  final bool enabled;
  final bool urlRules;
  final bool http3;
  final bool encryptedDns;
  final bool caReady;

  HttpInspectionState copyWith({
    bool? enabled,
    bool? urlRules,
    bool? http3,
    bool? encryptedDns,
    bool? caReady,
  }) => HttpInspectionState(
    enabled: enabled ?? this.enabled,
    urlRules: urlRules ?? this.urlRules,
    http3: http3 ?? this.http3,
    encryptedDns: encryptedDns ?? this.encryptedDns,
    caReady: caReady ?? this.caReady,
  );
}

class HttpInspectionNotifier extends Notifier<HttpInspectionState> {
  @override
  HttpInspectionState build() => const HttpInspectionState();

  void update(HttpInspectionState Function(HttpInspectionState state) fn) =>
      state = fn(state);

  void setCaReady(bool ready) {
    state = ready
        ? state.copyWith(caReady: true)
        : state.copyWith(caReady: false, enabled: false);
  }
}

final httpInspectionProvider =
    NotifierProvider<HttpInspectionNotifier, HttpInspectionState>(
      HttpInspectionNotifier.new,
    );

/// 出站代理协议。
enum OutboundProtocol {
  socks5('SOCKS5'),
  http('HTTP');

  const OutboundProtocol(this.label);

  final String label;
}

/// 出站代理的演示配置（对齐上游 `OutboundProxyConfig` 的字段）。
class OutboundProxyState {
  const OutboundProxyState({
    this.enabled = false,
    this.protocol = OutboundProtocol.socks5,
    this.host = '127.0.0.1',
    this.port = 7890,
    this.username = '',
    this.password = '',
    this.appPackage = '',
  });

  final bool enabled;
  final OutboundProtocol protocol;
  final String host;
  final int port;
  final String username;
  final String password;
  final String appPackage;

  OutboundProxyState copyWith({
    bool? enabled,
    OutboundProtocol? protocol,
    String? host,
    int? port,
    String? username,
    String? password,
    String? appPackage,
  }) => OutboundProxyState(
    enabled: enabled ?? this.enabled,
    protocol: protocol ?? this.protocol,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
    appPackage: appPackage ?? this.appPackage,
  );

  String? get validationError {
    if (!enabled) {
      return null;
    }
    if (host.trim().isEmpty) {
      return '请填写代理地址';
    }
    if (port < 1 || port > 65535) {
      return '端口需在 1–65535 之间';
    }
    return null;
  }
}

class OutboundProxyNotifier extends Notifier<OutboundProxyState> {
  @override
  OutboundProxyState build() => const OutboundProxyState();

  void update(OutboundProxyState Function(OutboundProxyState state) fn) =>
      state = fn(state);
}

final outboundProxyProvider =
    NotifierProvider<OutboundProxyNotifier, OutboundProxyState>(
      OutboundProxyNotifier.new,
    );

/// DNS 日志记录模式（上游 `DnsLogMode`）。
enum DnsLogMode {
  all('记录全部', '保存通过、拦截和错误请求'),
  blockedAndErrors('仅拦截与错误', '减少数据库写入，同时保留关键记录'),
  off('关闭日志', '不创建或写入 DNS 请求日志');

  const DnsLogMode(this.label, this.description);

  final String label;
  final String description;
}

class LogModeNotifier extends Notifier<({DnsLogMode mode, int retentionDays})> {
  @override
  ({DnsLogMode mode, int retentionDays}) build() =>
      (mode: DnsLogMode.all, retentionDays: 7);

  void setMode(DnsLogMode mode) => state = (mode: mode, retentionDays: state.retentionDays);

  void setRetentionDays(int days) =>
      state = (mode: state.mode, retentionDays: days);
}

final logModeProvider =
    NotifierProvider<LogModeNotifier, ({DnsLogMode mode, int retentionDays})>(
      LogModeNotifier.new,
    );

/// AI 分析里的一家用例（上游 `AiProvider` 的精简模型）。
class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    this.presetId = '',
    this.hasKey = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String presetId;
  final bool hasKey;

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? model,
    bool? hasKey,
  }) => AiProviderConfig(
    id: id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    presetId: presetId,
    hasKey: hasKey ?? this.hasKey,
  );
}

/// AI 分析设置（上游 `AgentApiSettingsStore` + `AgentApiConfig`）。
class AgentApiState {
  const AgentApiState({
    this.enabled = false,
    this.activeProviderId = 'openai',
    this.providers = const [
      AiProviderConfig(
        id: 'openai',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        presetId: 'openai',
        hasKey: true,
      ),
      AiProviderConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-chat',
        presetId: 'deepseek',
      ),
    ],
    this.systemPrompt = '你是一名网络安全与 DNS 威胁情报专家。'
        '擅长对域名安全性、防盗链、DGA 随机特征、恶意软件外联及追踪探针进行分析，'
        '并给出明确的处置建议。',
    this.temperature = 0.3,
  });

  final bool enabled;
  final String activeProviderId;
  final List<AiProviderConfig> providers;
  final String systemPrompt;
  final double temperature;

  AiProviderConfig? get activeProvider =>
      providers.where((provider) => provider.id == activeProviderId).firstOrNull;

  AgentApiState copyWith({
    bool? enabled,
    String? activeProviderId,
    List<AiProviderConfig>? providers,
    String? systemPrompt,
    double? temperature,
  }) => AgentApiState(
    enabled: enabled ?? this.enabled,
    activeProviderId: activeProviderId ?? this.activeProviderId,
    providers: providers ?? this.providers,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    temperature: temperature ?? this.temperature,
  );
}

class AgentApiNotifier extends Notifier<AgentApiState> {
  @override
  AgentApiState build() => const AgentApiState();

  void update(AgentApiState Function(AgentApiState state) fn) => state = fn(state);

  void reset() => state = const AgentApiState();

  void saveProvider(AiProviderConfig provider) {
    final list = [...state.providers];
    final index = list.indexWhere((item) => item.id == provider.id);
    if (index < 0) {
      list.add(provider);
    } else {
      list[index] = provider;
    }
    state = state.copyWith(providers: list, activeProviderId: provider.id);
  }

  void deleteProvider(String id) {
    final list = state.providers.where((item) => item.id != id).toList();
    state = state.copyWith(
      providers: list,
      activeProviderId: state.activeProviderId == id
          ? (list.firstOrNull?.id ?? '')
          : state.activeProviderId,
    );
  }
}

final agentApiProvider =
    NotifierProvider<AgentApiNotifier, AgentApiState>(AgentApiNotifier.new);

/// AI 厂商预设（只用于展示与预填，不预置模型）。
class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.group,
    required this.baseUrl,
  });

  final String id;
  final String name;
  final String group;
  final String baseUrl;
}

const aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    group: '国际厂商',
    baseUrl: 'https://api.openai.com/v1',
  ),
  AiProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    group: '国内厂商',
    baseUrl: 'https://api.deepseek.com/v1',
  ),
  AiProviderPreset(
    id: 'moonshot',
    name: 'Moonshot',
    group: '国内厂商',
    baseUrl: 'https://api.moonshot.cn/v1',
  ),
  AiProviderPreset(
    id: 'ollama',
    name: 'Ollama',
    group: '本地部署',
    baseUrl: 'http://127.0.0.1:11434/v1',
  ),
];
