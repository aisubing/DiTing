/// Dart side of `com.haoze.diting/dns_latency`: 真实 DNS 查询耗时测量。
///
/// 1.4.3 的测速页（`ui/DnsSpeedTestSection.kt`）调的是
/// `core/dns/DnsLatencyTester.testAverage`：对每个服务商连发 3 次**真实** DoH /
/// DoT / 明文查询，取成功样本的平均耗时。加密查询要建 TLS 连接、明文查询要开
/// UDP socket，两者都不能在 Dart 侧完成，所以这里只做参数与结果的搬运。
///
/// ## 契约（Kotlin 侧 `DnsLatencyBridge.kt` 必须逐字对齐）
/// - 通道：`com.haoze.diting/dns_latency`
/// - 方法：`probe`
/// - 入参：`{providers: List<Map>, domain: String, attempts: int}`
///   其中每个 provider map 是
///   `{id, name, host, port, protocol, url}`，`protocol ∈ dns|doh|dot`。
///   `url` 是 DoH 的完整查询地址（原生侧可用它代替 host 拼路径），DNS/DoT
///   服务商为空串。
/// - 返回：`List<Map>`，每项
///   `{providerId, providerName, protocol, elapsedMs, success, message,
///     attempts, successCount, elapsedSamplesMs}`。
/// - 失败语义：**测速失败不抛异常**，写在每项的 `success=false` + `message`；
///   只有参数非法（`providers` 为空）才 `result.error`。
///
/// ## 通道不存在时
/// 桌面宿主 / 单元测试里 `MethodChannel` 抛 `MissingPluginException`。这**不能**
/// 当成「测速失败」处理——那会让页面显示一个像真事的失败结果。这里把它转成
/// [DnsLatencyUnavailable]，页面据此显示「当前设备不支持测速」并禁用按钮。
library;

import 'package:flutter/services.dart';

/// 方案 B 的原生通道名。与仓内其余通道一致用 `com.haoze.diting/xxx`。
const dnsLatencyChannelName = 'com.haoze.diting/dns_latency';

/// 测速协议。`wireValue` 是通道上的字符串，必须与 Kotlin 侧一致。
enum DnsLatencyProtocol {
  dns('dns', 'DNS'),
  doh('doh', 'DoH'),
  dot('dot', 'DoT');

  const DnsLatencyProtocol(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static DnsLatencyProtocol? fromWire(String? value) {
    final normalized = value?.toLowerCase();
    for (final protocol in values) {
      if (protocol.wireValue == normalized) return protocol;
    }
    return null;
  }
}

/// 一个待测服务商。原生侧不认识服务商目录，host/port/协议必须由 Dart 传下去。
class DnsLatencyProviderSpec {
  const DnsLatencyProviderSpec({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.url = '',
  });

  final String id;
  final String name;

  /// DNS / DoT 是主机名或 IP；DoH 是从 url 里取出的 host（可能为空）。
  final String host;

  /// DNS 默认 53、DoT 默认 853、DoH 默认 443。
  final int port;

  final DnsLatencyProtocol protocol;

  /// DoH 的完整查询地址；其余协议为空串。
  final String url;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'protocol': protocol.wireValue,
    'url': url,
  };
}

/// 一个服务商的测速结果（对应 `DnsLatencyTester.Result`）。
class DnsLatencySample {
  const DnsLatencySample({
    required this.providerId,
    required this.providerName,
    required this.protocol,
    required this.elapsedMs,
    required this.success,
    required this.attempts,
    required this.successCount,
    this.samplesMs = const [],
    this.message,
  });

  final String providerId;
  final String providerName;
  final DnsLatencyProtocol protocol;

  /// 成功样本的平均耗时；`success=false` 时是失败那一刻的耗时（旧版行为），
  /// 页面只在 [success] 为真时展示它。
  final int elapsedMs;

  final bool success;

  /// 失败原因；成功且全部尝试都成功时为 `null`。
  final String? message;

  /// 本 provider 实际发起的查询次数。
  final int attempts;

  /// 成功的次数（`0..attempts`）。
  final int successCount;

  /// 每个成功样本的耗时，用于「样本 12 / 15 / 18 ms」。
  final List<int> samplesMs;

