/// 表单与特殊页的演示数据：字体族、表单样例、键值对、命名 URL、规则预设、
/// YAML 文本、错误详情、IP 质量报告。
///
/// 全部是常量，页面只读；需要可变的部分（列表顺序、勾选）由页面自己的
/// `State` 持有——这些数据没有跨页共享的必要。
library;

/// 字体族选项。
///
/// 本仓只打包了 JetBrainsMono 与 Twemoji 两个字族，其余取系统字体名：演示层
/// 不读系统字体表（那要平台通道），选了没有的字族会自然回退到默认字体，
/// 正好可以演示「fallback」这一行为。
class MockFontFamily {
  const MockFontFamily({
    required this.family,
    required this.label,
    required this.description,
    this.bundled = false,
  });

  /// 传给 `TextStyle.fontFamily` 的值；`null` 表示系统默认。
  final String? family;
  final String label;
  final String description;

  /// 是否是本仓打包的字体（一定可用）。
  final bool bundled;
}

const mockFontFamilies = <MockFontFamily>[
  MockFontFamily(
    family: null,
    label: '系统默认',
    description: '跟随宿主平台的中文界面字体，最稳妥的选择',
  ),
  MockFontFamily(
    family: 'JetBrainsMono',
    label: 'JetBrains Mono',
    description: '等宽，日志与规则列表的默认字体',
    bundled: true,
  ),
  MockFontFamily(
    family: 'Twemoji',
    label: 'Twemoji',
    description: '彩色 Emoji 字体，只影响表情符号',
    bundled: true,
  ),
  MockFontFamily(
    family: 'HarmonyOS Sans SC',
    label: 'HarmonyOS Sans SC',
    description: '鸿蒙系统中文黑体，仅在该系统可用',
  ),
  MockFontFamily(
    family: 'MiSans',
    label: 'MiSans',
    description: '小米系统字体，部分机型预装',
  ),
  MockFontFamily(
    family: 'Noto Sans SC',
    label: 'Noto Sans SC',
    description: 'Android 常见预装中文无衬线体',
  ),
  MockFontFamily(
    family: 'Source Han Serif SC',
    label: '思源宋体',
    description: '衬线中文字体，正文阅读更接近纸面',
  ),
  MockFontFamily(
    family: 'Courier New',
    label: 'Courier New',
    description: '经典等宽英文字体，中文会回退',
  ),
];

/// 规则预设（上游 `features/form/rule_preset.dart`）。
class MockRulePreset {
  const MockRulePreset({
    required this.title,
    required this.description,
    required this.glyphName,
    required this.rules,
  });

  final String title;
  final String description;
  final String glyphName;
  final List<String> rules;
}

const mockRulePresets = <MockRulePreset>[
  MockRulePreset(
    title: '阻断 QUIC',
    description: '强制回落 TCP，便于规则生效',
    glyphName: 'block',
    rules: ['AND,((NETWORK,UDP),(DST-PORT,443)),REJECT-DROP'],
  ),
  MockRulePreset(
    title: '阻断 STUN',
    description: '阻止 WebRTC 穿透暴露本机地址',
    glyphName: 'eyeOff',
    rules: ['AND,((NETWORK,UDP),(DST-PORT,3478/19302)),REJECT-DROP'],
  ),
  MockRulePreset(
    title: '阻断 DoT',
    description: '禁用 853 端口的加密 DNS，避免绕过本机解析',
    glyphName: 'dns',
    rules: ['DST-PORT,853,REJECT'],
  ),
  MockRulePreset(
    title: '阻断回环',
    description: '防止连接 0.0.0.0 / :: 命中本机监听端口',
    glyphName: 'sync',
    rules: [
      'IP-CIDR,127.0.0.0/8,REJECT,no-resolve',
      'IP-CIDR,0.0.0.0/32,REJECT,no-resolve',
      'IP-CIDR6,::1/128,REJECT,no-resolve',
      'IP-CIDR6,::/128,REJECT,no-resolve',
    ],
  ),
  MockRulePreset(
    title: '局域网直连',
    description: '内网地址与私有域名不走上游解析',
    glyphName: 'wifi',
    rules: ['GEOSITE,private,DIRECT', 'GEOIP,LAN,DIRECT,no-resolve'],
  ),
  MockRulePreset(
    title: '系统服务直连',
    description: 'Apple / Microsoft 的系统域名放行，避免推送失效',
    glyphName: 'devices',
    rules: ['GEOSITE,apple,DIRECT', 'GEOSITE,microsoft,DIRECT'],
  ),
  MockRulePreset(
    title: 'BT 直连',
    description: '下载器与公网 Tracker 不经过解析层',
    glyphName: 'cloudDownload',
    rules: [
      'GEOSITE,category-public-tracker,DIRECT',
      'GEOSITE,category-pt,DIRECT',
      r'PROCESS-NAME-REGEX,(?i)^(qbittorrent|transmission.*|aria2z|motrix)(\.exe)?$,DIRECT',
    ],
  ),
];

/// 演示用的 YAML 配置片段（编辑器骨架的初始内容）。
const mockYamlDocument = '''
# 谛听演示配置 —— 静态高亮，不接真实解析器
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: false

dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - https://dns.alidns.com/dns-query
  fallback:
    - tls://1.1.1.1:853

proxies:
  - name: "香港 01"
    type: ss
    server: hk01.example.com
    port: 8388
    cipher: aes-256-gcm
  - name: "东京 02"
    type: trojan
    server: jp02.example.com
    port: 443

proxy-groups:
  - name: 自动选择
    type: url-test
    proxies: [香港 01, 东京 02]
  - name: 手动切换
    type: select
    proxies: [自动选择, DIRECT]

rules:
  - DOMAIN-SUFFIX,ads.example.com,REJECT
  - GEOSITE,category-ads-all,REJECT
  - GEOIP,CN,DIRECT
  - MATCH,自动选择
''';

