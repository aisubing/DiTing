/// 配置域的「保留资源」演示数据：图标集 / User-Agent / 按需连接。
///
/// 上一轮这里是 `part of mock_config.dart`，与过滤器、追加规则、脚本、Clash
/// 提供者四族数据挤在同一个库里。那四族属于 FlClash 的代理内核，1.4.3 没有
/// 对应物，已随内核配置页一并删除；本库因此收敛成一个独立 library，只保留
/// 三张用户要求保留的表。
///
/// 只放**初始值**：可变副本由 `lib/state/config_providers_resources.dart` 持有，
/// 混在一起会让热重载后的「用户改过的状态」污染初始值。
library;

/// 图标集（上游 `IconSet`）。
class MockIconSet {
  const MockIconSet({
    required this.name,
    required this.url,
    required this.icons,
    this.fromUrl = true,
  });

  final String name;
  final String url;

  /// 集内图标名，预览页按网格铺开。
  final List<String> icons;
  final bool fromUrl;
}

const mockIconSets = <MockIconSet>[
  MockIconSet(
    name: 'DITING 官方图标',
    url: 'https://icons.example.com/DITING.json',
    icons: [
      'clash',
      'direct',
      'reject',
      'auto',
      'cn',
      'hk',
      'jp',
      'sg',
      'us',
      'uk',
      'tw',
      'kr',
      'streaming',
      'telegram',
      'github',
    ],
  ),
  MockIconSet(
    name: '地区旗帜',
    url: 'https://icons.example.com/flags.json',
    icons: [
      'flag-cn',
      'flag-hk',
      'flag-jp',
      'flag-sg',
      'flag-us',
      'flag-uk',
      'flag-tw',
      'flag-kr',
      'flag-de',
    ],
  ),
  MockIconSet(
    name: '自建补充',
    url: 'https://icons.example.com/custom.json',
    fromUrl: false,
    icons: ['home', 'office', 'nas', 'router', 'printer'],
  ),
];

/// User-Agent 列表。
class MockUserAgent {
  const MockUserAgent({required this.value, this.isDefault = false});

  final String value;
  final bool isDefault;
}

const mockUserAgents = <MockUserAgent>[
  MockUserAgent(value: 'clash-verge/v2.0.0', isDefault: true),
  MockUserAgent(
    value:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/126.0.0.0 Safari/537.36',
  ),
  MockUserAgent(
    value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
  ),
  MockUserAgent(value: 'curl/8.7.1'),
];

/// 按需连接的 SSID 白名单条目。
class MockSsidRule {
  const MockSsidRule({
    required this.ssid,
    this.cellular = true,
    this.wifi = true,
    this.delayMs = 0,
  });

  final String ssid;
  final bool cellular;
  final bool wifi;

  /// 连接后的等待时间；0 表示立即代理。
  final int delayMs;

  MockSsidRule copyWith({bool? cellular, bool? wifi, int? delayMs}) =>
      MockSsidRule(
        ssid: ssid,
        cellular: cellular ?? this.cellular,
        wifi: wifi ?? this.wifi,
        delayMs: delayMs ?? this.delayMs,
      );

  /// 「已连接该 SSID 时是否启用代理」。
  bool get enabled => cellular || wifi;
}

const mockSsidRules = <MockSsidRule>[
  MockSsidRule(ssid: 'Home-5G', cellular: false, delayMs: 800),
  MockSsidRule(ssid: 'Office-WiFi', cellular: true, wifi: true),
  MockSsidRule(ssid: 'Starbucks', cellular: true, wifi: false, delayMs: 1500),
];
