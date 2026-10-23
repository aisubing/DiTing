/// Proxies demo state; latency and selection are mutable while `mock_proxies.dart` is `const`, so
/// they key a flat map.
library;

import 'dart:math' as math;

import 'package:diting/data/mock_proxies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Key for one node in the state map; names never contain `\u0000`, so no collision.
String proxyKeyOf(String groupName, String proxyName) =>
    '$groupName\u0000$proxyName';


/// The proxies page's six presentation settings (upstream `ProxiesStyleSetting`).
class ProxiesSettings {
  const ProxiesSettings({
    this.type = ProxiesType.tab,
    this.sortType = ProxiesSortType.none,
    this.layout = ProxiesLayout.standard,
    this.cardType = ProxyCardType.standard,
    this.iconStyle = ProxiesIconStyle.filled,
    this.hideTimeoutProxies = false,
  });

  final ProxiesType type;

  final ProxiesSortType sortType;
  final ProxiesLayout layout;
  final ProxyCardType cardType;

  /// Only visible in list form, as upstream.
  final ProxiesIconStyle iconStyle;

  final bool hideTimeoutProxies;

  ProxiesSettings copyWith({
    ProxiesType? type,
    ProxiesSortType? sortType,
    ProxiesLayout? layout,
    ProxyCardType? cardType,
    ProxiesIconStyle? iconStyle,
    bool? hideTimeoutProxies,
  }) => ProxiesSettings(
    type: type ?? this.type,
    sortType: sortType ?? this.sortType,
    layout: layout ?? this.layout,
    cardType: cardType ?? this.cardType,
    iconStyle: iconStyle ?? this.iconStyle,
    hideTimeoutProxies: hideTimeoutProxies ?? this.hideTimeoutProxies,
  );
}

class ProxiesSettingsNotifier extends Notifier<ProxiesSettings> {
  @override
  ProxiesSettings build() => const ProxiesSettings();

  void setType(ProxiesType value) => state = state.copyWith(type: value);

  void setSortType(ProxiesSortType value) =>
      state = state.copyWith(sortType: value);

  void setLayout(ProxiesLayout value) => state = state.copyWith(layout: value);

  void setCardType(ProxyCardType value) =>
      state = state.copyWith(cardType: value);

  void setIconStyle(ProxiesIconStyle value) =>
      state = state.copyWith(iconStyle: value);

  void setHideTimeoutProxies(bool value) =>
      state = state.copyWith(hideTimeoutProxies: value);
}

final proxiesSettingsProvider =
    NotifierProvider<ProxiesSettingsNotifier, ProxiesSettings>(
      ProxiesSettingsNotifier.new,
    );


class ProxiesState {
  const ProxiesState({
    required this.delays,
    required this.selected,
    this.testingGroups = const {},
    this.testingAll = false,
    this.unfolded = const {},
    this.query = '',
  });

  final Map<String, int?> delays;
  final Map<String, String?> selected;

  /// Groups currently testing; all of them spin while `testingAll` is true.
  final Set<String> testingGroups;
  final bool testingAll;

  final Set<String> unfolded;

  final String query;

  ProxiesState copyWith({
    Map<String, int?>? delays,
    Map<String, String?>? selected,
    Set<String>? testingGroups,
    bool? testingAll,
    Set<String>? unfolded,
    String? query,
  }) => ProxiesState(
    delays: delays ?? this.delays,
    selected: selected ?? this.selected,
    testingGroups: testingGroups ?? this.testingGroups,
    testingAll: testingAll ?? this.testingAll,
    unfolded: unfolded ?? this.unfolded,
    query: query ?? this.query,
  );
}

class ProxiesNotifier extends Notifier<ProxiesState> {
  /// Demo test duration: long enough to show the spinner and latency swap.
  static const testDuration = Duration(milliseconds: 900);

  /// Fixed seed so repeated tests stay stable for screenshots and regressions.
  final _random = math.Random(20261019);

  @override
  ProxiesState build() {
    final delays = <String, int?>{};
    final selected = <String, String?>{};
    for (final group in mockProxyGroups) {
      selected[group.name] = group.selectedName;
      for (final proxy in group.proxies) {
        delays[proxyKeyOf(group.name, proxy.name)] = proxy.delayMs;
      }
    }
    return ProxiesState(
      delays: delays,
      selected: selected,
      unfolded: {mockProxyGroups.first.name},
    );
  }

  int? delayOf(String groupName, String proxyName) =>
      state.delays[proxyKeyOf(groupName, proxyName)];

  String? selectedOf(String groupName) => state.selected[groupName];

  bool isTesting(String groupName) =>
      state.testingAll || state.testingGroups.contains(groupName);

  bool isUnfolded(String groupName) => state.unfolded.contains(groupName);

  void setQuery(String value) => state = state.copyWith(query: value);

