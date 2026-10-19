part of 'mock_profiles.dart';

/// 节点协议（上游 `ProxyField`/`CustomProxy.type` 的常用子集）。
///
/// 每一种只保留演示表单里那几项真正有差异的字段；`defaultPort` 用于新建时
/// 预填端口，否则每加一个节点都要自己去查端口号。
enum ProxyProtocol {
  shadowsocks('Shadowsocks', 'ss', 8388),
  vmess('VMess', 'vmess', 443),
  vless('VLESS', 'vless', 443),
  trojan('Trojan', 'trojan', 443),
  hysteria2('Hysteria2', 'hysteria2', 443),
  tuic('TUIC', 'tuic', 443),
  wireguard('WireGuard', 'wireguard', 51820);

  const ProxyProtocol(this.label, this.value, this.defaultPort);

  final String label;
  final String value;
  final int defaultPort;

  /// 是否支持 TLS 三件套（TLS / SNI / 跳过证书校验）。
  bool get supportsTls => switch (this) {
    shadowsocks || wireguard => false,
    _ => true,
  };

  bool get supportsCipher =>
      this == shadowsocks || this == vmess || this == trojan;
}

/// 自建节点。
class MockProxy {
  const MockProxy({
    required this.id,
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    required this.latencyMs,
    this.cipher = '',
    this.password = '',
    this.tls = false,
    this.sni = '',
    this.skipCertVerify = false,
    this.udp = true,
  });

  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String server;
  final int port;
  final int latencyMs;
  final String cipher;
  final String password;
  final bool tls;
  final String sni;
  final bool skipCertVerify;
  final bool udp;

  /// 卡片副标题：`协议 · server:port`。
  String get endpoint => '${protocol.label} · $server:$port';

  /// 分享链接（演示用，格式与真实协议一致但内容是编的）。
  ///
  /// 只用来演示「分享链接 ↔ 表单」的双向填充，不做真实编码：真编码要 base64
  /// 每种协议自己的 JSON 结构，演示里没有联网可验证的解析器。
  String get shareLink => switch (protocol) {
    ProxyProtocol.shadowsocks =>
      'ss://${_fakeBase64('${cipher.isEmpty ? 'aes-256-gcm' : cipher}:$password')}'
          '@$server:$port#${Uri.encodeComponent(name)}',
    ProxyProtocol.trojan =>
      'trojan://$password@$server:$port?sni=$sni#${Uri.encodeComponent(name)}',
    ProxyProtocol.hysteria2 =>
      'hysteria2://$password@$server:$port?sni=$sni#${Uri.encodeComponent(name)}',
    _ =>
      '${protocol.value}://${_fakeUuid(password)}@$server:$port'
          '?type=ws&security=${tls ? 'tls' : 'none'}#${Uri.encodeComponent(name)}',
  };

  MockProxy copyWith({
    String? name,
    ProxyProtocol? protocol,
    String? server,
    int? port,
    String? cipher,
    String? password,
    bool? tls,
    String? sni,
    bool? skipCertVerify,
    bool? udp,
  }) {
    return MockProxy(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      latencyMs: latencyMs,
      cipher: cipher ?? this.cipher,
      password: password ?? this.password,
      tls: tls ?? this.tls,
      sni: sni ?? this.sni,
      skipCertVerify: skipCertVerify ?? this.skipCertVerify,
      udp: udp ?? this.udp,
    );
  }
}

/// 演示用的「看起来像 base64」的字符串：真 base64 会让链接长得不像自己能读的
/// 东西，而这里要的是能一眼看出「这段是加密的用户名密码」。
String _fakeBase64(String input) => 'YWVzLTI1Ni1nY206${_fakeUuid(input)}';

