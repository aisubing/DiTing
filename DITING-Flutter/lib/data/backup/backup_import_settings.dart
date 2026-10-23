part of 'backup_importer.dart';

/// 外观与系统设置分组的合并。
///
/// 设置类分组一律「本机已有值即跳过」：导入备份通常是恢复规则与订阅，
/// 顺手改掉用户当前的界面与开关属于意外行为（见 `backup_importer.dart` 文件头）。
extension _BackupImportSettings on BackupImporter {
  // ----------------------------------------------------------------- 设置

  /// 外观：本机已有值的项跳过（见文件头「合并语义」）。
  ///
  /// 1.4.3 的备份里每个首页组件单独存透明度、还有两句首页标语；2.0 早期导出
  /// 丢了这些字段，导回旧版时它们会变回默认值。
  BackupGroupOutcome _importAppearance(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('外观分组应为对象');
    }
    final settings = target.settings;
    var added = 0;
    var skipped = 0;

    void applyIfAbsent(String? current, void Function() write) {
      if (current != null && current.isNotEmpty) {
        skipped++;
      } else {
        write();
        added++;
      }
    }

    final themeMode = value['themeMode'];
    if (themeMode is String) {
      applyIfAbsent(
        settings.themeModeRaw,
        () => settings.setThemeModeRaw(themeMode),
      );
    }
    final palette = value['palette'];
    if (palette is String) {
      applyIfAbsent(settings.paletteRaw, () => settings.setPaletteRaw(palette));
    }
    final bottomBarIds = value['bottomBarIds'];
    if (bottomBarIds is List) {
      final ids = [
        for (final id in bottomBarIds)
          if (id is String) id,
      ];
      final current = settings.bottomBarIds;
      if (ids.length < LegacySettings.bottomBarMinCount) {
        skipped++;
      } else if (ids.length == current.length && ids.join() == current.join()) {
        skipped++;
      } else {
        settings.setBottomBarIds(ids);
        added++;
      }
    }
    final glass = value['liquidGlassMode'];
    if (glass is String) {
      if (settings.liquidGlassModeRaw == glass) {
        skipped++;
      } else {
        settings.setLiquidGlassModeRaw(glass);
        added++;
      }
    }
    final haptic = value['hapticEnabled'];
    if (haptic is bool) {
      if (settings.hapticEnabled == haptic) {
        skipped++;
      } else {
        settings.setHapticEnabled(haptic);
        added++;
      }
    }

    // 每个首页组件的透明度：本机统一用一个 `componentOpacity`，旧备份里五个
    // 键各自独立，这里按「有值就写回对应旧键」处理，让旧版恢复后的长相一致。
    final component = _decimal(value['componentOpacity']);
    for (final entry in const {
      'homePowerButtonOpacity': 'home_power_button_opacity',
      'homeProviderSelectorOpacity': 'home_provider_selector_opacity',
      'homeModeButtonOpacity': 'home_mode_button_opacity',
      'homePoemOpacity': 'home_poem_opacity',
      'homeDnsDetailOpacity': 'home_dns_detail_opacity',
    }.entries) {
      final opacity = _decimal(value[entry.key]) ?? component;
      if (opacity == null) continue;
      if (_sameOpacity(settings.homeOpacity(entry.value), opacity)) {
        skipped++;
      } else {
        settings.setHomeOpacity(entry.value, opacity);
        added++;
      }
    }
    if (component != null) {
      if (_sameOpacity(settings.componentOpacity, component)) {
        skipped++;
      } else {
        settings.setHomeComponentOpacity(component);
        added++;
      }
    }

    final running = value['homeSentenceRunning'];
    final stopped = value['homeSentenceStopped'];
    if (running is String || stopped is String) {
      final current = settings.homeSentences;
      final nextRunning = running is String && running.isNotEmpty
          ? running
          : current.running;
      final nextStopped = stopped is String && stopped.isNotEmpty
          ? stopped
          : current.stopped;
      if (nextRunning == current.running && nextStopped == current.stopped) {
        skipped++;
      } else {
        settings.setHomeSentences(running: nextRunning, stopped: nextStopped);
        added++;
      }
    }

