/// Real subscription data from the 1.4.3 Room tables; updates parse the body into rules tagged
/// `sub_<id>`.
library;

import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/mirror_template_repository.dart';
import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/db/subscription_repository.dart';
import 'package:diting/data/rules/rule_importer.dart';
import 'package:diting/data/rules/rule_parser.dart';
import 'package:diting/data/subscriptions/subscription_fetcher.dart';
import 'package:diting/data/subscriptions/subscription_url.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Normal and server mode share `diting_database`; express has its own file.
final subscriptionDatabaseFileProvider = Provider<String>((ref) {
  final mode = ref.watch(workModeProvider);
  return mode == AppWorkMode.express
      ? LegacyDatabase.expressFile
      : LegacyDatabase.mainFile;
});

/// Null on a fresh install (no legacy file yet), giving an empty list.
final subscriptionDatabaseProvider = FutureProvider<Database?>(
  (ref) => LegacyDatabase.open(ref.watch(subscriptionDatabaseFileProvider)),
);

/// Bumped by every write so all subscription readers rebuild together.
class SubscriptionRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final subscriptionRevisionProvider =
    NotifierProvider<SubscriptionRevisionNotifier, int>(
      SubscriptionRevisionNotifier.new,
    );

/// Real fetcher; tests inject a fake with `overrideWithValue`.
final subscriptionFetcherProvider = Provider<SubscriptionFetcher>(
  (ref) => HttpSubscriptionFetcher(),
);

/// Rule importer sharing the repository handle; null without a database.
final ruleImporterProvider = FutureProvider<RuleImporter?>((ref) async {
  final db = await ref.watch(subscriptionDatabaseProvider.future);
  return db == null ? null : RuleImporter(db);
});

/// Subscription repository; null without a legacy database.
final subscriptionRepositoryProvider = FutureProvider<SubscriptionRepository?>((
  ref,
) async {
  final db = await ref.watch(subscriptionDatabaseProvider.future);
  if (db == null) {
    return null;
  }
  return SubscriptionRepository(
    db,
    onChanged: () => ref.read(subscriptionRevisionProvider.notifier).bump(),
  );
});

/// A subscription as rendered (model plus group name and derived labels).
class SubscriptionEntry {
  const SubscriptionEntry({required this.record, this.groupName});

  final SubscriptionRecord record;

  /// Resolved group name; null means ungrouped.
  final String? groupName;

  int get id => record.id;
  String get name => record.name;
  String get url => record.url;
  bool get enabled => record.enabled;
  int get ruleCount => record.ruleCount;
  SubscriptionKind get kind => record.kind;
  SubscriptionSourceType get sourceType => record.sourceType;
  SubscriptionImportState get importState => record.importState;
  String? get importError => record.importError;
  int get consecutiveFailureCount => record.consecutiveFailureCount;
  int get lastUpdated => record.lastUpdated;
  int get lastAttemptAt => record.lastAttemptAt;

  /// Always false, since the parse chain is ported; kept so tests catch stale callers.
  bool get ruleCountIsLexicalOnly => false;

  bool get isRemote => record.isRemote;
  bool get isFailed => record.importState == SubscriptionImportState.failed;
  bool get isImporting =>
      record.importState == SubscriptionImportState.importing;

  /// Group chip key; a null group is shown as ungrouped.
  String get groupKey => groupName ?? ungroupedLabel;

  static const ungroupedLabel = '未分组';
}

/// All subscriptions and groups; group names resolve from here.
final subscriptionEntriesProvider = FutureProvider<List<SubscriptionEntry>>((
  ref,
) async {
  ref.watch(subscriptionRevisionProvider);
  final repository = await ref.watch(subscriptionRepositoryProvider.future);
  if (repository == null) {
    return const [];
  }
  final records = await repository.all();
  final groups = await repository.groups();
  final names = {for (final group in groups) group.id: group.name};
  return [
    for (final record in records)
      SubscriptionEntry(record: record, groupName: names[record.groupId]),
  ];
});

/// Groups from `subscription_group`, ordered by `addedAt ASC, name NOCASE ASC`.
final subscriptionGroupsProvider =
    FutureProvider<List<SubscriptionGroupRecord>>((ref) async {
      ref.watch(subscriptionRevisionProvider);
      final repository = await ref.watch(subscriptionRepositoryProvider.future);
      return repository == null
          ? const <SubscriptionGroupRecord>[]
          : repository.groups();
    });

