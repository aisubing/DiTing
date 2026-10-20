/// 观测域状态：请求 / DNS 查询读真实旧库表，连接与资源仍是演示数据。
///
/// ## 哪些是真的
/// - **请求**（本文件 [requestFeedProvider]）读 `http_request_log` 与 `dns_log`
///   两张表，合并口径与筛选 SQL 来自 1.4.3 的 `RequestLogRepository.load()`。
/// - **DNS 查询**（[dnsQueriesProvider]）读 `dns_log`，六档状态筛选见
///   `dns_query_repository.dart`。
///
/// ## 哪些仍是演示，为什么
/// - **连接**（[connectionsProvider]）：Go 引擎没有「枚举活动连接」的导出接口
///   （`tunnel-debug-sources.jar` 里没有对应方法），1.4.3 的连接页读的是它自己
///   内核的 tracker，本项目没有等价物。保留 `mockConnections` 之外的演示副本，
///   页面顶部文案如实说明「演示数据」。
/// - **资源**（[resourcesProvider]）：1.4.3 没有任何「资源下载器」后端，四类资源
///   是上游自带的演示清单；这里保留内存副本，不假装有真实来源。
///
/// 共享一份 revision（复用 `dnsLogRevisionProvider`）而不是再造一个计数器：
/// 「清空日志」与「刷新」改的就是同一批表，两个计数器会让一个动作只刷新一半
/// 页面。极速模式的库文件不同，`activeLogDatabaseProvider` 已经按模式选好了。
library;

import 'package:diting/data/db/dns_query_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/mock_observability.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

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

// ---------------------------------------------------------------------------
// 连接（演示）
// ---------------------------------------------------------------------------

/// 连接列表。
///
/// 演示来源：引擎没有连接枚举接口，见文件头的说明。
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

// ---------------------------------------------------------------------------
// 请求（真实表：http_request_log + dns_log）
// ---------------------------------------------------------------------------

/// 一条合并后的请求记录。
///
/// 1.4.3 的请求页是「DNS + HTTPS 两张表的并集」（`RequestLogRepository.load`
/// 返回 `RequestLogBatch` 后按 `timestamp` 倒序合并），所以这里也拍平成一个
/// 模型：两张表的专有字段可空，页面只渲染非空项。
class ObservedRequest {
  const ObservedRequest({
    required this.key,
    required this.timestamp,
    required this.source,
    required this.status,
    required this.title,
    this.protocol,
    this.packageName,
    this.matchedRule,
    this.message,
    this.cached = false,
    this.elapsedMs,
    this.blockSubscriptionId,
  });

  /// `https-<id>` / `dns-<id>`，与旧版 `RequestLogItem.key` 同形。
  final String key;
  final int timestamp;
  final RequestSource source;
  final RequestStatus status;

  /// HTTPS 行是 authority（可能为空串），DNS 行是 queryName。
  final String title;

  /// HTTPS 才有（`h2` / `http/1.1`）。
  final String? protocol;
  final String? packageName;
  final String? matchedRule;

  /// DNS 行的原始 message（`app=.., resolved=.., elapsed=..`）。
  final String? message;
  final bool cached;

  /// DNS 行的 `elapsed=NNms`；HTTPS 表没有耗时列，为 null 时不显示。
  final int? elapsedMs;
  final int? blockSubscriptionId;

  static ObservedRequest fromHttp(HttpRequestRecord record) => ObservedRequest(
    key: 'https-${record.id}',
    timestamp: record.timestamp,
    source: RequestSource.https,
    status: record.status,
    title: record.authority ?? '',
    protocol: record.protocol,
    packageName: record.packageName,
    matchedRule: record.matchedRule,
    blockSubscriptionId: record.blockSubscriptionId,
  );

