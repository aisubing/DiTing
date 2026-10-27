/// Read/write access to the legacy rule tables; `*_source` join tables carry provenance (`preset`,
/// `useradd`, `sub_<id>`) and a rule applies only when it and one of its sources are enabled.
library;

import 'dart:io';

import 'package:diting/data/mock_data.dart';
import 'package:sqflite/sqflite.dart';

class RuleRepository {
  RuleRepository(this._db);

  final Database _db;

  static const _ruleTables = {
    RuleKind.block: 'block_rule',
    RuleKind.allow: 'allow_rule',
    RuleKind.rewrite: 'rewrite_rule',
  };

  static const _sourceTables = {
    RuleKind.block: 'block_rule_source',
    RuleKind.allow: 'allow_rule_source',
    RuleKind.rewrite: 'rewrite_rule_source',
  };

  /// Sources that [clearUser] may delete; `preset` and `sub_*` are kept.
  static const userSources = ['useradd', 'local_import', 'local_hosts'];

  Future<Map<RuleKind, List<MockRule>>> loadAll() async {
    final subscriptions = await _subscriptionNames();
    return {
      for (final kind in RuleKind.values)
        kind: await _loadKind(kind, subscriptions),
    };
  }

  Future<List<MockRule>> loadKind(RuleKind kind) async =>
      _loadKind(kind, await _subscriptionNames());

  Future<Map<int, String>> _subscriptionNames() async {
    final rows = await _db.query('subscription', columns: ['id', 'name']);
    return {for (final row in rows) row['id'] as int: row['name'] as String};
  }

  Future<List<MockRule>> _loadKind(
    RuleKind kind,
    Map<int, String> subscriptionNames,
  ) async {
    final rows = await _db.query(_ruleTables[kind]!, orderBy: 'id DESC');
    final sourceRows = await _db.query(_sourceTables[kind]!);
    final byRule = <int, List<_SourceRef>>{};
    for (final row in sourceRows) {
      final ruleId = row['ruleId'] as int;
      (byRule[ruleId] ??= []).add(
        _SourceRef(row['source'] as String, (row['enabled'] as int) == 1),
      );
    }

    return [
      for (final row in rows)
        _toRule(
          kind,
          row,
          byRule[row['id'] as int] ?? const [],
          subscriptionNames,
        ),
    ];
  }

  MockRule _toRule(
    RuleKind kind,
    Map<String, Object?> row,
    List<_SourceRef> sources,
    Map<int, String> subscriptionNames,
  ) {
    final sourceEnabled = sources.isEmpty || sources.any((ref) => ref.enabled);
    final appScope = (row['appScope'] as String?)?.trim();
    return MockRule(
      id: '${row['id']}',
      pattern: row['pattern'] as String,
      kind: kind,
      source: _originOf(sources),
      enabled: (row['enabled'] as int) == 1 && sourceEnabled,
      important:
          kind != RuleKind.rewrite && (row['important'] as int? ?? 0) == 1,
      group: row['groupName'] as String?,
      subscriptionName: _subscriptionNameOf(sources, subscriptionNames),
      target: kind == RuleKind.rewrite ? row['targetValue'] as String? : null,
      appScope: appScope == null || appScope.isEmpty ? null : appScope,
      appInverted:
          kind != RuleKind.rewrite && (row['appInverted'] as int? ?? 0) == 1,
    );
  }

  RuleSource _originOf(List<_SourceRef> sources) {
    if (sources.any((ref) => ref.source == 'preset')) {
      return RuleSource.preset;
    }
    if (sources.any((ref) => ref.source.startsWith('sub_'))) {
      return RuleSource.subscription;
    }
    return RuleSource.user;
  }

  String? _subscriptionNameOf(
    List<_SourceRef> sources,
    Map<int, String> names,
  ) {
    for (final ref in sources) {
      if (!ref.source.startsWith('sub_')) {
        continue;
      }
      final id = int.tryParse(ref.source.substring(4));
      if (id != null && names.containsKey(id)) {
        return names[id];
      }
    }
    return null;
  }

