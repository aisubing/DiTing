/// 数据清理的 provider 层。
///
/// 页面只认 [dataCleanupServiceProvider]：它把 prefs、两条原生通道与数据库
/// 打开函数装配在一起。测试与非 Android 宿主拿到的是同一套「诚实降级」实现
/// （通道缺失 → 删 0 项，不抛异常），因此不需要 override 也能跑。
library;

import 'package:diting/data/cleanup/data_cleanup_service.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/app_version_provider.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/outbound_proxy_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 原生平台通道。`main()` 不必 override：默认实现已经把所有失败收成「不可用」。
final platformBridgeProvider = Provider<PlatformBridge>(
  (ref) => PlatformBridge(),
);

/// 清理服务。
///
/// 依赖装配在一处：动作本身只关心「删什么」，不关心 prefs 从哪来、证书服务
/// 是不是真的（测试里换成 fake 只需 override 一个 provider）。
final dataCleanupServiceProvider = Provider<DataCleanupService>((ref) {
  return DataCleanupService(
    prefs: ref.watch(legacyPrefsStoreProvider),
    platform: ref.watch(platformBridgeProvider),
    outboundProxy: ref.watch(outboundProxyStoreProvider),
    caCertificate: ref.watch(caCertificateServiceProvider),
    appVersionCode: ref.watch(appVersionProvider).code,
    openDatabase: LegacyDatabase.open,
  );
});

/// 正在执行的清理动作；页面据此禁用整张列表并显示进度。
class CleanupProgressNotifier extends Notifier<CleanupAction?> {
  @override
  CleanupAction? build() => null;

  void set(CleanupAction? action) => state = action;
}

final cleanupProgressProvider =
    NotifierProvider<CleanupProgressNotifier, CleanupAction?>(
      CleanupProgressNotifier.new,
    );

/// 执行一个动作，并让所有读数据的页面重新查表。
///
/// 刷新是必须的：清空日志后仪表盘、`/logs` 下钻页与流量页都还挂着旧行，
/// 不 bump 就会出现「清理成功，但页面还显示 3 条」。
class CleanupRunner {
  CleanupRunner(this._ref);

  final Ref _ref;

  Future<CleanupResult> run(CleanupAction action) async {
    final progress = _ref.read(cleanupProgressProvider.notifier);
    progress.set(action);
    try {
      final result = await _ref.read(dataCleanupServiceProvider).run(action);
      if (result.removed > 0 || !result.failed) _invalidate();
      return result;
    } finally {
      progress.set(null);
    }
  }

  void _invalidate() {
    // 日志 / 流量 / 缓存 / 竞速 / Bootstrap 五张表共用这一个 revision。
    _ref.read(dnsLogRevisionProvider.notifier).bump();
    // 订阅与镜像模板表有自己的计数器。
    _ref.read(subscriptionRevisionProvider.notifier).bump();
    // prefs 域（应用名单、权重、引导标记、壁纸）。
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
    // 出站代理走原生通道读，配置对象有自己的 revision。
    _ref.read(outboundProxyRevisionProvider.notifier).bump();
    // 证书状态重新探测（清证书那一条改了 `https_inspection_ready`）。
    _ref.invalidate(caCertificateStateProvider);
  }
}

final cleanupRunnerProvider = Provider<CleanupRunner>(CleanupRunner.new);

/// 每组动作的分组标题（照抄旧版 `DataCleanupScreen` 的五个 `SettingsGroupTitle`）。
const cleanupGroups = <String, List<CleanupAction>>{
  '运行数据': [
    CleanupAction.logs,
    CleanupAction.traffic,
    CleanupAction.crash,
    CleanupAction.dnsCache,
  ],
  '权重数据': [
    CleanupAction.providerWeights,
    CleanupAction.bootstrapWeights,
  ],
  '规则与订阅': [
    CleanupAction.domainRules,
    CleanupAction.addressRules,
    CleanupAction.subscriptions,
    CleanupAction.appRules,
  ],
  '存储与安全': [
    CleanupAction.outboundProxy,
    CleanupAction.caCertificate,
    CleanupAction.downloadCache,
    CleanupAction.customBackground,
  ],
  '引导与重置': [
    CleanupAction.settingsGuides,
    CleanupAction.allData,
  ],
};
