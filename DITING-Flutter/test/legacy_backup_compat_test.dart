import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:diting/data/backup/backup_exporter.dart';
import 'package:diting/data/backup/backup_importer.dart';
import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/legacy_schema.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 新旧备份互通的回归测试。
///
/// 三件事必须一直成立，否则用户升级后会丢配置：
///
/// 1. 1.4.3 导出的平铺备份能被 2.0 导入（此前直接报「这不是谛听的备份文件」）；
/// 2. 2.0 导出的文件**同时**带着旧版平铺键，导回 1.4.3 时不再是「内容为空」；
/// 3. 全新安装（没有任何旧库）时 2.0 自己建库，导入不再报「本机还没有规则库」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final statement in LegacySchema.statementsFor(
      LegacyDatabase.mainFile,
    )) {
      await db.execute(statement);
    }
  });

  tearDown(() => db.close());

  String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

  BackupImportTarget target([LegacyPrefsStore? store]) => BackupImportTarget(
    store: store ?? MemoryLegacyPrefsStore(),
    database: db,
  );

  group('1.4.3 → 2.0', () {
    test('旧版平铺备份能被导入，且规则/订阅真的落库', () async {
      final store = MemoryLegacyPrefsStore();
      final result = await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(store),
      );

      expect(result.failed, isFalse, reason: result.fatalError);
      expect(result.legacyFormat, isTrue);
      // 旧版把 customBlockRules 与 customAllowRules 分成两组，2.0 合成一组。
      expect(result.failedGroups, isEmpty);

      final blockRows = await db.query('block_rule');
      expect(blockRows, hasLength(4));
      expect(
        blockRows.where((row) => row['appScope'] == 'com.example.blocked'),
        hasLength(1),
        reason: '只对某个应用生效的规则必须保留 appScope',
      );
      final allowRows = await db.query('allow_rule');
      expect(allowRows, hasLength(4));

      final subscriptions = await db.query('subscription');
      expect(subscriptions, hasLength(3));
      expect(
        subscriptions.map((row) => row['url']),
        contains('https://example.com/ad-domain.txt'),
      );

      // 服务商没有 id 的旧条目要补 id，否则界面上一个都用不了。
      final providers = jsonDecode(
        store.read('dns_vpn_prefs', 'user_providers_json')! as String,
      );
      expect(providers, hasLength(2));
      for (final provider in providers as List) {
        expect((provider as Map)['id'], isNotEmpty);
      }
      expect(store.read('dns_vpn_prefs', 'selected_provider_id'), isNotNull);
      expect(store.read('dns_vpn_prefs', 'dns_resolution_mode'), isNotNull);
    });

    test('旧版备份里的 rewrite 规则按 targetType 落到正确分组', () async {
      final result = await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(),
      );
      expect(result.failed, isFalse);
      final rows = await db.query('rewrite_rule');
      expect(rows, hasLength(1));
      expect(rows.single['targetType'], 'CNAME');
      expect(rows.single['targetValue'], 'target.example.com');
    });

    test('旧版备份导入两次不产生重复行', () async {
      final store = MemoryLegacyPrefsStore();
      await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(store),
      );
      final second = await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(store),
      );
      expect(second.failed, isFalse);
      expect(await db.query('block_rule'), hasLength(4));
      expect(await db.query('allow_rule'), hasLength(4));
      expect(await db.query('subscription'), hasLength(3));
    });
  });

  group('2.0 → 1.4.3', () {
    test('导出的文件带旧版平铺键，1.4.3 读出来不再是空内容', () async {
      // 先让库里有内容，再导出。
      await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(MemoryLegacyPrefsStore()),
      );
      final store = MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {
          'user_providers_json':
              '[{"id":"user_a","name":"我的 DoH","protocol":"DOH",'
              '"url":"https://dns.example.com/dns-query","host":"","port":853}]',
          'selected_provider_id': 'user_a',
          'dns_resolution_mode': 'parallel_race',
          'race_provider_ids': '["user_a","preset_alidns_dns"]',
        },
      });
      final export = await const BackupExporter().export(
        BackupExportSource(settings: LegacySettings(store), database: db),
      );
      final root = jsonDecode(export.content) as Map<String, Object?>;

      // 新格式仍在，保证 2.0 自己能再导入一次。
      expect(root['format'], BackupFormat.magic);
      expect(root['data'], isA<Map>());

      // 旧格式的关键顶层键必须齐备：1.4.3 的解析器逐字段 optString，
      // 缺一个就是「导入后内容为空」。
      expect(root['formatVersion'], 10);
      expect(root['providers'], hasLength(1));
      expect(root['selectedProvider'], isA<Map>());
      expect(root['resolutionMode'], 'parallel_race');
      expect(root['raceProviderRefs'], hasLength(2));
      expect(root['customBlockRules'], hasLength(4));
      expect(root['customAllowRules'], hasLength(4));
      expect(root['customRewriteCnameRules'], hasLength(1));
      expect(root['subscriptions'], hasLength(3));
      expect(
        (root['subscriptions'] as List).first,
        containsPair('scope', 'dns'),
      );
      expect(root['appearance'], isA<Map>());
      expect(root['systemSettings'], isA<Map>());
      expect(
        (root['systemSettings'] as Map)['logRetentionDays'],
        isA<int>(),
        reason: '1.4.3 用 getInt 读这个键，写成字符串会被静默忽略',
      );
      expect((root['outboundProxy'] as Map)['credentialsOmitted'], isTrue);
      // 出站代理的应用包名键名必须与原生一致（outbound_proxy_app）。
      expect(
        (root['outboundProxy'] as Map).containsKey('proxyAppPackage'),
        isTrue,
      );
    });

    test('镜像模板跟着订阅一起导出', () async {
      await db.insert('mirror_template', {
        'name': '我的镜像',
        'template': 'https://mirror.example.com/{}',
        'addedAt': 1,
      });
      addTearDown(() => db.delete('mirror_template'));
      final export = await const BackupExporter().export(
        BackupExportSource(
          settings: LegacySettings(MemoryLegacyPrefsStore()),
          database: db,
        ),
      );
      final root = jsonDecode(export.content) as Map<String, Object?>;
      expect(root['mirrorTemplates'], [
        {'name': '我的镜像', 'template': 'https://mirror.example.com/{}'},
      ]);
      final data = root['data'] as Map<String, Object?>;
      final subscriptions = data['subscriptions'] as Map<String, Object?>;
      expect(subscriptions['mirrorTemplates'], hasLength(1));
    });

    test('旧版字段名逐一存在（防回归清单）', () async {
      final export = await const BackupExporter().export(
        BackupExportSource(
          settings: LegacySettings(
            MemoryLegacyPrefsStore({
              'dns_vpn_prefs': {'app_theme_mode': 'dark'},
            }),
          ),
          database: db,
        ),
      );
      final root = jsonDecode(export.content) as Map<String, Object?>;
      const required = [
        'providers',
        'selectedProvider',
        'resolutionMode',
        'presetDnsService',
        'raceTestDomain',
        'homeProviderVisibility',
        'bootstrapEnabled',
        'bootstrapIps',
        'bootstrapPresetIds',
        'dnsCache',
        'outboundProxy',
        'mirrorTemplates',
        'subscriptionGroups',
        'subscriptions',
        'customBlockRules',
        'customAllowRules',
        'customRewriteDomainRules',
        'customRewriteCnameRules',
        'customAddressRules',
        'excludedApps',
        'blockedApps',
        'blockedAppsEnabled',
        'appAllowlistRules',
        'appAllowlistEnabled',
        'httpInspection',
        'domainRulesEnabled',
        'addressRulesEnabled',
        'encryptedDnsBlockingEnabled',
        'blockResponseMode',
        'dynamicBlockResponse',
        'allowEditDefaultWhitelist',
        'subscriptionAutoUpdate',
        'appearance',
        'systemSettings',
      ];
      for (final key in required) {
        expect(root, contains(key), reason: '1.4.3 需要一个顶层键：$key');
      }
    });
  });

  group('全新安装', () {
    test('没有旧库时自建 schema，备份导入不再报没有规则库', () async {
      final path = p.join(
        Directory.systemTemp.createTempSync('diting_schema').path,
        LegacyDatabase.mainFile,
      );
      final fresh = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: LegacySchema.versionOf(LegacyDatabase.mainFile),
          onCreate: (database, version) async {
            for (final statement in LegacySchema.statementsFor(
              LegacyDatabase.mainFile,
            )) {
              await database.execute(statement);
            }
          },
        ),
      );
      addTearDown(() async {
        await fresh.close();
        Directory(p.dirname(path)).deleteSync(recursive: true);
      });

      final result = await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        BackupImportTarget(store: MemoryLegacyPrefsStore(), database: fresh),
      );
      expect(result.failed, isFalse, reason: result.fatalError);
      expect(result.failedGroups, isEmpty);
      expect(await fresh.query('subscription'), hasLength(3));
    });
  });
  group('重复导入', () {
    test('同一份备份导入两次，第二次不再报「新增」', () async {
      final store = MemoryLegacyPrefsStore();
      final first = await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(store),
      );
      expect(first.failed, isFalse);
      expect(first.added, greaterThan(0));

      final second = await const BackupImporter().import(
        fixture('legacy-export-1.4.3.json'),
        target(store),
      );
      expect(second.failed, isFalse);
      expect(second.added, 0, reason: '第二次导入时本机已经有全部条目，不应该再报告新增');
      expect(second.failedGroups, isEmpty);
    });

    test('同一份 2.0 备份连导三次，服务商不再反复报「更新」', () async {
      final store = MemoryLegacyPrefsStore();
      final target = BackupImportTarget(store: store, database: db);
      final content = fixture('legacy-export-1.4.3.json');
      final first = await const BackupImporter().import(content, target);
      expect(first.failed, isFalse, reason: first.fatalError);

      for (var round = 0; round < 2; round++) {
        final again = await const BackupImporter().import(content, target);
        final providers = again.outcomes.firstWhere(
          (outcome) => outcome.group == BackupGroup.providers,
        );
        expect(
          providers.updated,
          0,
          reason: '第 ${round + 2} 次导入仍把服务商标成更新',
        );
        expect(providers.added, 0);
      }
    });

    test('安卓 float 精度不会让透明度被反复导入', () async {
      // 安卓 SharedPreferences 用 Java float 存，putFloat(0.8) 读回来是
      // 0.800000011920929。设备上曾因此每次导入都报「外观 · 新增 6」。
      const stored = 0.800000011920929;
      final store = MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {
          'app_theme_mode': 'dark',
          'theme_color_style': 'system',
          'home_component_opacity': stored,
          'home_power_button_opacity': stored,
          'home_provider_selector_opacity': stored,
          'home_mode_button_opacity': stored,
          'home_poem_opacity': stored,
          'home_dns_detail_opacity': stored,
          'home_sentence_running': '测试运行中',
          'home_sentence_stopped': '测试已停止',
        },
      });
      final settings = LegacySettings(store);
      final export = await const BackupExporter().export(
        BackupExportSource(settings: settings, database: db),
      );
      final target = BackupImportTarget(store: store, database: db);
      for (var round = 0; round < 2; round++) {
        final result = await const BackupImporter().import(
          export.content,
          target,
        );
        final appearance = result.outcomes.firstWhere(
          (outcome) => outcome.group == BackupGroup.appearance,
        );
        expect(
          appearance.added,
          0,
          reason: '第 ${round + 1} 次导入又把透明度当成新项',
        );
      }
    });

    test('2.0 导出的备份导入回 2.0 也是幂等的', () async {
      final store = MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {
          'app_theme_mode': 'dark',
          'log_retention_days': 7,
          'user_providers_json':
              '[{"id":"user_a","name":"我的 DoH","protocol":"DOH",'
              '"url":"https://dns.example.com/dns-query","host":"","port":853}]',
          'selected_provider_id': 'user_a',
        },
      });
      final export = await const BackupExporter().export(
        BackupExportSource(settings: LegacySettings(store), database: db),
      );
      final empty = MemoryLegacyPrefsStore();
      final first = await const BackupImporter().import(
        export.content,
        target(empty),
      );
      expect(first.failed, isFalse, reason: first.fatalError);
      final second = await const BackupImporter().import(
        export.content,
        target(empty),
      );
      expect(second.failed, isFalse, reason: second.fatalError);
      expect(second.added, 0);
      expect(second.updated, 0);
    });
  });
}
