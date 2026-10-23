part of 'mock_profiles.dart';

enum ExtendMode {
  standard('标准模式', 'star', '用表单维护追加规则与匹配目标，界面里能看清每一条'),
  script('脚本模式', 'code', '用一段 JavaScript 改配置，适合批量改写难以用表单表达的字段');

  const ExtendMode(this.label, this.glyph, this.description);

  final String label;
  final String glyph;
  final String description;
}

/// Built-in targets of a match rule; the kernel knows these names directly.
enum MockRuleTarget {
  direct('DIRECT', '直连，不经过任何代理'),
  reject('REJECT', '拒绝连接，立即返回失败'),
  rejectDrop('REJECT-DROP', '丢弃数据包，不返回失败'),
  pass('PASS', '跳过后续规则，交给内核默认路由'),
  global('GLOBAL', '交给全局出口');

  const MockRuleTarget(this.value, this.description);

  final String value;
  final String description;
}

class MockScript {
  const MockScript({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.lineCount,
    required this.enabled,
  });

  final String id;
  final String name;
  final String updatedAt;
  final int lineCount;
  final bool enabled;
}

const mockScripts = <MockScript>[
  MockScript(
    id: 's1',
    name: '合并节点重命名',
    updatedAt: '2026-10-08 14:22',
    lineCount: 38,
    enabled: true,
  ),
  MockScript(
    id: 's2',
    name: '替换测速地址',
    updatedAt: '2026-09-30 11:05',
    lineCount: 12,
    enabled: true,
  ),
  MockScript(
    id: 's3',
    name: '剔除过期节点',
    updatedAt: '2026-09-12 20:41',
    lineCount: 24,
    enabled: false,
  ),
];

class MockGlobalRule {
  const MockGlobalRule({
    required this.id,
    required this.type,
    required this.content,
    required this.target,
    this.enabled = true,
  });

  final String id;
  final CustomRuleType type;
  final String content;
  final String target;
  final bool enabled;
}

const mockGlobalRules = <MockGlobalRule>[
  MockGlobalRule(
    id: 'gr1',
    type: CustomRuleType.domainSuffix,
    content: 'doubleclick.net',
    target: 'REJECT',
  ),
  MockGlobalRule(
    id: 'gr2',
    type: CustomRuleType.domainKeyword,
    content: 'umeng',
    target: 'REJECT',
  ),
  MockGlobalRule(
    id: 'gr3',
    type: CustomRuleType.geosite,
    content: 'category-ads-all',
    target: 'REJECT',
  ),
  MockGlobalRule(
    id: 'gr4',
    type: CustomRuleType.processName,
    content: 'Steam.exe',
    target: 'DIRECT',
    enabled: false,
  ),
  MockGlobalRule(
    id: 'gr5',
    type: CustomRuleType.ipCidr,
    content: '100.64.0.0/10',
    target: 'DIRECT',
  ),
];

/// Icon picker candidates: the 130 `AppGlyphs` names, standing in for an icon set the demo cannot
/// download.
const mockIconGroups = <String, List<String>>{
  '常用': [
    'bolt',
    'speed',
    'star',
    'shuffle',
    'split',
    'swap',
    'layers',
    'puzzle',
    'customize',
    'target',
    'pin',
    'verified',
  ],
  '网络': [
    'wifi',
    'wifiOff',
    'vpn',
    'dns',
    'link',
    'cloudDownload',
    'cloudSync',
    'upload',
    'send',
    'locate',
    'devices',
    'connections',
  ],
  '状态与操作': [
    'check',
    'checkCircle',
    'block',
    'info',
    'warning',
    'error',
    'lock',
    'lockOpen',
    'eye',
    'eyeOff',
    'refresh',
    'sync',
  ],
  '工具与内容': [
    'code',
    'rules',
    'settings',
    'sliders',
    'wrench',
    'filter',
    'sort',
    'broom',
    'copy',
    'edit',
    'compose',
    'delete',
  ],
};

/// YAML snippet for the preview page: real syntax, fabricated content.
const mockProfileYaml = '''
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
ipv6: false

profile:
  store-selected: true
  store-fake-ip: true

dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://cloudflare-dns.com/dns-query
    - tls://8.8.4.4:853

proxies:
  - name: "香港 01 · IPLC"
    type: vmess
    server: hk01.example.net
    port: 443
    uuid: 3f7c1e08-4b1d-9c2e-a0f1-2d3c5e6b7a90
    alterId: 0
    cipher: auto
    tls: true
    servername: hk01.example.net
    network: ws
    ws-opts:
      path: /vm
      headers:
        Host: hk01.example.net

  - name: "日本 02 · 软银"
    type: trojan
    server: jp02.example.net
    port: 443
    password: jp02-pass
    sni: jp02.example.net
    skip-cert-verify: false
    udp: true

  - name: "新加坡 03"
    type: ss
    server: sg03.example.net
    port: 8388
    cipher: aes-256-gcm
    password: sg03-pass
    udp: true

proxy-groups:
  - name: 🚀 节点选择
    type: select
    proxies:
      - ♻️ 自动选择
      - 香港 01 · IPLC
      - 日本 02 · 软银
      - DIRECT

  - name: ♻️ 自动选择
    type: url-test
    url: https://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    proxies:
      - 香港 01 · IPLC
      - 日本 02 · 软银
      - 新加坡 03

  - name: 🛑 广告拦截
    type: select
    proxies:
      - REJECT
      - DIRECT

rules:
  - DOMAIN-SUFFIX,adservice.example.com,🛑 广告拦截
  - DOMAIN-KEYWORD,analytics,🛑 广告拦截
  - GEOSITE,netflix,📺 流媒体
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - DOMAIN,intranet.example.com,DIRECT
  - PROCESS-NAME,Telegram.exe,🚀 节点选择
  - GEOIP,CN,DIRECT,no-resolve
  - MATCH,🚀 节点选择

rule-providers:
  广告拦截:
    type: http
    behavior: domain
    url: https://rules.example.com/adblock.yaml
    path: ./rules/adblock.yaml
    interval: 86400

proxy-providers:
  机场 A:
    type: http
    url: https://sub-a.example.com/providers/proxies
    path: ./providers/a.yaml
    interval: 43200
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
''';

/// Highlight ranges for the preview page (line to category), first lines only.
enum YamlToken {
  key('键'),
  section('顶层段'),
  comment('注释'),
  string('字符串'),
  number('数字');

  const YamlToken(this.label);

  final String label;
}
