import 'package:diting/app/theme/layout.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/logs_routes.dart';
import 'package:diting/routes/observability_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 设置域与路由表的**静态**守门。
///
/// 这里刻意不挂 widget 树：它守的是「值对不对」（键名、默认值、路由形状、
/// 枚举基数），不是「渲染成什么样」。渲染由 `app_shell_test.dart` 与
/// `route_catalog_test.dart` 覆盖，两边不重复。
///
/// 之所以需要这一组，是因为本轮改动里最危险的一类错误**不会**被渲染测试抓到：
/// 键名写错一个字母，设置照样存、界面照样显示，只有升级/降级后才丢设置。
void main() {
  group('旧版设置键（第三轮新增）', () {
    late LegacyPrefsStore store;
    late LegacySettings settings;

    setUp(() {
      store = MemoryLegacyPrefsStore();
      settings = LegacySettings(store);
    });

    test('日志模式默认 all，且写在数据集容器里', () {
      expect(settings.dnsLogModeRaw, 'all');
      settings.setDnsLogModeRaw('blocked_and_errors');
      // 普通模式 dnsContainer 就是 dns_vpn_prefs。
      expect(store.read('dns_vpn_prefs', 'dns_log_mode'), 'blocked_and_errors');
      // 极速模式实例换容器、键名不变：这是 1.4.3 的数据集设计。
      final express = LegacySettings(
        store,
        dnsContainer: LegacySettings.expressContainer,
      );
      expect(express.dnsLogModeRaw, 'all', reason: '极速模式是另一份数据');
      express.setDnsLogModeRaw('off');
      expect(store.read('diting_express_prefs', 'dns_log_mode'), 'off');
    });

    test('日志保留天数默认 7 且被夹在 1–30', () {
      expect(settings.logRetentionDays, 7);
      settings.setLogRetentionDays(0);
      expect(settings.logRetentionDays, 1);
      settings.setLogRetentionDays(99);
      expect(settings.logRetentionDays, 30);
    });

    test('后台隐藏默认关闭', () {
      expect(settings.hideFromRecentsEnabled, isFalse);
      settings.setHideFromRecentsEnabled(true);
      expect(
        store.read('dns_vpn_prefs', 'hide_from_recents_enabled'),
        isTrue,
      );
    });

    test('绕过局域网默认开启，且能写', () {
      expect(settings.bypassLanEnabled, isTrue);
      settings.setBypassLanEnabled(false);
      expect(settings.bypassLanEnabled, isFalse);
    });

    test('语言默认跟随系统，只有两个合法值', () {
      expect(settings.appLanguageModeRaw, 'system');
      settings.setAppLanguageModeRaw('chinese');
      expect(settings.appLanguageModeRaw, 'chinese');
      // 旧版枚举里预留了英文但没有文案资源，界面上不存在——本轮不臆造。
      expect(AppLanguageMode.values.length, 2);
    });

    test('启动更新检查是「disable」语义，默认 true 表示默认不检查', () {
      expect(settings.disableStartupUpdateCheck, isTrue);
      settings.setDisableStartupUpdateCheck(false);
      expect(settings.disableStartupUpdateCheck, isFalse);
    });

    test('通知栏四键写在独立容器 notification_settings_prefs', () {
      expect(settings.notificationPersistent, isTrue);
      expect(settings.notificationSpeed, isFalse);
      settings.setNotificationPersistent(false);
      settings.setNotificationSpeed(true);
      settings.setNotificationTexts(running: '守护中', stopped: '已停止');
      // 容器写错的话，前台服务读不到——界面上完全看不出来。
      expect(store.read('notification_settings_prefs', 'persistent'), isFalse);
      expect(store.read('notification_settings_prefs', 'speed'), isTrue);
      expect(
        store.read('notification_settings_prefs', 'custom_running_text'),
        '守护中',
      );
      expect(store.read('dns_vpn_prefs', 'persistent'), isNull);
    });

    test('软件背景：启用、当前、历史清单三个键', () {
      expect(settings.customBackgroundEnabled, isFalse);
      expect(settings.customBackgroundUri, isNull);
      expect(settings.customBackgroundUris, isEmpty);

      settings.setCustomBackgroundEnabled(true);
      settings.setCustomBackgroundUri('content://picked/1');
      settings.setCustomBackgroundUris(['content://picked/1', 'content://2']);
      expect(settings.customBackgroundEnabled, isTrue);
      expect(settings.customBackgroundUri, 'content://picked/1');
      expect(settings.customBackgroundUris, [
        'content://picked/1',
        'content://2',
      ]);
    });

    test('历史清单遇到坏 JSON 时返回空表而不是抛异常', () {
      store.putString('dns_vpn_prefs', 'custom_background_uris', '{not json');
      expect(settings.customBackgroundUris, isEmpty);
    });

    test('首启须知默认未确认', () {
      expect(settings.initialAgreementAccepted, isFalse);
      settings.setInitialAgreementAccepted(true);
      expect(settings.initialAgreementAccepted, isTrue);
    });
  });

  group('设置态 provider（内存 store）', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('日志模式三档枚举与落盘值', () {
      expect(LegacyLogMode.values.length, 3);
      expect(
        [for (final mode in LegacyLogMode.values) mode.storageValue],
        ['all', 'blocked_and_errors', 'off'],
      );
      final c = container();
      c.read(logModeProvider.notifier).select(LegacyLogMode.off);
      expect(c.read(logModeProvider), LegacyLogMode.off);
    });

    test('IPv6 三档，未知值回退 auto', () {
      expect(LegacyIpv6Mode.fromStorageValue('nonsense'), LegacyIpv6Mode.auto);
      expect(
        [for (final mode in LegacyIpv6Mode.values) mode.storageValue],
        ['auto', 'disable', 'prefer'],
      );
    });

    test('未知日志模式回退 all', () {
      expect(
        LegacyLogMode.fromStorageValue('whatever'),
        LegacyLogMode.all,
      );
    });

    test('前后台行为三项可分别写', () {
      final c = container();
      final notifier = c.read(foregroundBackgroundProvider.notifier);
      notifier.setHideFromRecents(true);
      notifier.setBypassLan(false);
      notifier.setIpv6Mode(LegacyIpv6Mode.disable);
      final state = c.read(foregroundBackgroundProvider);
      expect(state.hideFromRecents, isTrue);
      expect(state.bypassLan, isFalse);
      expect(state.ipv6Mode, LegacyIpv6Mode.disable);
    });

    test('背景图：添加会同时更新当前与清单，移除当前会退到清单末尾', () {
      final c = container();
      final notifier = c.read(customBackgroundProvider.notifier);
      notifier.add('content://1');
      notifier.add('content://2');
      var state = c.read(customBackgroundProvider);
      expect(state.uris, ['content://1', 'content://2']);
      expect(state.currentUri, 'content://2');
      expect(state.enabled, isTrue, reason: '添加一张后应自动启用');

      notifier.remove('content://2');
      state = c.read(customBackgroundProvider);
      expect(state.uris, ['content://1']);
      expect(state.currentUri, 'content://1');
    });
  });

  group('底栏上限回到旧版的 4', () {
    test('maxDockDestinations 与 LegacySettings.bottomBarMaxCount 一致', () {
      // 两个常量分别服务 UI 与解析，漂移会让「能配 5 项但存回去只剩 4 项」。
      expect(maxDockDestinations, LegacySettings.bottomBarMaxCount);
      expect(maxDockDestinations, 4);
    });
  });

  group('路由表形状', () {
    test('外观子树的八条路径都是 /theme 下的独立页', () {
      const paths = [
        SystemPaths.dayNight,
        SystemPaths.colorStyle,
        SystemPaths.homeOpacity,
        SystemPaths.bottomBar,
        SystemPaths.homeSentence,
        SystemPaths.notification,
        SystemPaths.background,
      ];
      expect(paths.length, 7);
      for (final path in paths) {
        expect(path, startsWith('/theme/'));
      }
      // 字体是保留项，不挂在 /theme 下（旧版没有此项，避免污染旧版路径空间）。
      expect(SystemPaths.fontFamily, '/font-family');
      // 字号是「字体设置」下的二级页，同样不污染 /theme 命名空间。
      expect(SystemPaths.fontSize, '/font-size');
    });

    test('日志下钻四条都在 /logs 下', () {
      for (final path in [
        LogPaths.cache,
        LogPaths.race,
        LogPaths.bootstrap,
        LogPaths.subscriptionStats,
      ]) {
        expect(path, startsWith('/logs/'));
      }
    });

    test('配置域只剩四条资源路由', () {
      // FlClash 的 general/network/tun/dns/ntp/sniffer/override/filters/rules/
      // scripts/providers/advanced 十二条已删除：1.4.3 没有内核配置这个概念。
      for (final path in [
        ConfigPaths.customResources,
        ConfigPaths.iconSets,
        ConfigPaths.userAgents,
        ConfigPaths.onDemand,
      ]) {
        expect(path, startsWith('/config/'));
      }
    });

    test('观测域只剩连接 / 请求 / 资源三条', () {
      expect(ObservabilityPaths.connections, '/connections');
      expect(ObservabilityPaths.requests, '/requests');
      expect(ObservabilityPaths.resources, '/resources');
    });

    test('设置子页两条', () {
      expect(SystemPaths.foregroundBackground, '/settings/background');
      expect(SystemPaths.language, '/settings/language');
    });

    test('功能中心路由全部以 /hub 或跨域绝对路径开头', () {
      // 功能中心的卡片混用两种：本域页（/hub/…）与跨域页（/rules/…、/theme 等）。
      // 后者必须是绝对路径，否则会在当前 branch 下相对解析成不存在的地址。
      for (final path in [
        HubPaths.providerManagement,
        HubPaths.cache,
        HubPaths.logRetention,
        HubPaths.configTransfer,
      ]) {
        expect(path, startsWith('/hub/'));
      }
    });
  });
}
