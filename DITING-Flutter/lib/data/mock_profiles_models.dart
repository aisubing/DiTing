part of 'mock_profiles.dart';

/// `merged` is upstream `custom`: a merge, not a third source.
enum ProfileKind {
  local('本地', '从文件导入，只在导入时读取一次', 'importFile'),
  remote('远程', '按更新周期自动拉取订阅', 'cloudSync'),
  merged('合并', '在订阅基础上手工维护节点、组与规则', 'customize');

  const ProfileKind(this.label, this.description, this.glyph);

  final String label;
  final String description;

  final String glyph;

  bool get isRemote => this == remote;
  bool get isMerged => this == merged;
}

/// Four fixed values: arbitrary minutes need a real timer.
enum AutoUpdateInterval {
  off('从不', null),
  hours6('每 6 小时', Duration(hours: 6)),
  hours12('每 12 小时', Duration(hours: 12)),
  hours24('每 24 小时', Duration(hours: 24));

  const AutoUpdateInterval(this.label, this.interval);

  final String label;
  final Duration? interval;
}

class MockSubscription {
  const MockSubscription({
    required this.usedGb,
    required this.totalGb,
    required this.expireAt,
  });

  final double usedGb;
  final double totalGb;
  final String expireAt;

  double get progress => totalGb == 0 ? 0 : (usedGb / totalGb).clamp(0, 1);
}

class MockProfile {
  const MockProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.updatedAt,
    required this.ruleCount,
    required this.proxyCount,
    this.url = '',
    this.fileName = '',
    this.fileSize = '',
    this.autoUpdate = AutoUpdateInterval.off,
    this.userAgent = '',
    this.subscription,
    this.downloadProgress,
    this.wavyProgress = false,
  });

  final String id;
  final String name;
  final ProfileKind kind;

  final String updatedAt;
  final int ruleCount;
  final int proxyCount;
  final String url;
  final String fileName;
  final String fileSize;
  final AutoUpdateInterval autoUpdate;
  final String userAgent;
  final MockSubscription? subscription;

  final double? downloadProgress;

  final bool wavyProgress;

  bool get isDownloading => downloadProgress != null;

  String get subtitle => switch (kind) {
    ProfileKind.remote when subscription != null =>
      '${_gb(subscription!.usedGb)} / ${_gb(subscription!.totalGb)}',
    ProfileKind.remote => '远程订阅',
    ProfileKind.local => fileName.isEmpty ? '本地文件' : fileName,
    ProfileKind.merged => '手工维护 · $proxyCount 个节点',
  };

  MockProfile copyWith({
    String? name,
    String? url,
    AutoUpdateInterval? autoUpdate,
    String? userAgent,
    String? updatedAt,
    double? downloadProgress,
    bool clearProgress = false,
    int? ruleCount,
    int? proxyCount,
    MockSubscription? subscription,
  }) {
    return MockProfile(
      id: id,
      name: name ?? this.name,
      kind: kind,
      updatedAt: updatedAt ?? this.updatedAt,
      ruleCount: ruleCount ?? this.ruleCount,
      proxyCount: proxyCount ?? this.proxyCount,
      url: url ?? this.url,
      fileName: fileName,
      fileSize: fileSize,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      userAgent: userAgent ?? this.userAgent,
      subscription: subscription ?? this.subscription,
      downloadProgress: clearProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      wavyProgress: wavyProgress,
    );
  }
}

String _gb(double value) => '${value.toStringAsFixed(value >= 10 ? 0 : 1)} GB';

enum ProfileOverride {
  dns('覆写 DNS', '使用本档案自己的 DNS 配置'),
  tun('覆写 TUN', '使用本档案自己的 TUN 设置'),
  sniffer('覆写域名嗅探', '关闭后跟随全局嗅探设置'),
  ntp('覆写 NTP', '使用本档案自己的时间同步设置');

  const ProfileOverride(this.label, this.description);

  final String label;
  final String description;
}

const mockProfiles = <MockProfile>[
  MockProfile(
    id: 'p-sub',
    name: '谛听 · 订阅',
    kind: ProfileKind.remote,
    url: 'https://sub.example.com/api/v1/client/subscribe?token=8f2a',
    updatedAt: '3 分钟前',
    ruleCount: 48213,
    proxyCount: 42,
    autoUpdate: AutoUpdateInterval.hours6,
    userAgent: 'clash-verge/v2.4.2',
    subscription: MockSubscription(
      usedGb: 44.1,
      totalGb: 100,
      expireAt: '2027-03-14',
    ),
  ),
  MockProfile(
    id: 'p-merge',
    name: '家里 · 合并档案',
    kind: ProfileKind.merged,
    updatedAt: '昨天 21:40',
    ruleCount: 1268,
    proxyCount: 9,
    userAgent: 'diting/1.0',
  ),
  MockProfile(
    id: 'p-backup',
    name: '备用线路（下载中）',
    kind: ProfileKind.remote,
    url: 'https://sub2.example.com/clash/backup.yaml',
    updatedAt: '正在更新',
    ruleCount: 0,
    proxyCount: 0,
    autoUpdate: AutoUpdateInterval.hours24,
    downloadProgress: 0.62,
    wavyProgress: true,
  ),
  MockProfile(
    id: 'p-local',
    name: '公司内网规则',
    kind: ProfileKind.local,
    fileName: 'office-clash.yaml',
    fileSize: '184.2 KB',
    updatedAt: '2026-10-12 09:15',
    ruleCount: 372,
    proxyCount: 4,
  ),
];

const mockUserAgents = <String>[
  'clash-verge/v2.4.2',
  'clash.meta',
  'diting/1.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'ClashforWindows/0.20.39',
];

const mockMaxProfilesCount = 32;
