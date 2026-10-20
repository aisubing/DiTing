import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 应用选择类页面的数据行为：真实清单 → 过滤排序 → 落盘 → 互斥清洗。
///
/// 这里不挂页面。四张选择页（`/apps`、应用独立规则、HTTPS 检查应用、出站代理
/// 应用）共用同一套「清单 + 过滤 + 排序 + 互斥」逻辑，逻辑一旦漂移，四个入口
/// 会给出互相矛盾的勾选状态；把这层钉住比逐个页面截图稳得多，也不需要原生通道。
void main() {
  /// 三档应用：一个系统应用、两个用户应用，标签大小写刻意混着。
  const systemApp = InstalledApp(
    packageName: 'com.android.systemui',
    label: 'System UI',
    isSystem: true,
    uid: 1000,
  );
  const maps = InstalledApp(
    packageName: 'com.example.maps',
    label: '地图',
    isSystem: false,
    uid: 10101,
  );
  const chat = InstalledApp(
    packageName: 'com.example.chat',
    label: 'Chat',
    isSystem: false,
    uid: 10102,
  );
  const device = [systemApp, maps, chat];

  ProviderContainer containerWith([Map<String, Map<String, Object>> seed = const {}]) {
    final container = ProviderContainer(
      overrides: [
        legacyPrefsStoreProvider.overrideWithValue(
          MemoryLegacyPrefsStore({
            for (final entry in seed.entries)
              entry.key: Map<String, Object>.from(entry.value),
          }),
        ),
        installedAppsSourceProvider.overrideWithValue(_FakeAppsSource(device)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('installedAppsProvider', () {
    test('读通道后按标签升序给出一份快照', () async {
      final container = containerWith();
      final snapshot = await container.read(installedAppsProvider.future);
      expect(snapshot.error, isNull);
      // 小写比较：'chat' < 'system ui' < '地图'（CJK 码位大于 ASCII）。
      expect(snapshot.apps.map((app) => app.packageName), [
        'com.example.chat',
        'com.android.systemui',
        'com.example.maps',
      ]);
      expect(snapshot.packageNames, {
        'com.android.systemui',
        'com.example.maps',
        'com.example.chat',
      });
    });

    test('通道缺失时给空列表 + 可读原因，而不是抛异常', () async {
      // 默认 override 不设置 source 时用 EmptyInstalledAppsSource；这里直接
      // 用一个抛 MissingPluginException 的实现模拟「装在没有桥的宿主上」。
      final container = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(MemoryLegacyPrefsStore()),
          installedAppsSourceProvider.overrideWithValue(_FailingAppsSource()),
        ],
      );
      addTearDown(container.dispose);
      final snapshot = await container.read(installedAppsProvider.future);
      expect(snapshot.apps, isEmpty);
      expect(snapshot.error, isNotNull);
      // 页面靠 isError 判断不出「通道坏了」还是「设备真没应用」，所以必须
      // 走 value + error 双字段：FutureProvider 本身不该进 error 态。
      expect(container.read(installedAppsProvider).hasError, isFalse);
    });

    test('bump 之后重新枚举', () async {
      final source = _FakeAppsSource(device);
      final container = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(MemoryLegacyPrefsStore()),
          installedAppsSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      await container.read(installedAppsProvider.future);
      expect(source.listCalls, 1);

      source.apps = const [chat];
      container.read(installedAppsRevisionProvider.notifier).bump();
      final next = await container.read(installedAppsProvider.future);
      expect(source.listCalls, 2);
      expect(next.apps.map((app) => app.packageName), ['com.example.chat']);
    });
  });

  group('互斥写入', () {
    /// 排除应用必须同时从「禁止联网」「HTTPS 检查」「应用独立规则」里清掉。
    ///
    /// 种子里的包名集合一律写成 `List<String>`：`LegacyPrefsStore` 的
    /// `putStringSet` 就是这么存的（桥接层把 set 序列化成字符串数组），
    /// 塞一个真 `Set` 进去会走不到解析分支，测出来的「空集」是假的。
    test('排除应用清掉另外三处', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'excluded_app_packages': <String>[],
          'blocked_app_packages': <String>['com.example.maps'],
          'blocked_apps_enabled': true,
          'http_inspection_app_packages': <String>['com.example.maps'],
          'http_inspection_enabled': true,
          'app_allowlist_rules_json': '{"com.example.maps":["api.example.com"]}',
        },
      });
      final settings = container.read(legacySettingsProvider);
      final excluded = {...settings.excludedPackages, 'com.example.maps'};
      settings.setExcludedPackages(excluded);
      settings.setBlockedApps(
        packages: settings.blockedAppPackages.difference(excluded),
        enabled: settings.blockedAppsEnabled,
      );
      settings.setHttpInspectionApps(
        packages: settings.httpInspectionPackages.difference(excluded),
        enabled: settings.httpInspectionEnabled,
      );
      settings.setAppAllowlistRules({
        for (final entry in settings.appAllowlistRules.entries)
          if (!excluded.contains(entry.key)) entry.key: entry.value,
      });
      container.read(legacySettingsRevisionProvider.notifier).bump();

      final next = container.read(legacySettingsProvider);
      expect(next.excludedPackages, {'com.example.maps'});
      expect(next.blockedAppPackages, isEmpty);
      expect(next.httpInspectionPackages, isEmpty);
      expect(next.appAllowlistRules, isEmpty);
      // 开关本身不该被顺手改掉。
      expect(next.blockedAppsEnabled, isTrue);
      expect(next.httpInspectionEnabled, isTrue);
    });

    test('HTTPS 检查应用清掉排除与禁止联网', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'excluded_app_packages': <String>['com.example.chat'],
          'blocked_app_packages': <String>['com.example.chat'],
          'http_inspection_app_packages': <String>[],
        },
      });
      final settings = container.read(legacySettingsProvider);
      const chosen = {'com.example.chat'};
      settings.setHttpInspectionApps(
        packages: chosen,
        enabled: settings.httpInspectionEnabled,
      );
      settings.setExcludedPackages(settings.excludedPackages.difference(chosen));
      settings.setBlockedApps(
        packages: settings.blockedAppPackages.difference(chosen),
        enabled: settings.blockedAppsEnabled,
      );
      container.read(legacySettingsRevisionProvider.notifier).bump();

      final next = container.read(legacySettingsProvider);
      expect(next.httpInspectionPackages, chosen);
      expect(next.excludedPackages, isEmpty);
      expect(next.blockedAppPackages, isEmpty);
    });
  });

  group('互斥清洗不能把自己清掉', () {
    /// 回归：`_dropOverlaps` 最初先 `setBlockedApps(packages)` 再读
    /// `blockedAppPackages.difference(packages)` —— 读回来的正是刚写进去的那份，
    /// 差集当场为空，用户点「保存」等于清空自己的选择。
    ///
    /// 现在归属方由 `_Owner` 显式传入，被跳过的正是刚写的那一份。这里用与页面
    /// 相同的调用顺序复现：先写归属方，再清其余三处。
    test('保存禁止联网名单后，该名单仍是刚提交的内容', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'blocked_app_packages': <String>[],
          'excluded_app_packages': <String>['com.example.maps'],
          'http_inspection_app_packages': <String>['com.example.maps'],
          'app_allowlist_rules_json': '{"com.example.maps":["a.example.com"]}',
        },
      });
      final settings = container.read(legacySettingsProvider);
      const chosen = {'com.example.maps'};

      // 与 BlockedAppsPage._saveBlocked 同序：先写归属方，再清其余。
      settings.setBlockedApps(packages: chosen, enabled: true);
      settings.setExcludedPackages(settings.excludedPackages.difference(chosen));
      settings.setHttpInspectionApps(
        packages: settings.httpInspectionPackages.difference(chosen),
        enabled: settings.httpInspectionEnabled,
      );
      settings.setAppAllowlistRules({
        for (final entry in settings.appAllowlistRules.entries)
          if (!chosen.contains(entry.key)) entry.key: entry.value,
      });
      container.read(legacySettingsRevisionProvider.notifier).bump();

      final next = container.read(legacySettingsProvider);
      // 关键断言：刚保存的那一份必须还在。
      expect(next.blockedAppPackages, chosen);
      expect(next.blockedAppsEnabled, isTrue);
      expect(next.excludedPackages, isEmpty);
      expect(next.httpInspectionPackages, isEmpty);
      expect(next.appAllowlistRules, isEmpty);
    });

    test('保存排除名单后，该名单仍是刚提交的内容', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'excluded_app_packages': <String>[],
          'blocked_app_packages': <String>['com.example.chat'],
        },
      });
      final settings = container.read(legacySettingsProvider);
      const chosen = {'com.example.chat'};

      settings.setExcludedPackages(chosen);
      settings.setBlockedApps(
        packages: settings.blockedAppPackages.difference(chosen),
        enabled: settings.blockedAppsEnabled,
      );
      container.read(legacySettingsRevisionProvider.notifier).bump();

      final next = container.read(legacySettingsProvider);
      expect(next.excludedPackages, chosen);
      expect(next.blockedAppPackages, isEmpty);
    });
  });

  group('过滤 / 排序的落盘', () {
    test('四个页面的 filter/sort 键互不干扰', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'excluded_apps_filter': 'SYSTEM',
          'excluded_apps_sort': 'PACKAGE_DESC',
          'app_allowlist_filter': 'ALL',
          'app_allowlist_sort': 'LABEL_DESC',
        },
      });
      final settings = container.read(legacySettingsProvider);
      expect(settings.excludedAppsFilterRaw, 'SYSTEM');
      expect(settings.excludedAppsSortRaw, 'PACKAGE_DESC');
      expect(settings.appAllowlistFilterRaw, 'ALL');
      expect(settings.appAllowlistSortRaw, 'LABEL_DESC');

      settings.setExcludedAppsFilterRaw(
        AppListFilter.selected.storageValue,
      );
      container.read(legacySettingsRevisionProvider.notifier).bump();
      final next = container.read(legacySettingsProvider);
      expect(next.excludedAppsFilterRaw, 'SELECTED');
      // 改一处不能带动另一处。
      expect(next.appAllowlistFilterRaw, 'ALL');
    });

    test('默认值：filter=USER、sort=LABEL_ASC', () {
      final container = containerWith();
      final settings = container.read(legacySettingsProvider);
      expect(settings.excludedAppsFilterRaw, 'USER');
      expect(settings.excludedAppsSortRaw, 'LABEL_ASC');
      expect(settings.appAllowlistFilterRaw, 'USER');
      expect(settings.appAllowlistSortRaw, 'LABEL_ASC');
      expect(settings.excludedPackages, isEmpty);
    });
  });

  group('应用独立规则', () {
    test('放行域名按 JSON 对象读写，空数组的包名被丢弃', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'app_allowlist_rules_json':
              '{"com.example.maps":["a.example.com","b.example.com"],'
              '"com.example.chat":[]}',
          'app_allowlist_enabled': true,
        },
      });
      final settings = container.read(legacySettingsProvider);
      expect(settings.appAllowlistRules, {
        'com.example.maps': {'a.example.com', 'b.example.com'},
      });
      expect(settings.appAllowlistEnabled, isTrue);
    });

    test('总开关独立于规则表', () {
      final container = containerWith({
        'dns_vpn_prefs': {
          'app_allowlist_rules_json': '{"com.example.maps":["a.example.com"]}',
          'app_allowlist_enabled': false,
        },
      });
      final settings = container.read(legacySettingsProvider);
      expect(settings.appAllowlistEnabled, isFalse);
      expect(settings.appAllowlistRules, isNotEmpty);
      settings.setAppAllowlistEnabled(true);
      container.read(legacySettingsRevisionProvider.notifier).bump();
      expect(container.read(legacySettingsProvider).appAllowlistEnabled, isTrue);
    });
  });

  group('HTTPS 绕过规则', () {
    test('读写 https_bypass_rules 并去掉空白项', () {
      final container = containerWith();
      final settings = container.read(legacySettingsProvider);
      expect(settings.httpsBypassRules, isEmpty);

      settings.setHttpsBypassRules({'example.com', '  ', 'a.example.com'});
      container.read(legacySettingsRevisionProvider.notifier).bump();
      final next = container.read(legacySettingsProvider);
      expect(next.httpsBypassRules, {'example.com', 'a.example.com'});
    });
  });

  group('httpsInspectionOperational', () {
    test('需要证书就绪 + 总开关 + 至少一个应用', () {
      /// 包名集合写成 `List<String>`，理由同上一组：这是 `putStringSet` 的存储形态。
      Map<String, Map<String, Object>> seed({
        required String backend,
        required bool ready,
        required bool enabled,
        required List<String> apps,
      }) => {
        'dns_vpn_prefs': {
          'https_inspection_ca_backend': backend,
          'https_inspection_ready': ready,
          'http_inspection_enabled': enabled,
          'http_inspection_app_packages': apps,
        },
      };

      bool operational(Map<String, Map<String, Object>> data) =>
          containerWith(data).read(legacySettingsProvider).httpsInspectionOperational;

      expect(
        operational(seed(
          backend: 'go-v1',
          ready: true,
          enabled: true,
          apps: ['com.example.maps'],
        )),
        isTrue,
      );
      // 缺任一条即为 false；尤其是旧后端（无 go-v1 标记）时 ready 必须为 false。
      expect(
        operational(seed(
          backend: 'legacy',
          ready: true,
          enabled: true,
          apps: ['com.example.maps'],
        )),
        isFalse,
      );
      expect(
        operational(seed(
          backend: 'go-v1',
          ready: false,
          enabled: true,
          apps: ['com.example.maps'],
        )),
        isFalse,
      );
      expect(
        operational(seed(
          backend: 'go-v1',
          ready: true,
          enabled: false,
          apps: ['com.example.maps'],
        )),
        isFalse,
      );
      expect(
        operational(seed(
          backend: 'go-v1',
          ready: true,
          enabled: true,
          apps: [],
        )),
        isFalse,
      );
    });
  });
}

class _FakeAppsSource implements InstalledAppsSource {
  _FakeAppsSource(this.apps);

  List<InstalledApp> apps;
  int listCalls = 0;

  @override
  Future<List<InstalledApp>> list() async {
    listCalls++;
    return apps;
  }

  @override
  Future<Map<String, int>> resolveUids(Iterable<String> packages) async => {
    for (final app in apps)
      if (packages.contains(app.packageName)) app.packageName: app.uid,
  };

  @override
  Future<bool> isSelf(String packageName) async => false;
}

class _FailingAppsSource implements InstalledAppsSource {
  @override
  Future<List<InstalledApp>> list() async =>
      throw MissingPluginException('模拟宿主没有 apps 通道');

  @override
  Future<Map<String, int>> resolveUids(Iterable<String> packages) async =>
      throw MissingPluginException('模拟宿主没有 apps 通道');

  @override
  Future<bool> isSelf(String packageName) async =>
      throw MissingPluginException('模拟宿主没有 apps 通道');
}
