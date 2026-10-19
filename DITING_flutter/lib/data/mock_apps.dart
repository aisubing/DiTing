part of 'mock_data.dart';


/// 应用流量排行。
class MockAppTraffic {
  const MockAppTraffic({
    required this.name,
    required this.packageName,
    required this.bytes,
    required this.queries,
    required this.iconGlyphName,
  });

  final String name;
  final String packageName;
  final int bytes;
  final int queries;
  final String iconGlyphName;
}

const mockAppTraffic = <MockAppTraffic>[
  MockAppTraffic(
    name: '浏览器',
    packageName: 'com.example.browser',
    bytes: 428_000_000,
    queries: 8214,
    iconGlyphName: 'language',
  ),
  MockAppTraffic(
    name: '视频',
    packageName: 'com.example.video',
    bytes: 1_284_000_000,
    queries: 3120,
    iconGlyphName: 'playPause',
  ),
  MockAppTraffic(
    name: '即时通讯',
    packageName: 'com.example.im',
    bytes: 96_400_000,
    queries: 2740,
    iconGlyphName: 'send',
  ),
  MockAppTraffic(
    name: '应用商店',
    packageName: 'com.example.store',
    bytes: 742_000_000,
    queries: 1180,
    iconGlyphName: 'cloudDownload',
  ),
  MockAppTraffic(
    name: '邮件',
    packageName: 'com.example.mail',
    bytes: 12_800_000,
    queries: 642,
    iconGlyphName: 'cloudSync',
  ),
  MockAppTraffic(
    name: '系统更新',
    packageName: 'com.android.updater',
    bytes: 318_000_000,
    queries: 84,
    iconGlyphName: 'refresh',
  ),
];

/// 已安装应用（应用选择页）。
class MockInstalledApp {
  const MockInstalledApp({
    required this.name,
    required this.packageName,
    required this.category,
  });

  final String name;
  final String packageName;
  final String category;
}

const mockInstalledApps = <MockInstalledApp>[
  MockInstalledApp(name: '浏览器', packageName: 'com.example.browser', category: '工具'),
  MockInstalledApp(name: '视频', packageName: 'com.example.video', category: '娱乐'),
  MockInstalledApp(name: '即时通讯', packageName: 'com.example.im', category: '社交'),
  MockInstalledApp(name: '应用商店', packageName: 'com.example.store', category: '工具'),
  MockInstalledApp(name: '邮件', packageName: 'com.example.mail', category: '办公'),
  MockInstalledApp(name: '音乐', packageName: 'com.example.music', category: '娱乐'),
  MockInstalledApp(name: '地图', packageName: 'com.example.maps', category: '出行'),
  MockInstalledApp(name: '相机', packageName: 'com.example.camera', category: '系统'),
  MockInstalledApp(name: '记事本', packageName: 'com.example.notes', category: '办公'),
  MockInstalledApp(name: '天气', packageName: 'com.example.weather', category: '生活'),
  MockInstalledApp(name: '阅读', packageName: 'com.example.reader', category: '阅读'),
  MockInstalledApp(name: '游戏中心', packageName: 'com.example.games', category: '游戏'),
];

/// 功能中心的一张卡。
class MockFeatureCard {
  const MockFeatureCard({
    required this.title,
    required this.subtitle,
    required this.glyphName,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String glyphName;
  final String route;
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

const mockFeatureCategories = <MockFeatureCategory>[
  MockFeatureCategory(
    title: '规则与订阅',
    cards: [
      MockFeatureCard(
        title: '黑名单',
        subtitle: '12 条自定义规则',
        glyphName: 'block',
        route: '/rules/block',
      ),
      MockFeatureCard(
        title: '白名单',
        subtitle: '6 条放行规则',
        glyphName: 'checkCircle',
        route: '/rules/allow',
      ),
      MockFeatureCard(
        title: '覆写名单',
        subtitle: '5 条改写规则',
        glyphName: 'swap',
        route: '/rules/rewrite',
      ),
      MockFeatureCard(
        title: '批量编辑',
        subtitle: '按行粘贴规则',
        glyphName: 'paste',
        route: '/rules/batch',
      ),
      MockFeatureCard(
        title: '规则订阅',
        subtitle: '5 个订阅 · 4 个分组',
        glyphName: 'cloudSync',
        route: '/subscriptions',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '应用与分流',
    cards: [
      MockFeatureCard(
        title: '应用选择',
        subtitle: '12 个已安装应用',
        glyphName: 'appsList',
        route: '/apps',
      ),
      MockFeatureCard(
        title: '服务商管理',
        subtitle: '6 个解析服务商',
        glyphName: 'dns',
        route: '/server',
      ),
      MockFeatureCard(
        title: '阻断响应',
        subtitle: 'NXDOMAIN',
        glyphName: 'gavel',
        route: '/demo',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '观测',
    cards: [
      MockFeatureCard(
        title: '日志仪表盘',
        subtitle: '请求 / 缓存 / 竞速',
        glyphName: 'logs',
        route: '/logs',
      ),
      MockFeatureCard(
        title: '流量统计',
        subtitle: '本日 2.88 GB',
        glyphName: 'dataUsage',
        route: '/traffic',
      ),
      MockFeatureCard(
        title: '网络工具',
        subtitle: '测速 / Ping / DNS / 路由',
        glyphName: 'tools',
        route: '/tools',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '智能',
    cards: [
      MockFeatureCard(
        title: 'AI 助手',
        subtitle: '分析域名与规则',
        glyphName: 'sparkle',
        route: '/agent',
      ),
    ],
  ),
  MockFeatureCategory(
    title: '系统',
    cards: [
      MockFeatureCard(
        title: '设置',
        subtitle: '外观 / 解析 / 底栏',
        glyphName: 'settings',
        route: '/settings',
      ),
      MockFeatureCard(
        title: '服务器模式',
        subtitle: '局域网 DNS',
        glyphName: 'vpn',
        route: '/server',
      ),
      MockFeatureCard(
        title: '关于',
        subtitle: '版本 1.4.3',
        glyphName: 'info',
        route: '/about',
      ),
      MockFeatureCard(
        title: '组件画廊',
        subtitle: '全部基础组件',
        glyphName: 'palette',
        route: '/demo',
      ),
    ],
  ),
];

/// 流量环形图 / 实时速率的采样序列（KB/s）。
const mockTrafficSamples = <double>[
  182, 240, 198, 320, 412, 388, 296, 344, 508, 462,
  398, 274, 318, 402, 486, 522, 448, 372, 296, 340,
  418, 364, 288, 246, 312, 396, 442, 386, 322, 268,
];

/// 设置页的五个透明度滑杆值域（0.1–1.0，`steps: 8`）。
const opacitySliderSteps = 8;
const opacitySliderMin = 0.1;
const opacitySliderMax = 1.0;