  void toggleUnfolded(String groupName) {
    final unfolded = {...state.unfolded};
    if (!unfolded.remove(groupName)) {
      unfolded.add(groupName);
    }
    state = state.copyWith(unfolded: unfolded);
  }

  void unfold(String groupName) {
    if (state.unfolded.contains(groupName)) {
      return;
    }
    state = state.copyWith(unfolded: {...state.unfolded, groupName});
  }

  /// Whether the group is selectable; load-balance and relay groups only give demo feedback.
  bool select(String groupName, String proxyName) {
    final group = _groupOf(groupName);
    if (group == null || !group.type.isComputedSelected) {
      return false;
    }
    state = state.copyWith(selected: {...state.selected, groupName: proxyName});
    return true;
  }

  Future<void> testGroup(String groupName) async {
    final group = _groupOf(groupName);
    if (group == null || isTesting(groupName)) {
      return;
    }
    state = state.copyWith(testingGroups: {...state.testingGroups, groupName});
    await Future<void>.delayed(testDuration);
    if (!ref.mounted) {
      return;
    }
    final delays = Map<String, int?>.of(state.delays);
    for (final proxy in group.proxies) {
      delays[proxyKeyOf(groupName, proxy.name)] = _nextDelay(proxy);
    }
    state = state.copyWith(
      delays: delays,
      selected: _withFastest(group, delays),
      testingGroups: {...state.testingGroups}..remove(groupName),
    );
  }

  Future<void> testAll() async {
    if (state.testingAll) {
      return;
    }
    state = state.copyWith(testingAll: true, testingGroups: const {});
    await Future<void>.delayed(testDuration);
    if (!ref.mounted) {
      return;
    }
    final delays = Map<String, int?>.of(state.delays);
    var selected = Map<String, String?>.of(state.selected);
    for (final group in mockProxyGroups) {
      for (final proxy in group.proxies) {
        delays[proxyKeyOf(group.name, proxy.name)] = _nextDelay(proxy);
      }
      selected = _withFastest(group, delays, into: selected);
    }
    state = state.copyWith(
      delays: delays,
      selected: selected,
      testingAll: false,
    );
  }

  /// Auto-test groups reorder by fastest non-timeout, like a real url-test group.
  Map<String, String?> _withFastest(
    MockProxyGroup group,
    Map<String, int?> delays, {
    Map<String, String?>? into,
  }) {
    if (group.type != ProxyGroupType.urlTest) {
      return into ?? state.selected;
    }
    int? best;
    String? bestName;
    for (final proxy in group.proxies) {
      final delay = delays[proxyKeyOf(group.name, proxy.name)];
      if (delay == null || delay < 0) {
        continue;
      }
      if (best == null || delay < best) {
        best = delay;
        bestName = proxy.name;
      }
    }
    if (bestName == null) {
      return into ?? state.selected;
    }
    return {...(into ?? state.selected), group.name: bestName};
  }

  int? _nextDelay(MockProxy proxy) => switch (proxy.protocol) {
    ProxyProtocol.reject => null,
    ProxyProtocol.direct => 3 + _random.nextInt(9),
    _ when _random.nextInt(8) == 0 => -1,
    _ => 26 + _random.nextInt(470),
  };

  MockProxyGroup? _groupOf(String name) {
    for (final group in mockProxyGroups) {
      if (group.name == name) {
        return group;
      }
    }
    return null;
  }
}

final proxiesProvider = NotifierProvider<ProxiesNotifier, ProxiesState>(
  ProxiesNotifier.new,
);


class ProxyNodeView {
  const ProxyNodeView({
    required this.name,
    required this.protocol,
    required this.delayMs,
  });

  final String name;
  final ProxyProtocol protocol;
  final int? delayMs;

  bool get isTimeout => delayMs != null && delayMs! < 0;
}

/// Read-only snapshot of one group, already filtered and sorted.
class ProxyGroupView {
  const ProxyGroupView({
    required this.name,
    required this.type,
    required this.glyphName,
    required this.nodes,
    required this.selectedName,
    required this.totalCount,
  });

  final String name;
  final ProxyGroupType type;
  final String glyphName;
  final List<ProxyNodeView> nodes;
  final String? selectedName;

  /// Node count before hiding timeouts, for the "N hidden" header label.
  final int totalCount;

  int get hiddenCount => totalCount - nodes.length;
}

