/// Persists icon sets, user agents and on-demand SSID rules as JSON blobs.
///
/// These lists are always replaced as a whole, so one JSON value per table
/// replaces three tables, DAOs and migrations. They live in their own
/// container to stay apart from the legacy-compatible keys of `LegacySettings`.
library;

import 'dart:convert';

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Reads and writes the three tables.
class ConfigResourceStore {
  const ConfigResourceStore(this._store);

  /// Own container; deliberately not one of the legacy names.
  static const container = 'diting_config_resources';

  static const _iconSetsKey = 'icon_sets_json';
  static const _userAgentsKey = 'user_agents_json';
  static const _selectedUaKey = 'selected_user_agent';
  static const _ssidRulesKey = 'ssid_rules_json';
  static const _onDemandKey = 'on_demand_enabled';

  final LegacyPrefsStore _store;

  /// Reads the tables; each group falls back to its defaults independently, so
  /// one corrupt blob does not reset the others.
  ConfigResourceSnapshot load() {
    final iconSets = _decodeList(_iconSetsKey, _iconSetFromMap);
    final userAgents = _decodeList(_userAgentsKey, _userAgentFromMap);
    final ssidRules = _decodeList(_ssidRulesKey, _ssidFromMap);
    final rawSelected = _store.read(container, _selectedUaKey);
    final selected = rawSelected is String ? rawSelected : null;
    return ConfigResourceSnapshot(
      iconSets: iconSets ?? mockIconSets,
      userAgents: userAgents ?? mockUserAgents,
      // Empty string means "no override" was chosen; a missing key means never set.
      // Both read as null.
      selectedUserAgent: selected == null || selected.isEmpty ? null : selected,
      ssidRules: ssidRules ?? mockSsidRules,
      onDemand: _store.read(container, _onDemandKey) == true,
    );
  }

  void saveIconSets(List<MockIconSet> sets) => _store.putString(
    container,
    _iconSetsKey,
    jsonEncode([
      for (final set in sets)
        {
          'name': set.name,
          'url': set.url,
          'icons': set.icons,
          'fromUrl': set.fromUrl,
        },
    ]),
  );

  void saveUserAgents(List<MockUserAgent> agents) => _store.putString(
    container,
    _userAgentsKey,
    jsonEncode([
      for (final agent in agents)
        {'value': agent.value, 'isDefault': agent.isDefault},
    ]),
  );

  /// Null means no override; an empty string is written to tell it from unset.
  void saveSelectedUserAgent(String? value) => _store.putString(
    container,
    _selectedUaKey,
    value ?? '',
  );

  void saveSsidRules(List<MockSsidRule> rules) => _store.putString(
    container,
    _ssidRulesKey,
    jsonEncode([
      for (final rule in rules)
        {
          'ssid': rule.ssid,
          'cellular': rule.cellular,
          'wifi': rule.wifi,
          'delayMs': rule.delayMs,
        },
    ]),
  );

  void saveOnDemand(bool value) => _store.putBool(container, _onDemandKey, value);

  /// Decodes one group; a missing key returns null so defaults are used.
  ///
  /// An empty array is valid and must not be replaced by the defaults.
  List<T>? _decodeList<T>(
    String key,
    T? Function(Map<String, Object?>) decode,
  ) {
    final raw = _store.read(container, key);
    if (raw is! String) return null;
    if (raw.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      debugPrint('config resources: $key 不是合法 JSON，回落到初始值');
      return null;
    }
    if (decoded is! List) {
      debugPrint('config resources: $key 不是数组，回落到初始值');
      return null;
    }
    final result = <T>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final value = decode(Map<String, Object?>.from(item));
      // A bad entry drops only itself.
      if (value != null) result.add(value);
    }
    return result;
  }

  MockIconSet? _iconSetFromMap(Map<String, Object?> map) {
    final name = map['name'];
    final url = map['url'];
    if (name is! String || name.trim().isEmpty) return null;
    final icons = map['icons'];
    return MockIconSet(
      name: name,
      url: url is String ? url : '',
      icons: icons is List
          ? [for (final icon in icons) if (icon is String) icon]
          : const [],
      fromUrl: map['fromUrl'] != false,
    );
  }

  MockUserAgent? _userAgentFromMap(Map<String, Object?> map) {
    final value = map['value'];
    if (value is! String || value.trim().isEmpty) return null;
    return MockUserAgent(value: value, isDefault: map['isDefault'] == true);
  }

  MockSsidRule? _ssidFromMap(Map<String, Object?> map) {
    final ssid = map['ssid'];
    if (ssid is! String || ssid.trim().isEmpty) return null;
    final delay = map['delayMs'];
    return MockSsidRule(
      ssid: ssid,
      cellular: map['cellular'] == true,
      wifi: map['wifi'] != false,
      delayMs: delay is int ? delay : 0,
    );
  }
}

/// Snapshot of all three tables.
class ConfigResourceSnapshot {
  const ConfigResourceSnapshot({
    required this.iconSets,
    required this.userAgents,
    required this.selectedUserAgent,
    required this.ssidRules,
    required this.onDemand,
  });

  final List<MockIconSet> iconSets;
  final List<MockUserAgent> userAgents;
  final String? selectedUserAgent;
  final List<MockSsidRule> ssidRules;
  final bool onDemand;
}
