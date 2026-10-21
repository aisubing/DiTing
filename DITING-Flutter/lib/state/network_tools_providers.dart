/// 网络诊断页的运行态：测速选中集 / 协议 / 域名 / 结果，以及四类探测的设置。
///
/// ## 为什么协议与域名要落盘
/// 旧版 `DnsSpeedTestSection` 把「用于测速的域名」和「参与了测速的服务商」
/// 存在 `ResolutionSettingsStore` 的两个键里（`race_test_domain` /
/// `latency_test_provider_ids`），并且明确说明「这里的选择只用于 DNS 查询测速，
/// 不影响竞速模式」。本仓沿用同一对键，容器是数据集容器
/// （`LegacySettings.dnsContainer`，普通 / 极速各一份）。
///
/// ## 为什么结果不进落盘
/// 结果只反映「刚才那次网络状态」，旧版也只留在 ViewModel 内存里；落盘会在
/// 下次进页面时显示一份可能已经过期的耗时。
library;

import 'dart:convert';

import 'package:diting/data/native/dns_latency_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 旧版 `ResolutionSettingsStore.KEY_LATENCY_TEST_PROVIDER_IDS`。
const latencyTestProviderIdsKey = 'latency_test_provider_ids';

/// 旧版 `ResolutionSettingsStore.KEY_RACE_TEST_DOMAIN`。
const raceTestDomainKey = 'race_test_domain';

/// 旧版 `ResolutionSettingsStore.DEFAULT_RACE_TEST_DOMAIN`。
const defaultRaceTestDomain = 'mihoyo.com';

/// 旧版 `RaceModeSettingsViewModel.LATENCY_TEST_ATTEMPTS`。
const latencyTestAttempts = 3;

/// 原生测速执行者。
///
/// 默认是「不可用」实现：组件画廊与纯 Dart 测试里没有通道，页面必须能显示
/// 「当前设备不支持测速」而不是崩溃。**main.dart 需要 override 成
/// `MethodChannelDnsLatencyRunner()`**。
final dnsLatencyRunnerProvider = Provider<DnsLatencyRunner>(
  (ref) => const UnavailableDnsLatencyRunner(),
);

/// 通道是否可用。页面据此禁用「开始测速」并给出不可用说明。
final latencyTestAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(dnsLatencyRunnerProvider).checkAvailable(),
);

/// 可测速的服务商目录（内置预设 + 用户自定义），带 host / port / 协议。
///
/// 用 `defaultDnsProviders` 而不是 `dnsProviderCatalogProvider`：后者是页面展示
/// 模型（`MockProvider` 只有一条拼接好的 endpoint 文本），而原生侧要的是
/// 结构化的 host / port / 协议，直接复用 Go 配置构造器用的那一份目录才不会
/// 出现「界面显示 DoH、实际测的是 DNS」这种错配。
final latencyTestCatalogProvider = Provider<List<DnsLatencyProviderSpec>>((
  ref,
) {
  final settings = ref.watch(legacySettingsProvider);
  final entries = [
    ...defaultDnsProviders,
    ...parseUserProviders(settings.userProvidersJson),
  ];
  return [for (final entry in entries) latencySpecOf(entry)];
});

/// 目录项 → 通道参数。
///
/// DoH 的 `host` 在预设里是空的（只有 url），必须从 url 里取——原生侧要用它
/// 做 bootstrap 解析与 SNI。取不到时留空串：原生侧会自己从 url 解析。
DnsLatencyProviderSpec latencySpecOf(DnsProviderEntry entry) {
  final protocol = switch (entry.protocol) {
    DnsProtocol.dns => DnsLatencyProtocol.dns,
    DnsProtocol.doh => DnsLatencyProtocol.doh,
    DnsProtocol.dot => DnsLatencyProtocol.dot,
  };
  final host = entry.host.isNotEmpty
      ? entry.host
      : Uri.tryParse(entry.url)?.host ?? '';
  final port = switch (protocol) {
    DnsLatencyProtocol.doh => 443,
    DnsLatencyProtocol.dot => entry.port == 0 ? 853 : entry.port,
    DnsLatencyProtocol.dns => entry.port == 0 ? 53 : entry.port,
  };
  return DnsLatencyProviderSpec(
    id: entry.id,
    name: entry.name,
    host: host,
    port: port,
    protocol: protocol,
    url: entry.url,
  );
}