  static ObservedRequest fromDns(DnsLogRow row) {
    final parsed = DnsLogMessage.parse(row.message);
    return ObservedRequest(
      key: 'dns-${row.id}',
      timestamp: row.timestamp,
      source: RequestSource.dns,
      status: row.status,
      title: row.queryName,
      packageName: row.packageName,
      matchedRule: parsed.blockedBy,
      message: row.message,
      cached: row.cached,
      elapsedMs: parsed.elapsedMs,
      blockSubscriptionId: row.blockSubscriptionId,
    );
  }
}

/// 请求页的查询条件。旧版的四维筛选（来源 / 状态 / 关键词 / 条数）原样保留。
class RequestFeedQuery {
  const RequestFeedQuery({
    this.source = RequestSource.all,
    this.status = RequestStatus.all,
    this.query = '',
    this.limit = 200,
  });

  final RequestSource source;
  final RequestStatus status;
  final String query;
  final int limit;

  RequestFeedQuery copyWith({
    RequestSource? source,
    RequestStatus? status,
    String? query,
    int? limit,
  }) => RequestFeedQuery(
    source: source ?? this.source,
    status: status ?? this.status,
    query: query ?? this.query,
    limit: limit ?? this.limit,
  );
}

class RequestFeedNotifier extends Notifier<RequestFeedQuery> {
  @override
  RequestFeedQuery build() => const RequestFeedQuery();

  void setSource(RequestSource source) {
    if (state.source == source) return;
    state = state.copyWith(source: source);
  }

  void setStatus(RequestStatus status) {
    if (state.status == status) return;
    state = state.copyWith(status: status);
  }

  void setQuery(String query) {
    if (state.query == query) return;
    state = state.copyWith(query: query);
  }

  void reset() => state = const RequestFeedQuery();
}

final requestFeedQueryProvider =
    NotifierProvider<RequestFeedNotifier, RequestFeedQuery>(
      RequestFeedNotifier.new,
    );

/// 合并后的请求列表 + 「可能还有更多」标记。
class RequestFeed {
  const RequestFeed({required this.items, required this.hasMore});

  const RequestFeed.empty() : items = const [], hasMore = false;

  final List<ObservedRequest> items;

  /// 任一侧查满 [RequestFeedQuery.limit] 就为真：旧版 `RequestLogBatch.hasMore`
  /// 用的是同一判据（两条查询各自 `LIMIT limit`）。
  final bool hasMore;
}

/// Express mode keeps its own database, and 1.4.3 passed `null` for the HTTP
/// DAO there (`RequestLogViewModel`: `RequestLogRepository(express.dnsLogDao(),
/// null)`), because `diting_express` has no `http_request_log` table. Query it
/// anyway and every build throws `no such table`.
Future<RequestFeed> _loadRequestFeed(Ref ref) async {
  final query = ref.watch(requestFeedQueryProvider);
  final express = ref.watch(workModeProvider) == AppWorkMode.express;

  final dnsFuture = query.source == RequestSource.https
      ? Future.value(const <DnsLogRow>[])
      : () async {
          final db = await ref.watch(activeLogDatabaseProvider.future);
          if (db == null) return const <DnsLogRow>[];
          return DnsQueryRepository(db).recent(
            limit: query.limit,
            status: query.status,
            query: query.query,
          );
        }();

  final httpFuture = query.source == RequestSource.dns || express
      ? Future.value(const <HttpRequestRecord>[])
      : () async {
          final db = await ref.watch(mainLogDatabaseProvider.future);
          if (db == null) return const <HttpRequestRecord>[];
          return HttpRequestRepository(db).recent(
            limit: query.limit,
            status: query.status,
            query: query.query,
          );
        }();

  // 两个 future 一起等，而不是先 `await dnsFuture` 再 `await httpFuture`：
  // 后者在 DNS 侧先抛错时会提前返回，http 侧的错误就变成无人处理的异步异常
  // （`FutureProvider` 里表现为整帧崩掉，而不是进 error 态让页面显示重试）。
  // 记录类型的 `.wait` 保留两侧的静态类型，也把两边的失败合并成同一个错误。
  final (dnsRows, httpRows) = await (dnsFuture, httpFuture).wait;

  final items = <ObservedRequest>[
    for (final row in dnsRows) ObservedRequest.fromDns(row),
    for (final row in httpRows) ObservedRequest.fromHttp(row),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return RequestFeed(
    items: items.take(query.limit).toList(growable: false),
    hasMore: dnsRows.length >= query.limit || httpRows.length >= query.limit,
  );
}

final requestFeedProvider = FutureProvider<RequestFeed>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  return _loadRequestFeed(ref);
});

