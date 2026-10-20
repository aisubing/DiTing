import 'package:diting/app/app.dart';
import 'package:diting/app/debug_probe.dart';
import 'package:diting/data/db/rule_bootstrap.dart';
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/native/outbound_proxy_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/state/outbound_proxy_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 入口。工程只有这一处 `runApp`；测试挂 [DitingApp] 时自己建 `ProviderScope`，
/// 以免与真实的全局容器互相污染。
///
/// 旧版配置与规则库都在首帧前读入，因此各 provider 的 `build()` 能同步拿到
/// 1.4.3 用户已经保存的值，不会先闪一帧默认主题或空规则再跳变。
///
/// 原生通道在这里统一注入。每个 provider 的默认实现都是「诚实的空实现」
/// （读不到应用列表 / 未生成根证书 / 内存出站代理），因此：
/// - 测试与非 Android 宿主不需要任何 override 就能跑；
/// - 漏掉下面任何一行不会崩溃，但对应功能会退化成空态——所以四条必须成组出现。
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
        // 真实应用清单（PackageManager + QUERY_ALL_PACKAGES）。四个选择页共用。
        installedAppsSourceProvider.overrideWithValue(
          MethodChannelInstalledAppsSource(),
        ),
        // 账号密码由 AndroidKeyStore 包装，Dart 只能读写整份配置。
        outboundProxyStoreProvider.overrideWithValue(
          MethodChannelOutboundProxyStore(),
        ),
        caCertificateServiceProvider.overrideWithValue(
          MethodChannelCaCertificateService(),
        ),
        // Guarded 包装把 MissingPluginException / PlatformException 转成可读的
        // 失败结果：诊断面板需要显示「为什么没能测」，而不是抛到 UI 变成红屏。
        diagnosticsRunnerProvider.overrideWithValue(
          GuardedDiagnosticsRunner(MethodChannelDiagnosticsRunner()),
        ),
      ],
      child: const DitingApp(),
    ),
  );
}
