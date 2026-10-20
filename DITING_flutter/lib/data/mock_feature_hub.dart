part of 'mock_data.dart';

/// 功能中心的一张卡。
///
/// 上游 `FeatureHubScreen.kt` 的卡片只有图标与标题；本仓的卡片组件多一行
/// 副标题，因此复用同一个 `description` 作为副标题，隐藏功能管理页也用它
/// 作为说明文案，避免两份文案漂移。
class MockFeatureCard {
  const MockFeatureCard({
    required this.title,
    required this.description,
    required this.glyphName,
    required this.route,
    this.featureKey,
    this.expressVisible = true,
    this.longPressRoute,
  });

  final String title;
  final String description;
  final String glyphName;
  final String route;

  /// 隐藏功能键；为空表示固定常驻、不可隐藏（隐藏功能管理卡自己）。
  final String? featureKey;

  /// 极速模式是否保留这张卡（上游 18 项门控 + 1 张固定卡）。
  final bool expressVisible;

  /// 长按动作；上游只有「日志」卡有。
  final String? longPressRoute;

  bool get isFixed => featureKey == null;
}

/// 功能中心的一个分类（上游 7 类 28 卡）。
class MockFeatureCategory {
  const MockFeatureCategory({
    required this.title,
    required this.cards,
  });

  final String title;
  final List<MockFeatureCard> cards;
}