/// Selected group id; null means all groups.
class SubscriptionGroupFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? groupId) => state = groupId;
}

final subscriptionGroupFilterProvider =
    NotifierProvider<SubscriptionGroupFilterNotifier, int?>(
      SubscriptionGroupFilterNotifier.new,
    );

/// Subscriptions in the selected group; filtering stays out of the page.
final filteredSubscriptionsProvider = Provider<List<SubscriptionEntry>>((ref) {
  final groupId = ref.watch(subscriptionGroupFilterProvider);
  final entries = ref.watch(subscriptionEntriesProvider).value ?? const [];
  if (groupId == null) {
    return entries;
  }
  return [
    for (final entry in entries)
      if (entry.record.groupId == groupId) entry,
  ];
});

/// Update progress and busy flags in one notifier, so they change in the same frame.
class SubscriptionUpdateState {
  const SubscriptionUpdateState({
    this.updatingIds = const {},
    this.updatingAll = false,
    this.progress = 0,
    this.lastMessage,
  });

  final Set<int> updatingIds;
  final bool updatingAll;

  /// 0..1, advanced by completed rows during update-all.
  final double progress;

  /// Summary of the last bulk update, e.g. "3 updated, 1 unchanged, 1 failed".
  final String? lastMessage;

  bool get isBusy => updatingAll || updatingIds.isNotEmpty;

  SubscriptionUpdateState copyWith({
    Set<int>? updatingIds,
    bool? updatingAll,
    double? progress,
    String? lastMessage,
    bool clearMessage = false,
  }) => SubscriptionUpdateState(
    updatingIds: updatingIds ?? this.updatingIds,
    updatingAll: updatingAll ?? this.updatingAll,
    progress: progress ?? this.progress,
    lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
  );
}

class SubscriptionUpdateNotifier extends Notifier<SubscriptionUpdateState> {
  @override
  SubscriptionUpdateState build() => const SubscriptionUpdateState();

  /// Updates one subscription; re-entry returns immediately. Reads a live snapshot, as `insert`
  /// leaves the cache stale.
  Future<SubscriptionFetchResult?> updateOne(int id) async {
    if (state.isBusy) {
      return null;
    }
    final entry = await _loadEntry(id);
    if (entry == null) {
      return null;
    }
    state = state.copyWith(updatingIds: {id}, clearMessage: true);
    final result = await _runOne(entry);
    if (!ref.mounted) {
      return result;
    }
    state = state.copyWith(
      updatingIds: const {},
      lastMessage: _summarize([result]),
    );
    return result;
  }

  /// Loads one entry with its group name straight from the database.
  Future<SubscriptionEntry?> _loadEntry(int id) async {
    final repository = await ref.read(subscriptionRepositoryProvider.future);
    if (repository == null) {
      return null;
    }
    final record = await repository.byId(id);
    if (record == null) {
      return null;
    }
    final groups = await repository.groups();
    final groupName = groups
        .where((group) => group.id == record.groupId)
        .map((group) => group.name)
        .firstOrNull;
    return SubscriptionEntry(record: record, groupName: groupName);
  }

