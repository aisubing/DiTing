/// Outbound-proxy state shared by the settings page and the tunnel start path.
///
/// The two halves of 1.4.3's outbound proxy live in different places on
/// purpose: the nine `outbound_proxy_*` keys stay in `dns_vpn_prefs` (readable
/// through `LegacyPrefsBridge`), but the username/password are AES-GCM
/// encrypted with an AndroidKeyStore key that only the platform can unwrap.
/// That is why every read/write goes through [OutboundProxyStore] instead of
/// the prefs view.
library;

import 'package:diting/data/native/outbound_proxy_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main()` with [MethodChannelOutboundProxyStore].
///
/// The default is in-memory so widget tests and non-Android hosts get a usable
/// object instead of a `MissingPluginException` on first read.
final outboundProxyStoreProvider = Provider<OutboundProxyStore>(
  (ref) => MemoryOutboundProxyStore(),
);

/// Current configuration, reloaded after every save.
///
/// A tunnel start reads this through `ref.read`, so it must never hold a stale
/// value: [bump] is called by the settings page after a successful write.
class OutboundProxyRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final outboundProxyRevisionProvider =
    NotifierProvider<OutboundProxyRevision, int>(OutboundProxyRevision.new);

final outboundProxyConfigProvider = FutureProvider<OutboundProxyConfig>((ref) {
  ref.watch(outboundProxyRevisionProvider);
  return ref.watch(outboundProxyStoreProvider).read();
});