    return BackupGroupOutcome(
      group: BackupGroup.appearance,
      added: added,
      skipped: skipped,
    );
  }

  /// 透明度比较要留容差。
  ///
  /// 安卓端的 SharedPreferences 用 Java `float` 存，`putFloat(0.8)` 读回来是
  /// `0.800000011920929`；用 `==` 比会和备份里的 `0.8` 永远不相等，于是每次
  /// 导入都把这五项判成「新增」，用户看到的是永远消不掉的汇总。
  bool _sameOpacity(double current, double incoming) =>
      (current - incoming).abs() < 0.001;

  double? _decimal(Object? value) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    if (value is String) return double.tryParse(value)?.clamp(0.0, 1.0);
    return null;
  }

  /// 系统设置：**值相同即跳过**。
  ///
  /// 早期版本无论值有没有变化都写一遍并计一次「新增」，于是同一份备份导入
  /// 两次都会报「新增 18 项」——用户看到的是「明明什么都没变，为什么又说新增」。
  /// 判断依据是本机当前值，不是「有没有写过这个键」。
  BackupGroupOutcome _importSystem(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('系统设置分组应为对象');
    }
    final settings = target.settings;
    var added = 0;
    var skipped = 0;

    void apply<T>(
      Object? incoming,
      T? current,
      void Function(T value) write, {
      Object? Function(Object incoming)? convert,
    }) {
      if (incoming == null) return;
      final Object? resolved = convert == null ? incoming : convert(incoming);
      if (resolved is! T) return;
      final T converted = resolved;
      if (converted == current) {
        skipped++;
        return;
      }
      write(converted);
      added++;
    }

    apply<bool>(
      value['bypassLan'],
      settings.bypassLanEnabled,
      settings.setBypassLanEnabled,
    );
    apply<String>(
      value['ipv6Mode'],
      settings.ipv6ModeRaw,
      settings.setIpv6ModeRaw,
    );
    apply<int>(
      value['logRetentionDays'],
      settings.logRetentionDays,
      settings.setLogRetentionDays,
      convert: (incoming) => (incoming as num).toInt(),
    );
    apply<String>(
      value['dnsLogMode'],
      settings.dnsLogModeRaw,
      settings.setDnsLogModeRaw,
    );
    apply<bool>(
      value['hideFromRecents'],
      settings.hideFromRecentsEnabled,
      settings.setHideFromRecentsEnabled,
    );
    apply<bool>(
      value['floatingLogEnabled'],
      settings.floatingLogEnabled,
      settings.setFloatingLogEnabled,
    );
    final floatingSize = value['floatingLogPanelSize'];
    if (floatingSize is int) {
      final current = settings.rawStore.read(
        LegacySettings.uiContainer,
        'floating_log_panel_size',
      );
      if (current == floatingSize) {
        skipped++;
      } else {
        settings.rawStore.putInt(
          LegacySettings.uiContainer,
          'floating_log_panel_size',
          floatingSize,
        );
        added++;
      }
    }
    apply<bool>(
      value['disableStartupUpdateCheck'],
      settings.disableStartupUpdateCheck,
      settings.setDisableStartupUpdateCheck,
    );
    apply<String>(
      value['appLanguageMode'],
      settings.appLanguageModeRaw,
      settings.setAppLanguageModeRaw,
    );
    apply<bool>(
      value['notificationPersistent'],
      settings.notificationPersistent,
      settings.setNotificationPersistent,
    );
    apply<bool>(
      value['notificationSpeed'],
      settings.notificationSpeed,
      settings.setNotificationSpeed,
    );
    final runningText = value['customRunningNotificationText'];
    final stoppedText = value['customStoppedNotificationText'];
    if (runningText is String || stoppedText is String) {
      final current = settings.notificationTexts;
      final running = runningText is String ? runningText : current.running;
      final stopped = stoppedText is String ? stoppedText : current.stopped;
      if (running == current.running && stopped == current.stopped) {
        skipped++;
      } else {
        settings.setNotificationTexts(running: running, stopped: stopped);
        added++;
      }
    }
    apply<bool>(
      value['domainRulesEnabled'],
      settings.domainRulesEnabled,
      settings.setDomainRulesEnabled,
    );
    final addressRules = value['addressRulesEnabled'];
    final encryptedDns = value['encryptedDnsBlockingEnabled'];
    final http3 = value['http3Enabled'];
    if (addressRules is bool || encryptedDns is bool || http3 is bool) {
      final nextAddress = addressRules is bool
          ? addressRules
          : settings.addressRulesEnabled;
      final nextEncrypted = encryptedDns is bool
          ? encryptedDns
          : settings.encryptedDnsBlockingEnabled;
      final nextHttp3 = http3 is bool ? http3 : settings.http3InspectionEnabled;
      if (nextAddress == settings.addressRulesEnabled &&
          nextEncrypted == settings.encryptedDnsBlockingEnabled &&
          nextHttp3 == settings.http3InspectionEnabled) {
        skipped++;
      } else {
        settings.setHttpInspectionToggles(
          http3: nextHttp3,
          encryptedDns: nextEncrypted,
          addressRules: nextAddress,
        );
        added++;
      }
    }
    apply<String>(
      value['blockResponseMode'],
      settings.blockResponseModeRaw,
      settings.setBlockResponseModeRaw,
    );
    final allowEdit = value['allowEditDefaultWhitelist'];
    if (allowEdit is bool) {
      final current = settings.rawStore.read(
        LegacySettings.uiContainer,
        'allow_edit_default_whitelist',
      );
      if (current == allowEdit) {
        skipped++;
      } else {
        settings.rawStore.putBool(
          LegacySettings.uiContainer,
          'allow_edit_default_whitelist',
          allowEdit,
        );
        added++;
      }
    }
    final dynamicBlock = value['dynamicBlockResponse'];
    if (dynamicBlock is Map) {
      final enabled = dynamicBlock['enabled'];
      final threshold = dynamicBlock['requestThreshold'];
      final window = dynamicBlock['windowSeconds'];
      final duration = dynamicBlock['nxDomainDurationSeconds'];
      final nextEnabled = enabled is bool
          ? enabled
          : settings.dynamicBlockEnabled;
      final nextThreshold = threshold is num
          ? threshold.toInt().clamp(2, 100)
          : settings.dynamicBlockRequestThreshold;
      final nextWindow = window is num
          ? window.toInt().clamp(10, 300)
          : settings.dynamicBlockWindowSeconds;
      final nextDuration = duration is num
          ? duration.toInt().clamp(60, 3600)
          : settings.dynamicBlockNxDomainDurationSeconds;
      if (nextEnabled == settings.dynamicBlockEnabled &&
          nextThreshold == settings.dynamicBlockRequestThreshold &&
          nextWindow == settings.dynamicBlockWindowSeconds &&
          nextDuration == settings.dynamicBlockNxDomainDurationSeconds) {
        skipped++;
      } else {
        settings.setDynamicBlockPolicy(
          enabled: nextEnabled,
          requestThreshold: nextThreshold,
          windowSeconds: nextWindow,
          nxDurationSeconds: nextDuration,
        );
        added++;
      }
    }
    for (final entry in {
      'app_traffic_stats_enabled': value['appTrafficStatsEnabled'],
      'traffic_stats_retention_days': value['trafficStatsRetentionDays'],
      'traffic_stats_hide_system_apps': value['trafficStatsHideSystemApps'],
    }.entries) {
      final incoming = entry.value;
      if (incoming is! bool && incoming is! int) continue;
      final current = settings.rawStore.read(
        LegacySettings.uiContainer,
        entry.key,
      );
      if (current == incoming) {
        skipped++;
        continue;
      }
      if (incoming is bool) {
        settings.rawStore.putBool(
          LegacySettings.uiContainer,
          entry.key,
          incoming,
        );
      } else {
        settings.rawStore.putInt(
          LegacySettings.uiContainer,
          entry.key,
          incoming as int,
        );
      }
      added++;
    }
    apply<bool>(
      value['subscriptionAutoUpdateEnabled'],
      settings.subscriptionAutoUpdateEnabled,
      settings.setSubscriptionAutoUpdateEnabled,
    );
    apply<int>(
      value['subscriptionAutoUpdateIntervalHours'],
      settings.subscriptionAutoUpdateIntervalHours,
      settings.setSubscriptionAutoUpdateIntervalHours,
      convert: (incoming) => (incoming as num).toInt(),
    );

    return BackupGroupOutcome(
      group: BackupGroup.system,
      added: added,
      skipped: skipped == 0 && added == 0 ? 1 : skipped,
    );
  }
}

/// JSON 里的字符串集合；接受数组或 `{value: ...}` 形状。
Set<String> _stringSet(Object? value) {
  if (value is List) {
    return {
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    };
  }
  if (value is Map) {
    return {
      for (final entry in value.keys)
        if ('$entry'.trim().isNotEmpty) '$entry'.trim(),
    };
  }
  return const {};
}
