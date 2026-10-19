/// 观测域演示状态：连接 / 请求 / DNS 查询 / 资源四份可变副本。
///
/// 为什么放进 provider 而不是页面 `State`：连接页的「全部关闭」与详情页的
/// 「关闭连接」改的是同一份列表——详情从页面 push 出去，页面 `State` 管不到
/// 它；资源页的「更新全部」要逐条推进进度，关掉页面不该把进度一起丢掉。
///
/// 全部只改内存副本：演示页不该把临时操作写回 `mock_observability.dart` 的
/// 常量，否则热重载后状态回不到初始值。
library;

import 'package:diting/data/mock_observability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 演示用固定延时：900 ms 足够看清按钮的 loading 态，又不至于让「全部更新」
/// 的四类资源等上十几秒。
const _updateDelay = Duration(milliseconds: 900);

/// 时间戳格式 `yyyy-MM-dd HH:mm`，与 mock 里 `updatedAt` 的字面量一致。
String _stampNow() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)} '
      '${two(now.hour)}:${two(now.minute)}';
}

/// 连接列表。
class ConnectionsNotifier extends Notifier<List<MockConnection>> {
  @override
  List<MockConnection> build() => [...mockConnections];

  /// 关闭单条。详情页与列表的关闭按钮走同一个入口。
  void close(String id) {
    state = [
      for (final connection in state)
        if (connection.id != id) connection,
    ];
  }

  /// 全部关闭。返回关掉的条数，供调用方在确认框之后显示结果。
  int closeAll() {
    final count = state.length;
    state = const [];
    return count;
  }
}

final connectionsProvider =
    NotifierProvider<ConnectionsNotifier, List<MockConnection>>(
      ConnectionsNotifier.new,
    );

/// 请求列表。请求是已结束的记录，只读，但仍放在 provider 里，好让页面与
/// 后续的「清空请求」共用一份数据。
final requestsProvider = Provider<List<MockRequest>>(
  (ref) => [...mockRequests],
);

/// DNS 查询列表。
final dnsQueriesProvider = Provider<List<MockDnsQuery>>(
  (ref) => [...mockDnsQueries],
);

/// 资源更新状态。
///
/// `updatingIds` 与 `updatingAll` 分开记：全部更新时每一条都要显示自己的
/// loading 态，只用一个布尔的话，用户看不出到底哪一条在动。
class ResourcesState {
  const ResourcesState({
    required this.resources,
    this.updatingIds = const {},
    this.updatingAll = false,
    this.completed = 0,
    this.total = 0,
  });

  final List<MockObsResource> resources;
  final Set<String> updatingIds;
  final bool updatingAll;

  /// 全部更新的进度：已完成 / 总数。
  final int completed;
  final int total;

  bool get isBusy => updatingAll || updatingIds.isNotEmpty;

  bool isUpdating(String id) => updatingIds.contains(id);

  ResourcesState copyWith({
    List<MockObsResource>? resources,
    Set<String>? updatingIds,
    bool? updatingAll,
    int? completed,
    int? total,
  }) => ResourcesState(
    resources: resources ?? this.resources,
    updatingIds: updatingIds ?? this.updatingIds,
    updatingAll: updatingAll ?? this.updatingAll,
    completed: completed ?? this.completed,
    total: total ?? this.total,
  );
}

class ResourcesNotifier extends Notifier<ResourcesState> {
  @override
  ResourcesState build() => ResourcesState(resources: [...mockObsResources]);

  /// 更新单条：置 loading → 等 900 ms → 刷新时间戳与体积。
  ///
  /// 更新中重复点击直接返回，避免同一行叠加两次计时。
  Future<void> updateOne(String id) async {
    if (state.isUpdating(id) || state.updatingAll) {
      return;
    }
    state = state.copyWith(updatingIds: {...state.updatingIds, id});
    await Future<void>.delayed(_updateDelay);
    if (!ref.mounted) {
      return;
    }
    _refresh(id);
    state = state.copyWith(
      updatingIds: {
        for (final other in state.updatingIds)
          if (other != id) other,
      },
    );
  }

  /// 全部更新：逐条串行。
  ///
  /// 串行而不是并发，是因为真实实现里资源下载走同一条队列；并发模拟会让
  /// 「正在更新 2/4」这种进度文案失去意义。
  Future<void> updateAll() async {
    if (state.isBusy) {
      return;
    }
    final targets = [for (final resource in state.resources) resource.id];
    if (targets.isEmpty) {
      return;
    }
    state = state.copyWith(
      updatingAll: true,
      completed: 0,
      total: targets.length,
    );
    for (final (index, id) in targets.indexed) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(updatingIds: {...state.updatingIds, id});
      await Future<void>.delayed(_updateDelay);
      if (!ref.mounted) {
        return;
      }
      _refresh(id);
      state = state.copyWith(
        updatingIds: {
          for (final other in state.updatingIds)
            if (other != id) other,
        },
        completed: index + 1,
      );
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(updatingAll: false, completed: 0, total: 0);
  }

  /// 改地址。地址是这份资源的唯一可变配置，其余字段刷新时都不动。
  void setUrl(String id, String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = state.copyWith(
      resources: [
        for (final resource in state.resources)
          if (resource.id == id)
            MockObsResource(
              id: resource.id,
              kind: resource.kind,
              name: resource.name,
              url: trimmed,
              updatedAt: resource.updatedAt,
              sizeBytes: resource.sizeBytes,
              lineCount: resource.lineCount,
              defaultUrl: resource.defaultUrl,
            )
          else
            resource,
      ],
    );
  }

  /// 刷新一条：时间戳换成本刻，体积按「演示增量」长一点。
  ///
  /// 用固定增量而不是随机数：截图与快照测试要能复现同一屏。
  void _refresh(String id) {
    state = state.copyWith(
      resources: [
        for (final resource in state.resources)
          if (resource.id == id)
            MockObsResource(
              id: resource.id,
              kind: resource.kind,
              name: resource.name,
              url: resource.url,
              updatedAt: _stampNow(),
              sizeBytes:
                  resource.sizeBytes + 1024 * (resource.lineCount % 7 + 1),
              lineCount: resource.lineCount,
              defaultUrl: resource.defaultUrl,
            )
          else
            resource,
      ],
    );
  }
}

final resourcesProvider = NotifierProvider<ResourcesNotifier, ResourcesState>(
  ResourcesNotifier.new,
);
