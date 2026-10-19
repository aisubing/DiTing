/// 代理域演示状态：节点延迟、组内选择、展开态、搜索词、外部提供者。
///
/// 节点延迟与「组内已选」都是可变状态，而 `mock_proxies.dart` 里是 `const`，
/// 所以这里按 `组名 + 节点名` 拼键把可变部分摊平成一个 Map——比复制整棵
/// 分组树更省事，也让「只重测某个组」只需改几行键值。
library;

import 'dart:math' as math;

import 'package:diting/data/mock_proxies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 节点在状态里的键。分组与节点名都不含 `\u0000`，拼起来不会撞车。
String proxyKeyOf(String groupName, String proxyName) =>
    '$groupName\u0000$proxyName';

/* ------------------------------------------------------------------ 样式 */

/// 代理页的六项呈现设置（上游 `ProxiesStyleSetting`）。
class ProxiesSettings {
  const ProxiesSettings({
    this.type = ProxiesType.tab,
    this.sortType = ProxiesSortType.none,
    this.layout = ProxiesLayout.standard,
    this.cardType = ProxyCardType.standard,
    this.iconStyle = ProxiesIconStyle.filled,
    this.hideTimeoutProxies = false,
  });

  /// 标签页 / 列表。
  final ProxiesType type;

  final ProxiesSortType sortType;
  final ProxiesLayout layout;
  final ProxyCardType cardType;

  /// 只在列表形式下可见，上游亦如此。
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

/* -------------------------------------------------------------- 分组状态 */

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

  /// 正在测速的分组；`testingAll` 为真时所有组都在转圈。
  final Set<String> testingGroups;
  final bool testingAll;

  /// 列表形式下展开的分组名。
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
  /// 测速演示耗时：短到不必等，长到能看清转圈与延迟数字的切换。
  static const testDuration = Duration(milliseconds: 900);

  /// 固定种子：同一次会话里反复点测速的结果稳定，便于截图与回归。
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

  /// 返回该组是否可选中；负载均衡与链式代理组只做演示反馈。
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

  /// 自动测速组按「最快且未超时」重排自己的已选节点，像真实 url-test 那样。
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

/* -------------------------------------------------------------- 派生视图 */

/// 一个节点在页面上的只读快照。
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

/// 一个分组在页面上的只读快照（已过滤、已排序）。
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

  /// 隐藏超时节点前的节点数，用于在头部标注「已隐藏 N 个」。
  final int totalCount;

  int get hiddenCount => totalCount - nodes.length;
}

/// 过滤（搜索 + 隐藏超时）与排序后的分组列表。
///
/// 搜索先于隐藏：搜到的超时节点若被隐藏开关吃掉，用户会以为搜索坏了——
/// 上游同样是先搜索再过滤。
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
        // 未测与超时沉底，其余按数值升序。
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

/* ------------------------------------------------------------ 外部提供者 */

/// 页面上的一个外部提供者条目（可改可测）。
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
        // 每次同步回来的条数略有出入，像真实订阅一样。
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
