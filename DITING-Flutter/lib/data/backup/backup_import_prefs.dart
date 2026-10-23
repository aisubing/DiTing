part of 'backup_importer.dart';

/// 服务商、Bootstrap、缓存、出站代理、应用名单与两类设置分组的合并。
///
/// 这些分组全部落在 prefs 上（不碰规则库），因此全新安装、规则库缺失时也能
/// 恢复——导入失败清单里只有规则与订阅类分组才该出现。
extension _BackupImportPrefs on BackupImporter {
  /// 服务商：按名字去重，同名不同配置时更新。
  ///
  /// 1.4.3 的服务商没有 id，2.0 的 `readUserProviders` 会丢弃没有 id 的条目，
  /// 所以旧备份（以及缺少 id 的第三方文件）在写入前补一个稳定的 id。
  BackupGroupOutcome _importProviders(
    Object? value,
    BackupImportTarget target,
  ) {
    // 1.4.3 的 `providers` 是纯数组；2.0 的 `{items, selection}` 也要接受。
    final List<Object?> incoming;
    if (value is List) {
      incoming = value;
    } else if (value is Map && value['items'] is List) {
      incoming = value['items'] as List<Object?>;
    } else {
      throw const BackupFormatException('服务商分组应为数组');
    }
    final existing = _decodeProviders(target.settings.userProvidersJson);
    final byName = {for (final item in existing) _nameOf(item): item};
    var added = 0;
    var updated = 0;
    var skipped = 0;
    for (final item in incoming) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final name = _nameOf(item);
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      final normalized = _withId(item, name);
      final current = byName[name];
      if (current == null) {
        existing.add(normalized);
        byName[name] = normalized;
        added++;
      } else if (_encodeConfig(current) == _encodeConfig(normalized)) {
        skipped++;
      } else {
        final index = existing.indexOf(current);
        // 本机已有一条同名服务商时保留它的 id：界面上的选择、各模式的候选
        // 列表都引用 id，换掉 id 等于把用户当前的解析链路拆掉。
        existing[index] = _keepId(normalized, current);
        byName[name] = existing[index];
        updated++;
      }
    }
    if (added > 0 || updated > 0) {
      target.store.putString(
        LegacySettings.uiContainer,
        'user_providers_json',
        jsonEncode(existing),
      );
    }
    return BackupGroupOutcome(
      group: BackupGroup.providers,
      added: added,
      skipped: skipped,
      updated: updated,
    );
  }

  /// 补齐 `id`：没有就按名字生成，保证同一份备份反复导入不会产生重复行。
  Map<Object?, Object?> _withId(Map<Object?, Object?> provider, String name) {
    final id = provider['id'];
    if (id is String && id.trim().isNotEmpty) return provider;
    return {...provider, 'id': 'user_${_slugOf(name)}'};
  }

  Map<Object?, Object?> _keepId(
    Map<Object?, Object?> incoming,
    Map<Object?, Object?> current,
  ) {
    final id = current['id'];
    if (id is String && id.isNotEmpty) return {...incoming, 'id': id};
    return incoming;
  }

  String _slugOf(String value) {
    final buffer = StringBuffer();
    for (final unit in value.trim().toLowerCase().codeUnits) {
      final isDigit = unit >= 0x30 && unit <= 0x39;
      final isLower = unit >= 0x61 && unit <= 0x7a;
      buffer.write(isDigit || isLower ? String.fromCharCode(unit) : '_');
    }
    return buffer.isEmpty ? 'provider' : buffer.toString();
  }

  List<Map<Object?, Object?>> _decodeProviders(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map) Map<Object?, Object?>.from(item),
      ];
    } on FormatException {
      return [];
    }
  }

  String _nameOf(Map<Object?, Object?> provider) {
    final name = provider['name'];
    return name is String ? name.trim() : '';
  }

  /// 只比较「配置内容」，不含 `id`。
  ///
  /// id 是本机生成的（旧备份根本没有 id，导入时补的是 `user_*` 占位），把
  /// 它算进相等判断会让同一份备份每导入一次都被判成「更新」，用户看到的是
  /// 永远消不掉的「更新 N 项」。
  String _encodeConfig(Object? value) {
    if (value is Map) {
      final stripped = {
        for (final entry in value.entries)
          if ('${entry.key}' != 'id') entry.key: entry.value,
      };
      return _encode(stripped);
    }
    return _encode(value);
  }

  /// 稳定的字符串形式，用来判断「是否完全相同」。
  String _encode(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return '{${keys.map((key) => '$key:${_encode(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_encode).join(',')}]';
    }
    return '$value';
  }

  /// 服务商选择状态：首选服务商、解析模式、各模式候选列表、主页可见性。
  ///
  /// 这些值在 1.4.3 里是各自独立的顶层字段，2.0 的旧备份根本不带它们，导入
  /// 后用户会发现「服务商都恢复了，但当前还是旧的那个」。
  void _applyProviderSelection(Object? value, BackupImportTarget target) {
    if (value is! Map) return;
    final settings = target.settings;
    final catalog = _providerNameIndex(settings);

    final selected = value['selectedProvider'];
    if (selected is Map) {
      final id = _resolveProviderId(selected, catalog);
      if (id != null) settings.setSelectedProviderId(id);
    }

    final mode = value['resolutionMode'];
    if (mode is String && mode.isNotEmpty) settings.setResolutionModeRaw(mode);

    final raceDomain = value['raceTestDomain'];
    if (raceDomain is String && raceDomain.trim().isNotEmpty) {
      settings.setRaceTestDomain(raceDomain.trim());
    }

    _applyProviderIds(
      settings,
      value['raceProviderRefs'],
      catalog,
      settings.setRaceProviderIds,
    );
    _applyProviderIds(
      settings,
      value['smartPredictionProviderRefs'],
      catalog,
      settings.setSmartPredictionProviderIds,
    );
    _applyProviderIds(
      settings,
      value['parallelRaceProviderRefs'],
      catalog,
      settings.setParallelRaceProviderIds,
    );
    _applyProviderIds(
      settings,
      value['primaryBackupProviderRefs'],
      catalog,
      settings.setPrimaryBackupProviderIds,
    );
    _applyProviderIds(
      settings,
      value['latencyTestProviderRefs'],
      catalog,
      settings.setLatencyTestProviderIds,
    );

    final visibility = value['homeProviderVisibility'];
    if (visibility is Map) {
      final protocols = _stringSet(visibility['visibleProtocols']);
      settings.setHomeProviderVisibility(
        visibleProtocols: protocols.isEmpty
            ? settings.homeVisibleProtocols
            : protocols,
        hiddenProviderIds: _idsOf(visibility['hiddenProviderRefs'], catalog),
        visibleProviderIds: _idsOf(visibility['visibleProviderRefs'], catalog),
      );
    }
  }

  void _applyProviderIds(
    LegacySettings settings,
    Object? refs,
    Map<String, String> catalog,
    void Function(List<String> ids) write,
  ) {
    if (refs is! List) return;
    // 空列表是有意义的（用户可能清空了候选），所以照写不误。
    write(_idsOf(refs, catalog).toList());
  }

  Set<String> _idsOf(Object? refs, Map<String, String> catalog) {
    if (refs is! List) return const {};
    final ids = <String>{};
    for (final ref in refs) {
      if (ref is! Map) continue;
      final id = _resolveProviderId(ref, catalog);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  /// 把引用解析成本机存在的 id。
  ///
  /// 顺序照抄 1.4.3 `ProviderConfigImporter.resolveProviderRef`：先看 id 命中，
  /// 再按 (名称, 协议) 回退——旧备份里的 id 在 2.0 可能已经不存在（预设集合
  /// 改过），只认 id 会让整条选择链断掉。
  String? _resolveProviderId(Map ref, Map<String, String> catalog) {
    final id = ref['id'];
    if (id is String && id.isNotEmpty && catalog.containsKey(id)) return id;
    final name = ref['name'];
    if (name is String && name.isNotEmpty) {
      final protocol = ref['protocol'];
      final key =
          '$name\u0000${protocol is String ? protocol.toUpperCase() : ''}';
      return catalog[key];
    }
    return id is String && id.isNotEmpty ? id : null;
  }

  /// id → id 与 (名称, 协议) → id 两张表。
  Map<String, String> _providerNameIndex(LegacySettings settings) {
    final index = <String, String>{};
    void add(String id, String name, String protocol) {
      index[id] = id;
      index['$name\u0000${protocol.toUpperCase()}'] = id;
    }

    for (final provider in defaultDnsProviders) {
      add(provider.id, provider.name, provider.protocol.storageValue);
    }
    for (final record in readUserProviders(settings)) {
      add(record.id, record.name, record.protocol.storageValue);
    }
    return index;
  }

  BackupGroupOutcome _importBootstrap(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('Bootstrap 分组应为对象');
    }
    final settings = target.settings;
    var added = 0;
    var skipped = 0;

    final enabled = value['enabled'];
    if (enabled is bool) {
      if (settings.bootstrapEnabled == enabled) {
        skipped++;
      } else {
        settings.setBootstrapEnabled(enabled);
        added++;
      }
    } else {
      skipped++;
    }

    final presetIds = value['presetIds'];
    if (presetIds is List) {
      final ids = {
        for (final id in presetIds)
          if (id is String) id,
      };
      if (ids.length == settings.bootstrapPresetIds.length &&
          ids.containsAll(settings.bootstrapPresetIds)) {
        skipped++;
      } else {
        settings.setBootstrapPresetIds(ids);
        added++;
      }
    } else {
      skipped++;
    }

    final custom = value['custom'];
    if (custom != null) {
      // 原样写回它自己的 JSON 编码：这一项本来就是「用户自定义节点的原始文本」。
      final encoded = jsonEncode(custom);
      if (settings.bootstrapCustomJson == encoded) {
        skipped++;
      } else {
        settings.setBootstrapCustomJson(encoded);
        added++;
      }
    } else {
      skipped++;
    }

    return BackupGroupOutcome(
      group: BackupGroup.bootstrap,
      added: added,
      skipped: skipped,
    );
  }

  /// 缓存策略：整组原子写入。
  ///
  /// 用 `applyCachePreset` 而不是逐个 setter：九个键必须一起落盘，否则引擎可能
  /// 读到「新模式 + 旧 TTL」的组合（`DnsCacheSettingsStore` 就是为这个原因把九
  /// 个键放在一次提交里）。
  BackupGroupOutcome _importCache(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('缓存分组应为对象');
    }
    final settings = target.settings;
    // 备份里缺的键回落到本机当前值，保证写出去的九项是一致的。
    final enabled = value['enabled'];
    final mode = value['mode'];
    final preset = value['preset'];
    final maxTtl = value['maxTtlSeconds'];
    final fixedTtl = value['fixedTtlSeconds'];
    final minTtlEnabled = value['minTtlEnabled'];
    final minTtl = value['minTtlSeconds'];
    final staleEnabled = value['staleFallbackEnabled'];
    final staleSeconds = value['staleFallbackSeconds'];

    final next = (
      preset: preset is String ? preset : (settings.cachePresetRaw ?? ''),
      enabled: enabled is bool ? enabled : settings.cacheEnabled,
      mode: mode is String ? mode : settings.cacheModeRaw,
      maxTtl: maxTtl is int ? maxTtl : settings.cacheMaxTtlSeconds,
      fixedTtl: fixedTtl is int ? fixedTtl : settings.cacheFixedTtlSeconds,
      minTtlEnabled: minTtlEnabled is bool
          ? minTtlEnabled
          : settings.cacheMinTtlEnabled,
      minTtl: minTtl is int ? minTtl : settings.cacheMinTtlSeconds,
      staleEnabled: staleEnabled is bool
          ? staleEnabled
          : settings.cacheStaleFallbackEnabled,
      staleSeconds: staleSeconds is int
          ? staleSeconds
          : settings.cacheStaleFallbackSeconds,
    );
    final unchanged =
        next.preset == (settings.cachePresetRaw ?? '') &&
        next.enabled == settings.cacheEnabled &&
        next.mode == settings.cacheModeRaw &&
        next.maxTtl == settings.cacheMaxTtlSeconds &&
        next.fixedTtl == settings.cacheFixedTtlSeconds &&
        next.minTtlEnabled == settings.cacheMinTtlEnabled &&
        next.minTtl == settings.cacheMinTtlSeconds &&
        next.staleEnabled == settings.cacheStaleFallbackEnabled &&
        next.staleSeconds == settings.cacheStaleFallbackSeconds;
    if (unchanged) {
      return const BackupGroupOutcome(group: BackupGroup.cache, skipped: 1);
    }

    settings.applyCachePreset(
      storageValue: next.preset,
      enabled: next.enabled,
      mode: next.mode,
      maxTtlSeconds: next.maxTtl,
      fixedTtlSeconds: next.fixedTtl,
      minTtlEnabled: next.minTtlEnabled,
      minTtlSeconds: next.minTtl,
      staleFallbackEnabled: next.staleEnabled,
      staleFallbackSeconds: next.staleSeconds,
    );
    return const BackupGroupOutcome(
      group: BackupGroup.cache,
      // 九项一起算一条策略：报「9 项」会让汇总看起来像导入了九条规则。
      added: 1,
    );
  }

  /// 出站代理：备份不含凭据，所以只能恢复「非凭据」的那几项。
  ///
  /// 恢复的开关若为真但本机没有凭据，代理会连不上。这里**不**自动把它打开：
  /// 报「已更新」而实际连不上，比明确跳过更糟。
  BackupGroupOutcome _importOutbound(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('出站代理分组应为对象');
    }
    var restored = 0;
    var skipped = 0;
    for (final entry in const {
      'protocol': 'outbound_proxy_protocol',
      'host': 'outbound_proxy_host',
      // 1.4.3 与原生 `OutboundProxyBridge.KEY_APP` 都用 `outbound_proxy_app`；
      // 早期 2.0 写成了 `outbound_proxy_app_package`，读回来永远是空。
      'proxyAppPackage': 'outbound_proxy_app',
    }.entries) {
      final raw = value[entry.key];
      if (raw is! String || raw.isEmpty) continue;
      final current = target.store.read(
        LegacySettings.uiContainer,
        entry.value,
      );
      if (current == raw) {
        skipped++;
        continue;
      }
      target.store.putString(LegacySettings.uiContainer, entry.value, raw);
      restored++;
    }
    final port = value['port'];
    if (port is int) {
      final current = target.store.read(
        LegacySettings.uiContainer,
        'outbound_proxy_port',
      );
      if (current == port) {
        skipped++;
      } else {
        target.store.putInt(
          LegacySettings.uiContainer,
          'outbound_proxy_port',
          port,
        );
        restored++;
      }
    }
    return BackupGroupOutcome(
      group: BackupGroup.outbound,
      // 账号密码不在备份里，所以「新增」只覆盖地址类字段。
      added: restored,
      skipped: skipped,
    );
  }
}
