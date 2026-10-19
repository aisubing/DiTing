part of 'mock_config.dart';

/// 过滤器：一条正则 + 一个名字，用于在日志与连接列表里折叠噪声。
class MockFilter {
  const MockFilter({required this.label, required this.regex});

  final String label;
  final String regex;

  MockFilter copyWith({String? label, String? regex}) =>
      MockFilter(label: label ?? this.label, regex: regex ?? this.regex);
}

const mockFilters = <MockFilter>[
  MockFilter(label: '局域网广播', regex: r'^https?://192\.168\.\d+\.\d+/'),
  MockFilter(label: '遥测上报', regex: r'/v\d+/(analytics|telemetry|report)'),
  MockFilter(label: '应用商店', regex: r'://(play|app)\.google\.com/'),
  MockFilter(label: '广告 SDK', regex: r'://(umeng|growing|adjust)\.'),
  MockFilter(label: '证书校验', regex: r'://ocsp\.'),
];

/// 追加规则的种类。
enum AddedRuleKind {
  domain('DOMAIN', '精确域名'),
  domainSuffix('DOMAIN-SUFFIX', '域名后缀'),
  domainKeyword('DOMAIN-KEYWORD', '域名关键词'),
  ipCidr('IP-CIDR', 'IPv4 网段'),
  geoip('GEOIP', 'GeoIP 国家码'),
  process('PROCESS-NAME', '进程名');

  const AddedRuleKind(this.type, this.label);

  /// 规则类型字面量（写进规则行，与 mihomo 一致，不做本地化）。
  final String type;
  final String label;
}

/// 一条追加规则。
class MockAddedRule {
  const MockAddedRule({
    required this.id,
    required this.kind,
    required this.payload,
    required this.policy,
    this.noResolve = false,
  });

  final String id;
  final AddedRuleKind kind;
  final String payload;

  /// 命中的策略组名。
  final String policy;
  final bool noResolve;

  /// 上游 `Rule.searchFields`：搜索同时匹配规则内容与策略。
  List<String> get searchFields => [kind.type, payload, policy];

  String get line =>
      [kind.type, payload, policy, if (noResolve) 'no-resolve'].join(',');

  MockAddedRule copyWith({
    AddedRuleKind? kind,
    String? payload,
    String? policy,
    bool? noResolve,
  }) => MockAddedRule(
    id: id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    policy: policy ?? this.policy,
    noResolve: noResolve ?? this.noResolve,
  );
}

const mockAddedRules = <MockAddedRule>[
  MockAddedRule(
    id: 'ar-1',
    kind: AddedRuleKind.domainSuffix,
    payload: 'netflix.com',
    policy: '流媒体',
  ),
  MockAddedRule(
    id: 'ar-2',
    kind: AddedRuleKind.domainKeyword,
    payload: 'spotify',
    policy: '流媒体',
  ),
  MockAddedRule(
    id: 'ar-3',
    kind: AddedRuleKind.ipCidr,
    payload: '203.0.113.0/24',
    policy: 'DIRECT',
    noResolve: true,
  ),
  MockAddedRule(
    id: 'ar-4',
    kind: AddedRuleKind.geoip,
    payload: 'CN',
    policy: 'DIRECT',
  ),
  MockAddedRule(
    id: 'ar-5',
    kind: AddedRuleKind.domain,
    payload: 'api.internal.example.com',
    policy: '内网',
  ),
  MockAddedRule(
    id: 'ar-6',
    kind: AddedRuleKind.process,
    payload: 'Telegram.exe',
    policy: '节点选择',
  ),
];

/// 可选的策略组名，追加规则表单用。
const mockRulePolicies = <String>[
  '节点选择',
  '自动选择',
  '流媒体',
  '内网',
  'DIRECT',
  'REJECT',
];

/// 脚本（上游 `Script`）。
class MockScript {
  const MockScript({
    required this.name,
    required this.code,
    this.description,
    this.fromUrl = false,
  });

  final String name;
  final String code;
  final String? description;

  /// 由 URL 导入的脚本在列表里显示为只读来源。
  final bool fromUrl;

  MockScript copyWith({String? name, String? code}) => MockScript(
    name: name ?? this.name,
    code: code ?? this.code,
    description: description,
    fromUrl: fromUrl,
  );
}

const mockScripts = <MockScript>[
  MockScript(
    name: '广告域名清理',
    description: '在匹配规则前移除已知的广告域名',
    code: '''
function main(config, profileName) {
  config.rules = (config.rules || []).filter(
    (rule) => !rule.includes('AD-BLOCK')
  );
  return config;
}''',
  ),
  MockScript(
    name: '节点重命名',
    description: '给订阅里的节点加上地区前缀',
    fromUrl: true,
    code: '''
function main(config) {
  for (const group of config['proxy-groups'] || []) {
    group.name = `[订阅] \${group.name}`;
  }
  return config;
}''',
  ),
  MockScript(
    name: 'DNS 兜底',
    description: '未配置 DNS 时补一组国内服务商',
    code: '''
function main(config) {
  config.dns = config.dns || { enable: true };
  config.dns.nameserver = ['223.5.5.5', '119.29.29.29'];
  return config;
}''',
  ),
];

/// Clash 提供者（上游 `ClashProvider`）。
class MockClashProvider {
  const MockClashProvider({
    required this.name,
    required this.url,
    required this.behavior,
    required this.intervalLabel,
    this.fromUrl = true,
  });

  final String name;
  final String url;

  /// 行为类型：`domain` / `ipcidr` / `classical`。
  final String behavior;

  /// 更新间隔的展示值（如「24 小时」）。
  final String intervalLabel;
  final bool fromUrl;
}

const mockClashProviders = <MockClashProvider>[
  MockClashProvider(
    name: 'reject-list',
    url: 'https://rules.example.com/reject.yaml',
    behavior: 'domain',
    intervalLabel: '24 小时',
  ),
  MockClashProvider(
    name: 'cn-cidr',
    url: 'https://rules.example.com/cn-cidr.yaml',
    behavior: 'ipcidr',
    intervalLabel: '72 小时',
  ),
  MockClashProvider(
    name: 'streaming',
    url: 'https://rules.example.com/streaming.yaml',
    behavior: 'domain',
    intervalLabel: '168 小时',
  ),
];

/// 提供者上一次更新时间（展示用固定值，演示层不真的拉取）。
const mockProviderUpdatedAt = '2026-10-18 09:12';

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
