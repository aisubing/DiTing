/// Applies the on-demand whitelist to the live tunnel.
///
/// The switch and the SSID table are persisted configuration; without this runner they were only
/// ever displayed. There is no background network callback in this build (the platform channel
/// reports the joined SSID on demand), so the whitelist is re-evaluated on start, on resume and
/// whenever the user asks for it — the same foreground catch-up that [AutoUpdateRunner] uses.
library;

import 'package:diting/pages/config/on_demand_capabilities.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What one evaluation did, so the page can say why nothing happened.
enum OnDemandOutcome {
  /// The on-demand switch is off; the tunnel is left to the power button.
  disabled('按需连接已关闭，未做改动'),

  /// Server mode owns its own service; the tunnel whitelist does not apply.
  serverMode('服务器模式不使用隧道，未做改动'),

  /// The platform could not report the network, so the whitelist cannot be trusted.
  unknownSsid('无法读取当前 Wi-Fi，未做改动'),

  /// Not on Wi-Fi and no whitelist entry covers cellular.
  noWifi('当前不在 Wi-Fi 上，已断开 VPN'),

  /// Matched an entry, so the tunnel was (or already is) running.
  started('已匹配白名单，VPN 已启动'),

  /// Already running for a matching network; nothing to change.
  alreadyRunning('已匹配白名单，VPN 正在运行'),

  /// Did not match, so a running tunnel was stopped.
  stopped('当前网络不在白名单，已断开 VPN'),

  /// Did not match and nothing was running.
  alreadyStopped('当前网络不在白名单，VPN 未启动'),

  /// The tunnel is mid-transition; the next evaluation picks it up.
  busy('VPN 正在切换状态，稍后再试'),

  /// The whitelist matched but the system dialog has not been accepted yet.
  needsConsent('已匹配白名单，等待系统 VPN 授权');

  const OnDemandOutcome(this.label);

  final String label;
}

/// Re-evaluates the whitelist against the network the device is on now and moves the tunnel to
/// match it.
class OnDemandRunner {
  OnDemandRunner(this._ref);

  final Ref _ref;

  Future<OnDemandOutcome> apply() async {
    final resources = _ref.read(configResourcesProvider);
    if (!resources.onDemand) {
      return OnDemandOutcome.disabled;
    }
    // Server mode runs the LAN DNS service instead of the tunnel, so there is nothing to switch.
    if (_ref.read(workModeProvider) == AppWorkMode.server) {
      return OnDemandOutcome.serverMode;
    }
    // Read the SSID fresh: the cached provider may describe the network from before a switch.
    final ssid = await _ref.read(currentSsidReaderProvider)();
    final decision = decideSsid(
      enabled: true,
      rules: resources.ssidRules,
      currentSsid: ssid,
    );
    final power = _ref.read(powerProvider);
    switch (decision.state) {
      case SsidMatchState.disabled:
        return OnDemandOutcome.disabled;
      case SsidMatchState.unknown:
        return OnDemandOutcome.unknownSsid;
      case SsidMatchState.matched:
        if (power.isRunning) {
          return OnDemandOutcome.alreadyRunning;
        }
        if (power.isBusy) {
          return OnDemandOutcome.busy;
        }
        await _ref.read(powerProvider.notifier).toggle();
        final after = _ref.read(powerProvider);
        // `toggle` returns once the start is scheduled; `starting` means the system consent
        // dialog is still open and the real answer arrives through `onPrepareResult`.
        return after.isRunning
            ? OnDemandOutcome.started
            : OnDemandOutcome.needsConsent;
      case SsidMatchState.noWifi:
      case SsidMatchState.unmatched:
        if (!power.isRunning) {
          return OnDemandOutcome.alreadyStopped;
        }
        if (power.isBusy) {
          return OnDemandOutcome.busy;
        }
        await _ref.read(powerProvider.notifier).stop();
        return OnDemandOutcome.stopped;
    }
  }
}

final onDemandRunnerProvider = Provider<OnDemandRunner>(OnDemandRunner.new);
