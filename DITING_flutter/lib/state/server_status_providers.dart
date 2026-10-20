/// 服务器模式的状态与端口：与 VPN 电源状态分开，避免两种模式互相污染。
library;

import 'dart:async';

import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/db/rule_snapshot.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/server/dns_server_bridge.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 服务器模式的监听端口。
class ServerPortNotifier extends Notifier<int> {
  @override
  int build() => ref.read(legacySettingsProvider).serverPort;

  void set(int port) {
    final clamped = port.clamp(1024, 65535);
    state = clamped;
    ref.read(legacySettingsProvider).setServerPort(clamped);
  }
}

final serverPortProvider = NotifierProvider<ServerPortNotifier, int>(
  ServerPortNotifier.new,
);

/// 服务器模式的 5 态状态卡。
enum ServerStatus {
  stopped('已停止'),
  starting('启动中'),
  running('运行中'),
  stopping('停止中'),
  error('异常');

  const ServerStatus(this.label);

  final String label;
}

class ServerStatusNotifier extends Notifier<ServerStatus> {
  bool _disposed = false;

  /// Last native failure, kept for diagnostics without changing the five-state
  /// UI contract.
  String? lastError;

  @override
  ServerStatus build() {
    ref.onDispose(() => _disposed = true);
    // Leaving server mode must not leave a LAN DNS listener behind; the UI
    // would otherwise show another mode while the port stays bound.
    ref.listen(workModeProvider, (previous, next) {
      if (next != AppWorkMode.server &&
          (state == ServerStatus.running || state == ServerStatus.starting)) {
        unawaited(_stop());
      }
    });
    if (ref.read(legacySettingsProvider).serverServiceActive) {
      scheduleMicrotask(syncStatus);
      return ServerStatus.starting;
    }
    return ServerStatus.stopped;
  }

  Future<void> syncStatus() async {
    try {
      final status = await ref.read(dnsServerControllerProvider).status();
      if (_disposed) return;
      ref.read(legacySettingsProvider).setServerServiceActive(status.running);
      if (status.error != null && !status.running) {
        lastError = status.error;
        state = ServerStatus.error;
      } else {
        state = status.running ? ServerStatus.running : ServerStatus.stopped;
      }
      ref
          .read(serviceStatsProvider.notifier)
          .applyNative(status.stats, running: status.running);
    } catch (_) {
      if (!_disposed) state = ServerStatus.stopped;
    }
  }

  Future<void> toggle() async {
    if (state == ServerStatus.starting || state == ServerStatus.stopping) return;
    if (state == ServerStatus.running) {
      await _stop();
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    if (ref.read(workModeProvider) != AppWorkMode.server) {
      _fail('请先切换到服务器模式');
      return;
    }
    // Only one tunnel-like data plane at a time: stop the VPN before binding.
    await ref.read(powerProvider.notifier).stopIfActive();
    if (_disposed) return;
    state = ServerStatus.starting;
    lastError = null;
    final settings = ref.read(legacySettingsProvider);
    try {
      final config = buildServerDnsConfig(settings);
      final rules = await _serverRules();
      if (_disposed) return;
      final result = await ref.read(dnsServerControllerProvider).start(
        DnsServerStartRequest(
          port: config.port,
          dnsConfig: config.encode(),
          ruleSnapshot: encodeRuleSnapshot(rules),
          rewriteRules: encodeRewriteRules(rules),
          adBlockEnabled: config.adBlockEnabled,
        ),
      );
      if (_disposed) return;
      if (!result.started) {
        _fail(result.error ?? 'DNS 服务启动失败');
        return;
      }
      settings.setServerServiceActive(true);
      ref.read(serviceStatsProvider.notifier).markStarted();
      state = ServerStatus.running;
    } catch (error) {
      if (!_disposed) _fail(_messageOf(error));
    }
  }

  Future<void> _stop() async {
    state = ServerStatus.stopping;
    try {
      await ref.read(dnsServerControllerProvider).stop();
    } catch (error) {
      lastError = _messageOf(error);
    }
    if (_disposed) return;
    ref.read(legacySettingsProvider).setServerServiceActive(false);
    ref.read(serviceStatsProvider.notifier).reset();
    state = ServerStatus.stopped;
  }

  Future<Map<RuleKind, List<MockRule>>> _serverRules() async {
    try {
      final repository = await ref.read(serverRuleRepositoryProvider.future);
      return repository == null
          ? <RuleKind, List<MockRule>>{}
          : await repository.loadAll();
    } catch (_) {
      // A missing/locked legacy DB must not prevent the server from starting;
      // upstream resolution still works with an empty per-dataset rule set.
      return <RuleKind, List<MockRule>>{};
    }
  }

  void _fail(String message) {
    lastError = message;
    ref.read(legacySettingsProvider).setServerServiceActive(false);
    state = ServerStatus.error;
  }

  static String _messageOf(Object error) => error is PlatformException
      ? (error.message ?? error.code)
      : error.toString();
}

final dnsServerControllerProvider = Provider<DnsServerController>(
  (ref) => MethodChannelDnsServerController(),
);

final serverStatusProvider =
    NotifierProvider<ServerStatusNotifier, ServerStatus>(
      ServerStatusNotifier.new,
    );
