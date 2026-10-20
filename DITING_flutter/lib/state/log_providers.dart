/// Log data for the dashboard, read from the database of the active mode.
library;

import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Normal and server modes share `diting_database`; express has its own file.
final activeLogDatabaseFileProvider = Provider<String>((ref) {
  final mode = ref.watch(workModeProvider);
  return mode == AppWorkMode.express
      ? LegacyDatabase.expressFile
      : LegacyDatabase.mainFile;
});

final dnsLogRepositoryProvider = FutureProvider<DnsLogRepository?>((ref) async {
  final db = await LegacyDatabase.open(ref.watch(activeLogDatabaseFileProvider));
  return db == null ? null : DnsLogRepository(db);
});

class DnsLogRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dnsLogRevisionProvider = NotifierProvider<DnsLogRevisionNotifier, int>(
  DnsLogRevisionNotifier.new,
);

/// Latest rows for the active mode. `null` database (fresh install) is an
/// empty list, not an error.
final dnsLogsProvider = FutureProvider<List<DnsLogRecord>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final repository = await ref.watch(dnsLogRepositoryProvider.future);
  return repository?.recent() ?? const [];
});
