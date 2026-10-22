/// 订阅自动更新的**执行**侧（对应旧版
/// `SubscriptionAutoUpdateEngine.executePeriodic`）。
///
/// ## 为什么需要这个文件
/// `auto_update_providers.dart` 只负责把「总开关 + 间隔」落进数据集 prefs，分组
/// 开关落进 `subscription_group.autoUpdateEnabled`。上一轮到此为止，于是页面上
/// 打开开关之后**什么都不会发生**——设置是真的，执行是空的。
///
/// 旧版靠 WorkManager 的周期任务执行。本仓没有 WorkManager（原生侧未移植
/// `SubscriptionAutoUpdateScheduler`），因此这里做的是**前台补跑**：
///
/// - 应用启动、以及每次回到前台时检查一次是否到期；
/// - 「到期」的判据是订阅表里的真实 `lastAttemptAt`（上次尝试时间，成功 / 304 /
///   失败都会写）与设置的间隔小时数比较——不额外维护一个「上次运行」的本地
///   变量，避免两条真相打架；
/// - 到期才跑，跑的时候复用 [SubscriptionUpdateNotifier.updateAll]：真发包、
///   真解析、真入库，与用户手点「全部更新」是同一条链路。
///
/// 应用被完全关闭期间不会执行——这是与旧版的真实差距，页面文案必须照实说，
/// 不能承诺「会在后台按此频率更新」。
library;

import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/state/auto_update_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次「是否执行 / 执行结果」的判定。
enum AutoUpdateSkip {
  /// 总开关关闭。
  disabled('自动更新已关闭'),

  /// 旧库不存在（全新安装）。
  noDatabase('订阅数据库不可用'),

  /// 没有符合条件的订阅（远程 + 启用 + 分组放行）。
  noSubscriptions('没有可自动更新的订阅'),

  /// 全部订阅都还没到间隔时间。
  notDue('未到更新时间'),

  /// 用户正在手动更新，本轮让路（旧版 `BlockedByManualOperation`）。
  busy('正在手动更新，本轮跳过');

  const AutoUpdateSkip(this.label);

  final String label;
}

/// 一次检查的结果。[skip] 为 null 表示真的跑了一轮。
class AutoUpdateRun {
  const AutoUpdateRun({this.skip, this.summary, this.ranCount = 0, this.dueAt});

  /// 跳过原因；null 表示执行过。
  final AutoUpdateSkip? skip;

  /// 执行摘要（如「3 个已更新，1 个未变化」）。
  final String? summary;

  /// 本轮实际更新的订阅数。
  final int ranCount;

  /// 最近一个到期时刻（epoch ms）；用于「下次更新时间」的展示。
  final int? dueAt;

  bool get didRun => skip == null;
}

/// 自动更新的检查与执行入口。
class AutoUpdateRunner {
  AutoUpdateRunner(this._ref);

  final Ref _ref;

  /// 到期判据：`lastAttemptAt` 为 0（从未尝试）或距今已超过间隔。
  ///
  /// 用 `lastAttemptAt` 而不是 `lastUpdated`：一个一直 304 的订阅 `lastUpdated`
  /// 很久不变，用它会永远判定「到期」而每次都发一轮请求；失败过的订阅
  /// `lastUpdated` 也不动，会让它一直重试。旧版的周期任务同样按「上次尝试」
  /// 起算，只是计时器由 WorkManager 持有。
  static bool isDue(SubscriptionRecord record, int intervalHours, int nowMs) {
    final last = record.lastAttemptAt;
    if (last <= 0) {
      return true;
    }
    final intervalMs = intervalHours * 3600 * 1000;
    return nowMs - last >= intervalMs;
  }

  /// 下一个到期时刻（epoch ms）。没有可更新订阅时返回 null。
  static int? nextDueAt(
    List<SubscriptionRecord> records,
    int intervalHours,
    int nowMs,
  ) {
    if (records.isEmpty) {
      return null;
    }
    final intervalMs = intervalHours * 3600 * 1000;
    var earliest = nowMs + intervalMs;
    for (final record in records) {
      final due = record.lastAttemptAt <= 0
          ? nowMs
          : record.lastAttemptAt + intervalMs;
      if (due < earliest) {
        earliest = due;
      }
    }
    return earliest;
  }

  /// 检查并（在到期时）执行一轮自动更新。
  ///
  /// 任何一步失败都返回跳过或空摘要，绝不抛出：它由生命周期回调驱动，抛异常
  /// 会变成「一回到前台就红屏」。
  Future<AutoUpdateRun> runIfDue() async {
    final settings = _ref.read(autoUpdateSettingsProvider);
    if (!settings.enabled) {
      return const AutoUpdateRun(skip: AutoUpdateSkip.disabled);
    }
    final repository = await _ref.read(subscriptionRepositoryProvider.future);
    if (repository == null) {
      return const AutoUpdateRun(skip: AutoUpdateSkip.noDatabase);
    }
    final records = await repository.allAutoUpdatableRemote();
    if (records.isEmpty) {
      return const AutoUpdateRun(skip: AutoUpdateSkip.noSubscriptions);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = [
      for (final record in records)
        if (isDue(record, settings.intervalHours, now)) record,
    ];
    if (due.isEmpty) {
      return AutoUpdateRun(
        skip: AutoUpdateSkip.notDue,
        dueAt: nextDueAt(records, settings.intervalHours, now),
      );
    }
    // 与用户手动更新互斥：正在跑的时候让路，下一轮再补。
    if (_ref.read(subscriptionUpdateProvider).isBusy) {
      return const AutoUpdateRun(skip: AutoUpdateSkip.busy);
    }
    final groups = await repository.groups();
    final names = {for (final group in groups) group.id: group.name};
    final entries = [
      for (final record in due)
        SubscriptionEntry(record: record, groupName: names[record.groupId]),
    ];
    await _ref.read(subscriptionUpdateProvider.notifier).updateAll(entries);
    final message = _ref.read(subscriptionUpdateProvider).lastMessage;
    return AutoUpdateRun(
      summary: message ?? '已检查 ${entries.length} 个订阅',
      ranCount: entries.length,
      dueAt: nextDueAt(records, settings.intervalHours, now),
    );
  }
}

final autoUpdateRunnerProvider = Provider<AutoUpdateRunner>(
  AutoUpdateRunner.new,
);

/// 最近一次**真实执行**的自动更新结果；跳过（未到期 / 关闭）不写这里。
///
/// 页面据此显示「上次自动更新」；`null` 表示本次会话还没跑过。
class AutoUpdateLastRunNotifier extends Notifier<AutoUpdateRun?> {
  @override
  AutoUpdateRun? build() => null;

  void record(AutoUpdateRun run) => state = run;
}

final autoUpdateLastRunProvider =
    NotifierProvider<AutoUpdateLastRunNotifier, AutoUpdateRun?>(
      AutoUpdateLastRunNotifier.new,
    );

/// 可自动更新的订阅（远程 + 启用 + 分组放行），用于展示「下次更新时间」。
final autoUpdatableSubscriptionsProvider =
    FutureProvider<List<SubscriptionRecord>>((ref) async {
      ref.watch(subscriptionRevisionProvider);
      final repository = await ref.watch(subscriptionRepositoryProvider.future);
      if (repository == null) {
        return const <SubscriptionRecord>[];
      }
      return repository.allAutoUpdatableRemote();
    });
