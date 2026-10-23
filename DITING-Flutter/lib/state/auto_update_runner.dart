/// Foreground catch-up for 1.4.3 `executePeriodic`: runs on start and resume, as there is no
/// WorkManager.
library;

import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/state/auto_update_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AutoUpdateSkip {
  disabled('自动更新已关闭'),

  /// Legacy DB missing (fresh install).
  noDatabase('订阅数据库不可用'),

  /// No eligible subscriptions (remote, enabled, group allowed).
  noSubscriptions('没有可自动更新的订阅'),

  notDue('未到更新时间'),

  /// A manual update is running; yield (1.4.3 `BlockedByManualOperation`).
  busy('正在手动更新，本轮跳过');

  const AutoUpdateSkip(this.label);

  final String label;
}

/// Result of one check; a null [skip] means a real run happened.
class AutoUpdateRun {
  const AutoUpdateRun({this.skip, this.summary, this.ranCount = 0, this.dueAt});

  /// Why the run was skipped; null when it executed.
  final AutoUpdateSkip? skip;

  /// Run summary, e.g. "3 updated, 1 unchanged".
  final String? summary;

  final int ranCount;

  /// Next due time (epoch ms) for the "next update" label.
  final int? dueAt;

  bool get didRun => skip == null;
}

class AutoUpdateRunner {
  AutoUpdateRunner(this._ref);

  final Ref _ref;

  /// Due from `lastAttemptAt`, not `lastUpdated`: a 304-only row would otherwise look due forever.
  static bool isDue(SubscriptionRecord record, int intervalHours, int nowMs) {
    final last = record.lastAttemptAt;
    if (last <= 0) {
      return true;
    }
    final intervalMs = intervalHours * 3600 * 1000;
    return nowMs - last >= intervalMs;
  }

  /// Next due time (epoch ms); null when no subscription is eligible.
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

  /// Never throws: lifecycle callbacks drive it, so an exception would red-screen on every resume.
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
    // Mutually exclusive with manual updates: yield now, catch up next round.
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

class AutoUpdateLastRunNotifier extends Notifier<AutoUpdateRun?> {
  @override
  AutoUpdateRun? build() => null;

  void record(AutoUpdateRun run) => state = run;
}

final autoUpdateLastRunProvider =
    NotifierProvider<AutoUpdateLastRunNotifier, AutoUpdateRun?>(
      AutoUpdateLastRunNotifier.new,
    );

/// Eligible subscriptions (remote, enabled, group allowed) for the "next update" label.
final autoUpdatableSubscriptionsProvider =
    FutureProvider<List<SubscriptionRecord>>((ref) async {
      ref.watch(subscriptionRevisionProvider);
      final repository = await ref.watch(subscriptionRepositoryProvider.future);
      if (repository == null) {
        return const <SubscriptionRecord>[];
      }
      return repository.allAutoUpdatableRemote();
    });
