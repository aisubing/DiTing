/// 备份文件的格式定义与分组（1.4.3 `ui/transfer/TransferConfigDto.kt` 的等价物）。
///
/// ## 格式约定
///
/// 一份备份是一个 JSON 对象，顶层固定两把键：
///
/// ```json
/// { "format": "diting-backup", "version": 1, "exportedAt": 1690000000000,
///   "selection": ["providers", "subscriptions", ...],
///   "data": { "providers": {...}, "subscriptions": [...], ... } }
/// ```
///
/// `format` 与 `version` 必须校验：这是用户从文件管理器随手挑来的文件也能进到
/// 解析器的入口，不做标记校验会把任意 JSON（甚至是别的应用的备份）当成自己的
/// 配置写进库里。旧版 `ConfigTransferParser.FORMAT_VERSION` 同样先校验。
///
/// ## 为什么 backupGroup 是字符串而不是枚举索引
///
/// 分组键同时出现在导出勾选清单、`data` 的键、以及导入汇总的文案里。用索引时
/// 增删一项就会让已导出的旧备份全部错位，而错位的表现是「导入成功但数据串到了
/// 另一组」——不报错，只是错了。
library;

/// 备份分组。声明顺序即页面上的勾选顺序（照抄旧版 `ConfigTransferScreen` 五组）。
enum BackupGroup {
  providers('providers', '自定义 DNS 服务商', 'DoH、DoT 服务商与解析配置'),
  bootstrap('bootstrap', '自定义 Bootstrap IP', '引导 DNS 节点与启用状态'),
  cache('cache', 'DNS 缓存策略', 'DNS 缓存开关、预设与 TTL 控制'),
  outbound('outbound', '出站代理配置', 'SOCKS5 / HTTP 代理与代理应用，不含账号密码'),
  subscriptions('subscriptions', '网络规则订阅', '订阅源链接、镜像加速与自动更新'),
  domainRules('domainRules', '自定义屏蔽域名规则', '手动添加的域名屏蔽规则及状态'),
  rewriteDomain('rewriteDomain', '自定义复写域名规则', 'IPv4 / IPv6 域名覆写规则'),
  rewriteCname('rewriteCname', '自定义复写 CNAME 规则', 'CNAME 域名覆写规则'),
  addressRules('addressRules', '自定义屏蔽地址规则', 'URL 路径屏蔽规则'),
  excluded('excluded', '排除应用名单', '绕过过滤使用系统 DNS 的应用'),
  blocked('blocked', '禁止联网名单', '服务运行时禁止联网的应用'),
  allowlist('allowlist', '应用独立规则与放行', '单应用放行规则与域名白名单'),
  httpInspection('httpInspection', 'HTTPS 抓包检测配置', '流量抓包开关与目标应用名单'),
  appearance('appearance', '外观与界面个性化', '主题风格、组件透明度与标语'),
  system('system', '系统与通用设置', '局域网绕行、日志模式、语言与通知');

  const BackupGroup(this.key, this.title, this.description);

  /// `data` 里使用的键；**不可改名**，否则旧备份读不出来。
  final String key;
  final String title;
  final String description;

  static BackupGroup? fromKey(String? key) {
    for (final group in values) {
      if (group.key == key) return group;
    }
    return null;
  }
}

/// 备份文件标记与版本。
abstract final class BackupFormat {
  /// 顶层 `format` 值。改它等于让所有旧备份失效，不要改。
  static const magic = 'diting-backup';

  /// 当前写出的版本。
  static const version = 1;

  /// 能读进来的最高版本。更高版本说明是新版应用写的，本版无法安全解析。
  static const maxReadableVersion = 1;

  /// 文件名前缀，后面接时间戳。
  static const fileNamePrefix = 'DITING-backup';

  /// 把时间戳格式化成 `yyyyMMdd-HHmmss`（本地时区）。
  static String stampOf(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}

/// 解析/校验失败的原因，直接作为用户可见文案。
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}
