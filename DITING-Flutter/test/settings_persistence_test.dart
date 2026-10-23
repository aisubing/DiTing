import 'package:diting/app/theme/layout.dart';
import 'package:diting/data/dashboard_models.dart';
import 'package:diting/data/http/request_user_agent.dart';
import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/config/on_demand_capabilities.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settings that used to reset on restart: appearance, dashboard order, on-demand matching and the
/// user agent every client sends.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryLegacyPrefsStore store;

  setUp(() => store = MemoryLegacyPrefsStore());

  ProviderContainer container() {
    final instance = ProviderContainer(
      overrides: [legacyPrefsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(instance.dispose);
    return instance;
  }

  group('外观设置重新打开后仍在', () {
    test('纯黑主题', () {
      container().read(pureBlackProvider.notifier).toggle(true);
      expect(store.read('dns_vpn_prefs', 'pure_black_theme'), isTrue);
      expect(container().read(pureBlackProvider), isTrue);
    });

    test('字号按布局上限钳位后再落盘', () {
      final notifier = container().read(textScaleProvider.notifier);
      notifier.set(3);
      expect(store.read('dns_vpn_prefs', 'app_text_scale'), maxTextScale);
      expect(container().read(textScaleProvider), maxTextScale);

      notifier.set(0.1);
      expect(container().read(textScaleProvider), minTextScale);
    });

    test('字体族空值表示跟随系统', () {
      final notifier = container().read(selectedFontFamilyProvider.notifier);
      notifier.select('Noto Sans SC');
      expect(store.read('dns_vpn_prefs', 'app_font_family'), 'Noto Sans SC');
      expect(container().read(selectedFontFamilyProvider), 'Noto Sans SC');

      notifier.select(null);
      expect(container().read(selectedFontFamilyProvider), isNull);
    });
  });

  group('看板卡片顺序重新打开后仍在', () {
    test('没有落盘时用默认布局', () {
      expect(container().read(dashboardWidgetsProvider), defaultDashboardWidgets);
    });

    test('增删与移动都会写回', () {
      final notifier = container().read(dashboardWidgetsProvider.notifier);
      notifier.remove(DashboardWidget.status);
      expect(
        container().read(dashboardWidgetsProvider),
        isNot(contains(DashboardWidget.status)),
      );
      expect(store.read('dns_vpn_prefs', 'dashboard_widget_order'), isNotNull);

      notifier.add(DashboardWidget.status);
      notifier.move(0, 1);
      final reopened = container().read(dashboardWidgetsProvider);
      expect(reopened.first, isNot(DashboardWidget.status));
      expect(reopened, contains(DashboardWidget.status));
    });

    test('清空看板不会回落到默认布局', () {
      final notifier = container().read(dashboardWidgetsProvider.notifier);
      for (final widget in container().read(dashboardWidgetsProvider)) {
        notifier.remove(widget);
      }
      expect(container().read(dashboardWidgetsProvider), isEmpty);
    });

    test('改名后的未知卡片只丢自己', () {
      store.putString(
        'dns_vpn_prefs',
        'dashboard_widget_order',
        '["status","no_such_card","networkSpeed"]',
      );
      expect(container().read(dashboardWidgetsProvider), [
        DashboardWidget.status,
        DashboardWidget.networkSpeed,
      ]);
    });

    test('坏 JSON 回落到默认布局', () {
      store.putString(
        'dns_vpn_prefs',
        'dashboard_widget_order',
        '{not json',
      );
      expect(container().read(dashboardWidgetsProvider), defaultDashboardWidgets);
    });
  });

  group('按需连接判定用的是真实 SSID', () {
    const rules = [MockSsidRule(ssid: 'Home-5G', cellular: false, delayMs: 800)];

    test('开关关闭时不看白名单', () {
      expect(
        decideSsid(
          enabled: false,
          rules: rules,
          currentSsid: 'Home-5G',
        ).state,
        SsidMatchState.disabled,
      );
    });

    test('读不到 SSID 与未连 Wi-Fi 分开报告', () {
      expect(
        decideSsid(enabled: true, rules: rules, currentSsid: null).state,
        SsidMatchState.unknown,
      );
      expect(
        decideSsid(enabled: true, rules: rules, currentSsid: '').state,
        SsidMatchState.noWifi,
      );
    });

    test('命中时带回规则，未命中不启动', () {
      final matched = decideSsid(
        enabled: true,
        rules: rules,
        currentSsid: 'Home-5G',
      );
      expect(matched.state, SsidMatchState.matched);
      expect(matched.rule?.delayMs, 800);

      expect(
        decideSsid(
          enabled: true,
          rules: rules,
          currentSsid: 'home-5g',
        ).state,
        SsidMatchState.unmatched,
      );
    });

    test('页面 provider 读的是已落盘的白名单', () {
      final notifier = container().read(configResourcesProvider.notifier);
      notifier.setOnDemand(true);
      notifier.putSsid(
        null,
        const MockSsidRule(ssid: 'Cafe', cellular: false, wifi: true),
      );
      final decision = container().read(onDemandDecisionProvider);
      // No platform channel in tests, so the SSID is unknown rather than fabricated.
      expect(decision.state, SsidMatchState.unknown);
    });
  });

  group('User-Agent 是所有请求共用的真实值', () {
    test('没选时用兜底值', () {
      expect(container().read(requestUserAgentProvider), appFallbackUserAgent);
      expect(resolveRequestUserAgent('  '), appFallbackUserAgent);
    });

    test('选中后 provider 跟着变', () {
      final notifier = container().read(configResourcesProvider.notifier);
      notifier.addUserAgent('MyAgent/1.0');
      notifier.selectUserAgent('MyAgent/1.0');
      expect(container().read(requestUserAgentProvider), 'MyAgent/1.0');

      notifier.selectUserAgent(null);
      expect(container().read(requestUserAgentProvider), appFallbackUserAgent);
    });
  });
}
