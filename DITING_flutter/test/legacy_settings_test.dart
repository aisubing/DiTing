import 'package:diting/app/theme/colors.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1.4.3 的落盘契约：容器、键名、默认值与旧值语义都不能漂移。
void main() {
  MemoryLegacyPrefsStore legacyStore() => MemoryLegacyPrefsStore({
    'dns_vpn_prefs': {
      'app_theme_mode': 'dark',
      'theme_color_style': 'indigo',
      'home_component_opacity': 0.8,
      'home_poem_opacity': 0.4,
      'home_sentence_running': '运行句子',
      'home_sentence_stopped': '停止句子',
      'bottom_bar_destinations': '["home","network_tools","settings","network_tools","bogus"]',
      'bottom_bar_haptic_enabled': false,
      'dns_resolution_mode': 'parallel_race',
    },
    'diting_settings': {
      'app_work_mode': 'dns',
      'work_mode_initial_selected': true,
    },
    'diting_dns_mode_prefs': {'local_listen_port': 2053},
  });

  group('LegacySettings 读取', () {
    test('外观键按旧版键名与值域解析', () {
      final settings = LegacySettings(legacyStore());

      expect(settings.themeModeRaw, 'dark');
      expect(settings.paletteRaw, 'indigo');
      expect(settings.componentOpacity, 0.8);
      // 单项未设置时回退到 home_component_opacity。
      expect(settings.homeOpacity('home_power_button_opacity'), 0.8);
      expect(settings.homeOpacity('home_poem_opacity'), 0.4);
      expect(settings.homeSentences.running, '运行句子');
      expect(settings.homeSentences.stopped, '停止句子');
      expect(settings.hapticEnabled, isFalse);
    });

    test('底栏数组丢掉未知 id 与重复项', () {
      final settings = LegacySettings(legacyStore());
      expect(settings.bottomBarIds, ['home', 'network_tools', 'settings']);
    });

    test('工作模式 / 解析模式 / 端口读取旧容器', () {
      final settings = LegacySettings(legacyStore());
      expect(settings.workModeRaw, 'dns');
      expect(settings.workModeSelected, isTrue);
      expect(settings.resolutionModeRaw, 'parallel_race');
      expect(settings.serverPort, 2053);
    });

    test('空存储返回 1.4.3 的默认值', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      expect(settings.themeModeRaw, isNull);
      expect(settings.paletteRaw, isNull);
      expect(settings.componentOpacity, 1);
      expect(settings.homeSentences.running, LegacySettings.defaultRunningSentence);
      expect(settings.homeSentences.stopped, LegacySettings.defaultStoppedSentence);
      expect(settings.bottomBarIds, LegacySettings.defaultBottomBarIds);
      expect(settings.hapticEnabled, isTrue);
      expect(settings.workModeRaw, 'normal');
      expect(settings.workModeSelected, isFalse);
      expect(settings.resolutionModeRaw, 'single');
      // 旧版已把默认端口从 5353/5354 迁到 1053。
      expect(settings.serverPort, 1053);
    });

    test('显式值越界时按旧版钳位', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {'home_poem_opacity': 0.01},
        'diting_dns_mode_prefs': {'local_listen_port': 80},
      }));
      expect(settings.homeOpacity('home_poem_opacity'), 0.1);
      expect(settings.serverPort, 1024);
    });
  });

  group('LegacySettings 写入', () {
    test('写回同名容器与键名', () {
      final store = MemoryLegacyPrefsStore();
      final settings = LegacySettings(store);

      settings.setThemeModeRaw('light');
      settings.setPaletteRaw('indigo');
      settings.setHomeOpacity('home_poem_opacity', 0.3);
      settings.setHomeSentences(running: 'a', stopped: 'b');
      settings.setBottomBarIds([
        'home',
        'feature_hub',
        'feature_hub',
        'settings',
        'network_tools',
        'app_traffic_stats',
      ]);
      settings.setHapticEnabled(false);
      settings.setWorkModeRaw('express');
      settings.setWorkModeSelected(true);
      settings.setResolutionModeRaw('smart_prediction');
      settings.setServerPort(1053);

      expect(store.read('dns_vpn_prefs', 'app_theme_mode'), 'light');
      expect(store.read('dns_vpn_prefs', 'theme_color_style'), 'indigo');
      expect(store.read('dns_vpn_prefs', 'home_poem_opacity'), 0.3);
      expect(store.read('dns_vpn_prefs', 'home_sentence_running'), 'a');
      expect(store.read('dns_vpn_prefs', 'bottom_bar_destinations'),
          '["home","feature_hub","settings","network_tools"]');
      expect(store.read('dns_vpn_prefs', 'bottom_bar_haptic_enabled'), false);
      expect(store.read('diting_settings', 'app_work_mode'), 'express');
      expect(store.read('diting_settings', 'work_mode_initial_selected'), true);
      expect(store.read('dns_vpn_prefs', 'dns_resolution_mode'), 'smart_prediction');
      expect(store.read('diting_dns_mode_prefs', 'local_listen_port'), 1053);
    });

    test('清空工作模式会移除两个键而不是写 false', () {
      final store = MemoryLegacyPrefsStore({
        'diting_settings': {
          'app_work_mode': 'dns',
          'work_mode_initial_selected': true,
        },
      });
      LegacySettings(store).clearWorkModeSelection();
      expect(store.read('diting_settings', 'app_work_mode'), isNull);
      expect(store.read('diting_settings', 'work_mode_initial_selected'), isNull);
    });
  });

  group('枚举落盘值', () {
    test('GOLD 色板仍存历史值 indigo', () {
      expect(AppPalette.gold.storageValue, 'indigo');
      expect(AppPalette.fromStorageValue('indigo'), AppPalette.gold);
      expect(AppPalette.fromStorageValue('nope'), AppPalette.system);
    });

    test('服务器模式仍存 dns', () {
      expect(AppWorkMode.server.storageValue, 'dns');
      expect(AppWorkMode.fromStorageValue('dns'), AppWorkMode.server);
      expect(AppWorkMode.fromStorageValue(null), AppWorkMode.normal);
    });

    test('解析模式落盘值与枚举名不同名', () {
      expect(ResolutionMode.smart.storageValue, 'smart_prediction');
      expect(ResolutionMode.parallel.storageValue, 'parallel_race');
      expect(ResolutionMode.fromStorageValue('parallel_race'),
          ResolutionMode.parallel);
    });

    test('底栏 id 与旧版一致', () {
      expect(BottomBarDestination.appTraffic.storageValue, 'app_traffic_stats');
      expect(BottomBarDestination.networkTools.storageValue, 'network_tools');
      expect(
        {for (final destination in BottomBarDestination.values) destination.storageValue},
        LegacySettings.bottomBarIdValues,
      );
    });
  });

  group('Provider 接入旧值', () {
    ProviderContainer containerWith(LegacyPrefsStore store) {
      final container = ProviderContainer(
        overrides: [legacyPrefsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('启动即读到旧设置', () {
      final container = containerWith(legacyStore());

      expect(container.read(themeModeProvider), AppThemeMode.dark);
      expect(container.read(paletteProvider), AppPalette.gold);
      expect(container.read(hapticProvider), isFalse);
      expect(container.read(homeOpacityProvider)[HomeLayer.poem], 0.4);
      expect(container.read(homeSentenceProvider).running, '运行句子');
      expect(container.read(bottomBarProvider), [
        BottomBarDestination.home,
        BottomBarDestination.networkTools,
        BottomBarDestination.settings,
      ]);
      expect(container.read(workModeProvider), AppWorkMode.server);
      expect(container.read(resolutionModeProvider), ResolutionMode.parallel);
      expect(container.read(serverPortProvider), 2053);
      expect(container.read(workModeSelectedProvider), isTrue);
    });

    test('用户修改后立刻写回旧键', () {
      final store = MemoryLegacyPrefsStore();
      final container = containerWith(store);

      container.read(themeModeProvider.notifier).select(AppThemeMode.light);
      container.read(paletteProvider.notifier).select(AppPalette.gold);
      container.read(hapticProvider.notifier).toggle(false);
      container
          .read(homeOpacityProvider.notifier)
          .set(HomeLayer.powerButton, 0.6);
      container
          .read(homeSentenceProvider.notifier)
          .set(running: '新句子', stopped: '旧停止');
      container.read(workModeProvider.notifier).select(AppWorkMode.express);
      container
          .read(resolutionModeProvider.notifier)
          .select(ResolutionMode.primaryBackup);
      container.read(serverPortProvider.notifier).set(1053);

      expect(store.read('dns_vpn_prefs', 'app_theme_mode'), 'light');
      expect(store.read('dns_vpn_prefs', 'theme_color_style'), 'indigo');
      expect(store.read('dns_vpn_prefs', 'bottom_bar_haptic_enabled'), false);
      expect(store.read('dns_vpn_prefs', 'home_power_button_opacity'), 0.6);
      expect(store.read('dns_vpn_prefs', 'home_sentence_running'), '新句子');
      expect(store.read('diting_settings', 'app_work_mode'), 'express');
      expect(store.read('dns_vpn_prefs', 'dns_resolution_mode'), 'primary_backup');
      expect(store.read('diting_dns_mode_prefs', 'local_listen_port'), 1053);
    });

    test('底栏改动按旧版 JSON 数组格式保存', () {
      final store = MemoryLegacyPrefsStore();
      final container = containerWith(store);

      final toggled = container
          .read(bottomBarProvider.notifier)
          .toggle(BottomBarDestination.settings);

      expect(toggled, isTrue);
      expect(
        store.read('dns_vpn_prefs', 'bottom_bar_destinations'),
        '["home","feature_hub","log_dashboard","settings"]',
      );
    });

    test('不足两项的旧数组回退默认且未知 id 被忽略', () {
      final container = containerWith(MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {
          'bottom_bar_destinations': '["bogus","home"]',
        },
      }));
      expect(container.read(bottomBarProvider), [
        BottomBarDestination.home,
        BottomBarDestination.featureHub,
        BottomBarDestination.logDashboard,
      ]);
    });
  });
}