String _fakeUuid(String seed) {
  final code = seed.codeUnits.fold<int>(0x1a2b, (sum, unit) => sum * 31 + unit);
  final hex = (code.abs() % 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '${hex.substring(0, 8)}-4b1d-9c2e-${hex.substring(0, 4)}-a0f12d3c5e6b';
}

/// 代理组类型（上游 `GroupType`）。
enum GroupKind {
  selector('手动选择', 'select', '由用户指定一个出口'),
  urlTest('自动测速', 'url-test', '定期测速，选延迟最低的'),
  fallback('故障转移', 'fallback', '按顺序尝试，可用即停'),
  loadBalance('负载均衡', 'load-balance', '按策略分摊连接'),
  relay('链式代理', 'relay', '按顺序串成一条链路');

  const GroupKind(this.label, this.value, this.description);

  final String label;
  final String value;
  final String description;

  /// 只有自动测速类需要测速地址与间隔。
  bool get needsProbe => this == urlTest || this == fallback;

  bool get needsStrategy => this == loadBalance;
}

/// 负载均衡策略（上游 `LoadBalanceStrategy`）。
enum BalanceStrategy {
  consistentHashing('一致性哈希', 'consistent-hashing'),
  roundRobin('轮询', 'round-robin'),
  stickySessions('会话保持', 'sticky-sessions');

  const BalanceStrategy(this.label, this.value);

  final String label;
  final String value;
}

/// 代理组。
class MockProxyGroup {
  const MockProxyGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.members,
    this.filter = '',
    this.useProviders = const [],
    this.icon = '',
    this.probeUrl = 'https://www.gstatic.com/generate_204',
    this.intervalSeconds = 300,
    this.strategy = BalanceStrategy.consistentHashing,
    this.hidden = false,
    this.lazy = true,
  });

  final String id;
  final String name;
  final GroupKind kind;

  /// 组内成员顺序即优先级（fallback / relay 依赖它）。
  final List<String> members;
  final String filter;
  final List<String> useProviders;
  final String icon;
  final String probeUrl;
  final int intervalSeconds;
  final BalanceStrategy strategy;
  final bool hidden;
  final bool lazy;

  MockProxyGroup copyWith({
    String? name,
    GroupKind? kind,
    List<String>? members,
    String? filter,
    List<String>? useProviders,
    String? icon,
    String? probeUrl,
    int? intervalSeconds,
    BalanceStrategy? strategy,
    bool? hidden,
    bool? lazy,
  }) {
    return MockProxyGroup(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      members: members ?? this.members,
      filter: filter ?? this.filter,
      useProviders: useProviders ?? this.useProviders,
      icon: icon ?? this.icon,
      probeUrl: probeUrl ?? this.probeUrl,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      strategy: strategy ?? this.strategy,
      hidden: hidden ?? this.hidden,
      lazy: lazy ?? this.lazy,
    );
  }
}

/// 自定义规则类型（上游 `RuleAction` 的常用子集）。
enum CustomRuleType {
  domain('DOMAIN', '完整域名', 'example.com'),
  domainSuffix('DOMAIN-SUFFIX', '域名后缀', 'example.com'),
  domainKeyword('DOMAIN-KEYWORD', '域名关键词', 'example'),
  geosite('GEOSITE', '域名集合', 'cn'),
  ipCidr('IP-CIDR', 'IP 段', '192.168.0.0/16'),
  geoip('GEOIP', 'IP 归属地', 'CN'),
  ruleSet('RULE-SET', '规则集合', '广告拦截'),
  processName('PROCESS-NAME', '进程名', 'Telegram.exe'),
  dstPort('DST-PORT', '目标端口', '443');

  const CustomRuleType(this.value, this.label, this.hint);

  final String value;
  final String label;

  /// 内容输入框的占位提示；每种类型的合法内容差别很大。
  final String hint;

  /// 域名类规则可以加 `no-resolve` 之外的排查选项；只有 IP 类需要 no-resolve。
  bool get supportsNoResolve => this == ipCidr || this == geoip;

  bool get supportsSrc => this == ipCidr || this == dstPort;
}

/// 自定义规则（上游 `Rule`）。
class MockCustomRule {
  const MockCustomRule({
    required this.id,
    required this.type,
    required this.content,
    required this.target,
    this.noResolve = false,
    this.src = false,
    this.disabled = false,
  });

  final String id;
  final CustomRuleType type;
  final String content;
  final String target;
  final bool noResolve;
  final bool src;
  final bool disabled;

  /// 规则的一行文本形式，与 YAML 里写法一致，用于快速编辑。
  String get text {
    final flags = [
      if (noResolve) 'no-resolve',
      if (src) 'src',
      if (disabled) 'disabled',
    ];
    final suffix = flags.isEmpty ? '' : ',${flags.join(',')}';
    return '${type.value},$content,$target$suffix';
  }

  MockCustomRule copyWith({
    CustomRuleType? type,
    String? content,
    String? target,
    bool? noResolve,
    bool? src,
    bool? disabled,
  }) {
    return MockCustomRule(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
      target: target ?? this.target,
      noResolve: noResolve ?? this.noResolve,
      src: src ?? this.src,
      disabled: disabled ?? this.disabled,
    );
  }
}

/// 代理提供者（上游 `proxy-providers`）。
class MockProxyProvider {
  const MockProxyProvider({
    required this.id,
    required this.name,
    required this.url,
    required this.updatedAt,
    required this.proxyCount,
    this.intervalMinutes = 720,
    this.healthCheck = true,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String url;
  final String updatedAt;
  final int proxyCount;
  final int intervalMinutes;
  final bool healthCheck;
  final bool enabled;
}

/// 规则提供者（上游 `rule-providers`）。
class MockRuleProvider {
  const MockRuleProvider({
    required this.id,
    required this.name,
    required this.url,
    required this.behavior,
    required this.ruleCount,
    required this.updatedAt,
    this.format = 'yaml',
  });

  final String id;
  final String name;
  final String url;

  /// `domain` / `ipcidr` / `classical`，决定规则内容怎么解析。
  final String behavior;
  final int ruleCount;
  final String updatedAt;
  final String format;
}

/// 拨号器：把某个节点或组的出站请求再套一层（上游 `dialer-proxy`）。
class MockDialer {
  const MockDialer({required this.proxyName, required this.target});

  final String proxyName;
  final String target;
}
