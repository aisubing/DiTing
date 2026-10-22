/// AI 分析（Agent API）的设置与调用状态。
///
/// ## 上一轮是什么
///
/// 整页「演示」：厂商列表、密钥、温度、系统提示词全在一个 Notifier 的内存里
/// （`AgentApiNotifier`），杀进程就回到写死的两条预置；两个「功能测试」入口弹的是
/// 一份写死的研判；页脚写着「本演示不会真正发起网络请求」。
///
/// ## 现在
///
/// 1. **落盘**：九个键与厂商 JSON 走 1.4.3 `AgentApiSettingsStore` 的原键名
///    （见 `legacy_settings_parity.dart` 的 AI 分析段），容器是全局
///    `dns_vpn_prefs`。升级用户在这里能看到自己原来那家厂商与密钥。
/// 2. **真实请求**：分析走 `AgentApiClient`，模型名可在线拉取
///    （`GET /models`），连通性测试真发一次 `chat/completions`。
/// 3. **上下文来自真表**：`agent_analysis.dart` 从 `dns_log` /
///    `http_request_log` 汇总最近窗口，模型对着真实数据下结论。
///
/// 密钥在厂商 JSON 里用旧版同一套 `KeyObfuscator` 混淆；只有「当前生效配置」
/// 那四个平铺键（`agent_api_key` 等）沿用旧版的明文写法——旧版就是这么存的，
/// 单方面改成密文会让回退到 1.4.3 的用户读不到自己的 Key。
library;

import 'dart:convert';

import 'package:diting/data/agent/key_obfuscator.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// 厂商模型（旧版 `AiProvider` / `AiProviderPreset`）
// ---------------------------------------------------------------------------

/// 一条已配置的 AI 厂商。`presetId` 非空表示它由内置预设创建。
class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    this.presetId = '',
    this.sealedKey = '',
  });

  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String presetId;

  /// 混淆后的密钥（`KeyObfuscator.seal` 的输出）。空串表示未配置。
  final String sealedKey;

  bool get hasKey => sealedKey.isNotEmpty;

  /// 明文密钥，仅用于构造请求头；不要写进日志或界面。
  String get apiKey => openApiKey(sealedKey);

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? model,
    String? presetId,
    String? sealedKey,
  }) => AiProviderConfig(
    id: id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    presetId: presetId ?? this.presetId,
    sealedKey: sealedKey ?? this.sealedKey,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'apiKey': sealedKey,
    'modelName': model,
    'presetId': presetId,
  };

  /// 解析一条厂商；字段缺失按旧版 `decodeAiProviders` 的宽松方式处理。
  static AiProviderConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}'.trim();
    final baseUrl = '${raw['baseUrl'] ?? ''}'.trim();
    if (id.isEmpty || baseUrl.isEmpty) return null;
    return AiProviderConfig(
      id: id,
      name: '${raw['name'] ?? ''}'.trim().isEmpty
          ? id
          : '${raw['name']}'.trim(),
      baseUrl: baseUrl,
      model: '${raw['modelName'] ?? ''}'.trim(),
      presetId: '${raw['presetId'] ?? ''}'.trim(),
      sealedKey: '${raw['apiKey'] ?? ''}'.trim(),
    );
  }
}

/// 内置厂商预设：只登记名称与接口地址，模型名一律在线拉取。
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

const aiProviderPresetMainland = '国内厂商';
const aiProviderPresetOverseas = '海外厂商';
const aiProviderPresetAggregator = '聚合与本地部署';

