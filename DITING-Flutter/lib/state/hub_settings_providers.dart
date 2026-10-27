/// AI analysis settings and call state under the 1.4.3 `AgentApiSettingsStore` keys in
/// `dns_vpn_prefs`.
library;

import 'dart:convert';

import 'package:diting/data/agent/key_obfuscator.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A configured AI provider; a non-empty `presetId` means it came from a preset.
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

  /// Obfuscated key (`KeyObfuscator.seal`). Empty when unset.
  final String sealedKey;

  bool get hasKey => sealedKey.isNotEmpty;

  /// Plain key for request headers only; never log or display it.
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

  /// Parses one provider leniently, like the legacy `decodeAiProviders`.
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

/// Built-in preset: name and base URL only; models are fetched online.
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

/// Mirrors the legacy `AiProviderPresets.all` (16 entries).
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

  /// Active provider; falls back to the first entry like legacy `getActiveProvider`.
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

/// Reads the legacy keys plus provider JSON; missing JSON seeds one migrated or keyless DeepSeek
/// entry.
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

/// Decodes the provider JSON; an empty list means corrupt, so the caller decides whether to seed.
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

class AgentApiNotifier extends Notifier<AgentApiState> {
  LegacySettings get _settings => ref.read(legacySettingsProvider);

  @override
  AgentApiState build() {
    // Rebuild when other pages or processes write the legacy settings.
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

  /// Legacy `syncProviderToConfig`: mirrors the active provider into the flat keys 1.4.3 reads.
  void _syncActiveToFlatKeys(
    List<AiProviderConfig> providers,
    String activeId,
  ) {
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

  void update(AgentApiState Function(AgentApiState state) fn) =>
      state = fn(state);

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

  /// Adds or updates a provider; a non-empty [plainKey] replaces the key, empty keeps it.
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

  /// Restores defaults by clearing providers, key, prompt and temperature.
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
