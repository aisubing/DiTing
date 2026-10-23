/// Kept-resource demo data. Initial values only; mutable copies live in
/// `lib/state/config_providers_resources.dart`.
library;

class MockIconSet {
  const MockIconSet({
    required this.name,
    required this.url,
    required this.icons,
    this.fromUrl = true,
  });

  final String name;
  final String url;

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

  final int delayMs;

  MockSsidRule copyWith({bool? cellular, bool? wifi, int? delayMs}) =>
      MockSsidRule(
        ssid: ssid,
        cellular: cellular ?? this.cellular,
        wifi: wifi ?? this.wifi,
        delayMs: delayMs ?? this.delayMs,
      );

  bool get enabled => cellular || wifi;
}

const mockSsidRules = <MockSsidRule>[
  MockSsidRule(ssid: 'Home-5G', cellular: false, delayMs: 800),
  MockSsidRule(ssid: 'Office-WiFi', cellular: true, wifi: true),
  MockSsidRule(ssid: 'Starbucks', cellular: true, wifi: false, delayMs: 1500),
];
