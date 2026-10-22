/// 订阅域的真实数据源：读旧库 `subscription` / `subscription_group`，更新走真实
/// HTTP 下载 + 真实规则解析与入库。
///
/// 与演示版的三个关键差别：
/// 1. 列表来自 `diting_database`（普通/服务器）或 `diting_express`（极速）里
///    1.4.3 的 Room 表，不再有 `mockSubscriptions` 播种；
/// 2. 更新是**真发包**（[HttpSubscriptionFetcher]），304 / HTTP 错误 / 超时
///    分别落成 `ready` / `failed` 三种状态；
/// 3. 正文下载后经 `lib/data/rules/` 解析成 block/allow/rewrite 并按
///    `sub_<id>` 来源写进规则表，`ruleCount` 是**真实入库条数**。
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

/// 普通与服务器模式共用 `diting_database`；极速模式有独立文件。
final subscriptionDatabaseFileProvider = Provider<String>((ref) {
  final mode = ref.watch(workModeProvider);
  return mode == AppWorkMode.express
      ? LegacyDatabase.expressFile
      : LegacyDatabase.mainFile;
});

/// `null` 表示全新安装（旧库文件还不存在），此时列表为空而不是报错。
final subscriptionDatabaseProvider = FutureProvider<Database?>(
  (ref) => LegacyDatabase.open(ref.watch(subscriptionDatabaseFileProvider)),
);

/// 任何写操作后自增，让所有读订阅表的 provider 一起重建。
class SubscriptionRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final subscriptionRevisionProvider =
    NotifierProvider<SubscriptionRevisionNotifier, int>(
      SubscriptionRevisionNotifier.new,
    );

/// 真实的下载实现；测试用 `overrideWithValue` 注入 fake。
final subscriptionFetcherProvider = Provider<SubscriptionFetcher>(
  (ref) => HttpSubscriptionFetcher(),
);

/// 规则入库器：与订阅仓库共用同一个库句柄。库不存在时为 null。
final ruleImporterProvider = FutureProvider<RuleImporter?>((ref) async {
  final db = await ref.watch(subscriptionDatabaseProvider.future);
  return db == null ? null : RuleImporter(db);
});

/// 订阅仓库：没有旧库时返回 null，调用方据此渲染空状态。
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

/// 一条订阅在 UI 上的展开形态（模型 + 分组名 + 派生文案）。
class SubscriptionEntry {
  const SubscriptionEntry({required this.record, this.groupName});

  final SubscriptionRecord record;

  /// `groupId` 解析出来的分组名；null 表示「未分组」。
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

  /// `ruleCount` 现在是**真实入库条数**（解析后写进 `block_rule` /
  /// `allow_rule` / `rewrite_rule` / `go_url_rule` 的行数）。
  ///
  /// 恒为 `false`：解析链已移植，不再需要「词法行数」的免责说明。保留这个 getter
  /// 是为了让仍按旧口径写文案的调用点被编译器/测试盯住，而不是让它们悄悄说错话。
  bool get ruleCountIsLexicalOnly => false;

  bool get isRemote => record.isRemote;
  bool get isFailed => record.importState == SubscriptionImportState.failed;
  bool get isImporting =>
      record.importState == SubscriptionImportState.importing;

  /// 分组 chip 的键。`null` 分组统一显示「未分组」。
  String get groupKey => groupName ?? ungroupedLabel;

  static const ungroupedLabel = '未分组';
}

/// 全部订阅 + 全部分组。分组名用它解析，未命中落到「未分组」。
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

/// 分组列表（`subscription_group` 表，顺序即 `addedAt ASC, name NOCASE ASC`）。
final subscriptionGroupsProvider =
    FutureProvider<List<SubscriptionGroupRecord>>((ref) async {
      ref.watch(subscriptionRevisionProvider);
      final repository = await ref.watch(subscriptionRepositoryProvider.future);
      return repository == null
          ? const <SubscriptionGroupRecord>[]
          : repository.groups();
    });

/// 当前选中的分组 id；`null` 表示「全部」。
class SubscriptionGroupFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? groupId) => state = groupId;
}

final subscriptionGroupFilterProvider =
    NotifierProvider<SubscriptionGroupFilterNotifier, int?>(
      SubscriptionGroupFilterNotifier.new,
    );

/// 当前分组下的订阅。筛选放在 provider 里，页面只负责渲染。
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

/// 更新进度与忙碌标记。三者放一个 notifier：进度和「哪几条正在更新」必须同帧
/// 变化，拆开会让卡片先转圈、再出进度条，出现一次可见错位。
class SubscriptionUpdateState {
  const SubscriptionUpdateState({
    this.updatingIds = const {},
    this.updatingAll = false,
    this.progress = 0,
    this.lastMessage,
  });

  final Set<int> updatingIds;
  final bool updatingAll;

  /// 0..1，全部更新时按已完成条数推进。
  final double progress;

  /// 最近一次批量更新的结果摘要（如「3 个已更新，1 个未变化，1 个失败」）。
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