  /// Updates all serially like upstream's single WorkManager queue.
  Future<void> updateAll(List<SubscriptionEntry> targets) async {
    if (state.isBusy || targets.isEmpty) {
      return;
    }
    state = state.copyWith(updatingAll: true, progress: 0, clearMessage: true);
    final results = <SubscriptionFetchResult>[];
    for (final (index, entry) in targets.indexed) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(updatingIds: {entry.id});
      results.add(await _runOne(entry));
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        updatingIds: const {},
        progress: (index + 1) / targets.length,
      );
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      updatingAll: false,
      progress: 0,
      lastMessage: _summarize(results),
    );
  }

  /// Runs one update and records the result; exceptions become failures so the UI never stays busy.
  Future<SubscriptionFetchResult> _runOne(SubscriptionEntry entry) async {
    final repository = await ref.read(subscriptionRepositoryProvider.future);
    if (repository == null) {
      return const SubscriptionFetchResult.failed('订阅数据库不可用');
    }
    if (!entry.isRemote) {
      // Local-file subscriptions have no URL, matching upstream's failure.
      await repository.markUpdateFailed(
        entry.id,
        error: '本地文件订阅无法更新',
        attemptedAt: DateTime.now().millisecondsSinceEpoch,
      );
      return const SubscriptionFetchResult.failed('本地文件订阅无法更新');
    }
    await repository.setImportState(
      entry.id,
      SubscriptionImportState.importing,
    );
    final result = await ref
        .read(subscriptionFetcherProvider)
        .fetch(entry.record);
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (result.outcome) {
      case SubscriptionFetchOutcome.notModified:
        await repository.markNotModified(
          entry.id,
          attemptedAt: now,
          etag: result.etag ?? entry.record.httpEtag,
          lastModified: result.lastModified ?? entry.record.httpLastModified,
        );
      case SubscriptionFetchOutcome.content:
        // Parse and import; the count is rows actually written.
        final imported = await _importContent(entry, result.content ?? '');
        if (imported == null) {
          // A download that cannot be stored must report failure, not "updated".
          await repository.markUpdateFailed(
            entry.id,
            error: '规则库不可用，下载的规则无法入库',
            attemptedAt: now,
          );
          return const SubscriptionFetchResult.failed('规则库不可用，下载的规则无法入库');
        }
        await repository.markImported(
          entry.id,
          ruleCount: imported.insertedCount,
          lastUpdated: now,
          etag: result.etag,
          lastModified: result.lastModified,
        );
      case SubscriptionFetchOutcome.failed:
        await repository.markUpdateFailed(
          entry.id,
          error: result.error ?? '更新失败',
          attemptedAt: now,
        );
    }
    return result;
  }

  /// Parses the body and rewrites the rule tables for `sub_<id>` only; null without a rule
  /// database.
  Future<RuleImportSummary?> _importContent(
    SubscriptionEntry entry,
    String content,
  ) async {
    final importer = await ref.read(ruleImporterProvider.future);
    if (importer == null) {
      return null;
    }
    final source = subscriptionSourceTag(entry.id);
    final parsed = parseCategorized(content);
    await importer.removeRulesBySource(source);
    if (parsed.isEmpty) {
      return const RuleImportSummary();
    }
    return importer.import(
      parsed,
      source: source,
      kind: entry.kind.storageValue,
      enabled: entry.enabled,
    );
  }

  static String _summarize(List<SubscriptionFetchResult> results) {
    if (results.isEmpty) {
      return '没有可更新的订阅';
    }
    final updated = results.where((result) => result.isSuccess).length;
    final unchanged = results.where((result) => result.isNotModified).length;
    final failed = results.where((result) => result.isFailure).length;
    final parts = <String>[
      if (updated > 0) '$updated 个已更新',
      if (unchanged > 0) '$unchanged 个未变化',
      if (failed > 0) '$failed 个失败',
    ];
    return parts.isEmpty ? '没有可更新的订阅' : parts.join('，');
  }
}

final subscriptionUpdateProvider =
    NotifierProvider<SubscriptionUpdateNotifier, SubscriptionUpdateState>(
      SubscriptionUpdateNotifier.new,
    );

/// Result of adding a subscription; failures carry a readable reason.
sealed class AddSubscriptionResult {
  const AddSubscriptionResult();
}

class AddSubscriptionOk extends AddSubscriptionResult {
  const AddSubscriptionOk(this.id);
  final int id;
}

class AddSubscriptionFailure extends AddSubscriptionResult {
  const AddSubscriptionFailure(this.message);
  final String message;
}

class SubscriptionActions {
  const SubscriptionActions(this._ref);

  final Ref _ref;