/// Filtered and sorted groups; search runs before hiding so a searched timeout node is not
/// swallowed.
final visibleProxyGroupsProvider = Provider<List<ProxyGroupView>>((ref) {
  final settings = ref.watch(proxiesSettingsProvider);
  final state = ref.watch(proxiesProvider);
  final query = state.query.trim().toLowerCase();
  final groups = <ProxyGroupView>[];
  for (final group in mockProxyGroups) {
    final groupMatched =
        query.isNotEmpty && group.name.toLowerCase().contains(query);
    final nodes = <ProxyNodeView>[];
    var matched = false;
    for (final proxy in group.proxies) {
      final delay = state.delays[proxyKeyOf(group.name, proxy.name)];
      if (query.isNotEmpty &&
          !groupMatched &&
          !proxy.name.toLowerCase().contains(query)) {
        continue;
      }
      if (query.isEmpty &&
          settings.hideTimeoutProxies &&
          delay != null &&
          delay < 0) {
        continue;
      }
      matched = true;
      nodes.add(
        ProxyNodeView(
          name: proxy.name,
          protocol: proxy.protocol,
          delayMs: delay,
        ),
      );
    }
    if (!matched || nodes.isEmpty) {
      continue;
    }
    groups.add(
      ProxyGroupView(
        name: group.name,
        type: group.type,
        glyphName: group.glyphName,
        nodes: _sorted(nodes, settings.sortType),
        selectedName: state.selected[group.name],
        totalCount: group.proxies.length,
      ),
    );
  }
  return groups;
});

List<ProxyNodeView> _sorted(List<ProxyNodeView> nodes, ProxiesSortType type) {
  final sorted = List<ProxyNodeView>.of(nodes);
  switch (type) {
    case ProxiesSortType.none:
      break;
    case ProxiesSortType.delay:
      sorted.sort((a, b) {
        // Untested and timed-out nodes sink; the rest sort by latency.
        int rank(ProxyNodeView node) =>
            node.delayMs == null || node.delayMs! < 0 ? 1 : 0;
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) {
          return byRank;
        }
        return (a.delayMs ?? 0).compareTo(b.delayMs ?? 0);
      });
    case ProxiesSortType.name:
      sorted.sort((a, b) => a.name.compareTo(b.name));
  }
  return sorted;
}


/// One external provider entry on the page (editable and testable).
class ProxyProviderEntry {
  const ProxyProviderEntry({
    required this.name,
    required this.url,
    required this.count,
    required this.updatedAt,
    required this.intervalHours,
    this.filter,
    this.isUpdating = false,
  });

  ProxyProviderEntry.fromMock(MockProxyProvider provider)
    : name = provider.name,
      url = provider.url,
      count = provider.count,
      updatedAt = provider.updatedAt,
      intervalHours = provider.intervalHours,
      filter = provider.filter,
      isUpdating = false;

  final String name;
  final String url;
  final int count;
  final String updatedAt;
  final int intervalHours;
  final String? filter;
  final bool isUpdating;

  ProxyProviderEntry copyWith({
    String? name,
    String? url,
    int? count,
    String? updatedAt,
    int? intervalHours,
    String? filter,
    bool clearFilter = false,
    bool? isUpdating,
  }) => ProxyProviderEntry(
    name: name ?? this.name,
    url: url ?? this.url,
    count: count ?? this.count,
    updatedAt: updatedAt ?? this.updatedAt,
    intervalHours: intervalHours ?? this.intervalHours,
    filter: clearFilter ? null : (filter ?? this.filter),
    isUpdating: isUpdating ?? this.isUpdating,
  );
}

class ProxyProvidersNotifier extends Notifier<List<ProxyProviderEntry>> {
  static const updateDuration = Duration(milliseconds: 700);

  final _random = math.Random(7);

  @override
  List<ProxyProviderEntry> build() => [
    for (final provider in mockProxyProviders)
      ProxyProviderEntry.fromMock(provider),
  ];

  bool get isBusy => state.any((provider) => provider.isUpdating);

  Future<void> updateAll() async {
    if (isBusy) {
      return;
    }
    state = [for (final provider in state) provider.copyWith(isUpdating: true)];
    await Future<void>.delayed(updateDuration);
    if (!ref.mounted) {
      return;
    }
    state = [for (final provider in state) _refreshed(provider)];
  }

  Future<void> update(String name) async {
    final index = state.indexWhere((provider) => provider.name == name);
    if (index < 0 || state[index].isUpdating) {
      return;
    }
    state = [
      for (final provider in state)
        provider.name == name ? provider.copyWith(isUpdating: true) : provider,
    ];
    await Future<void>.delayed(updateDuration);
    if (!ref.mounted) {
      return;
    }
    state = [
      for (final provider in state)
        provider.name == name ? _refreshed(provider) : provider,
    ];
  }

  void save(int index, ProxyProviderEntry entry) {
    if (index < 0 || index >= state.length) {
      return;
    }
    final next = List<ProxyProviderEntry>.of(state)..[index] = entry;
    state = next;
  }

  ProxyProviderEntry _refreshed(ProxyProviderEntry provider) =>
      provider.copyWith(
        isUpdating: false,
        updatedAt: _nowLabel(),
        // The synced entry count varies slightly, like a real subscription.
        count: math.max(1, provider.count + _random.nextInt(5) - 2),
      );
}

final proxyProvidersProvider =
    NotifierProvider<ProxyProvidersNotifier, List<ProxyProviderEntry>>(
      ProxyProvidersNotifier.new,
    );

String _nowLabel() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
}
