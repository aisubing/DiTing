import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Server mode's upstream list: 18 presets plus legacy custom entries.
final serverUpstreamListProvider = Provider<List<ServerUpstream>>((ref) {
  return serverUpstreams(ref.read(legacySettingsProvider));
});

class ServerSelectedUpstreamNotifier extends Notifier<ServerUpstream> {
  @override
  ServerUpstream build() {
    final settings = ref.read(legacySettingsProvider);
    final upstreams = serverUpstreams(settings);
    return upstreams.firstWhere(
      (upstream) => upstream.id == settings.serverSelectedUpstreamId,
      orElse: () => upstreams.first,
    );
  }

  void select(String id) {
    final match = ref
        .read(serverUpstreamListProvider)
        .where((upstream) => upstream.id == id);
    if (match.isEmpty) return;
    state = match.first;
    ref.read(legacySettingsProvider).setServerSelectedUpstreamId(id);
  }
}

final serverSelectedUpstreamProvider =
    NotifierProvider<ServerSelectedUpstreamNotifier, ServerUpstream>(
      ServerSelectedUpstreamNotifier.new,
    );
