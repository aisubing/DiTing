/// Provider catalog, selection and race lists backed by the 1.4.3 prefs.
///
/// 1.4.3 keeps presets in code and only persists custom providers
/// (`user_providers_json`), the selected id, the three mode-specific id lists
/// and the home visibility filter. Everything here reads and writes those exact
/// keys so a started tunnel and the settings screens agree.
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/data/vpn/provider_store.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presets only, as a fallback for hosts that never loaded the prefs snapshot
/// (tests, the component gallery).
List<MockProvider> defaultProviderCatalog() => [
  for (final provider in defaultDnsProviders)
    provider.toMock(latencyMs: -1, isPreset: true),
];

ProviderProtocol _protocolOf(DnsProtocol protocol) => switch (protocol) {
  DnsProtocol.dns => ProviderProtocol.dns,
  DnsProtocol.doh => ProviderProtocol.doh,
  DnsProtocol.dot => ProviderProtocol.dot,
};

/// The full catalog: 18 presets followed by the custom providers in file order.
List<MockProvider> buildProviderCatalog(LegacySettings settings) {
  final latencies = settings.providerLatenciesMs;
  return [
    for (final provider in defaultDnsProviders)
      provider.toMock(latencyMs: latencies[provider.id] ?? -1, isPreset: true),
    for (final record in readUserProviders(settings))
      MockProvider(
        id: record.id,
        name: record.name,
        protocol: _protocolOf(record.protocol),
        address: record.address,
        latencyMs: latencies[record.id] ?? -1,
      ),
  ];
}

/// Endpoint text for one provider. `latencyMs < 0` means "no measurement yet"
/// (the health store is empty on a fresh install), which the UI renders as a
/// dash instead of a fake number.
String endpointOfProvider(String id, List<MockProvider> catalog) {
  final provider = catalog.firstWhere(
    (candidate) => candidate.id == id,
    orElse: () => catalog.first,
  );
  return '${provider.protocol.label} · ${provider.address}';
}

/// Same as [endpointOfProvider] but for callers that only have a container.
String providerEndpointFromCatalog(WidgetRef ref, String id) =>
    endpointOfProvider(id, ref.watch(dnsProviderCatalogProvider));

/// Display text for a provider's last measured latency.
String providerLatencyLabel(MockProvider provider) =>
    provider.latencyMs < 0 ? '未测速' : '${provider.latencyMs}ms';

/// Names joined for the race summary; ids missing from the catalog are skipped
/// instead of rendering a bare UUID.
String summaryOfProviders(Set<String> ids, List<MockProvider> catalog) {
  final names = [
    for (final provider in catalog)
      if (ids.contains(provider.id)) provider.name,
  ];
  if (names.isEmpty) {
    return '未选择服务商';
  }
  if (names.length == 1) {
    return names.first;
  }
  return '已选 ${names.length} 个：${names.join('、')}';
}

class ProviderCatalogNotifier extends Notifier<List<MockProvider>> {
  @override
  List<MockProvider> build() =>
      buildProviderCatalog(ref.watch(legacySettingsProvider));

  void _refresh() =>
      state = buildProviderCatalog(ref.read(legacySettingsProvider));

  /// Persists one custom provider; presets are read-only by contract.
  void addCustom({
    required String name,
    required ProviderProtocol protocol,
    required String address,
  }) {
    addUserProvider(
      ref.read(legacySettingsProvider),
      name: name,
      protocol: _dnsProtocolOf(protocol),
      address: address,
    );
    _refresh();
  }

  void updateCustom({
    required String id,
    required String name,
    required ProviderProtocol protocol,
    required String address,
  }) {
    updateUserProvider(
      ref.read(legacySettingsProvider),
      id: id,
      name: name,
      protocol: _dnsProtocolOf(protocol),
      address: address,
    );
    _refresh();
    ref.invalidate(selectedProviderProvider);
    ref.invalidate(raceProvidersProvider);
  }

  void deleteCustom(String id) {
    deleteUserProvider(ref.read(legacySettingsProvider), id);
    _refresh();
    ref.invalidate(selectedProviderProvider);
    ref.invalidate(raceProvidersProvider);
  }
}

DnsProtocol _dnsProtocolOf(ProviderProtocol protocol) => switch (protocol) {
  ProviderProtocol.dns => DnsProtocol.dns,
  ProviderProtocol.doh => DnsProtocol.doh,
  ProviderProtocol.dot => DnsProtocol.dot,
};

final dnsProviderCatalogProvider =
    NotifierProvider<ProviderCatalogNotifier, List<MockProvider>>(
      ProviderCatalogNotifier.new,
    );