/// 功能中心分类。
///
/// 路由全部写成字面量而不是引用 `lib/routes/routes.dart` 的常量：本文件是
/// `mock_data.dart` 的 part，不能 import。**改路由常量时必须同步这里**，
/// `test/route_catalog_test.dart` 会校验两者一致，漏改会红。
const mockFeatureCategories = <MockFeatureCategory>[
  MockFeatureCategory(
    title: 'DNS 服务',
    cards: [
      MockFeatureCard(
        title: '服务商管理',
        description: '配置与管理 DoH、DoT 与传统 DNS 解析服务商',
        glyphName: 'dns',
        route: '/hub/providers',
        featureKey: 'provider_management',
      ),
      MockFeatureCard(
        title: '引导解析设置',
        description: '配置用于首次解析加密上游域名的引导 DNS 节点',
        glyphName: 'language',
        route: '/hub/bootstrap',
        featureKey: 'bootstrap_settings',
      ),
      MockFeatureCard(
        title: '解析模式',
        description: '选择单一服务、智能选择、最快响应或依次尝试策略',
        glyphName: 'shuffle',
        route: '/hub/resolution',
        featureKey: 'resolution_mode',
      ),
      MockFeatureCard(
        title: '缓存设置',
        description: '配置 DNS 缓存开关、缓存策略与最大最小生存时间 (TTL)',
        glyphName: 'memory',
        route: '/hub/cache',
        featureKey: 'cache_settings',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '策略与规则',
    cards: [
      MockFeatureCard(
        title: '规则控制',
        description: '统一管理拦截策略开关与在线网络规则订阅',
        glyphName: 'rules',
        route: '/hub/rules',
        featureKey: 'rule_control',
      ),
      MockFeatureCard(
        title: '黑名单',
        description: '自定义屏蔽域名列表，匹配时返回拦截响应',
        glyphName: 'block',
        route: '/rules/block',
        featureKey: 'blacklist',
      ),
      MockFeatureCard(
        title: '白名单',
        description: '自定义放行域名列表，豁免所有规则直接放行',
        glyphName: 'verified',
        route: '/rules/allow',
        featureKey: 'whitelist',
      ),
      MockFeatureCard(
        title: '覆写名单',
        description: '自定义域名覆写指向特定 IPv4/IPv6 或 CNAME',
        glyphName: 'swap',
        route: '/rules/rewrite',
        featureKey: 'rewrite_list',
        expressVisible: false,
      ),
    ],
  ),
  MockFeatureCategory(
    title: '网络控制',
    cards: [
      MockFeatureCard(
        title: '应用流量统计',
        description: '统计各应用的网络连接数、上传与下载流量明细',
        glyphName: 'dataUsage',
        route: '/traffic',
        featureKey: 'traffic_stats',
        expressVisible: false,
      ),
      MockFeatureCard(
        title: '应用独立规则',
        description: '为特定应用单独指定专属域名放行与网络规则',
        glyphName: 'appsList',
        route: '/hub/app-rules',
        featureKey: 'app_rules',
        expressVisible: false,
      ),
      MockFeatureCard(
        title: '禁止联网应用',
        description: '在本地隧道层拦截指定应用的全部网络外联',
        glyphName: 'wifiOff',
        route: '/hub/blocked-apps',
        featureKey: 'blocked_apps',
        expressVisible: false,
      ),
      MockFeatureCard(
        title: '排除应用',
        description: '允许指定应用绕过本软件直连网络',
        glyphName: 'appsList',
        route: '/hub/excluded-apps',
        featureKey: 'excluded_apps',
        expressVisible: false,
      ),
    ],
  ),
  MockFeatureCategory(
    title: '高级与诊断',
    cards: [
      MockFeatureCard(
        title: 'HTTPS 流量检查',
        description: '解密并检查特定应用的 HTTP(S) 流量，支持域名与 URL 过滤',
        glyphName: 'target',
        route: '/hub/https-inspection',
        featureKey: 'https_inspection',
        expressVisible: false,
      ),
      MockFeatureCard(
        title: '出站代理',
        description: '将过滤后的流量转发到本地 SOCKS5 或 HTTP 代理',
        glyphName: 'link',
        route: '/hub/outbound-proxy',
        featureKey: 'outbound_proxy',
        expressVisible: false,
      ),
      MockFeatureCard(
        title: '网络诊断',
        description: '提供 DNS 查询、Ping 延迟测试与网络连通性诊断工具',
        glyphName: 'speed',
        route: '/tools',
        featureKey: 'network_tools',
        expressVisible: false,
      ),
      MockFeatureCard(
        title: 'AI 分析',
        description: '配置大语言模型接口与密钥，用于日志研判与网络流量分析',
        glyphName: 'sparkle',
        route: '/hub/agent',
        featureKey: 'agent_api',
        expressVisible: false,
      ),
    ],
  ),
  MockFeatureCategory(
    title: '界面与设置',
    cards: [
      MockFeatureCard(
        title: '外观调整',
        description: '自定义日夜模式、主题色彩、组件透明度与软件壁纸背景',
        glyphName: 'palette',
        route: '/theme',
        featureKey: 'appearance',
      ),
      MockFeatureCard(
        title: '服务显示',
        description: '自定义在首页解析服务下拉列表中显示的服务商',
        glyphName: 'eye',
        route: '/hub/provider-visibility',
        featureKey: 'service_display',
      ),
      MockFeatureCard(
        title: '隐藏功能',
        description: '自定义在功能中心显示的功能卡片，不改后台运行',
        glyphName: 'eyeOff',
        route: '/hub/hidden-features',
      ),
      MockFeatureCard(
        title: '其他设置',
        description: '语言切换、前后台行为、通知设置等全局配置',
        glyphName: 'settings',
        route: '/settings',
        featureKey: 'other_settings',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '数据与维护',
    cards: [
      MockFeatureCard(
        title: '日志',
        description: '实时解析统计、请求明细查询与日志导出',
        glyphName: 'logs',
        route: '/logs',
        featureKey: 'logs',
        longPressRoute: '/hub/log-retention',
      ),
      MockFeatureCard(
        title: '备份与迁移',
        description: '导出与导入服务商、规则订阅及个性化设置',
        glyphName: 'export',
        route: '/hub/config-transfer',
        featureKey: 'data_management',
      ),
      MockFeatureCard(
        title: '数据清理',
        description: '删除缓存、日志或域名与地址过滤规则',
        glyphName: 'broom',
        route: '/hub/data-cleanup',
        featureKey: 'data_cleanup',
      ),
      MockFeatureCard(
        title: '更新与支持',
        description: '检查软件新版本发布、查看更新日志',
        glyphName: 'refresh',
        route: '/app-update',
        featureKey: 'app_update',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '关于谛听',
    cards: [
      MockFeatureCard(
        title: '应用信息',
        description: '查看软件版本信息、核心技术架构与开源地址',
        glyphName: 'info',
        route: '/about',
        featureKey: 'app_info',
      ),
      MockFeatureCard(
        title: '赞助',
        description: '支持谛听项目持续维护与开发',
        glyphName: 'star',
        route: '/sponsor',
        featureKey: 'sponsor',
      ),
      MockFeatureCard(
        title: '赞助者名单',
        description: '鸣谢支持谛听项目的赞助者',
        glyphName: 'verified',
        route: '/hub/sponsor-list',
        featureKey: 'sponsor_list',
      ),
      MockFeatureCard(
        title: '共建者名单',
        description: '感谢为谛听贡献代码与建议的共建者',
        glyphName: 'account',
        route: '/hub/co-builders',
        featureKey: 'contributors',
      ),
    ],
  ),
];

/// 一个可被隐藏的功能（隐藏功能管理页的数据源）。
class MockHiddenFeature {
  const MockHiddenFeature({
    required this.key,
    required this.title,
    required this.description,
    required this.glyphName,
    required this.category,
    required this.expressVisible,
    required this.route,
  });

  final String key;
  final String title;
  final String description;
  final String glyphName;
  final String category;
  final bool expressVisible;
  final String route;
}

/// 全部可隐藏功能，顺序与功能中心卡片一致；固定卡不在其中。
final List<MockHiddenFeature> mockHiddenFeatures = [
  for (final category in mockFeatureCategories)
    for (final card in category.cards)
      if (card.featureKey case final key?)
        MockHiddenFeature(
          key: key,
          title: card.title,
          description: card.description,
          glyphName: card.glyphName,
          category: category.title,
          expressVisible: card.expressVisible,
          route: card.route,
        ),
];

/// 按分类分组后的隐藏功能，供管理页按上游顺序渲染。
Map<String, List<MockHiddenFeature>> hiddenFeaturesByCategory({required bool express}) {
  final result = <String, List<MockHiddenFeature>>{};
  for (final feature in mockHiddenFeatures) {
    if (express && !feature.expressVisible) {
      continue;
    }
    result.putIfAbsent(feature.category, () => []).add(feature);
  }
  return result;
}

/// 当前模式可见的分类（已过滤隐藏键，并剔除空分类）。
List<MockFeatureCategory> visibleFeatureCategories({
  required bool express,
  required Set<String> hiddenKeys,
}) {
  final result = <MockFeatureCategory>[];
  for (final category in mockFeatureCategories) {
    final cards = [
      for (final card in category.cards)
        if ((!express || card.expressVisible) &&
            (card.isFixed || !hiddenKeys.contains(card.featureKey)))
          card,
    ];
    if (cards.isNotEmpty) {
      result.add(MockFeatureCategory(title: category.title, cards: cards));
    }
  }
  return result;
}
