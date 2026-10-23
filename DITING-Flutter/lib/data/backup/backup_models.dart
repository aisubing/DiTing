/// Backup file format definition and groups.
///
/// A backup is a JSON object with a fixed `format`/`version` marker and a
/// `data` map keyed by [BackupGroup.key].
library;

/// Backup groups. Declaration order is the order shown on the export screen.
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

  /// Key used in `data`. Never rename: it would break existing backups.
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

/// Backup file marker and version fields.
abstract final class BackupFormat {
  /// Top-level `format` value. Changing it invalidates all existing backups.
  static const magic = 'diting-backup';

  /// Version written by this build.
  static const version = 1;

  /// Highest version this build can parse; newer backups are rejected.
  static const maxReadableVersion = 1;

  static const fileNamePrefix = 'DITING-backup';

  /// Format a timestamp as `yyyyMMdd-HHmmss` in local time.
  static String stampOf(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}

/// Backup parse/validation failure; the message is user-visible.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}