/// 照抄旧版 `AiProviderPresets.all`（16 条）：地址均核对自厂商官方文档。
const aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    group: aiProviderPresetMainland,
    baseUrl: 'https://api.deepseek.com',
  ),
  AiProviderPreset(
    id: 'zhipu',
    name: '智谱 GLM',
    group: aiProviderPresetMainland,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
  ),
  AiProviderPreset(
    id: 'moonshot',
    name: 'Kimi（月之暗面）',
    group: aiProviderPresetMainland,
    baseUrl: 'https://api.moonshot.cn/v1',
  ),
  AiProviderPreset(
    id: 'dashscope',
    name: '阿里云百炼（通义千问）',
    group: aiProviderPresetMainland,
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  ),
  AiProviderPreset(
    id: 'volcengine-ark',
    name: '火山方舟（豆包）',
    group: aiProviderPresetMainland,
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
  ),
  AiProviderPreset(
    id: 'minimax',
    name: 'MiniMax',
    group: aiProviderPresetMainland,
    baseUrl: 'https://api.minimax.io/v1',
  ),
  AiProviderPreset(
    id: 'qianfan',
    name: '百度千帆（ERNIE）',
    group: aiProviderPresetMainland,
    baseUrl: 'https://qianfan.baidubce.com/v2',
  ),
  AiProviderPreset(
    id: 'stepfun',
    name: '阶跃星辰',
    group: aiProviderPresetMainland,
    baseUrl: 'https://api.stepfun.com/v1',
  ),
  AiProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    group: aiProviderPresetOverseas,
    baseUrl: 'https://api.openai.com/v1',
  ),
  AiProviderPreset(
    id: 'gemini',
    name: 'Google Gemini',
    group: aiProviderPresetOverseas,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
  ),
  AiProviderPreset(
    id: 'xai',
    name: 'xAI Grok',
    group: aiProviderPresetOverseas,
    baseUrl: 'https://api.x.ai/v1',
  ),
  AiProviderPreset(
    id: 'mistral',
    name: 'Mistral AI',
    group: aiProviderPresetOverseas,
    baseUrl: 'https://api.mistral.ai/v1',
  ),
  AiProviderPreset(
    id: 'groq',
    name: 'Groq',
    group: aiProviderPresetOverseas,
    baseUrl: 'https://api.groq.com/openai/v1',
  ),
  AiProviderPreset(
    id: 'siliconflow',
    name: '硅基流动',
    group: aiProviderPresetAggregator,
    baseUrl: 'https://api.siliconflow.cn/v1',
  ),
  AiProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    group: aiProviderPresetAggregator,
    baseUrl: 'https://openrouter.ai/api/v1',
  ),
  AiProviderPreset(
    id: 'ollama',
    name: 'Ollama（本机）',
    group: aiProviderPresetAggregator,
    baseUrl: 'http://localhost:11434/v1',
  ),
];

// ---------------------------------------------------------------------------
// 状态
// ---------------------------------------------------------------------------

/// AI 分析设置（旧版 `AgentApiSettingsStore`）。
class AgentApiState {
  const AgentApiState({
    this.enabled = true,
    this.activeProviderId = '',
    this.providers = const [],
    this.systemPrompt = '',
    this.temperature = 0.7,
  });

  final bool enabled;
  final String activeProviderId;
  final List<AiProviderConfig> providers;
  final String systemPrompt;
  final double temperature;

  /// 当前生效厂商：找不到 id 时回落到第一条（旧版 `getActiveProvider`）。
  AiProviderConfig? get activeProvider {
    if (providers.isEmpty) return null;
    for (final provider in providers) {
      if (provider.id == activeProviderId) return provider;
    }
    return providers.first;
  }

  bool get ready {
    final provider = activeProvider;
    return enabled && provider != null && provider.hasKey;
  }

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

/// 读旧版九个键 + 厂商 JSON。
///
/// 厂商 JSON 缺失时按旧版 `performInitialMigration` 播种：曾经配过 Key 或改过地址
/// 的用户得到一条「已配置厂商」，其余得到一条 DeepSeek 空密钥条目。这样升级后
/// 「我的厂商」不会是一张空列表——而那正是最容易被误当成「设置丢了」的样子。
AgentApiState loadAgentApiState(LegacySettings settings) {
  final rawProviders = settings.agentAiProvidersJson;
  final providers = decodeAiProviders(rawProviders);
  return AgentApiState(
    enabled: settings.agentApiEnabled,
    activeProviderId: settings.agentAiActiveProviderId.isEmpty
        ? (providers.isEmpty ? '' : providers.first.id)
        : settings.agentAiActiveProviderId,
    providers: providers.isEmpty
        ? seedProviders(settings, rawProviders == null)
        : providers,
    systemPrompt: settings.agentApiSystemPrompt,
    temperature: settings.agentApiTemperature,
  );
}

/// 解析厂商 JSON；损坏时返回空列表（由调用方决定是否播种）。
List<AiProviderConfig> decodeAiProviders(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final result = <AiProviderConfig>[];
    for (final item in decoded) {
      final provider = AiProviderConfig.fromJson(item);
      if (provider != null) result.add(provider);
    }
    return result;
  } on FormatException {
    return const [];
  }
}

