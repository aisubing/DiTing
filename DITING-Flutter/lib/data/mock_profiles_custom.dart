part of 'mock_profiles.dart';

/// Proxy protocols (subset of upstream `ProxyField` / `CustomProxy.type`); `defaultPort` pre-fills
/// the port.
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

  bool get supportsTls => switch (this) {
    shadowsocks || wireguard => false,
    _ => true,
  };

  bool get supportsCipher =>
      this == shadowsocks || this == vmess || this == trojan;
}

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

  String get endpoint => '${protocol.label} · $server:$port';

  /// Demo only: real encoding needs per-protocol base64 JSON.
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

String _fakeBase64(String input) => 'YWVzLTI1Ni1nY206${_fakeUuid(input)}';

String _fakeUuid(String seed) {
  final code = seed.codeUnits.fold<int>(0x1a2b, (sum, unit) => sum * 31 + unit);
  final hex = (code.abs() % 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '${hex.substring(0, 8)}-4b1d-9c2e-${hex.substring(0, 4)}-a0f12d3c5e6b';
}

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

  /// Only the auto-probing kinds need a probe URL and interval.
  bool get needsProbe => this == urlTest || this == fallback;

  bool get needsStrategy => this == loadBalance;
}

enum BalanceStrategy {
  consistentHashing('一致性哈希', 'consistent-hashing'),
  roundRobin('轮询', 'round-robin'),
  stickySessions('会话保持', 'sticky-sessions');

  const BalanceStrategy(this.label, this.value);

  final String label;
  final String value;
}

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

  /// Member order is priority order; fallback and relay depend on it.
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

  /// Placeholder for the content field; valid content differs per type.
  final String hint;

  /// Only the IP-based types support `no-resolve`.
  bool get supportsNoResolve => this == ipCidr || this == geoip;

  bool get supportsSrc => this == ipCidr || this == dstPort;
}

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

  /// One-line rule text, same syntax as YAML, for quick editing.
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

  /// `domain`, `ipcidr` or `classical`; decides how the content is parsed.
  final String behavior;
  final int ruleCount;
  final String updatedAt;
  final String format;
}

/// Dialer: wraps the outbound of a node or group (upstream `dialer-proxy`).
class MockDialer {
  const MockDialer({required this.proxyName, required this.target});

  final String proxyName;
  final String target;
}
