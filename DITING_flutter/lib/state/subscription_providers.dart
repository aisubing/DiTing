/// 规则订阅域演示状态。
///
/// 为什么订阅列表要有自己的条目模型：`MockSubscription` 是常量数据，没有
/// `copyWith`，而订阅页要就地改「启用 / 更新时间 / 更新中 / 错误」四个字段。
/// 直接改 mock 常量会让热重载与测试之间互相污染，因此这里复制成可变条目。
library;

import 'package:diting/data/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一条可变的订阅条目。
class SubscriptionEntry {
  const SubscriptionEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.importType,
    required this.ruleCount,
    required this.group,
    this.enabled = true,
    this.updatedAt = '2026-10-18 09:24',
    this.error,
  });

  SubscriptionEntry.fromMock(MockSubscription subscription)
    : id = subscription.id,
      name = subscription.name,
      url = subscription.url,
      importType = subscription.importType,
      ruleCount = subscription.ruleCount,
      group = subscription.group,
      enabled = subscription.enabled,
      updatedAt = subscription.updatedAt,
      error = subscription.error;

  final String id;
  final String name;
  final String url;
  final SubscriptionImportType importType;
  final int ruleCount;
  final String group;
  final bool enabled;
  final String updatedAt;

  /// 非空表示上次更新失败，卡片用错误色呈现。
  final String? error;

  SubscriptionEntry copyWith({
    String? name,
    int? ruleCount,
    String? group,
    bool? enabled,
    String? updatedAt,
    String? error,
    bool clearError = false,
  }) => SubscriptionEntry(
    id: id,
    name: name ?? this.name,
    url: url,
    importType: importType,
    ruleCount: ruleCount ?? this.ruleCount,
    group: group ?? this.group,
    enabled: enabled ?? this.enabled,
    updatedAt: updatedAt ?? this.updatedAt,
    error: clearError ? null : (error ?? this.error),
  );
}

/// 订阅页的完整状态：条目 + 谁在更新 + 全部更新的进度。
///
/// 三者放一个 notifier：全部更新时进度与「哪几条正在更新」必须同帧变化，
/// 拆开会让卡片先显示转圈、再显示进度条，出现一次可见的错位。
class SubscriptionState {
  const SubscriptionState({
    required this.entries,
    this.updatingIds = const {},
    this.updatingAll = false,
    this.progress = 0,
  });

  final List<SubscriptionEntry> entries;
  final Set<String> updatingIds;
  final bool updatingAll;

  /// 0..1，全部更新时按已完成条数推进。
  final double progress;

  SubscriptionState copyWith({
    List<SubscriptionEntry>? entries,
    Set<String>? updatingIds,
    bool? updatingAll,
    double? progress,
  }) => SubscriptionState(
    entries: entries ?? this.entries,
    updatingIds: updatingIds ?? this.updatingIds,
    updatingAll: updatingAll ?? this.updatingAll,
    progress: progress ?? this.progress,
  );
}

class SubscriptionsNotifier extends Notifier<SubscriptionState> {
  /// 一次模拟更新的耗时。短到演示时不必等，长到能看见进度条动。
  static const _updateDelay = Duration(milliseconds: 700);

  var _sequence = 0;

  @override
  SubscriptionState build() => SubscriptionState(
    entries: [for (final item in mockSubscriptions) SubscriptionEntry.fromMock(item)],
  );

  bool get isBusy => state.updatingAll || state.updatingIds.isNotEmpty;

