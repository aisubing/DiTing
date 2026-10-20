import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_vpn_controller.dart';

/// 应用层纯逻辑用例（不挂 UI，因此不受页面实现进度影响）。
void main() {
  group('AppThemeSpec 值语义', () {
    test('同参构造相等且 hashCode 一致', () {
      const a = AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.light);
      const b = AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.light);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AppThemeSpec(
        seedColor: Color(0xFF007AFF),
        brightness: Brightness.dark,
      )));
    });

    test('copyWith 只改指定字段', () {
      const spec = AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.light);
      final dark = spec.copyWith(brightness: Brightness.dark, pureBlack: true);
      expect(dark.brightness, Brightness.dark);
      expect(dark.pureBlack, isTrue);
      expect(dark.seedColor, spec.seedColor);
    });
  });

  group('buildAppTheme 装配顺序', () {
    // 顺序是 load-bearing：纯黑必须在 seededColorScheme 之后、shape/surface/type
    // 之前，否则 surface 会重新算出带色偏的深色。
    test('纯黑主题的 surface 是纯黑', () {
      final theme = buildAppTheme(
        const AppThemeSpec(
          seedColor: Color(0xFF007AFF),
          brightness: Brightness.dark,
          pureBlack: true,
        ),
      );
      expect(theme.colorScheme.surface, const Color(0xFF000000));
      expect(theme.brightness, Brightness.dark);
    });

    test('非纯黑深色主题的 surface 不是纯黑', () {
      final theme = buildAppTheme(
        const AppThemeSpec(
          seedColor: Color(0xFF007AFF),
          brightness: Brightness.dark,
        ),
      );
      expect(theme.colorScheme.surface, isNot(const Color(0xFF000000)));
    });

    test('深色主题带 ElevatedColorScheme 扩展，浅色不带', () {
      final dark = buildAppTheme(
        const AppThemeSpec(
          seedColor: Color(0xFF007AFF),
          brightness: Brightness.dark,
        ),
      );
      final light = buildAppTheme(
        const AppThemeSpec(
          seedColor: Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
      );
      expect(dark.extension<ElevatedColorScheme>(), isNotNull);
      expect(light.extension<ElevatedColorScheme>(), isNull);
    });

    test('不同种子色产出不同 primary', () {
      final purple = buildAppTheme(
        const AppThemeSpec(seedColor: Color(0xFFAF52DE), brightness: Brightness.light),
      );
      final blue = buildAppTheme(
        const AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.light),
      );
      expect(purple.colorScheme.primary, isNot(blue.colorScheme.primary));
    });

    test('形状与排版被装配进去', () {
      final theme = buildAppTheme(
        const AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.light),
      );
      // AppShape 把 Card 圆角设成 AppCorner.md，若漏了 withAppShapes 这里会是 M3 默认值。
      expect(theme.cardTheme.shape, isNotNull);
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, isNotNull);
    });
  });

  group('AppThemeCache', () {
    test('同一 spec 返回同一实例（否则 ThemeCrossFade 每帧闪）', () {
      final cache = AppThemeCache();
      const spec = AppThemeSpec(
        seedColor: Color(0xFF007AFF),
        brightness: Brightness.light,
      );
      expect(identical(cache.of(spec), cache.of(spec)), isTrue);
    });

    test('不同 spec 返回不同实例', () {
      final cache = AppThemeCache();
      final light = cache.of(
        const AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.light),
      );
      final dark = cache.of(
        const AppThemeSpec(seedColor: Color(0xFF007AFF), brightness: Brightness.dark),
      );
      expect(identical(light, dark), isFalse);
    });

    test('缓存容量有上界（避免主题切换久了无限增长）', () {
      final cache = AppThemeCache();
      for (var i = 0; i < AppPalette.values.length * 4; i++) {
        cache.of(
          AppThemeSpec(
            seedColor: Color(0xFF000000 | (i * 977) & 0xFFFFFF),
            brightness: i.isEven ? Brightness.light : Brightness.dark,
          ),
        );
      }
      expect(cache.length, lessThanOrEqualTo(AppThemeCache.maxEntries));
    });
  });

  group('AppPalette', () {
    test('system 用默认种子色；blue 就是默认蓝，两者 effectiveSeed 相同', () {
      expect(AppPalette.system.effectiveSeed, defaultPrimaryColor);
      expect(AppPalette.blue.effectiveSeed, defaultPrimaryColor);
      // 其余色板各有自己的种子色。
      for (final palette in AppPalette.values) {
        if (palette == AppPalette.system || palette == AppPalette.blue) {
          continue;
        }
        expect(palette.seed, isNotNull, reason: '${palette.name} 缺种子色');
        expect(
          palette.effectiveSeed,
          isNot(defaultPrimaryColor),
          reason: '${palette.name} 不该复用默认蓝',
        );
      }
    });

    test('fromSeed 能还原色板，未知种子回退 system', () {
      expect(AppPalette.fromSeed(AppPalette.purple.seed!), AppPalette.purple);
      expect(AppPalette.fromSeed(const Color(0xFF123456)), AppPalette.system);
    });

    test('每个色板都有非空中文标签与 swatch', () {
      for (final palette in AppPalette.values) {
        expect(palette.label, isNotEmpty);
        expect(palette.swatch, isA<Color>());
      }
    });
  });

  group('layout 常量', () {
    test('断点单调且 isMobileWidth 边界闭合', () {
      expect(maxMobileWidth, lessThan(maxLaptopWidth));
      expect(isMobileWidth(maxMobileWidth), isTrue);
      expect(isMobileWidth(maxMobileWidth + 0.1), isFalse);
    });

    test('clampTextScale 把越界值夹回区间', () {
      expect(clampTextScale(0), minTextScale);
      expect(clampTextScale(9), maxTextScale);
      expect(clampTextScale(1.2), 1.2);
    });
  });

  group('外观 provider', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('切换色板后 effectiveSeed 跟着变', () {
      final c = container();
      // 1.4.3 未设置 `theme_color_style` 时回退 SYSTEM（旧枚举的默认值），
      // Flutter 侧没有 Monet，SYSTEM 退化为默认蓝。
      expect(c.read(paletteProvider), AppPalette.system);
      c.read(paletteProvider.notifier).select(AppPalette.purple);
      expect(c.read(paletteProvider).effectiveSeed, AppPalette.purple.effectiveSeed);
    });

    test('纯黑只在深色下有意义，但 provider 本身不改亮度', () {
      final c = container();
      c.read(themeModeProvider.notifier).select(AppThemeMode.dark);
      c.read(pureBlackProvider.notifier).toggle(true);
      expect(c.read(pureBlackProvider), isTrue);
      expect(c.read(themeModeProvider), AppThemeMode.dark);
    });

    test('底栏至少留 2 项、最多 5 项', () {
      final c = container();
      final notifier = c.read(bottomBarProvider.notifier);
      final defaults = c.read(bottomBarProvider);
      expect(defaults.length, greaterThanOrEqualTo(2));
      expect(defaults.length, lessThanOrEqualTo(maxDockDestinations));

      // 全部打开：被 5 项上限挡住。
      for (final destination in BottomBarDestination.values) {
        notifier.toggle(destination);
      }
      expect(c.read(bottomBarProvider).length, maxDockDestinations);

      // 全部关掉：被 2 项下限挡住。
      for (final destination in BottomBarDestination.values) {
        notifier.toggle(destination);
      }
      expect(c.read(bottomBarProvider).length, greaterThanOrEqualTo(2));
    });

    test('重置底栏回到默认配置', () {
      final c = container();
      final notifier = c.read(bottomBarProvider.notifier);
      final defaults = List.of(c.read(bottomBarProvider));
      notifier.toggle(BottomBarDestination.settings);
      notifier.reset();
      expect(c.read(bottomBarProvider), defaults);
    });

    test('透明度被夹在 0.1–1.0', () {
      final c = container();
      final notifier = c.read(homeOpacityProvider.notifier);
      notifier.set(HomeLayer.powerButton, 0);
      expect(c.read(homeOpacityProvider)[HomeLayer.powerButton], 0.1);
      notifier.set(HomeLayer.powerButton, 5);
      expect(c.read(homeOpacityProvider)[HomeLayer.powerButton], 1.0);
    });

    test('每个 HomeLayer 都有默认透明度', () {
      final c = container();
      final opacity = c.read(homeOpacityProvider);
      for (final layer in HomeLayer.values) {
        expect(opacity[layer], isNotNull, reason: '${layer.name} 缺默认值');
      }
    });
  });

  group('工作模式 provider', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [vpnControllerProvider.overrideWithValue(FakeVpnController())],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('电源状态经真实桥接的 toggle 流转', () async {
      final c = container();
      final power = c.read(powerProvider.notifier);
      expect(c.read(powerProvider), PowerState.stopped);

      power.toggle();
      expect(c.read(powerProvider), PowerState.starting);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(powerProvider), PowerState.running);

      power.toggle();
      expect(c.read(powerProvider), PowerState.stopping);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(powerProvider), PowerState.stopped);
    });

    test('busy 期间再点 toggle 被忽略', () async {
      final c = container();
      final power = c.read(powerProvider.notifier);
      power.toggle();
      power.toggle();
      expect(c.read(powerProvider), PowerState.starting);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(powerProvider), PowerState.running);
    });

    test('未授予 VPN 权限时保持启动中，授权后继续', () async {
      final fake = FakeVpnController(prepared: false);
      final c = ProviderContainer(
        overrides: [vpnControllerProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      await c.read(powerProvider.notifier).toggle();
      expect(c.read(powerProvider), PowerState.starting);
      expect(fake.startCalls, 0);

      fake.grantPermission();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(powerProvider), PowerState.running);
      expect(fake.startCalls, 1);
    });

    test('启动失败进入 error 状态', () async {
      final fake = FakeVpnController(started: false, error: 'boom');
      final c = ProviderContainer(
        overrides: [vpnControllerProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      await c.read(powerProvider.notifier).toggle();
      expect(c.read(powerProvider), PowerState.error);
      expect(c.read(powerProvider.notifier).lastError, 'boom');
    });

    test('端口夹在 1024–65535', () {
      final c = container();
      final notifier = c.read(serverPortProvider.notifier);
      notifier.set(80);
      expect(c.read(serverPortProvider), 1024);
      notifier.set(70000);
      expect(c.read(serverPortProvider), 65535);
      notifier.set(8080);
      expect(c.read(serverPortProvider), 8080);
    });

    test('竞速至少 2 个服务商', () {
      final c = container();
      final notifier = c.read(raceProvidersProvider.notifier);
      final initial = c.read(raceProvidersProvider).length;
      expect(initial, greaterThanOrEqualTo(2));
      for (final id in c.read(raceProvidersProvider).toList()) {
        notifier.toggle(id);
      }
      expect(c.read(raceProvidersProvider).length, greaterThanOrEqualTo(2));
    });

    test('selectedProviderProvider 拒绝不存在的 id', () {
      final c = container();
      final before = c.read(selectedProviderProvider);
      c.read(selectedProviderProvider.notifier).select('does-not-exist');
      expect(c.read(selectedProviderProvider), before);
    });

    test('serviceStatsProvider 的 bump/reset 对称', () {
      final c = container();
      final notifier = c.read(serviceStatsProvider.notifier);
      final baseline = c.read(serviceStatsProvider);
      notifier.bump();
      expect(c.read(serviceStatsProvider).queries, baseline.queries + 1);
      notifier.reset();
      expect(c.read(serviceStatsProvider).queries, baseline.queries);
    });

    test('每个 AppWorkMode 都有标题/徽标/摘要', () {
      for (final mode in AppWorkMode.values) {
        expect(mode.title, isNotEmpty);
        expect(mode.badge, isNotEmpty);
        expect(mode.summary, isNotEmpty);
      }
    });
  });
}