/// Providers the home picker may show. Mirrors `HomeProviderVisibility`:
/// a protocol-level switch hides the whole group, a per-provider switch hides
/// one entry, and a provider explicitly re-enabled under a hidden protocol stays.
/// The currently selected provider is never filtered out, matching the upstream
/// hint that the active service always stays visible.
final visibleProvidersProvider = Provider<List<MockProvider>>((ref) {
  final settings = ref.watch(legacySettingsProvider);
  final catalog = ref.watch(dnsProviderCatalogProvider);
  final selectedId = ref.watch(selectedProviderProvider);
  final visibleProtocols = settings.homeVisibleProtocols;
  final hidden = settings.homeHiddenProviderIds;
  final explicit = settings.homeVisibleProviderIds;
  return [
    for (final provider in catalog)
      if (provider.id == selectedId ||
          (visibleProtocols.contains(provider.protocol.name.toUpperCase())
              ? !hidden.contains(provider.id)
              : explicit.contains(provider.id)))
        provider,
  ];
});

/// Currently selected single-mode provider.
class SelectedProviderNotifier extends Notifier<String> {
  @override
  String build() {
    final catalog = ref.watch(dnsProviderCatalogProvider);
    final id = ref.watch(legacySettingsProvider).selectedProviderId;
    if (catalog.any((provider) => provider.id == id)) return id;
    return catalog.isEmpty ? id : catalog.first.id;
  }

  /// Ignores unknown ids: the catalog is the source of truth, and a stale UI
  /// must not persist an id the engine cannot resolve.
  void select(String id) {
    if (!ref.read(dnsProviderCatalogProvider).any((p) => p.id == id)) return;
    ref.read(legacySettingsProvider).setSelectedProviderId(id);
    state = id;
  }
}

final selectedProviderProvider =
    NotifierProvider<SelectedProviderNotifier, String>(
      SelectedProviderNotifier.new,
    );

/// Provider set used by the multi-provider resolution modes.
///
/// Single mode surfaces the parallel-race list (what the user last configured);
/// its own selection lives in [selectedProviderProvider]. The two id lists are
/// ordered for primary-backup, so writes keep the stored order and append.
class RaceProvidersNotifier extends Notifier<Set<String>> {
  static const minCount = 2;

  @override
  Set<String> build() {
    final settings = ref.watch(legacySettingsProvider);
    final mode = ref.watch(resolutionModeProvider);
    final catalogIds = {
      for (final provider in ref.watch(dnsProviderCatalogProvider)) provider.id,
    };
    final stored = mode.isSingle
        ? settings.parallelRaceProviderIds
        : settings.providerIdsOf(mode.storageValue);
    final storedOrDefault = stored.isEmpty && mode.isSingle
        ? const ['preset_alidns_dns', 'preset_dnspod_dns']
        : stored;
    return {
      for (final id in storedOrDefault)
        if (catalogIds.contains(id)) id,
    };
  }

  /// Returns false when the removal would drop below [minCount].
  bool toggle(String id) {
    if (!ref.read(dnsProviderCatalogProvider).any((p) => p.id == id)) {
      return false;
    }
    final next = {...state};
    final removing = next.remove(id);
    if (removing && next.length < minCount) {
      return false;
    }
    if (!removing) {
      next.add(id);
    }
    _persist(next);
    state = next;
    return true;
  }

  void reset() {
    final settings = ref.read(legacySettingsProvider);
    final mode = ref.read(resolutionModeProvider);
    final defaults = {
      for (final provider in ref.read(dnsProviderCatalogProvider).take(2))
        provider.id,
    };
    _persist(defaults);
    state = defaults;
    if (!mode.isSingle) {
      // `_persist` already wrote the active mode's key.
      return;
    }
    settings.setParallelRaceProviderIds(defaults.toList());
  }

  /// Persists an explicit order. Primary-backup keeps the sequence it is given;
  /// the other modes are sets and only retain the ids.
  void reorder(List<String> ids) {
    final valid = {
      for (final provider in ref.read(dnsProviderCatalogProvider)) provider.id,
    };
    final ordered = [
      for (final id in ids)
        if (valid.contains(id)) id,
    ];
    final mode = ref.read(resolutionModeProvider);
    if (mode.isSingle) {
      ref.read(legacySettingsProvider).setParallelRaceProviderIds(ordered);
    } else {
      ref
          .read(legacySettingsProvider)
          .setProviderIdsOf(mode.storageValue, ordered);
    }
    state = ordered.toSet();
  }

  void _persist(Set<String> ids) {
    final settings = ref.read(legacySettingsProvider);
    final mode = ref.read(resolutionModeProvider);
    if (mode.isSingle) {
      settings.setParallelRaceProviderIds(ids.toList());
      return;
    }
    final key = mode.storageValue;
    if (key == 'primary_backup') {
      // Preserve the primary→backup order; newly added ids go last.
      final current = settings.providerIdsOf(key);
      final ordered = [
        for (final id in current)
          if (ids.contains(id)) id,
        for (final id in ids)
          if (!current.contains(id)) id,
      ];
      settings.setProviderIdsOf(key, ordered);
      return;
    }
    settings.setProviderIdsOf(key, ids.toList());
  }
}

final raceProvidersProvider =
    NotifierProvider<RaceProvidersNotifier, Set<String>>(
      RaceProvidersNotifier.new,
    );
