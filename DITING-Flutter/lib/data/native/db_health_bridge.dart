/// Dart side of `com.haoze.diting/db_health`: what the native log writers had to drop and why.
///
/// The 2.1.7 failure mode was silent — a locked `diting_database` left every log page empty and
/// nothing said so. These counters make "no logs at all" visible from 故障排查.
library;

import 'package:flutter/services.dart';

const dbHealthChannelName = 'com.haoze.diting/db_health';

class DbWriteHealthSnapshot {
  const DbWriteHealthSnapshot({
    this.droppedRows = 0,
    this.openFailures = 0,
    this.lastCause = '',
  });

  /// Rows thrown away because they could not be buffered or persisted at all.
  final int droppedRows;

  /// How many times opening the database failed (a locked file, not a missing one).
  final int openFailures;

  /// Last native failure, e.g. `SQLiteDatabaseLockedException: database is locked`.
  final String lastCause;

  /// True when nothing was dropped and no open failed during this process lifetime.
  bool get healthy => droppedRows == 0 && openFailures == 0;

  static const unavailable = DbWriteHealthSnapshot();

  static DbWriteHealthSnapshot fromMap(Object? raw) {
    if (raw is! Map) return unavailable;
    return DbWriteHealthSnapshot(
      droppedRows: (raw['droppedRows'] as num?)?.toInt() ?? 0,
      openFailures: (raw['openFailures'] as num?)?.toInt() ?? 0,
      lastCause: raw['lastCause'] as String? ?? '',
    );
  }
}

class DbHealthBridge {
  DbHealthBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(dbHealthChannelName);

  final MethodChannel _channel;

  Future<DbWriteHealthSnapshot> status() async {
    try {
      return DbWriteHealthSnapshot.fromMap(
        await _channel.invokeMethod<Object?>('status'),
      );
    } on MissingPluginException {
      return DbWriteHealthSnapshot.unavailable;
    } on PlatformException {
      return DbWriteHealthSnapshot.unavailable;
    }
  }
}