/// 服务商的端点文案，与旧版 `DnsProvider.endpointLabel()` 同形：
/// `[DoH] https://…` / `[DNS] 1.1.1.1:53`。
///
/// 直接拼枚举会漏出源码标识符（`DnsLatencyProtocol.doh`），必须走 `.label`。
String latencyEndpointLabel(DnsLatencyProviderSpec spec) {
  if (spec.protocol == DnsLatencyProtocol.doh) {
    final url = spec.url.isNotEmpty
        ? spec.url
        : 'https://${spec.host}/dns-query';
    return '[${spec.protocol.label}] $url';
  }
  return '[${spec.protocol.label}] ${spec.host}:${spec.port}';
}

/// 当前协议下可测速的服务商。
final latencyProvidersOfProtocolProvider =
    Provider.family<List<DnsLatencyProviderSpec>, DnsLatencyProtocol>((
      ref,
      protocol,
    ) {
      return [
        for (final spec in ref.watch(latencyTestCatalogProvider))
          if (spec.protocol == protocol) spec,
      ];
    });

/// 目录里出现过的协议，按「明文 → DoH → DoT」的固定顺序。
///
/// 与旧版 `availableProtocols` 同序（`DnsProtocol.MANAGED_PROTOCOLS`）；
/// 一个都没有时回落到三档全给，页面才不会出现空的分段控件。
final latencyTestProtocolsProvider = Provider<List<DnsLatencyProtocol>>((ref) {
  final present = {
    for (final spec in ref.watch(latencyTestCatalogProvider)) spec.protocol,
  };
  final ordered = [
    for (final protocol in DnsLatencyProtocol.values)
      if (present.contains(protocol)) protocol,
  ];
  return ordered.isEmpty ? DnsLatencyProtocol.values : ordered;
});

