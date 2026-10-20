import 'package:diting/app/app.dart';
import 'package:diting/app/debug_probe.dart';
import 'package:diting/data/db/rule_bootstrap.dart';
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 入口。工程只有这一处 `runApp`；测试挂 [DitingApp] 时自己建 `ProviderScope`，
/// 以免与真实的全局容器互相污染。
///
/// 旧版配置与规则库都在首帧前读入，因此各 provider 的 `build()` 能同步拿到
/// 1.4.3 用户已经保存的值，不会先闪一帧默认主题或空规则再跳变。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installDebugProbe();
  final store = await loadLegacyPrefsStore();
  final settings = LegacySettings(store);
  final rules = await bootstrapRules(
    settings,
    versionCode: await readAppVersionCode(),
  );
  runApp(
    ProviderScope(
      overrides: [
        legacyPrefsStoreProvider.overrideWithValue(store),
        ruleRepositoryProvider.overrideWithValue(rules.repository),
        initialRulesProvider.overrideWithValue(rules.rules),
      ],
      child: const DitingApp(),
    ),
  );
}
