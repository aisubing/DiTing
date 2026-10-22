/// 进程内存的实时采样。
///
/// 与 [speedSeriesProvider] 同一种形状：`Notifier` + 显式 `attachPolling()`，由
/// 卡片在 `initState` 里挂、`dispose` 里摘。定时器放进 provider 构造函数会让每次
/// watch 都起一个，测试里也就永远 settle 不下来。
///
/// 采样周期 2 秒而不是 1 秒：`getProcessMemoryInfo` 要跨 Binder 问
/// `ActivityManager`，比读一次计数器贵得多，而内存占用本来也不是每秒都变的量。
library;

import 'dart:async';

import 'package:diting/data/native/process_memory.dart';
import 'package:diting/state/cleanup_providers.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 内存采样周期。
const memoryPollInterval = Duration(seconds: 2);

final processMemoryProvider =
    NotifierProvider<ProcessMemoryNotifier, ProcessMemory>(
      ProcessMemoryNotifier.new,
    );

class ProcessMemoryNotifier extends Notifier<ProcessMemory> {
  Timer? _timer;
  int _attachments = 0;
  bool _inFlight = false;

  @override
  ProcessMemory build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _attachments = 0;
    });
    return const ProcessMemory();
  }

  void attachPolling() {
    _attachments++;
    if (debugDisableDashboardLiveUpdates || _timer != null) return;
    _timer = Timer.periodic(memoryPollInterval, (_) => tick());
    unawaited(tick());
  }

  void detachPolling() {
    if (_attachments > 0) _attachments--;
    if (_attachments > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  /// 取一拍真实内存；通道缺失时快照的 `available` 为 false，卡片显示破折号。
  Future<void> tick() async {
    if (_inFlight) return;
    _inFlight = true;
    ProcessMemory next;
    try {
      next = await ref.read(platformBridgeProvider).memoryInfo();
    } catch (_) {
      next = const ProcessMemory();
    } finally {
      _inFlight = false;
    }
    if (!ref.mounted) return;
    state = next;
  }
}
