/// Demo data for forms and one-off pages: all constants, mutable state lives in the page.
library;

/// Font family options. Only JetBrainsMono and Twemoji ship with the app; other names fall back to
/// the system default.
class MockFontFamily {
  const MockFontFamily({
    required this.family,
    required this.label,
    required this.description,
    this.bundled = false,
  });

  /// Value for `TextStyle.fontFamily`; null means the system default.
  final String? family;
  final String label;
  final String description;

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

class MockCompletion {
  const MockCompletion({
    required this.label,
    required this.detail,
    this.isKey = false,
  });

  final String label;
  final String detail;

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
  description:
      '内核在 3 次重试后仍未能在 10 秒内完成握手。'
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

const mockNamedUrls = <({String label, String url})>[
  (label: '主订阅', url: 'https://sub.example.com/diting/main'),
  (label: '备用订阅', url: 'https://backup.example.com/diting/backup'),
  (label: '自建规则', url: 'https://rules.example.com/diting/custom.yaml'),
];

const mockMapEntries = <String, String>{
  'mixed-port': '7890',
  'allow-lan': 'true',
  'mode': 'rule',
  'log-level': 'info',
};