/// 补全候选词（编辑器浮层用）。
class MockCompletion {
  const MockCompletion({
    required this.label,
    required this.detail,
    this.isKey = false,
  });

  final String label;
  final String detail;

  /// YAML 顶层键用不同颜色，和值区分开。
  final bool isKey;
}

const mockCompletions = <MockCompletion>[
  MockCompletion(label: 'mixed-port', detail: '端口', isKey: true),
  MockCompletion(label: 'allow-lan', detail: '布尔', isKey: true),
  MockCompletion(label: 'mode', detail: 'rule / global / direct', isKey: true),
  MockCompletion(label: 'log-level', detail: 'info / warning', isKey: true),
  MockCompletion(label: 'ipv6', detail: '布尔', isKey: true),
  MockCompletion(label: 'dns', detail: '区块', isKey: true),
  MockCompletion(label: 'proxies', detail: '区块', isKey: true),
  MockCompletion(label: 'proxy-groups', detail: '区块', isKey: true),
  MockCompletion(label: 'rules', detail: '区块', isKey: true),
  MockCompletion(label: 'fake-ip-range', detail: 'CIDR', isKey: true),
  MockCompletion(label: 'nameserver', detail: '列表', isKey: true),
  MockCompletion(label: 'fallback', detail: '列表', isKey: true),
  MockCompletion(label: 'DOMAIN-SUFFIX', detail: '规则类型'),
  MockCompletion(label: 'DOMAIN-KEYWORD', detail: '规则类型'),
  MockCompletion(label: 'GEOSITE', detail: '规则类型'),
  MockCompletion(label: 'GEOIP', detail: '规则类型'),
  MockCompletion(label: 'MATCH', detail: '兜底规则'),
  MockCompletion(label: 'DIRECT', detail: '策略'),
  MockCompletion(label: 'REJECT', detail: '策略'),
  MockCompletion(label: 'REJECT-DROP', detail: '策略'),
];

/// 错误页的演示数据。
class MockErrorDetail {
  const MockErrorDetail({
    required this.code,
    required this.title,
    required this.description,
    required this.stack,
  });

  final String code;
  final String title;
  final String description;
  final String stack;
}

const mockErrorDetail = MockErrorDetail(
  code: 'DITING-CORE-4302',
  title: '内核启动失败',
  description: '内核在 3 次重试后仍未能在 10 秒内完成握手。'
      '常见原因是配置文件端口冲突，或上一次运行的内核进程没有正常退出。',
  stack: '''
#0      CoreProcess.start (package:diting/core/process.dart:142)
#1      CoreManager._launch (package:diting/core/manager.dart:88)
#2      Future._propagateToListeners (dart:async/future_impl.dart:852)
#3      _RootZone.runUnary (dart:async/zone.dart:1618)
#4      CoreManager.start (package:diting/core/manager.dart:41)
#5      ServiceState.apply (package:diting/service/state.dart:203)
#6      _ServiceIntentHandler.handle (package:diting/service/handler.dart:77)
#7      MethodChannel._invokeMethod (package:flutter/src/services/platform_channel.dart:344)
#8      AppBootstrap.run (package:diting/app/bootstrap.dart:52)
#9      main (package:diting/main.dart:18)
''',
);

/// IP 质量报告（上游 `models/ip_quality.dart` 的演示等价物）。
class MockIpQualitySource {
  const MockIpQualitySource({
    required this.name,
    required this.status,
    this.ipType,
    this.latencyMs,
  });

  final String name;

  /// 该来源的结果：命中 / 超时 / 限流 / 失败 / IP 不一致。
  final String status;
  final String? ipType;
  final int? latencyMs;
}

class MockIpQualityReport {
  const MockIpQualityReport({
    required this.ip,
    required this.ipType,
    required this.level,
    required this.organization,
    required this.asn,
    required this.sources,
  });

  final String ip;

  /// 住宅 / 移动 / 商业 / 机房。
  final String ipType;

  /// 优秀 / 一般 / 风险。
  final String level;
  final String organization;
  final String asn;
  final List<MockIpQualitySource> sources;
}

const mockIpQualityReport = MockIpQualityReport(
  ip: '203.0.113.24',
  ipType: '机房',
  level: '风险',
  organization: 'Example Hosting Ltd.',
  asn: 'AS64500',
  sources: [
    MockIpQualitySource(
      name: 'ipinfo.io',
      status: '命中',
      ipType: '机房',
      latencyMs: 182,
    ),
    MockIpQualitySource(
      name: 'ipapi.com',
      status: '命中',
      ipType: '机房',
      latencyMs: 264,
    ),
    MockIpQualitySource(
      name: 'scamalytics',
      status: '限流',
      latencyMs: null,
    ),
    MockIpQualitySource(
      name: 'ipwho.is',
      status: '超时',
    ),
    MockIpQualitySource(
      name: 'ip-api.com',
      status: 'IP 不一致',
      ipType: '商业',
    ),
  ],
);

/// 命名 URL 表单里预置的样例条目。
const mockNamedUrls = <({String label, String url})>[
  (label: '主订阅', url: 'https://sub.example.com/diting/main'),
  (label: '备用订阅', url: 'https://backup.example.com/diting/backup'),
  (label: '自建规则', url: 'https://rules.example.com/diting/custom.yaml'),
];

/// 键值编辑器里预置的样例。
const mockMapEntries = <String, String>{
  'mixed-port': '7890',
  'allow-lan': 'true',
  'mode': 'rule',
  'log-level': 'info',
};