  /// 成功率文案的口径：`successCount/attempts`。
  String get successRateLabel => '成功率 $successCount/$attempts';

  static DnsLatencySample fromMap(Map<Object?, Object?> map) {
    final rawSamples = map['elapsedSamplesMs'];
    final attempts = (map['attempts'] as num?)?.toInt() ?? 1;
    final success = map['success'] == true;
    final successCount =
        (map['successCount'] as num?)?.toInt() ?? (success ? 1 : 0);
    return DnsLatencySample(
      providerId: map['providerId'] as String? ?? '',
      providerName: map['providerName'] as String? ?? '',
      protocol:
          DnsLatencyProtocol.fromWire(map['protocol'] as String?) ??
          DnsLatencyProtocol.dns,
      elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
      success: success,
      message: map['message'] as String?,
      attempts: attempts < 1 ? 1 : attempts,
      successCount: successCount,
      samplesMs: [
        if (rawSamples is List)
          for (final item in rawSamples)
            if (item is num) item.toInt(),
      ],
    );
  }
}

/// 设备/宿主没有测速通道。
///
/// 独立成一个异常而不是返回「全部失败」的结果：页面必须把「这台设备不支持
/// 测速」与「服务商这次没应答」分开说，否则用户会以为自己的网络坏了。
class DnsLatencyUnavailable implements Exception {
  const DnsLatencyUnavailable([this.message = '当前设备不支持测速']);

  final String message;

  @override
  String toString() => message;
}

/// 原生测速的执行者。
abstract class DnsLatencyRunner {
  /// 通道是否可用。
  ///
  /// 用「空 providers 的 probe」探测：原生侧对空列表 `result.error`，Dart 侧
  /// 收到的是 `PlatformException`——**通道存在**；而宿主没有这个通道时收到的
  /// 是 `MissingPluginException`。不能用「随便一个未知方法名」探测：Kotlin 的
  /// `setMethodCallHandler` 对未知方法返回 `notImplemented()`，Dart 侧同样抛
  /// `MissingPluginException`，真机上会被误判成不支持。
  Future<bool> checkAvailable();

  /// [attempts] 是每个服务商的查询次数，1–10（旧版固定 3）。
  Future<List<DnsLatencySample>> probe({
    required List<DnsLatencyProviderSpec> providers,
    required String domain,
    int attempts = 3,
  });
}

class MethodChannelDnsLatencyRunner implements DnsLatencyRunner {
  MethodChannelDnsLatencyRunner({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(dnsLatencyChannelName);

  final MethodChannel _channel;

  @override
  Future<bool> checkAvailable() async {
    try {
      await _channel.invokeMethod<Object?>('probe', {
        'providers': const <Object?>[],
        'domain': '',
        'attempts': 1,
      });
      // 原生侧接受空列表并返回了结果（不该发生，但通道显然在）。
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      // 通道在，只是拒绝了空 providers。
      return true;
    }
  }

  @override
  Future<List<DnsLatencySample>> probe({
    required List<DnsLatencyProviderSpec> providers,
    required String domain,
    int attempts = 3,
  }) async {
    final safeAttempts = attempts.clamp(1, 10);
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('probe', {
        'providers': [for (final provider in providers) provider.toMap()],
        'domain': domain,
        'attempts': safeAttempts,
      });
    } on MissingPluginException {
      throw const DnsLatencyUnavailable();
    } on PlatformException catch (error) {
      final detail = error.message;
      throw DnsLatencyUnavailable(
        detail == null || detail.isEmpty
            ? '测速通道调用失败（${error.code}）'
            : '测速通道调用失败：$detail',
      );
    }
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          DnsLatencySample.fromMap(Map<Object?, Object?>.from(item)),
    ];
  }
}

/// 没有原生实现的宿主（组件画廊、纯 Dart 测试）用这个：一律判为不可用。
class UnavailableDnsLatencyRunner implements DnsLatencyRunner {
  const UnavailableDnsLatencyRunner();

  @override
  Future<bool> checkAvailable() async => false;

  @override
  Future<List<DnsLatencySample>> probe({
    required List<DnsLatencyProviderSpec> providers,
    required String domain,
    int attempts = 3,
  }) async => throw const DnsLatencyUnavailable();
}