  Future<AddSubscriptionResult> add({
    required String name,
    required String url,
    required SubscriptionKind kind,
    int? groupId,
    String? mirrorTemplate,
    bool mirrorFallback = true,
  }) async {
    final urlError = validateSubscriptionUrl(url);
    if (urlError != null) {
      return AddSubscriptionFailure(urlError);
    }
    final trimmedUrl = url.trim();
    final trimmedName = name.trim();
    final repository = await _ref.read(subscriptionRepositoryProvider.future);
    if (repository == null) {
      return const AddSubscriptionFailure('订阅数据库不可用（未找到 1.4.3 数据库）');
    }
    final existing = await repository.byUrlAndKind(trimmedUrl, kind);
    if (existing != null) {
      return AddSubscriptionFailure(
        '该订阅链接已作为${kind.displayName}存在（「${existing.name}」）',
      );
    }
    String? normalizedMirror;
    try {
      normalizedMirror = normalizeMirrorTemplate(mirrorTemplate);
    } on FormatException catch (error) {
      return AddSubscriptionFailure(error.message);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await repository.insert(
      SubscriptionRecord(
        id: 0,
        url: trimmedUrl,
        name: trimmedName.isEmpty
            ? extractNameFromUrl(trimmedUrl)
            : trimmedName,
        sourceType: SubscriptionSourceType.remote,
        kind: kind,
        enabled: true,
        ruleCount: 0,
        lastUpdated: 0,
        addedAt: now,
        // Like upstream `addSubscription`: the row starts as `importing`.
        importState: SubscriptionImportState.importing,
        lastAttemptAt: 0,
        consecutiveFailureCount: 0,
        mirrorTemplate: normalizedMirror,
        mirrorFallback: mirrorFallback,
        groupId: groupId,
      ),
    );
    return AddSubscriptionOk(id);
  }

  /// Master switch; also flips its source rows, since a rule is active only when both it and a
  /// source are enabled.
  Future<void> setEnabled(int id, bool enabled) async {
    await (await _ref.read(subscriptionRepositoryProvider.future))
        ?.setEnabled(id, enabled);
    await (await _ref.read(ruleImporterProvider.future))
        ?.setSourceEnabled(subscriptionSourceTag(id), enabled);
  }

  Future<void> rename(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await (await _ref.read(subscriptionRepositoryProvider.future))
        ?.setName(id, trimmed);
  }

  /// Deletes rules first; the other order would leave ownerless rules blocking.
  Future<void> remove(int id) async {
    await (await _ref.read(ruleImporterProvider.future))
        ?.removeRulesBySource(subscriptionSourceTag(id));
    await (await _ref.read(subscriptionRepositoryProvider.future))
        ?.deleteById(id);
  }

  /// Creates a group and returns its id, or the existing id on a name clash.
  Future<int?> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return (await _ref.read(subscriptionRepositoryProvider.future))
        ?.insertGroup(name: trimmed);
  }
}

final subscriptionActionsProvider = Provider<SubscriptionActions>(
  SubscriptionActions.new,
);

// Mirror templates (the mirror_template table).

/// Template repository; null without a legacy database.
final mirrorTemplateRepositoryProvider =
    FutureProvider<MirrorTemplateRepository?>((ref) async {
      final db = await ref.watch(subscriptionDatabaseProvider.future);
      if (db == null) return null;
      return MirrorTemplateRepository(
        db,
        onChanged: () => ref.read(subscriptionRevisionProvider.notifier).bump(),
      );
    });

/// All mirror templates, ordered by `addedAt DESC` like legacy `observeAll`.
final mirrorTemplatesProvider = FutureProvider<List<MirrorTemplateRecord>>((
  ref,
) async {
  ref.watch(subscriptionRevisionProvider);
  final repository = await ref.watch(mirrorTemplateRepositoryProvider.future);
  return repository == null
      ? const <MirrorTemplateRecord>[]
      : repository.all();
});

/// Mirror-template CRUD; `onChanged` bumps the revision so the list rebuilds.
class MirrorTemplateActions {
  MirrorTemplateActions(this._ref);

  final Ref _ref;

  Future<MirrorTemplateRepository?> _repository() =>
      _ref.read(mirrorTemplateRepositoryProvider.future);

  /// New row id, or null on a name clash or empty input.
  Future<int?> create({required String name, required String template}) async =>
      (await _repository())?.insert(name: name, template: template);

  /// Returns false on a name clash or invalid input.
  Future<bool> update({
    required int id,
    required String name,
    required String template,
  }) async =>
      await (await _repository())?.update(
        id: id,
        name: name,
        template: template,
      ) ??
      false;

  Future<void> remove(int id) async => (await _repository())?.delete(id);
}

final mirrorTemplateActionsProvider = Provider<MirrorTemplateActions>(
  MirrorTemplateActions.new,
);