  /// 单条更新。更新中重复点击直接返回，避免同一行叠加两次下载。
  ///
  /// 条目来源是 `subscriptionRepositoryProvider` 的**实时快照**，而不是
  /// `subscriptionEntriesProvider.value` 的缓存：添加面板刚 `insert` 完就立刻
  /// 调这里，而列表 provider 可能还没重建完，读缓存会拿到不含新行的旧列表，
  /// 于是「添加后自动更新一次」静默什么都不做。
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

  /// 从数据库直接取一条（含分组名），不走列表 provider 的缓存。
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

  /// 全部更新：逐条串行，进度按条数推进。
  ///
  /// 串行而不是并发：上游走同一条 WorkManager 队列，并发会让「正在更新 2/5」
  /// 的文案失去意义，也会让连续失败计数在竞争下失真。
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

  /// 跑一条，并把结果落库。异常一律转成失败结果，不能让 UI 卡在忙碌态。
  Future<SubscriptionFetchResult> _runOne(SubscriptionEntry entry) async {
    final repository = await ref.read(subscriptionRepositoryProvider.future);
    if (repository == null) {
      return const SubscriptionFetchResult.failed('订阅数据库不可用');
    }
    if (!entry.isRemote) {
      // 本地文件订阅没有可下载的地址，与上游
      // `SubscriptionUpdateOutcome.Failed("本地文件订阅无法更新")` 一致。
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
        // 解析 + 入库。条数用**真实写入条数**，不是词法行数。
        final imported = await _importContent(entry, result.content ?? '');
        if (imported == null) {
          // 库不可用：正文下载成功但落不了盘，必须报失败，不能显示「已更新」
          // 而库里一条规则都没有。
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

  /// 解析正文并写规则表；返回 null 表示规则库不可用。
  ///
  /// 先删该订阅的旧规则再导新的：订阅内容是「当前全量」，增量追加会让上一版
  /// 已经移除的域名永远留在库里。删除只动 `sub_<id>` 来源行，用户手加或别的
  /// 订阅引用的同一 pattern 不受影响。
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

/// 添加订阅的结果。失败时带上可读原因，面板据此给字段级提示。
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

/// 订阅写操作入口：添加 / 启停 / 重命名 / 删除。
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
        // 与上游 `addSubscription` 一致：新行先落 `importing`，下载完成后再改。
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

  /// 订阅总开关。
  ///
  /// 除了写 `subscription.enabled`，还要把该订阅的**来源行**一起置 0/1：
  /// 规则是否生效取决于「规则行启用 && 至少一个来源行启用」，只改订阅行会让
  /// 关掉的订阅继续拦截（规则行仍然是 1）。
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

  /// 删除订阅，并清掉它贡献的规则。
  ///
  /// 顺序是先删规则再删订阅行：反过来的话，若第二步失败就留下一批没有主的规则
  /// 继续拦截，用户会看到「订阅已删除但域名还是打不开」。
  Future<void> remove(int id) async {
    await (await _ref.read(ruleImporterProvider.future))
        ?.removeRulesBySource(subscriptionSourceTag(id));
    await (await _ref.read(subscriptionRepositoryProvider.future))
        ?.deleteById(id);
  }

  /// 新建分组并返回 id；同名已存在时返回已有 id。
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

// ---------------------------------------------------------------------------
// 镜像站模板（mirror_template 表）
// ---------------------------------------------------------------------------

/// 模板仓库：没有旧库时为 null，页面据此渲染空状态。
final mirrorTemplateRepositoryProvider =
    FutureProvider<MirrorTemplateRepository?>((ref) async {
      final db = await ref.watch(subscriptionDatabaseProvider.future);
      if (db == null) return null;
      return MirrorTemplateRepository(
        db,
        onChanged: () => ref.read(subscriptionRevisionProvider.notifier).bump(),
      );
    });

/// 全部镜像站模板（`addedAt DESC`，与旧版 `observeAll` 同序）。
final mirrorTemplatesProvider = FutureProvider<List<MirrorTemplateRecord>>((
  ref,
) async {
  ref.watch(subscriptionRevisionProvider);
  final repository = await ref.watch(mirrorTemplateRepositoryProvider.future);
  return repository == null
      ? const <MirrorTemplateRecord>[]
      : repository.all();
});

/// 镜像站模板的增删改。写成功后由仓库的 `onChanged` 自增 revision，
/// 列表 provider 自动重建。
class MirrorTemplateActions {
  MirrorTemplateActions(this._ref);

  final Ref _ref;

  Future<MirrorTemplateRepository?> _repository() =>
      _ref.read(mirrorTemplateRepositoryProvider.future);

  /// 返回新行 id；同名或空输入返回 null（调用方据此提示，不静默覆盖）。
  Future<int?> create({required String name, required String template}) async =>
      (await _repository())?.insert(name: name, template: template);

  /// 返回 false 表示同名冲突或输入非法。
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

