/// 数据清理的动作清单与结果模型（1.4.3 `DataCleanupScreen.CleanupAction`）。
///
/// 与执行逻辑分开：页面只需要「有哪些动作、每个动作的标题与后果」，不需要
/// 拿到数据库句柄。放在独立文件里也让 `data_cleanup_service.dart` 能专注于
/// 「怎么删」。
library;

/// 清理动作，声明顺序即页面上的分组顺序（照抄旧版 `DataCleanupScreen`）。
enum CleanupAction {
  logs('删除请求日志'),
  traffic('删除流量统计'),
  crash('删除崩溃日志'),
  dnsCache('删除 DNS 缓存'),
  providerWeights('恢复 DNS 默认权重'),
  bootstrapWeights('恢复 Bootstrap 权重'),
  domainRules('删除全部域名规则'),
  addressRules('删除全部地址规则'),
  subscriptions('删除全部规则订阅'),
  appRules('重置应用控制名单'),
  outboundProxy('重置出站代理配置'),
  caCertificate('重置 HTTPS 抓包证书'),
  downloadCache('清理下载与临时缓存'),
  customBackground('清除自定义背景缓存'),
  settingsGuides('重置所有新手引导'),
  allData('清理全部本地数据');

  const CleanupAction(this.title);

  final String title;

  /// 清理完成后是否要让整个进程退出。
  ///
  /// 旧版这两个动作调 `onExitApp()`：它们把 `initial_agreement_accepted` 也清掉
  /// 了，留在前台会得到「应用仍在运行，但下次启动要重新同意协议」的分裂状态。
  bool get exitsApp => this == settingsGuides || this == allData;

  /// 是否需要让运行中的引擎重新加载配置。
  ///
  /// 旧版 `onRuntimeDnsSettingsChanged()` 覆盖的六个动作：规则、订阅、应用名单
  /// 与出站代理都已下发给引擎，删完不刷新则引擎继续用内存里的旧副本。
  bool get affectsEngine => const {
    domainRules,
    addressRules,
    subscriptions,
    appRules,
    outboundProxy,
  }.contains(this);
}

/// 一次清理的结果：删掉了多少条目、有没有额外说明。
class CleanupResult {
  const CleanupResult({required this.action, required this.removed, this.detail});

  /// 清理失败：缺少该能力，或某一步抛了异常。[detail] 是原因。
  const CleanupResult.failed(this.action, String this.detail) : removed = 0;

  final CleanupAction action;

  /// 删除的条目数（行 / 文件 / 键）。**0 是合法结果**，不是失败。
  final int removed;

  /// 补充说明；失败时是原因。
  final String? detail;

  bool get failed => detail != null && removed == 0;

  /// 给用户看的完成文案。
  ///
  /// 条数为 0 时如实说明「没有可清理的数据」，不说「已删除」——那会让用户以为
  /// 按钮生效了，下次发现问题时无从判断。
  String get message {
    if (removed > 0) {
      final suffix = detail == null ? '' : '（$detail）';
      return '已${action.title}：$removed 项$suffix';
    }
    return detail ?? '已${action.title}：没有可清理的数据';
  }
}
