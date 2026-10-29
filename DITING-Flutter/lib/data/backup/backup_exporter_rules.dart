part of 'backup_exporter.dart';

// Subscription and rule groups of the backup export.

extension _BackupRuleExport on BackupExporter {
  Future<Object?> _subscriptions(BackupExportSource source) async {
    final db = source.database;
    if (db == null) return const [];
    final repository = SubscriptionRepository(db);
    final groups = await repository.groups();
    final rows = await repository.all();
    // `mirror_template` has no repository layer; early databases may lack the table.
    var templates = const <Map<String, Object?>>[];
    if (await _hasTable(db, 'mirror_template')) {
      templates = await db.query(
        'mirror_template',
        columns: ['name', 'template'],
        orderBy: 'name',
      );
    }
    return {
      'groups': [
        for (final group in groups)
          {'name': group.name, 'autoUpdateEnabled': group.autoUpdateEnabled},
      ],
      'mirrorTemplates': [
        for (final row in templates)
          {'name': row['name'], 'template': row['template']},
      ],
      'items': [
        for (final row in rows)
          {
            'url': row.url,
            'name': row.name,
            'kind': row.kind.storageValue,
            'scope': 'dns',
            'sourceType': row.sourceType.storageValue,
            'enabled': row.enabled,
            'groupName': _groupNameOf(groups, row.groupId),
            'mirrorTemplate': row.mirrorTemplate,
            'mirrorFallback': row.mirrorFallback,
          },
      ],
    };
  }

  Future<bool> _hasTable(Database db, String name) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  String? _groupNameOf(List<SubscriptionGroupRecord> groups, int? groupId) {
    if (groupId == null) return null;
    for (final group in groups) {
      if (group.id == groupId) return group.name;
    }
    return null;
  }

  /// Block and allow rules share one group, split by each rule's `kind`; `appScope`, `appInverted`
  /// and `rawLine` must be kept.
  Future<Object?> _rules(BackupExportSource source, BackupGroup group) async {
    final db = source.database;
    if (db == null) return const [];
    final exported = <Object?>[];
    for (final kind in const [RuleKind.block, RuleKind.allow]) {
      final table = kind == RuleKind.block ? 'block_rule' : 'allow_rule';
      final sourceTable = kind == RuleKind.block
          ? 'block_rule_source'
          : 'allow_rule_source';
      final userRuleIds = await _userRuleIds(db, sourceTable);
      final rows = await db.query(table, orderBy: 'id DESC');
      for (final row in rows) {
        // User-added only: presets ship with the app, subscriptions rebuild.
        if (!userRuleIds.contains(row['id'] as int)) continue;
        exported.add({
          'pattern': row['pattern'],
          'kind': kind == RuleKind.allow ? 'allow' : 'block',
          'enabled': (row['enabled'] as int? ?? 1) == 1,
          'important': (row['important'] as int? ?? 0) == 1,
          'appScope': row['appScope'],
          'appInverted': (row['appInverted'] as int? ?? 0) == 1,
          'rawLine': row['rawLine'],
          'group': row['groupName'],
        });
      }
    }
    return exported;
  }

  /// Ids of user-origin rules (`useradd`/`local_import`/`local_hosts`).
  Future<Set<int>> _userRuleIds(Database db, String sourceTable) async {
    final rows = await db.query(sourceTable, columns: ['ruleId', 'source']);
    return {
      for (final row in rows)
        if (RuleRepository.userSources.contains(row['source']))
          row['ruleId'] as int,
    };
  }

  /// Rewrite rules, split by `targetType` into IPv4/IPv6 and CNAME.
  Future<Object?> _rewriteRules(
    BackupExportSource source,
    Set<String> targetTypes,
  ) async {
    final db = source.database;
    if (db == null) return const [];
    final rows = await db.query('rewrite_rule', orderBy: 'id DESC');
    final userRuleIds = await _userRewriteRuleIds(db);
    return [
      for (final row in rows)
        if (targetTypes.contains(row['targetType']) &&
            userRuleIds.contains(row['id'] as int))
          {
            'pattern': row['pattern'],
            'targetType': row['targetType'],
            'targetValue': row['targetValue'],
            'rawLine': row['rawLine'],
            'enabled': (row['enabled'] as int? ?? 1) == 1,
          },
    ];
  }

  Future<Set<int>> _userRewriteRuleIds(Database db) async {
    final rows = await db.query(
      'rewrite_rule_source',
      columns: ['ruleId', 'source'],
    );
    return {
      for (final row in rows)
        if (RuleRepository.userSources.contains(row['source']))
          row['ruleId'] as int,
    };
  }

  Object? _addressRules(BackupExportSource source) async {
    final db = source.database;
    if (db == null) return const [];
    final rows = await db.query('go_url_rule', orderBy: 'id DESC');
    final userRuleIds = <int>{};
    final sources = await db.query(
      'go_url_rule_source',
      columns: ['ruleId', 'source'],
    );
    for (final row in sources) {
      if (RuleRepository.userSources.contains(row['source'])) {
        userRuleIds.add(row['ruleId'] as int);
      }
    }
    return [
      for (final row in rows)
        if (userRuleIds.contains(row['id'] as int))
          {
            'pattern': row['pattern'],
            'kind': row['kind'],
            'rawLine': row['rawLine'],
            'enabled': (row['enabled'] as int? ?? 1) == 1,
          },
    ];
  }
}
