/// 服务器模式需要、但原生侧尚未提供的两个平台能力：忽略电池优化 / 清空缓存。
///
/// **临时位置说明**：`lib/data/native/` 与 `android/` 属于本轮另一位实现者
/// （Lead）的作用域，Dart 封装 `BatteryBridge` 还不存在。为了不伪造「可用」，
/// 这里用裸 `MethodChannel` 做最小探测，并把「通道缺失」当成一个明确的第三态
/// （`unavailable`）上屏：开关置灰、文案写「当前设备不可用」。
///
/// 待 Lead 补齐原生实现后，本文件可以整体换成
/// `package:diting/data/native/battery_bridge.dart`，页面侧只依赖
/// [BatteryOptimizationProbe] 与 [clearServerDnsCache] 两个入口，替换成本很低。
///
/// 需要 Lead 实现的原生方法（与 1.4.3 的 `BatteryOptimizationHelper` 同语义）：
///
/// | 通道 | 方法 | 返回 |
/// |---|---|---|
/// | `com.haoze.diting/battery` | `isIgnoringBatteryOptimizations` | `bool` |
/// | `com.haoze.diting/battery` | `requestIgnoreBatteryOptimizations` | `bool`（是否已忽略） |
/// | `com.haoze.diting/dns_server` | `clearCache` | `bool`（是否已清空） |
///
/// `android/` 侧对应 `PowerManager.isIgnoringBatteryOptimizations` 与
/// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`（见
/// `Android/app/src/main/java/com/haoze/diting/permission/BatteryOptimizationHelper.kt`），
/// 清空缓存对应 `DnsServerEngine` 里的 `engine.clearDNSCache()`。
library;

import 'package:flutter/services.dart';

const batteryChannelName = 'com.haoze.diting/battery';
const serverChannelName = 'com.haoze.diting/dns_server';

/// 忽略电池优化的三态：可用/不可用/未知（通道缺失）。
enum BatteryOptimizationState {
  /// 已在系统白名单里。
  ignored,

  /// 系统支持，但当前未加入白名单。
  notIgnored,

  /// 没有原生通道（桌面宿主、测试宿主，或原生实现尚未接入）。
  unavailable,
}

/// 查询忽略电池优化状态；通道缺失返回 [BatteryOptimizationState.unavailable]。
Future<BatteryOptimizationState> readBatteryOptimization() async {
  try {
    final granted = await const MethodChannel(batteryChannelName)
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

/// 发起系统「忽略电池优化」请求；返回发起后读回的状态。
///
/// 无论如何都再查一次系统状态：用户可能在系统对话框里点了取消，这一格不能
/// 因为「调用成功」就显示已忽略。
Future<BatteryOptimizationState> requestBatteryOptimization() async {
  try {
    await const MethodChannel(batteryChannelName)
        .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
  } on MissingPluginException {
    return BatteryOptimizationState.unavailable;
  } on PlatformException {
    return BatteryOptimizationState.unavailable;
  }
  return readBatteryOptimization();
}

/// 清空服务器模式的 DNS 缓存；返回 false 表示原生侧还没有这个接口。
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