  SubscriptionEntry? entryOf(String id) {
    for (final entry in state.entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  void toggleEnabled(String id) {
    _update(id, (entry) => entry.copyWith(enabled: !entry.enabled));
  }

  void remove(String id) {
    state = state.copyWith(
      entries: [
        for (final entry in state.entries)
          if (entry.id != id) entry,
      ],
    );
  }

  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _update(id, (entry) => entry.copyWith(name: trimmed));
  }

  /// 添加订阅。名称与地址都做 trim：粘贴来的地址常带首尾空格与换行。
  bool add({
    required String name,
    required String url,
    required String group,
    SubscriptionImportType importType = SubscriptionImportType.remote,
  }) {
    final trimmedUrl = url.trim();
    final trimmedName = name.trim();
    if (trimmedUrl.isEmpty || trimmedName.isEmpty) {
      return false;
    }
    if (state.entries.any((entry) => entry.url == trimmedUrl)) {
      return false;
    }
    state = state.copyWith(
      entries: [
        ...state.entries,
        SubscriptionEntry(
          id: 'sub-user-${_sequence++}',
          name: trimmedName,
          url: trimmedUrl,
          importType: importType,
          ruleCount: 0,
          group: group,
        ),
      ],
    );
    return true;
  }

  /// 更新单条。更新中重复点击直接返回，避免同一行叠加两次计时。
  Future<void> updateOne(String id) async {
    if (state.updatingIds.contains(id) || state.updatingAll) {
      return;
    }
    state = state.copyWith(updatingIds: {...state.updatingIds, id});
    await Future<void>.delayed(_updateDelay);
    if (!ref.mounted) {
      return;
    }
    _update(
      id,
      (entry) => entry.copyWith(
        updatedAt: _stampNow(),
        // 演示数据没有真规则可拉，用固定增量模拟「拉到了新规则」。
        ruleCount: entry.ruleCount + (entry.importType ==
                SubscriptionImportType.remote
            ? 12
            : 0),
        clearError: true,
      ),
    );
    state = state.copyWith(
      updatingIds: {
        for (final other in state.updatingIds)
          if (other != id) other,
      },
    );
  }

  /// 全部更新：逐条串行，进度按条数推进。
  ///
  /// 串行而不是并发，是因为真实实现里更新走同一条 WorkManager 队列；并发模拟
  /// 会让「正在更新 2/5」这种文案失去意义。
  Future<void> updateAll() async {
    if (isBusy) {
      return;
    }
    final targets = [
      for (final entry in state.entries)
        if (entry.enabled && entry.importType == SubscriptionImportType.remote)
          entry.id,
    ];
    if (targets.isEmpty) {
      return;
    }
    state = state.copyWith(updatingAll: true, progress: 0);
    for (final (index, id) in targets.indexed) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(updatingIds: {...state.updatingIds, id});
      await Future<void>.delayed(_updateDelay);
      if (!ref.mounted) {
        return;
      }
      _update(
        id,
        (entry) => entry.copyWith(updatedAt: _stampNow(), clearError: true),
      );
      state = state.copyWith(
        updatingIds: {
          for (final other in state.updatingIds)
            if (other != id) other,
        },
        progress: (index + 1) / targets.length,
      );
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(updatingAll: false, progress: 0);
  }

  void _update(String id, SubscriptionEntry Function(SubscriptionEntry) update) {
    state = state.copyWith(
      entries: [
        for (final entry in state.entries)
          if (entry.id == id) update(entry) else entry,
      ],
    );
  }
}

final subscriptionsProvider =
    NotifierProvider<SubscriptionsNotifier, SubscriptionState>(
      SubscriptionsNotifier.new,
    );

/// 当前分组；`null` 表示「全部」。
class SubscriptionGroupFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? group) => state = group;
}

final subscriptionGroupFilterProvider =
    NotifierProvider<SubscriptionGroupFilterNotifier, String?>(
      SubscriptionGroupFilterNotifier.new,
    );

/// 分组 chip 的数据源：内置分组 + 用户新建订阅时出现的分组，保持首次出现顺序。
final subscriptionGroupsProvider = Provider<List<String>>((ref) {
  final entries = ref.watch(subscriptionsProvider).entries;
  final groups = <String>[];
  for (final group in [
    ...mockSubscriptionGroups,
    for (final entry in entries) entry.group,
  ]) {
    if (!groups.contains(group)) {
      groups.add(group);
    }
  }
  return groups;
});

/// 当前分组下的订阅。筛选放在 provider 里，页面只负责渲染。
final filteredSubscriptionsProvider = Provider<List<SubscriptionEntry>>((ref) {
  final group = ref.watch(subscriptionGroupFilterProvider);
  final entries = ref.watch(subscriptionsProvider).entries;
  if (group == null) {
    return entries;
  }
  return [
    for (final entry in entries)
      if (entry.group == group) entry,
  ];
});

/// 演示用时间戳：固定到分钟，避免同一秒内的两次更新看起来没变化。
String _stampNow() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)} '
      '${two(now.hour)}:${two(now.minute)}';
}