/// 参与测速的服务商 id 集合（落盘）。
class LatencySelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final settings = ref.watch(legacySettingsProvider);
    final known = {
      for (final spec in ref.watch(latencyTestCatalogProvider)) spec.id,
    };
    return {
      for (final id in _readIds(settings))
        if (known.contains(id)) id,
    };
  }

  /// 旧版 `toggleLatencyTestProvider`：纯增删，没有上限。
  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) {
      next.add(id);
    }
    _persist(next);
    state = next;
  }

  static List<String> _readIds(LegacySettings settings) {
    final raw = settings.rawValue(latencyTestProviderIdsKey);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.isNotEmpty) item,
      ];
    } on FormatException {
      return const [];
    }
  }

  void _persist(Set<String> ids) {
    final settings = ref.read(legacySettingsProvider);
    ref
        .read(legacyPrefsStoreProvider)
        .putString(
          settings.dnsContainer,
          latencyTestProviderIdsKey,
          jsonEncode(ids.toList()..sort()),
        );
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

final latencySelectionProvider =
    NotifierProvider<LatencySelectionNotifier, Set<String>>(
      LatencySelectionNotifier.new,
    );

/// 当前测速协议。默认明文（旧版 `selectedProtocol = DnsProtocol.DNS`），
/// 目录里没有明文服务商时才退到第一个可用协议。
class LatencyProtocolNotifier extends Notifier<DnsLatencyProtocol> {
  @override
  DnsLatencyProtocol build() {
    final available = ref.watch(latencyTestProtocolsProvider);
    return available.first;
  }

  void select(DnsLatencyProtocol protocol) {
    if (state == protocol) return;
    if (!ref.read(latencyTestProtocolsProvider).contains(protocol)) return;
    state = protocol;
  }
}

final latencyProtocolProvider =
    NotifierProvider<LatencyProtocolNotifier, DnsLatencyProtocol>(
      LatencyProtocolNotifier.new,
    );

/// 测速域名（落盘到 `race_test_domain`）。
class LatencyDomainNotifier extends Notifier<String> {
  @override
  String build() {
    final settings = ref.watch(legacySettingsProvider);
    final raw = settings.rawValue(raceTestDomainKey);
    final value = raw is String ? raw.trim() : '';
    return value.isEmpty ? defaultRaceTestDomain : value;
  }

  /// 空白串存回默认域名，与 `setRaceTestDomain` 的 `takeIf { isNotBlank }`
  /// 逐字一致。输入过程中允许临时为空（否则用户删不干净再重打）。
  void setDomain(String value) {
    final trimmed = value.replaceAll(RegExp(r'\s'), '');
    if (trimmed == state) return;
    state = trimmed;
    _persist(trimmed);
  }

  void _persist(String value) {
    final settings = ref.read(legacySettingsProvider);
    ref
        .read(legacyPrefsStoreProvider)
        .putString(
          settings.dnsContainer,
          raceTestDomainKey,
          value.isEmpty ? defaultRaceTestDomain : value,
        );
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

final latencyDomainProvider = NotifierProvider<LatencyDomainNotifier, String>(
  LatencyDomainNotifier.new,
);

/// 一次测速的完整状态。
class LatencyTestState {
  const LatencyTestState({
    this.running = false,
    this.results = const [],
    this.error,
    this.unavailable = false,
  });

  final bool running;

  /// 已按「成功优先、耗时升序」排好序，页面直接按下标当名次。
  final List<DnsLatencySample> results;

  /// 执行失败的原因（通道报错、没有选中服务商……）。与「单个服务商测速失败」
  /// 不同：后者在 [results] 里带 `success=false`。
  final String? error;

  /// 这台设备根本没有测速通道。
  final bool unavailable;
}

class LatencyTestNotifier extends Notifier<LatencyTestState> {
  @override
  LatencyTestState build() {
    final available = ref.watch(latencyTestAvailableProvider);
    if (available.value == false) {
      return const LatencyTestState(unavailable: true);
    }
    return const LatencyTestState();
  }

  Future<void> run() async {
    if (state.running) return;
    final selected = ref.read(latencySelectionProvider);
    // 与旧版 `runLatencyTest` 一致：测的是**选中集合里的全部**服务商，不只是
    // 当前协议页签下显示的那一批——协议行只决定「现在能勾哪些」，勾选本身跨
    // 协议保留。结果行因此必须带协议徽标，否则用户认不出哪个是 DoT。
    final providers = [
      for (final spec in ref.read(latencyTestCatalogProvider))
        if (selected.contains(spec.id)) spec,
    ];
    if (providers.isEmpty) {
      state = LatencyTestState(
        results: state.results,
        unavailable: state.unavailable,
        error: '请先选择至少一个测速服务商',
      );
      return;
    }
    final domain = ref.read(latencyDomainProvider);
    if (domain.isEmpty) {
      state = LatencyTestState(
        results: state.results,
        unavailable: state.unavailable,
        error: '请输入用于测速的域名',
      );
      return;
    }
    state = LatencyTestState(running: true, results: const []);
    try {
      final results = await ref
          .read(dnsLatencyRunnerProvider)
          .probe(
            providers: providers,
            domain: domain,
            attempts: latencyTestAttempts,
          );
      state = LatencyTestState(results: sortLatencySamples(results));
    } on DnsLatencyUnavailable catch (error) {
      state = LatencyTestState(unavailable: true, error: error.message);
    }
  }

  void clearError() {
    if (state.error == null) return;
    state = LatencyTestState(
      results: state.results,
      unavailable: state.unavailable,
    );
  }
}

final latencyTestProvider =
    NotifierProvider<LatencyTestNotifier, LatencyTestState>(
      LatencyTestNotifier.new,
    );

/// 结果排序：成功优先 → 平均耗时升序 → 成功次数降序 → 名称。
///
/// 逐条转写自 `RaceModeSettingsViewModel.runLatencyTest` 的 `sortedWith`。
/// 「成功优先」必须是第一关键字：失败项的 `elapsedMs` 是超时那一刻的耗时，
/// 按它排序会把最慢的失败项排到成功项前面。
List<DnsLatencySample> sortLatencySamples(List<DnsLatencySample> samples) {
  final sorted = [...samples];
  sorted.sort((a, b) {
    if (a.success != b.success) return a.success ? -1 : 1;
    if (a.success) {
      final byElapsed = a.elapsedMs.compareTo(b.elapsedMs);
      if (byElapsed != 0) return byElapsed;
    }
    final byCount = b.successCount.compareTo(a.successCount);
    if (byCount != 0) return byCount;
    return a.providerName.compareTo(b.providerName);
  });
  return sorted;
}

/// 进度条的分母：成功项里的最大耗时。全失败时给 0，页面据此不画条。
int latencyBarMax(List<DnsLatencySample> samples) {
  var max = 0;
  for (final sample in samples) {
    if (sample.success && sample.elapsedMs > max) max = sample.elapsedMs;
  }
  return max;
}
