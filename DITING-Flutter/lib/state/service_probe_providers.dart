/// 服务状态卡的探测目标：全部由真实状态算出，没有一项是写死的字面量。
///
/// 上游 `widgets/service_status.dart` 里那四行是常量表（`本机解析 / DoH 通道 /
/// 本地缓存 / 上游服务商`，连「命中 98%」「5 个可用 · 1 个异常」都是字面量）。
/// 本仓换成从旧库与设置里算：
/// 1. **本机解析**：`127.0.0.1:<serverPort>`，端口读旧版 `local_listen_port`；
/// 2. **当前服务商**：单选模式取选中的那个，多路模式取竞速集合里目录顺序的第一
///    个（与首页「DNS 服务详情」块同序）；
/// 3. **本地缓存**：有效条数与累计命中读 `dns_cache`（`DnsCacheDao` 的两条聚合）；
/// 4. **上游服务商**：目录里已测速 / 未测速的个数，读 `provider_health_json`。
///
/// ## 为什么单独一个文件
/// 这段逻辑要被卡片和它的详情浮层同时用，且要有测试覆盖（widget 测试里
/// `dnsLatencyRunnerProvider` 是「不可用」实现，但**目标列表**仍必须正确）。
/// 塞在卡片里就只能靠渲染断言去验证端口与缓存数字。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/data/native/dns_latency_bridge.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/log_dashboard_overview_providers.dart';
import 'package:diting/state/network_tools_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 服务种类。决定图标与探测方式说明，避免把「类型」写成裸字符串。
enum ProbeKind {
  dns('DNS'),
  http('HTTP'),
  cache('缓存'),
  upstream('上游');

  const ProbeKind(this.label);

  final String label;
}

/// 一个被探测的服务。
class ProbeService {
  const ProbeService({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    this.spec,
  });

  final String id;
  final String name;
  final String description;
  final ProbeKind kind;

  /// 可探测的网络目标；`null` 表示这一项没有网络目标（如本地缓存），
  /// 只显示状态、不显示耗时。给一个假目标再报「失败」会误导用户去查网络。
  final DnsLatencyProviderSpec? spec;
}

/// 当前应显示的探测项。
final probeServicesProvider = Provider<List<ProbeService>>((ref) {
  final mode = ref.watch(workModeProvider);
  final serverPort = ref.watch(serverPortProvider);
  final catalog = ref.watch(dnsProviderCatalogProvider);
  final selectedId = ref.watch(selectedProviderProvider);
  final raceIds = ref.watch(raceProvidersProvider);
  final offMode = ref.watch(logDashboardProvider).value?.offMode;

  final services = <ProbeService>[];
  // 极速模式没有局域网监听端口（`ExpressVpnService` 只挂 resolver），这一项
  // 直接不出现——显示一个探不通的端口比不显示更糟。
  if (mode != AppWorkMode.express) {
    services.add(
      ProbeService(
        id: 'local',
        name: '本机解析',
        description: '127.0.0.1:$serverPort · UDP',
        kind: ProbeKind.dns,
        spec: DnsLatencyProviderSpec(
          id: 'local',
          name: '本机解析',
          host: '127.0.0.1',
          port: serverPort,
          protocol: DnsLatencyProtocol.dns,
        ),
      ),
    );
  }

  final primaryId = mode == AppWorkMode.normal || mode == AppWorkMode.express
      ? selectedId
      : catalog.where((provider) => raceIds.contains(provider.id)).firstOrNull?.id;
  final primary = catalog
      .where((provider) => provider.id == primaryId)
      .firstOrNull;
  if (primary != null) {
    services.add(
      ProbeService(
        id: primary.id,
        name: '当前服务商',
        description: '${primary.protocol.label} · ${primary.address}',
        kind: primary.protocol == ProviderProtocol.doh
            ? ProbeKind.http
            : ProbeKind.dns,
        spec: latencySpecOf(providerEntryOf(primary)),
      ),
    );
  }

  services.add(
    ProbeService(
      id: 'cache',
      name: '本地缓存',
      description: offMode == null
          ? '读取中…'
          : '有效 ${offMode.cacheEntries} 条 · 累计命中 ${offMode.cacheHits} 次',
      kind: ProbeKind.cache,
    ),
  );

  final measured = catalog.where((provider) => provider.latencyMs >= 0).length;
  services.add(
    ProbeService(
      id: 'upstream',
      name: '上游服务商',
      description: '$measured 个已测速 · ${catalog.length - measured} 个未测速',
      kind: ProbeKind.upstream,
    ),
  );
  return services;
});

/// `MockProvider` 是展示模型，通道要结构化参数；这里从它的 `address` 反解。
///
/// 反解而不是让目录再存一份结构化字段：`MockProvider.address` 就是旧版
/// `DnsProvider.endpointLabel()` 的产物（`https://…` 或 `1.1.1.1:53`），
/// 两处口径因此不会分叉。
DnsProviderEntry providerEntryOf(MockProvider provider) {
  final protocol = switch (provider.protocol) {
    ProviderProtocol.dns => DnsProtocol.dns,
    ProviderProtocol.doh => DnsProtocol.doh,
    ProviderProtocol.dot => DnsProtocol.dot,
  };
  final isUrl = provider.address.contains('://');
  final uri = isUrl ? Uri.tryParse(provider.address) : null;
  final hostPort = isUrl ? '' : provider.address;
  final host = uri?.host ?? hostPort.split(':').first;
  final port = uri != null
      ? (uri.hasPort ? uri.port : 443)
      : int.tryParse(hostPort.split(':').last) ?? 0;
  return DnsProviderEntry(
    id: provider.id,
    name: provider.name,
    protocol: protocol,
    host: host,
    port: port,
    url: isUrl ? provider.address : '',
  );
}

/// 「最近探测」文案：按真实时间差算，没有探测过就写「尚未探测」。
String probeAgoLabel(DateTime? at) {
  if (at == null) return '尚未探测';
  final seconds = DateTime.now().difference(at).inSeconds;
  if (seconds < 5) return '刚刚';
  if (seconds < 60) return '$seconds 秒前';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes 分钟前';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours 小时前';
  return '${hours ~/ 24} 天前';
}
