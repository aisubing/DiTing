part of 'settings_page.dart';

/// 设置页的「功能入口」组。
///
/// 上游没有这一组：它有 9 个底栏 tab，代理/配置/连接各自占一格，设置页只放
/// 真正的设置。DITING 的底栏只有 6 格，第二轮补齐的十几个领域页需要一个稳定的
/// 入口——功能中心（`/hub`）是卡片式浏览，这里提供的是「按用途直达」的列表，
/// 两者不重复：功能中心用来发现，这里用来回访。
///
/// 一律用 `ListItem` + `onTap` 推路由，**不用** `ListItem.next`：后者的语义是
/// 「原地展开一个内联子页」，而这里的去处是真路由，用它会留下一个空的展开面板。
class _FeatureEntrySection extends StatelessWidget {
  const _FeatureEntrySection();

  @override
  Widget build(BuildContext context) {
    return generateSection(
      title: '代理与配置',
      items: [
        _routeItem(
          title: '代理',
          subtitle: '分组、节点、延迟测试与代理设置',
          glyph: AppGlyphs.proxies,
          path: ProxiesPaths.proxies,
        ),
        _routeItem(
          title: '配置档案',
          subtitle: '切换、编辑、自定义节点与代理组',
          glyph: AppGlyphs.profiles,
          path: ProfilesPaths.profiles,
        ),
        _routeItem(
          title: '订阅与规则',
          subtitle: '规则订阅、黑白名单与批量编辑',
          glyph: AppGlyphs.rules,
          path: Routes.subscriptions,
        ),
      ],
      footer: '这些页面也可在功能中心按卡片浏览。',
    );
  }
}

/// 观测与内核配置入口。
class _ObserveAndConfigSection extends StatelessWidget {
  const _ObserveAndConfigSection();

  @override
  Widget build(BuildContext context) {
    return generateSection(
      title: '观测与内核',
      items: [
        _routeItem(
          title: '连接',
          subtitle: '活动连接、链路与关闭操作',
          glyph: AppGlyphs.connections,
          path: ObservabilityPaths.connections,
        ),
        _routeItem(
          title: 'DNS 查询',
          subtitle: '查询记录、失败原因与缓存',
          glyph: AppGlyphs.dns,
          path: ObservabilityPaths.dnsQueries,
        ),
        _routeItem(
          title: '资源更新',
          subtitle: 'Geo、图标集、规则提供者与脚本',
          glyph: AppGlyphs.resources,
          path: ObservabilityPaths.resources,
        ),
        _routeItem(
          title: '网络设置',
          subtitle: 'VPN、TUN、IPv6 与路由',
          glyph: AppGlyphs.wifi,
          path: ConfigPaths.network,
        ),
        _routeItem(
          title: '通用设置',
          subtitle: '日志级别、端口、鉴权与 Hosts',
          glyph: AppGlyphs.sliders,
          path: ConfigPaths.general,
        ),
        _routeItem(
          title: '覆写编辑器',
          subtitle: '按字段类型改内核配置',
          glyph: AppGlyphs.compose,
          path: ConfigPaths.override,
        ),
      ],
    );
  }
}

/// 系统与安全入口。
class _SystemSection extends StatelessWidget {
  const _SystemSection();

  @override
  Widget build(BuildContext context) {
    return generateSection(
      title: '系统与安全',
      items: [
        _routeItem(
          title: '应用访问控制',
          subtitle: '按应用允许或禁止走代理',
          glyph: AppGlyphs.appsList,
          path: SystemPaths.access,
        ),
        _routeItem(
          title: '备份与恢复',
          subtitle: '本地导出与 WebDAV 同步',
          glyph: AppGlyphs.cloudDownload,
          path: SystemPaths.backup,
        ),
        _routeItem(
          title: '免责声明',
          subtitle: '使用须知与免责条款',
          glyph: AppGlyphs.gavel,
          path: SystemPaths.disclaimer,
        ),
        _routeItem(
          title: '开发者选项',
          subtitle: '调试开关与诊断动作',
          glyph: AppGlyphs.wrench,
          path: SystemPaths.developer,
        ),
        _routeItem(
          title: '检查更新',
          subtitle: '版本对比与更新日志',
          glyph: AppGlyphs.refresh,
          path: SystemPaths.appUpdate,
        ),
        _routeItem(
          title: '赞助与共建',
          subtitle: '支持项目持续维护',
          glyph: AppGlyphs.star,
          path: SystemPaths.sponsor,
        ),
      ],
      footer: '免责声明首次启动时必须同意；本演示不强制。',
    );
  }
}

/// 一行「图标 + 标题 + 副标题 + 右箭头」的跳转项。
///
/// 设置页里所有跳转都用这一个工厂，保证行高、箭头尺寸、副标题省略规则一致。
Widget _routeItem({
  required String title,
  required String subtitle,
  required Glyph glyph,
  required String path,
}) {
  return _RouteItem(
    title: title,
    subtitle: subtitle,
    glyph: glyph,
    path: path,
  );
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.path,
  });

  final String title;
  final String subtitle;
  final Glyph glyph;
  final String path;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: GlyphIcon(glyph),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
      onTap: () => context.push(path),
    );
  }
}
