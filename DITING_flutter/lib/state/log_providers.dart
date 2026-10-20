/// Log data for the dashboard, read from the database of the active mode.
library;

import 'package:diting/data/db/dns_cache_repository.dart';
import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/race_log_repository.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Normal and server modes share `diting_database`; express has its own file.
final activeLogDatabaseFileProvider = Provider<String>((ref) {
  final mode = ref.watch(workModeProvider);
  return mode == AppWorkMode.express
      ? LegacyDatabase.expressFile
      : LegacyDatabase.mainFile;
});

/// `null` on fresh installs, where the Dart layer has not created the file yet.
final activeLogDatabaseProvider = FutureProvider<Database?>(
  (ref) => LegacyDatabase.open(ref.watch(activeLogDatabaseFileProvider)),
);

/// All three dashboard views read from the same legacy file; the revision
/// counter is bumped by "refresh" and "clear" so one action reloads all of
/// them instead of leaving stale rows in a hidden tab.
class DnsLogRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dnsLogRevisionProvider = NotifierProvider<DnsLogRevisionNotifier, int>(
  DnsLogRevisionNotifier.new,
);

Future<T> _viaDatabase<T>(
  Ref ref,
  Future<T> Function(Database db) build,
  T empty,
) async {
  final db = await ref.watch(activeLogDatabaseProvider.future);
  return db == null ? empty : build(db);
}

/// Latest rows for the active mode.
final dnsLogsProvider = FutureProvider<List<DnsLogRecord>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  return _viaDatabase(
    ref,
    (db) => DnsLogRepository(db).recent(),
    const <DnsLogRecord>[],
  );
});

final dnsCacheProvider = FutureProvider<List<DnsCacheRecord>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  return _viaDatabase(
    ref,
    (db) => DnsCacheRepository(db).entries(),
    const <DnsCacheRecord>[],
  );
});

/// Ranking rows with provider ids already resolved to display names.
final raceRankingProvider = FutureProvider<RaceRankingBoard>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final settings = ref.watch(legacySettingsProvider);
  final names = {
    for (final provider in [
      ...defaultDnsProviders,
      ...parseUserProviders(settings.userProvidersJson),
    ])
      provider.id: provider.name,
  };
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return const RaceRankingBoard.empty();
  final repository = RaceLogRepository(db);
  final entries = await repository.ranking();
  final summary = await repository.summary();
  return RaceRankingBoard(
    summary: RaceSummary(
      requests: summary.requests,
      failures: summary.failures,
      averageLatencyMs: summary.averageLatencyMs,
    ),
    entries: [
      for (final entry in entries)
        RaceRanking(
          provider: names[entry.providerId] ?? entry.providerId,
          wins: entry.wins,
          averageLatencyMs: entry.averageLatencyMs,
        ),
    ],
  );
});

/// Ranking rows plus the whole-table summary shown above them.
class RaceRankingBoard {
  const RaceRankingBoard({required this.summary, required this.entries});

  const RaceRankingBoard.empty()
    : summary = const RaceSummary(requests: 0, failures: 0, averageLatencyMs: 0),
      entries = const [];

  final RaceSummary summary;
  final List<RaceRanking> entries;
}

class RaceSummary {
  const RaceSummary({
    required this.requests,
    required this.failures,
    required this.averageLatencyMs,
  });

  final int requests;
  final int failures;
  final int averageLatencyMs;
}

/// Ranking row after name resolution.
class RaceRanking {
  const RaceRanking({
    required this.provider,
    required this.wins,
    required this.averageLatencyMs,
  });

  final String provider;
  final int wins;
  final int averageLatencyMs;
}
