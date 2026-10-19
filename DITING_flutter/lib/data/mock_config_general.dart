part of 'mock_config.dart';

/// 日志级别。
///
/// 上游直接上屏 `LogLevel.name`；本项目 `AGENT_MISTAKES.md` 记录过枚举插值
/// 会把 Dart 标识符漏到界面上（`silent` / `info`），所以统一带 `label`。
enum LogLevel {
  silent('静默'),
  error('错误'),
  warning('警告'),
  info('信息'),
  debug('调试');

  const LogLevel(this.label);

  final String label;
}

/// 覆写编辑器演示用的字段类型。
///
/// 上游的「字段类型」不是枚举而是五个 `OverrideField` 子类；演示层要让用户
/// 看得见「一个 key 用哪种控件」，所以抽成枚举 + 说明文字。
enum OverrideFieldKind {
  toggle('开关', '布尔值，行尾一个 Switch'),
  options('选项', '从固定集合里选一个'),
  number('数字', '整数输入，带范围校验'),
  text('文本', '单行文本输入'),
  list('列表', '字符串列表，可增删行');

  const OverrideFieldKind(this.label, this.description);

  final String label;
  final String description;
}

/// 一条覆写条目：键 + 值 + 字段类型 + 分组。
class MockOverrideEntry {
  const MockOverrideEntry({
    required this.key,
    required this.label,
    required this.value,
    required this.kind,
    required this.section,
    this.description,
    this.options = const [],
    this.min,
    this.max,
    this.unit,
  });

  /// 上游键名（`mtu`、`listen` 等），同时用作列表的稳定 id。
  final String key;
  final String label;

  /// 当前值的展示形式。数字、布尔也存字符串：这是演示层，「保存」只是把
  /// 字符串写回状态，不需要真实的类型系统。
  final String value;
  final OverrideFieldKind kind;
  final String section;
  final String? description;

  /// [OverrideFieldKind.options] 的候选；其余类型为空。
  final List<String> options;
  final int? min;
  final int? max;
  final String? unit;

  MockOverrideEntry copyWith({String? value}) => MockOverrideEntry(
    key: key,
    label: label,
    value: value ?? this.value,
    kind: kind,
    section: section,
    description: description,
    options: options,
    min: min,
    max: max,
    unit: unit,
  );
}

/// 某个开关的宿主设置（一次性写进 provider 的初始快照）。
const _keepUserAgent = Object();

class MockConfigSnapshot {
  const MockConfigSnapshot({
    required this.logLevel,
    required this.testUrl,
    required this.ports,
    required this.allowLan,
    required this.externalController,
    required this.controllerSecret,
    required this.authentication,
    required this.account,
    required this.password,
    required this.unifiedDelay,
    required this.userAgent,
    required this.tcpConcurrent,
    required this.findProcess,
    required this.closeConnections,
    required this.onlyStatisticsProxy,
    required this.checkCertificate,
    required this.autoCheckUpdate,
    required this.ipv6,
    required this.appendSystemDns,
    required this.geodataMemconservative,
    required this.openLogs,
    required this.hosts,
  });

  final LogLevel logLevel;
  final String testUrl;
  final MockPorts ports;
  final bool allowLan;
  final bool externalController;
  final String controllerSecret;
  final bool authentication;
  final String account;
  final String password;
  final bool unifiedDelay;

  /// 全局 UA；null 表示跟随订阅或内核默认。
  final String? userAgent;
  final bool tcpConcurrent;
  final bool findProcess;
  final bool closeConnections;
  final bool onlyStatisticsProxy;
  final bool checkCertificate;
  final bool autoCheckUpdate;
  final bool ipv6;
  final bool appendSystemDns;
  final bool geodataMemconservative;
  final bool openLogs;

  /// Hosts 表：域名 → 地址。
  final Map<String, String> hosts;

