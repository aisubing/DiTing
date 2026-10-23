library;

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

  /// Whether the process must exit after this action; both also clear `initial_agreement_accepted`.
  bool get exitsApp => this == settingsGuides || this == allData;

  /// Whether the engine must reload afterwards, or it keeps using the stale copy.
  bool get affectsEngine => const {
    domainRules,
    addressRules,
    subscriptions,
    appRules,
    outboundProxy,
  }.contains(this);
}

class CleanupResult {
  const CleanupResult({required this.action, required this.removed, this.detail});

  const CleanupResult.failed(this.action, String this.detail) : removed = 0;

  final CleanupAction action;

  /// Removed rows / files / keys. Zero is a valid result, not a failure.
  final int removed;

  final String? detail;

  bool get failed => detail != null && removed == 0;

  /// User-facing message; with zero rows it says there was nothing to clean.
  String get message {
    if (removed > 0) {
      final suffix = detail == null ? '' : '（$detail）';
      return '已${action.title}：$removed 项$suffix';
    }
    return detail ?? '已${action.title}：没有可清理的数据';
  }
}
