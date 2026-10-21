/// 服务器模式需要、但 Dart 侧还没有封装的两个平台能力探测。
///
/// **为什么不直接用 `PlatformBridge`**：`lib/data/native/platform_bridge.dart`
/// 把「通道缺失」和「取值为 false」压成同一个 `false` 返回值——
/// `isIgnoringBatteryOptimizations()` 在「没进白名单」和「这台设备没有通道」
/// 两种情况下都返回 `false`。设置页必须把这两件事分开说（前者引导用户去加白，
/// 后者只能写「当前设备不可用」），所以这里用裸 `MethodChannel` 自己按异常
/// 类型区分，而不是复用那个封装。
///
/// 通道名与方法名逐字对齐原生实现（`PlatformBridge.kt`）：
///
/// | 通道 | 方法 | 返回 |
/// |---|---|---|
/// | `com.haoze.diting/platform` | `isIgnoringBatteryOptimizations` | `bool` |
/// | `com.haoze.diting/platform` | `requestIgnoreBatteryOptimizations` | `bool`（是否唤起了设置页） |
///
/// 「清空缓存」目前**没有**原生实现：`com.haoze.diting/dns_server` 只注册了
/// `start` / `stop` / `status`（见 `DnsServerBridge.kt`），引擎侧的
/// `engine.clearDNSCache()` 没有任何通道暴露它。这里同样按「探测到不可用」处理，
/// 页面如实显示「当前版本尚未接入清空缓存」，而不是假装清空成功。
///
/// 待原生补上 `clearCache` 后，本文件只需改注释，页面侧不用动。
library;

import 'package:flutter/services.dart';

/// 与 `PlatformBridge.kt` 的 `CHANNEL` 一致。
const platformChannelName = 'com.haoze.diting/platform';

/// 与 `DnsServerBridge.kt` 的 `CHANNEL` 一致。
const serverChannelName = 'com.haoze.diting/dns_server';

/// 忽略电池优化的三态：已忽略 / 未忽略 / 设备不支持。
enum BatteryOptimizationState {
  /// 已在系统白名单里。
  ignored,

  /// 系统支持，但当前未加入白名单。
  notIgnored,

  /// 没有原生通道（桌面宿主、测试宿主）。
  unavailable,
}

/// 查询忽略电池优化状态；通道缺失返回 [BatteryOptimizationState.unavailable]。
Future<BatteryOptimizationState> readBatteryOptimization() async {
  try {
    final granted = await const MethodChannel(platformChannelName)
        .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    if (granted == null) {
      return BatteryOptimizationState.unavailable;
    }
    return granted
        ? BatteryOptimizationState.ignored
        : BatteryOptimizationState.notIgnored;
  } on MissingPluginException {
    return BatteryOptimizationState.unavailable;
  } on PlatformException {
    return BatteryOptimizationState.unavailable;
  }
}

/// 发起系统「忽略电池优化」请求，返回发起后读回的**系统状态**。
///
/// 不看原生返回值：它只表示「是否唤起了设置页」，用户在系统对话框里点取消后
/// 通道照样返回 true。这一格要反映「现在到底在不在白名单里」，所以调用完无条件
/// 重读一次。
Future<BatteryOptimizationState> requestBatteryOptimization() async {
  try {
    await const MethodChannel(platformChannelName)
        .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
  } on MissingPluginException {
    return BatteryOptimizationState.unavailable;
  } on PlatformException {
    return BatteryOptimizationState.unavailable;
  }
  return readBatteryOptimization();
}

/// 清空服务器模式的 DNS 缓存；返回 false 表示原生侧还没有这个接口。
///
/// 现在必然返回 false——原生只注册了 start / stop / status。保留这次调用而不是
/// 写死 `false`：等原生补上 `clearCache`，这里自动生效，页面不用改。
Future<bool> clearServerDnsCache() async {
  try {
    return await const MethodChannel(serverChannelName)
            .invokeMethod<bool>('clearCache') ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