  MockConfigSnapshot copyWith({
    LogLevel? logLevel,
    String? testUrl,
    MockPorts? ports,
    bool? allowLan,
    bool? externalController,
    String? controllerSecret,
    bool? authentication,
    String? account,
    String? password,
    bool? unifiedDelay,
    Object? userAgent = _keepUserAgent,
    bool? tcpConcurrent,
    bool? findProcess,
    bool? closeConnections,
    bool? onlyStatisticsProxy,
    bool? checkCertificate,
    bool? autoCheckUpdate,
    bool? ipv6,
    bool? appendSystemDns,
    bool? geodataMemconservative,
    bool? openLogs,
    Map<String, String>? hosts,
  }) => MockConfigSnapshot(
    logLevel: logLevel ?? this.logLevel,
    testUrl: testUrl ?? this.testUrl,
    ports: ports ?? this.ports,
    allowLan: allowLan ?? this.allowLan,
    externalController: externalController ?? this.externalController,
    controllerSecret: controllerSecret ?? this.controllerSecret,
    authentication: authentication ?? this.authentication,
    account: account ?? this.account,
    password: password ?? this.password,
    unifiedDelay: unifiedDelay ?? this.unifiedDelay,
    userAgent: userAgent == _keepUserAgent
        ? this.userAgent
        : userAgent as String?,
    tcpConcurrent: tcpConcurrent ?? this.tcpConcurrent,
    findProcess: findProcess ?? this.findProcess,
    closeConnections: closeConnections ?? this.closeConnections,
    onlyStatisticsProxy: onlyStatisticsProxy ?? this.onlyStatisticsProxy,
    checkCertificate: checkCertificate ?? this.checkCertificate,
    autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
    ipv6: ipv6 ?? this.ipv6,
    appendSystemDns: appendSystemDns ?? this.appendSystemDns,
    geodataMemconservative:
        geodataMemconservative ?? this.geodataMemconservative,
    openLogs: openLogs ?? this.openLogs,
    hosts: hosts ?? this.hosts,
  );
}

/// 五个入站端口。
class MockPorts {
  const MockPorts({
    required this.mixed,
    required this.port,
    required this.socks,
    required this.redir,
    required this.tproxy,
  });

  final int mixed;
  final int port;
  final int socks;
  final int redir;
  final int tproxy;

  MockPorts copyWith({
    int? mixed,
    int? port,
    int? socks,
    int? redir,
    int? tproxy,
  }) => MockPorts(
    mixed: mixed ?? this.mixed,
    port: port ?? this.port,
    socks: socks ?? this.socks,
    redir: redir ?? this.redir,
    tproxy: tproxy ?? this.tproxy,
  );

  /// 端口冲突检测：五个端口必须两两不同。
  bool get hasConflict => {mixed, port, socks, redir, tproxy}.length != 5;
}

/// 默认测试地址。
const defaultTestUrl = 'http://cp.cloudflare.com/generate_204';

/// 通用设置的初始值。
const mockConfigSnapshot = MockConfigSnapshot(
  logLevel: LogLevel.info,
  testUrl: defaultTestUrl,
  ports: MockPorts(
    mixed: 7890,
    port: 7891,
    socks: 7892,
    redir: 7893,
    tproxy: 7894,
  ),
  allowLan: false,
  externalController: true,
  controllerSecret: 'diting-demo-8f3a',
  authentication: false,
  account: 'diting',
  password: 'demo-pass-2024',
  unifiedDelay: false,
  userAgent: null,
  tcpConcurrent: true,
  findProcess: false,
  closeConnections: true,
  onlyStatisticsProxy: false,
  checkCertificate: true,
  autoCheckUpdate: true,
  ipv6: true,
  appendSystemDns: false,
  geodataMemconservative: true,
  openLogs: false,
  hosts: {
    'dns.alidns.com': '223.5.5.5',
    'doh.pub': '1.12.12.12',
    'cdn.example.com': '10.0.0.8',
    'router.lan': '192.168.1.1',
  },
);

/// 端口重置回默认值时的提示文案用得上。
const mockDefaultPorts = MockPorts(
  mixed: 7890,
  port: 7891,
  socks: 7892,
  redir: 7893,
  tproxy: 7894,
);
