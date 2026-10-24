import 'package:diting/app/theme/layout.dart';
import 'package:diting/data/native/background_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Static guard for the settings domain and route table: a misspelled key still saves and
/// displays fine, only losing settings on upgrade
class _FakeBackgroundBridge extends BackgroundBridge {
  final List<String> released = [];

  @override
  Future<bool> release(String uri) async {
    released.add(uri);
    return true;
  }
}

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
      expect(store.read('dns_vpn_prefs', 'dns_log_mode'), 'blocked_and_errors');
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
    _FakeBackgroundBridge? bridge;

    ProviderContainer container() {
      final fake = _FakeBackgroundBridge();
      bridge = fake;
      final c = ProviderContainer(
        overrides: [backgroundBridgeProvider.overrideWithValue(fake)],
      );
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
      expect(bridge!.released, ['content://2']);
    });
  });

  group('底栏上限回到旧版的 4', () {
    test('maxDockDestinations 与 LegacySettings.bottomBarMaxCount 一致', () {
      expect(maxDockDestinations, LegacySettings.bottomBarMaxCount);
      expect(maxDockDestinations, 4);
    });
  });

}
