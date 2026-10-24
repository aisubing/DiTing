import 'package:diting/app/app.dart';
import 'package:diting/app/debug_probe.dart';
import 'package:diting/data/db/rule_bootstrap.dart';
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/native/app_version.dart';
import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/native/dns_latency_bridge.dart';
import 'package:diting/data/native/outbound_proxy_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/app_version_provider.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/state/network_tools_providers.dart';
import 'package:diting/state/outbound_proxy_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// App entry point, the only `runApp`. Legacy settings and rules load before the first
/// frame so providers see stored values instead of flashing defaults. Native channels are
/// injected here as a group: defaults are stubs, so a missing override degrades a feature.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installDebugProbe();
  final watch = Stopwatch()..start();
  var last = 0;
  void stage(String label) {
    if (!kDebugMode) return;
    debugPrint('startup $label +${watch.elapsedMilliseconds - last}ms');
    last = watch.elapsedMilliseconds;
  }

  // The two loads share the wait; the rules bootstrap needs both results, so it stays last.
  final storeTask = loadLegacyPrefsStore();
  final versionTask = loadAppVersion();
  final store = await storeTask;
  stage('prefs');
  final settings = LegacySettings(store);
  // Single source of truth: `pubspec.yaml`. The value feeds preset seeding,
  // cleanup actions and page display.
  final version = await versionTask;
  stage('version');
  final rules = await bootstrapRules(settings, versionCode: version.code);
  stage('rules');
  runApp(
    ProviderScope(
      overrides: [
        legacyPrefsStoreProvider.overrideWithValue(store),
        appVersionProvider.overrideWithValue(version),
        ruleRepositoryProvider.overrideWithValue(rules.repository),
        initialRulesProvider.overrideWithValue(rules.rules),
        // Real app list via PackageManager (QUERY_ALL_PACKAGES), shared by the four picker pages.
        installedAppsSourceProvider.overrideWithValue(
          MethodChannelInstalledAppsSource(),
        ),
        // Credentials are wrapped by AndroidKeyStore, so Dart only sees the whole config blob.
        outboundProxyStoreProvider.overrideWithValue(
          MethodChannelOutboundProxyStore(),
        ),
        caCertificateServiceProvider.overrideWithValue(
          MethodChannelCaCertificateService(),
        ),
        // Turns plugin exceptions into readable failures for the diagnostics
        // panel instead of red screens.
        diagnosticsRunnerProvider.overrideWithValue(
          GuardedDiagnosticsRunner(MethodChannelDiagnosticsRunner()),
        ),
        // Deliberately unguarded: failures are reported per item via `success=false` so the page
        // can tell "unsupported device" from "probe ran and failed".
        dnsLatencyRunnerProvider.overrideWithValue(
          MethodChannelDnsLatencyRunner(),
        ),
      ],
      child: const DitingApp(),
    ),
  );
}