  /// Inserts a user rule and its `useradd` source, reusing a row with the same identity.
  Future<MockRule> add(RuleKind kind, String pattern, {String? target}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.transaction<int>((txn) async {
      final existing = await _findExisting(txn, kind, pattern, target);
      final ruleId =
          existing ?? await _insertRule(txn, kind, pattern, target, now);
      await txn.insert(_sourceTables[kind]!, {
        'ruleId': ruleId,
        'source': 'useradd',
        'enabled': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return ruleId;
    });
    return MockRule(
      id: '$id',
      pattern: pattern,
      kind: kind,
      source: RuleSource.user,
      target: target,
    );
  }

  Future<int?> _findExisting(
    DatabaseExecutor txn,
    RuleKind kind,
    String pattern,
    String? target,
  ) async {
    final rows = kind == RuleKind.rewrite
        ? await txn.query(
            'rewrite_rule',
            columns: ['id'],
            where: 'pattern = ? AND targetType = ? AND targetValue = ?',
            whereArgs: [pattern, rewriteTargetType(target), target],
            limit: 1,
          )
        : await txn.query(
            _ruleTables[kind]!,
            columns: ['id'],
            where:
                'pattern = ? AND important = 0 AND appScope IS NULL '
                'AND appInverted = 0 AND dnsType IS NULL AND isRegex = 0',
            whereArgs: [pattern],
            limit: 1,
          );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<int> _insertRule(
    DatabaseExecutor txn,
    RuleKind kind,
    String pattern,
    String? target,
    int addedAt, {
    String? groupName,
  }) {
    if (kind == RuleKind.rewrite) {
      return txn.insert('rewrite_rule', {
        'pattern': pattern,
        'targetType': rewriteTargetType(target),
        'targetValue': target,
        'rawLine': pattern,
        'addedAt': addedAt,
        'enabled': 1,
      });
    }
    return txn.insert(_ruleTables[kind]!, {
      'pattern': pattern,
      'rawLine': pattern,
      'addedAt': addedAt,
      'enabled': 1,
      'groupName': groupName,
      'important': 0,
      'appScope': null,
      'appInverted': 0,
      'isWildcard': pattern.contains('*') ? 1 : 0,
      'denyallow': null,
      'isRegex': 0,
      'dnsType': null,
    });
  }

  Future<void> setEnabled(RuleKind kind, int id, bool enabled) => _db.update(
    _ruleTables[kind]!,
    {'enabled': enabled ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// [promotePreset] turns a preset rule into a user rule, so a preset reset cannot revert the
  /// edit.
  Future<void> update(
    RuleKind kind,
    int id,
    String pattern, {
    String? target,
    bool promotePreset = false,
  }) async {
    await _db.transaction((txn) async {
      if (kind == RuleKind.rewrite) {
        await txn.update(
          'rewrite_rule',
          {
            'pattern': pattern,
            'targetType': rewriteTargetType(target),
            'targetValue': target,
            'rawLine': pattern,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.update(
          _ruleTables[kind]!,
          {'pattern': pattern, 'rawLine': pattern},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      if (promotePreset) {
        final sources = _sourceTables[kind]!;
        await txn.delete(
          sources,
          where: 'ruleId = ? AND source = ?',
          whereArgs: [id, 'preset'],
        );
        await txn.insert(sources, {
          'ruleId': id,
          'source': 'useradd',
          'enabled': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> delete(RuleKind kind, int id) =>
      _db.delete(_ruleTables[kind]!, where: 'id = ?', whereArgs: [id]);

  /// Removes user-owned sources and any rules left without a source.
  Future<int> clearUser(RuleKind kind) async {
    final table = _ruleTables[kind]!;
    final sources = _sourceTables[kind]!;
    return _db.transaction<int>((txn) async {
      final placeholders = List.filled(userSources.length, '?').join(',');
      final affected = await txn.rawQuery(
        'SELECT DISTINCT ruleId FROM $sources WHERE source IN ($placeholders)',
        userSources,
      );
      await txn.delete(
        sources,
        where: 'source IN ($placeholders)',
        whereArgs: userSources,
      );
      await txn.delete(
        table,
        where:
            'NOT EXISTS (SELECT 1 FROM $sources s WHERE s.ruleId = $table.id)',
      );
      return affected.length;
    });
  }

  Future<int> resetPresetWhitelist(
    List<({String domain, String group})> entries,
  ) {
    return _db.transaction<int>((txn) async {
      await txn.delete(
        'allow_rule_source',
        where: 'source = ?',
        whereArgs: ['preset'],
      );
      await txn.delete(
        'allow_rule',
        where:
            'NOT EXISTS (SELECT 1 FROM allow_rule_source s '
            'WHERE s.ruleId = allow_rule.id)',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in entries) {
        final id = await _insertRule(
          txn,
          RuleKind.allow,
          entry.domain,
          null,
          now,
          groupName: entry.group,
        );
        await txn.insert('allow_rule_source', {
          'ruleId': id,
          'source': 'preset',
          'enabled': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return entries.length;
    });
  }

  /// `appScope` is a `|`-separated list, so the package may be the whole value or a slice.
  static String _scopeClause(String scopeColumn) =>
      '($scopeColumn = ? OR $scopeColumn LIKE ? OR $scopeColumn LIKE ? '
      'OR $scopeColumn LIKE ?)';

  static List<String> _scopeArgs(String packageName) => [
    packageName,
    '$packageName|%',
    '%|$packageName|%',
    '%|$packageName',
  ];

  /// Excludes the `*` full-block marker; sources are read, so all-disabled yields false.
  Future<List<MockRule>> loadForApp(String packageName) async {
    final subscriptions = await _subscriptionNames();
    final result = <MockRule>[];
    for (final kind in [RuleKind.block, RuleKind.allow]) {
      final rows = await _db.query(
        _ruleTables[kind]!,
        where:
            '${_scopeClause('appScope')} AND appInverted = 0 AND pattern <> ?',
        whereArgs: [..._scopeArgs(packageName), '*'],
        orderBy: 'id DESC',
      );
      if (rows.isEmpty) continue;
      final ids = [for (final row in rows) row['id'] as int];
      final placeholders = List.filled(ids.length, '?').join(',');
      final sourceRows = await _db.query(
        _sourceTables[kind]!,
        where: 'ruleId IN ($placeholders)',
        whereArgs: ids,
      );
      final byRule = <int, List<_SourceRef>>{};
      for (final row in sourceRows) {
        (byRule[row['ruleId'] as int] ??= []).add(
          _SourceRef(row['source'] as String, (row['enabled'] as int) == 1),
        );
      }
      result.addAll([
        for (final row in rows)
          _toRule(
            kind,
            row,
            byRule[row['id'] as int] ?? const [],
            subscriptions,
          ),
      ]);
    }
    return result;
  }

  /// Returns the new row, or null when an identical scoped rule already exists; that duplicate is
  /// re-enabled and gets a `useradd` source.
  Future<MockRule?> addForApp(
    RuleKind kind,
    String pattern,
    String packageName, {
    bool important = false,
  }) async {
    if (kind == RuleKind.rewrite) {
      throw ArgumentError('rewrite rules are global only');
    }
    final trimmed = pattern.trim();
    if (trimmed.isEmpty || packageName.trim().isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final outcome = await _db.transaction<int?>((txn) async {
      final existing = await txn.query(
        _ruleTables[kind]!,
        columns: ['id'],
        where: 'pattern = ? AND important = ? AND appScope = ? AND appInverted = 0',
        whereArgs: [trimmed, important ? 1 : 0, packageName],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        // Re-enable a disabled duplicate instead of silently no-oping.
        await txn.update(
          _ruleTables[kind]!,
          {'enabled': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert(_sourceTables[kind]!, {
          'ruleId': id,
          'source': 'useradd',
          'enabled': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        return null;
      }
      final id = await txn.insert(_ruleTables[kind]!, {
        'pattern': trimmed,
        'rawLine': trimmed,
        'addedAt': now,
        'enabled': 1,
        'important': important ? 1 : 0,
        'appScope': packageName,
        'appInverted': 0,
        'isWildcard': trimmed.contains('*') ? 1 : 0,
        'denyallow': null,
        'isRegex': 0,
        'dnsType': null,
      });
      await txn.insert(_sourceTables[kind]!, {
        'ruleId': id,
        'source': 'useradd',
        'enabled': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return id;
    });
    if (outcome == null) return null;
    return MockRule(
      id: '$outcome',
      pattern: trimmed,
      kind: kind,
      source: RuleSource.user,
      important: important,
      appScope: packageName,
    );
  }

  /// Whether the app has the `*` full-block rule (`*$app=<pkg>`).
  Future<bool> hasFullBlock(String packageName) async {
    final rows = await _db.query(
      'block_rule',
      columns: ['id'],
      where:
          'pattern = ? AND appInverted = 0 AND enabled = 1 '
          'AND ${_scopeClause('appScope')}',
      whereArgs: ['*', ..._scopeArgs(packageName)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Enables or removes the app's `pattern = '*'` full-block rule; returns the new state.
  Future<bool> setFullBlock(String packageName, bool enabled) async {
    final existing = await _db.query(
      'block_rule',
      columns: ['id'],
      where: 'pattern = ? AND appInverted = 0 AND ${_scopeClause('appScope')}',
      whereArgs: ['*', ..._scopeArgs(packageName)],
      limit: 1,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      if (enabled) {
        final id = existing.isEmpty
            ? await txn.insert('block_rule', {
                'pattern': '*',
                'rawLine': '*\$app=$packageName',
                'addedAt': now,
                'enabled': 1,
                'important': 0,
                'appScope': packageName,
                'appInverted': 0,
                'isWildcard': 1,
                'denyallow': null,
                'isRegex': 0,
                'dnsType': null,
              })
            : existing.first['id'] as int;
        await txn.update(
          'block_rule',
          {'enabled': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('block_rule_source', {
          'ruleId': id,
          'source': 'useradd',
          'enabled': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await txn.delete('block_rule', where: 'id = ?', whereArgs: [id]);
        await txn.delete(
          'block_rule_source',
          where: 'ruleId = ?',
          whereArgs: [id],
        );
      }
    });
    return enabled;
  }
}

String rewriteTargetType(String? target) {
  if (target == null || target.isEmpty) {
    return 'CNAME';
  }
  final address = InternetAddress.tryParse(target);
  if (address == null) {
    return 'CNAME';
  }
  return address.type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6';
}

class _SourceRef {
  const _SourceRef(this.source, this.enabled);

  final String source;
  final bool enabled;
}
