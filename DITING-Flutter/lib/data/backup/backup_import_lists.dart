part of 'backup_importer.dart';

/// 应用名单（排除 / 禁止联网 / 独立规则 / HTTPS 抓包）。
///
/// 四组都做并集：导入一份备份不该把本机已经加过的条目删掉。
extension _BackupImportLists on BackupImporter {
  // ------------------------------------------------------------- 应用名单

  BackupGroupOutcome _importExcluded(Object? value, BackupImportTarget target) {
    final incoming = _stringSet(value);
    if (incoming.isEmpty) {
      return const BackupGroupOutcome(group: BackupGroup.excluded, skipped: 1);
    }
    final settings = target.settings;
    final merged = {...settings.excludedPackages, ...incoming};
    final added = merged.length - settings.excludedPackages.length;
    settings.setExcludedPackages(merged);
    return BackupGroupOutcome(
      group: BackupGroup.excluded,
      added: added,
      skipped: incoming.length - added,
    );
  }

  BackupGroupOutcome _importBlocked(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('禁止联网分组应为对象');
    }
    final incoming = _stringSet(value['packages']);
    final settings = target.settings;
    final merged = {...settings.blockedAppPackages, ...incoming};
    final added = merged.length - settings.blockedAppPackages.length;
    settings.setBlockedApps(
      packages: merged,
      // 开关按「备份或本机任一为真」取并集：用户导入一份开了这项的备份，
      // 却因为本机是关的而整体无效，会让人以为导入没生效。
      enabled: settings.blockedAppsEnabled || value['enabled'] == true,
    );
    return BackupGroupOutcome(
      group: BackupGroup.blocked,
      added: added,
      skipped: incoming.length - added,
    );
  }

  BackupGroupOutcome _importAllowlist(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('应用独立规则分组应为对象');
    }
    final rules = value['rules'];
    final settings = target.settings;
    final merged = {
      for (final entry in settings.appAllowlistRules.entries)
        entry.key: {...entry.value},
    };
    var added = 0;
    if (rules is Map) {
      for (final entry in rules.entries) {
        final package = '${entry.key}';
        if (package.trim().isEmpty) continue;
        final domains = _stringSet(entry.value);
        if (domains.isEmpty) continue;
        final existing = merged[package] ?? <String>{};
        final before = existing.length;
        merged[package] = {...existing, ...domains};
        added += merged[package]!.length - before;
      }
    }
    settings.setAppAllowlistRules(merged);
    settings.setAppAllowlistEnabled(
      settings.appAllowlistEnabled || value['enabled'] == true,
    );
    return BackupGroupOutcome(
      group: BackupGroup.allowlist,
      added: added,
      skipped: added == 0 ? 1 : 0,
    );
  }

  BackupGroupOutcome _importHttpInspection(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('HTTPS 抓包分组应为对象');
    }
    final incoming = _stringSet(value['packages']);
    final settings = target.settings;
    final merged = {...settings.httpInspectionPackages, ...incoming};
    final added = merged.length - settings.httpInspectionPackages.length;
    settings.setHttpInspectionApps(
      packages: merged,
      // 抓包开关**不**从备份打开：`https_inspection_ready` 依赖本机是否装了
      // CA，拿别人的开关来打开本机的抓包会让每个 HTTPS 请求都失败。
      enabled: settings.httpInspectionEnabled,
    );
    // HTTP/3 抓包是纯开关，跟着同一个分组走。
    final http3 = value['http3Enabled'];
    if (http3 is bool) {
      settings.setHttpInspectionToggles(
        http3: http3,
        encryptedDns: settings.encryptedDnsBlockingEnabled,
        addressRules: settings.addressRulesEnabled,
      );
    }
    return BackupGroupOutcome(
      group: BackupGroup.httpInspection,
      added: added,
      skipped: incoming.length - added,
    );
  }
}
