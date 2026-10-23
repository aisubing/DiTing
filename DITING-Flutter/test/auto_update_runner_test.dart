import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/state/auto_update_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Due-time logic for shipping a release; a mistake silently never updates or re-downloads each
/// foreground
void main() {
  SubscriptionRecord record({
    int id = 1,
    int lastAttemptAt = 0,
    bool enabled = true,
    String sourceType = 'remote',
  }) => SubscriptionRecord(
    id: id,
    url: 'https://example.com/$id.yaml',
    name: '订阅 $id',
    sourceType: SubscriptionSourceType.fromStorage(sourceType),
    kind: SubscriptionKind.normalize('normal'),
    enabled: enabled,
    ruleCount: 0,
    lastUpdated: 0,
    addedAt: 0,
    importState: SubscriptionImportState.ready,
    lastAttemptAt: lastAttemptAt,
    consecutiveFailureCount: 0,
    mirrorFallback: true,
  );

  const hour = 3600 * 1000;

  group('isDue', () {
    test('从未尝试过 → 到期', () {
      expect(AutoUpdateRunner.isDue(record(), 24, 1000), isTrue);
    });

    test('未满间隔 → 未到期', () {
      final now = 100 * hour;
      expect(
        AutoUpdateRunner.isDue(record(lastAttemptAt: now - 23 * hour), 24, now),
        isFalse,
      );
    });

    test('刚好满间隔 → 到期（边界含等于）', () {
      final now = 100 * hour;
      expect(
        AutoUpdateRunner.isDue(record(lastAttemptAt: now - 24 * hour), 24, now),
        isTrue,
      );
    });

    test('超过间隔 → 到期', () {
      final now = 100 * hour;
      expect(
        AutoUpdateRunner.isDue(record(lastAttemptAt: now - 25 * hour), 24, now),
        isTrue,
      );
    });

    test('间隔按设置变化，不是写死 24 小时', () {
      final now = 100 * hour;
      final target = record(lastAttemptAt: now - 7 * hour);
      expect(AutoUpdateRunner.isDue(target, 6, now), isTrue);
      expect(AutoUpdateRunner.isDue(target, 12, now), isFalse);
    });
  });

  group('nextDueAt', () {
    test('空列表 → null', () {
      expect(AutoUpdateRunner.nextDueAt(const [], 24, 1000), isNull);
    });

    test('取最早到期的那条', () {
      final now = 100 * hour;
      final records = [
        record(id: 1, lastAttemptAt: now - 2 * hour),
        record(id: 2, lastAttemptAt: now - 20 * hour),
        record(id: 3, lastAttemptAt: now - 10 * hour),
      ];
      expect(AutoUpdateRunner.nextDueAt(records, 24, now), now + 4 * hour);
    });

    test('从未尝试的订阅立即到期（返回 now）', () {
      final now = 100 * hour;
      final records = [
        record(id: 1, lastAttemptAt: now - 1 * hour),
        record(id: 2),
      ];
      expect(AutoUpdateRunner.nextDueAt(records, 24, now), now);
    });
  });

  test('AutoUpdateSkip 的每种原因都有可读文案', () {
    for (final skip in AutoUpdateSkip.values) {
      expect(skip.label, isNotEmpty, reason: '$skip 缺少文案');
    }
  });

  test('AutoUpdateRun.didRun 只在没有跳过原因时为真', () {
    expect(const AutoUpdateRun().didRun, isTrue);
    expect(const AutoUpdateRun(summary: '1 个已更新').didRun, isTrue);
    expect(
      const AutoUpdateRun(skip: AutoUpdateSkip.disabled).didRun,
      isFalse,
    );
  });
}
