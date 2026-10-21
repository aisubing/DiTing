import 'package:diting/data/dashboard_models.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/data/log_dashboard_models.dart';
import 'package:diting/data/log_dashboard_rows.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// 概览块的**纯函数**与**落盘键**守卫（不碰数据库）。
///
/// 与 `real_data_wiring_test.dart` 分工：那边用真 schema 跑聚合 SQL，这边钉那些
/// 一旦被「简化」就会悄悄改变口径的判定，以及自动更新的两个 prefs 键。
///
/// 这些判定都在旧版里有明确原文（`DashboardLogLabels.kt` /
/// `SubscriptionAutoUpdateSettings.kt`），改动等于改产品语义，必须有人先看见。
void main() {
  group('行映射：DNS', () {
    test('连接行按 queryType / 前缀 / message 三种线索识别', () {
      expect(isConnectionLog(queryType: 0, queryName: 'anything'), isTrue);
      expect(
        isConnectionLog(queryType: 1, queryName: 'TCP 1.1.1.1:443'),
        isTrue,
      );
      expect(
        isConnectionLog(queryType: 1, queryName: 'UDP 1.1.1.1:53'),
        isTrue,
      );
      expect(
        isConnectionLog(
          queryType: 1,
          queryName: 'example.com',
          message: 'blocked_by=connection',
        ),
        isTrue,
      );
      expect(isConnectionLog(queryType: 1, queryName: 'example.com'), isFalse);
    });

    test('结果文案：连接行的 PASSED 是「旁路」，域名查询是「通过」', () {
      expect(dnsResultLabelOf('PASSED', isConnection: true), '旁路');
      expect(dnsResultLabelOf('PASSED', isConnection: false), '通过');
      expect(dnsResultLabelOf('REWRITTEN', isConnection: false), '覆写');
      expect(dnsResultLabelOf('BLOCKED', isConnection: false), '过滤');
      expect(dnsResultLabelOf('ERROR', isConnection: false), '失败');
      // 未知结果原样显示（旧版 `else => result`）。这条兜底只属于**展示层**：
      // 搬进 `dailyStats` 的分档 switch 会把新结果值算进「通过」（README §7.2）。
      expect(
        dnsResultLabelOf('SOMETHING_NEW', isConnection: false),
        'SOMETHING_NEW',
      );
    });

    test('结果档位：覆写归通过、连接归旁路、缓存单列', () {
      expect(
        dnsRowStatusOf('PASSED', isConnection: false, cached: false),
        LogRowStatus.passed,
      );
      expect(
        dnsRowStatusOf('PASSED', isConnection: false, cached: true),
        LogRowStatus.cached,
      );
      expect(
        dnsRowStatusOf('REWRITTEN', isConnection: false, cached: false),
        LogRowStatus.passed,
      );
      expect(
        dnsRowStatusOf('BLOCKED', isConnection: false, cached: false),
        LogRowStatus.filtered,
      );
      expect(
        dnsRowStatusOf('ERROR', isConnection: false, cached: false),
        LogRowStatus.failed,
      );
      // 连接行即使 result=PASSED 也算旁路，不能算进「通过」。
      expect(
        dnsRowStatusOf('PASSED', isConnection: true, cached: false),
        LogRowStatus.bypassed,
      );
    });

    test('副标题与来源列', () {
      expect(
        dnsRowMetaOf(
          queryType: 1,
          queryName: 'example.com',
          cached: true,
          message: 'elapsed=12ms',
        ),
        'A · 命中缓存 · elapsed=12ms',
      );
      expect(
        dnsRowMetaOf(queryType: 28, queryName: 'v6.example', cached: false),
        'AAAA',
      );
      expect(
        dnsRowMetaOf(
          queryType: 0,
          queryName: 'TCP 1.1.1.1:443',
          cached: false,
          packageName: 'com.example.app',
        ),
        'TCP 直连 · com.example.app',
      );
      expect(
        dnsRowSourceOf(queryType: 1, queryName: 'example.com'),
        'DNS',
      );
      expect(
        dnsRowSourceOf(queryType: 0, queryName: 'TCP 1.1.1.1:443'),
        'TCP',
      );
      expect(
        dnsRowSourceOf(queryType: 0, queryName: 'UDP 1.1.1.1:53'),
        'UDP',
      );
    });

    test('时间戳缺失给 --:--:--，不拿当前时钟冒充', () {
      expect(dashboardClockOf(0), '--:--:--');
      expect(dashboardClockOf(-1), '--:--:--');
      expect(
        dashboardClockOf(DateTime(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch),
        '03:04:05',
      );
    });
  });

  group('行映射：HTTPS', () {
    test('四档映射与「仅拦截与错误」筛选一致', () {
      expect(httpRowStatusOf('allowed'), LogRowStatus.passed);
      // 覆写成功的 HTTPS 请求确实被正常放行，旧版也算「通过」。
      expect(httpRowStatusOf('rewritten'), LogRowStatus.passed);
      expect(httpRowStatusOf('blocked'), LogRowStatus.filtered);
      expect(httpRowStatusOf('invalid'), LogRowStatus.filtered);
      for (final outcome in [
        'passthrough',
        'bypassed',
        'unsupported_protocol',
        'resource_bypass',
      ]) {
        expect(httpRowStatusOf(outcome), LogRowStatus.bypassed);
      }
      expect(httpRowStatusOf('whatever'), LogRowStatus.failed);

      // 筛选只看「是不是通过」：旁路不算通过，过滤模式下要保留。
      expect(httpOutcomeIsPassed('allowed'), isTrue);
      expect(httpOutcomeIsPassed('passthrough'), isFalse);
      expect(httpOutcomeIsPassed('blocked'), isFalse);
    });

    test('authority 为空时显示「未取得 authority」，不渲染空行', () {
      final row = logRecentRequestOfHttp(
        HttpRequestRecord(
          id: 1,
          timestamp: DateTime(2026, 10, 20, 13, 41).millisecondsSinceEpoch,
          packageName: 'com.example.ads',
          protocol: 'http/1.1',
          outcome: 'blocked',
          matchedRule: 'RULE-SET,广告拦截',
        ),
      );
      expect(row.name, '未取得 authority');
      expect(row.source, 'HTTPS');
      expect(row.resultLabel, '过滤');
      expect(row.meta, 'http/1.1 · com.example.ads · RULE-SET,广告拦截');
    });
  });

  group('速率序列（SpeedSeries）', () {
    test('数据源缺失与「采样到 0」互不混淆', () {
      const series = SpeedSeries(
        samples: [SpeedSample(up: 0, down: 0)],
        revision: 3,
        source: SpeedSource.noNativeChannel,
      );
      expect(series.unsupported, isTrue);
      expect(series.last.isZero, isTrue);
      expect(series.hasTraffic, isFalse);
    });

    test('有非零采样时 hasTraffic 为真', () {
      const series = SpeedSeries(
        samples: [SpeedSample(up: 0, down: 0), SpeedSample(up: 12, down: 34)],
        revision: 2,
      );
      expect(series.unsupported, isFalse);
      expect(series.hasTraffic, isTrue);
      expect(series.downValues(), [0, 34]);
      expect(series.upValues(), [0, 12]);
    });
  });

  group('订阅自动更新设置（数据集 prefs）', () {
    test('默认关闭、24 小时，越界值回落到默认', () {
      final store = MemoryLegacyPrefsStore();
      final settings = LegacySettings(store);
      expect(settings.subscriptionAutoUpdateEnabled, isFalse);
      expect(
        settings.subscriptionAutoUpdateIntervalHours,
        LegacySettings.defaultSubscriptionAutoUpdateIntervalHours,
      );

      // 旧版把非法值当默认值读（不是 clamp 到边界）。
      store.putInt(
        'dns_vpn_prefs',
        LegacySettings.subscriptionAutoUpdateIntervalKey,
        500,
      );
      expect(
        LegacySettings(store).subscriptionAutoUpdateIntervalHours,
        LegacySettings.defaultSubscriptionAutoUpdateIntervalHours,
      );
    });

    test('写入口 clamp 到 1–168，且落在数据集容器里', () {
      final store = MemoryLegacyPrefsStore();
      final settings = LegacySettings(store);
      settings.setSubscriptionAutoUpdateIntervalHours(0);
      expect(
        store.read(
          'dns_vpn_prefs',
          LegacySettings.subscriptionAutoUpdateIntervalKey,
        ),
        1,
      );
      settings.setSubscriptionAutoUpdateIntervalHours(9999);
      expect(
        store.read(
          'dns_vpn_prefs',
          LegacySettings.subscriptionAutoUpdateIntervalKey,
        ),
        168,
      );
      settings.setSubscriptionAutoUpdateEnabled(true);
      expect(
        store.read(
          'dns_vpn_prefs',
          LegacySettings.subscriptionAutoUpdateEnabledKey,
        ),
        isTrue,
      );
      // 极速模式读的是自己的容器，不能被普通模式的写入带过去。
      expect(settings.forExpress().subscriptionAutoUpdateEnabled, isFalse);
    });
  });
}