List<AiProviderConfig> seedProviders(LegacySettings settings, bool firstRun) {
  final hasLegacyConfig =
      settings.agentApiKey.isNotEmpty ||
      settings.agentApiBaseUrl != 'https://api.deepseek.com/v1';
  if (firstRun && hasLegacyConfig) {
    return [
      AiProviderConfig(
        id: 'migrated_default',
        name: '已配置厂商',
        baseUrl: settings.agentApiBaseUrl,
        model: settings.agentApiModel,
        sealedKey: sealApiKey(settings.agentApiKey),
      ),
    ];
  }
  return const [
    AiProviderConfig(
      id: 'preset_deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
      presetId: 'deepseek',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class AgentApiNotifier extends Notifier<AgentApiState> {
  LegacySettings get _settings => ref.read(legacySettingsProvider);

  @override
  AgentApiState build() {
    // 读其他页面/其他进程写入的值：`legacySettingsRevisionProvider` 一变就重建。
    ref.watch(legacySettingsRevisionProvider);
    return loadAgentApiState(ref.watch(legacySettingsProvider));
  }

  void _bump() => ref.read(legacySettingsRevisionProvider.notifier).bump();

  void _saveProviders(List<AiProviderConfig> providers, String activeId) {
    final settings = _settings;
    settings.setAgentAiProvidersJson(
      jsonEncode([for (final provider in providers) provider.toJson()]),
    );
    settings.setAgentAiActiveProviderId(activeId);
    _syncActiveToFlatKeys(providers, activeId);
    state = state.copyWith(providers: providers, activeProviderId: activeId);
    _bump();
  }

  /// 旧版 `syncProviderToConfig`：把生效厂商的地址/密钥/模型写进四个平铺键。
  ///
  /// 这四个键是**旧版真正的读取来源**（`getAgentApiConfig`），不同步的话：
  /// 本仓界面显示新厂商，旧版分析仍在用上一个。`temperature` 与 `system_prompt`
  /// 是独立的全局项，不在这里覆盖。
  void _syncActiveToFlatKeys(List<AiProviderConfig> providers, String activeId) {
    final settings = _settings;
    AiProviderConfig? active;
    for (final provider in providers) {
      if (provider.id == activeId) {
        active = provider;
        break;
      }
    }
    active ??= providers.isEmpty ? null : providers.first;
    if (active == null) return;
    settings.setAgentApiBaseUrl(active.baseUrl);
    settings.setAgentApiKey(active.apiKey);
    settings.setAgentApiModel(active.model);
  }

  void update(AgentApiState Function(AgentApiState state) fn) => state = fn(state);

  void setEnabled(bool value) {
    _settings.setAgentApiEnabled(value);
    state = state.copyWith(enabled: value);
    _bump();
  }

  void setTemperature(double value) {
    final rounded = (value * 10).round() / 10;
    _settings.setAgentApiTemperature(rounded);
    state = state.copyWith(temperature: rounded);
    _bump();
  }

  void setSystemPrompt(String value) {
    _settings.setAgentApiSystemPrompt(value);
    state = state.copyWith(systemPrompt: value);
    _bump();
  }

  void selectProvider(String id) {
    _saveProviders(state.providers, id);
  }

  /// 新增或更新一条厂商。[plainKey] 非空时才覆盖密钥（编辑时留空=保留原密钥）。
  void saveProvider(AiProviderConfig provider, {String? plainKey}) {
    final sealed = (plainKey == null || plainKey.trim().isEmpty)
        ? provider.sealedKey
        : sealApiKey(plainKey.trim());
    final next = provider.copyWith(sealedKey: sealed);
    final list = [...state.providers];
    final index = list.indexWhere((item) => item.id == next.id);
    if (index < 0) {
      list.add(next);
    } else {
      list[index] = next;
    }
    _saveProviders(list, next.id);
  }

  void deleteProvider(String id) {
    final list = state.providers.where((item) => item.id != id).toList();
    final nextActive = state.activeProviderId == id
        ? (list.isEmpty ? '' : list.first.id)
        : state.activeProviderId;
    _saveProviders(list, nextActive);
  }

  /// 恢复默认：清空厂商、密钥、提示词与温度（旧版「恢复出厂默认配置」）。
  void reset() {
    final settings = _settings;
    final store = ref.read(legacyPrefsStoreProvider);
    for (final key in const [
      'agent_api_key',
      'agent_api_system_prompt',
      'agent_api_temperature',
      'agent_api_model',
      'agent_api_base_url',
      'agent_ai_providers_json',
      'agent_ai_active_provider_id',
    ]) {
      store.remove(LegacySettings.uiContainer, key);
    }
    settings.setAgentApiEnabled(true);
    _bump();
    state = loadAgentApiState(settings);
    if (state.providers.isEmpty) {
      state = state.copyWith(providers: seedProviders(settings, true));
    }
  }
}

final agentApiProvider = NotifierProvider<AgentApiNotifier, AgentApiState>(
  AgentApiNotifier.new,
);