// ---------------------------------------------------------------------------
// DNS 查询（真实表：dns_log）
// ---------------------------------------------------------------------------

/// `diting_database`：普通 / 服务器模式，也是 `http_request_log` 与
/// `app_traffic_daily` 唯一存在的库。
///
/// 与 `activeLogDatabaseProvider`（按工作模式二选一）分开：极速模式的
/// `diting_express` 明确排除了这两个实体（见 `ExpressRulesDatabase` 类注释），
/// 对它执行 `SELECT ... FROM http_request_log` 会直接抛 `no such table`。
/// 请求页与流量页读这张表时必须无视当前模式，改用本 provider。
final mainLogDatabaseProvider = FutureProvider<Database?>(
  (ref) => LegacyDatabase.open(LegacyDatabase.mainFile),
);

/// 空结果，供「库里没有这张表」之外的正常空态复用。
const _noDnsRows = <DnsLogRow>[];

/// DNS 查询页的概览窗口：不受状态 chip 影响，用来算总数 / 失败 / 命中缓存，
/// 以及提供关键词 chip 的取值来源。
final dnsQueryWindowProvider = FutureProvider<List<DnsLogRow>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return _noDnsRows;
  return DnsQueryRepository(db).recent(limit: _dnsWindowSize);
});

/// 概览窗口条数。与日志页的「最近 200 行」同量级，但这里表格更宽、行更高，
/// 取 300 条仍够覆盖一次排查会话，又不会让首帧查询变慢。
const _dnsWindowSize = 300;

/// 页面当前选中的状态档位。搜索词与「只看失败 / 仅看缓存」是页面内状态：
/// 前者进 SQL（与旧版一致），后两者是对已取回行的即时过滤。
class DnsQueryStatusNotifier extends Notifier<RequestStatus> {
  @override
  RequestStatus build() => RequestStatus.all;

  void select(RequestStatus status) {
    if (state == status) return;
    state = status;
  }
}

final dnsQueryStatusProvider =
    NotifierProvider<DnsQueryStatusNotifier, RequestStatus>(
      DnsQueryStatusNotifier.new,
    );

/// 关键词也进 SQL：旧版用 `LIKE '%<lowercased>%'` 匹配 queryName / packageName /
/// message，放在 Dart 侧过滤会漏掉「窗口外但匹配」的行，两边的条数就对不上。
class DnsQueryTextNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    if (state == query) return;
    state = query;
  }

  void clear() => state = '';
}

final dnsQueryTextProvider = NotifierProvider<DnsQueryTextNotifier, String>(
  DnsQueryTextNotifier.new,
);

final dnsQueriesProvider = FutureProvider<List<DnsLogRow>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final status = ref.watch(dnsQueryStatusProvider);
  final query = ref.watch(dnsQueryTextProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return _noDnsRows;
  return DnsQueryRepository(db).recent(
    limit: _dnsWindowSize,
    status: status,
    query: query,
  );
});

// ---------------------------------------------------------------------------
// 资源（演示）
// ---------------------------------------------------------------------------

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

/// 资源清单（演示）。
///
/// 1.4.3 没有资源下载器：这四类资源来自上游自带的演示清单，刷新只是改内存
/// 副本里的时间戳与体积。数据层不依赖 widget 层，所以这里的「刷新」不改
/// `mock_observability.dart` 的常量，只改 provider 里的副本。
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
