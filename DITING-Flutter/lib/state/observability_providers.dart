/// Observability state; requests merge `http_request_log` and `dns_log`, DNS queries read
/// `dns_log`, the rest is demo.
library;

import 'package:diting/data/db/dns_query_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/mock_observability.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Long enough to show the loading state without stalling "update all".
const _updateDelay = Duration(milliseconds: 900);

/// Timestamp format `yyyy-MM-dd HH:mm`, matching the mock's `updatedAt`.
String _stampNow() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)} '
      '${two(now.hour)}:${two(now.minute)}';
}

class ConnectionsNotifier extends Notifier<List<MockConnection>> {
  @override
  List<MockConnection> build() => [...mockConnections];

  /// Closes one connection; the detail page and list share this entry point.
  void close(String id) {
    state = [
      for (final connection in state)
        if (connection.id != id) connection,
    ];
  }

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

/// One record merged from the DNS and HTTPS tables; only the non-null per-table fields render.
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

  /// `https-<id>` or `dns-<id>`, shaped like the legacy `RequestLogItem.key`.
  final String key;
  final int timestamp;
  final RequestSource source;
  final RequestStatus status;

  /// Authority for HTTPS rows (possibly empty), query name for DNS rows.
  final String title;

  /// HTTPS only (`h2` / `http/1.1`).
  final String? protocol;
  final String? packageName;
  final String? matchedRule;

  /// Raw DNS message (`app=.., resolved=.., elapsed=..`).
  final String? message;
  final bool cached;

  /// `elapsed=NNms` for DNS rows; null and hidden for HTTPS, which has no column.
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

/// Request-page query: the legacy four filters (source, status, keyword, limit).
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

class RequestFeed {
  const RequestFeed({required this.items, required this.hasMore});

  const RequestFeed.empty() : items = const [], hasMore = false;

  final List<ObservedRequest> items;

  /// True when either side filled [RequestFeedQuery.limit].
  final bool hasMore;
}

/// Express keeps its own database without `http_request_log`, so querying it throws `no such
/// table`.
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

  // Await both together: a sequential await returns early when the DNS side throws, leaving the
  // HTTP error unhandled.
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

/// The main `diting_database`, the only one with `http_request_log` and `app_traffic_daily`.
final mainLogDatabaseProvider = FutureProvider<Database?>(
  (ref) => LegacyDatabase.open(LegacyDatabase.mainFile),
);

/// Empty result reused for normal empty states.
const _noDnsRows = <DnsLogRow>[];

/// Overview window for the DNS page, independent of the status chips.
final dnsQueryWindowProvider = FutureProvider<List<DnsLogRow>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return _noDnsRows;
  return DnsQueryRepository(db).recent(limit: _dnsWindowSize);
});

/// Covers a debugging session without slowing the first frame.
const _dnsWindowSize = 300;

/// Selected status filter. The keyword goes to SQL; the toggles filter fetched rows.
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

/// The keyword goes into SQL (`LIKE`), since Dart-side filtering misses rows outside the window.
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
  return DnsQueryRepository(db)
      .recent(limit: _dnsWindowSize, status: status, query: query);
});

/// `updatingIds` and `updatingAll` are separate so each row shows its own loading state during
/// update-all.
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

/// Demo: 1.4.3 has no downloader, so refreshing rewrites this copy's timestamps, not the mock ones.
class ResourcesNotifier extends Notifier<ResourcesState> {
  @override
  ResourcesState build() => ResourcesState(resources: [...mockObsResources]);

  /// Marks the row loading, waits, then refreshes its timestamp and size.
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

  /// Updates all serially, like a single download queue.
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

  /// Changes the URL, the only editable field of a resource.
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

  /// Refreshes a row; the size grows by a fixed increment so snapshots reproduce.
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
