import 'package:diting/app/app.dart';
import 'package:diting/app/debug_probe.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 入口。工程只有这一处 `runApp`；测试挂 [DitingApp] 时自己建 `ProviderScope`，
/// 以免与真实的全局容器互相污染。
///
/// 旧版 SharedPreferences 在首帧前一次性读入，因此各状态 provider 的 `build()`
/// 能同步拿到 1.4.3 用户已经保存的值，不会先闪一帧默认主题再跳变。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installDebugProbe();
  final store = await loadLegacyPrefsStore();
  runApp(
    ProviderScope(
      overrides: [legacyPrefsStoreProvider.overrideWithValue(store)],
      child: const DitingApp(),
    ),
  );
}
