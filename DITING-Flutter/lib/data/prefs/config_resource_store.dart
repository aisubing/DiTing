/// 三张「保留资源」表的持久化：图标集 / User-Agent / 按需连接的 SSID 规则。
///
/// ## 为什么存成一条 JSON 而不是三张 sqlite 表
///
/// 这三组的操作**都是整表替换**（增一条、删一条、切换开关，最后都把整份列表交回
/// notifier），没有按行查询、没有跨表关联、条数在几十的量级。为它们建三张表要多写
/// 三个 DAO、三份 schema 迁移和一轮 sqflite 异步装配，换来的能力这里一个都用不上。
/// 一条 JSON 记录与「整表替换」的语义完全同构，读回时逐项校验即可。
///
/// ## 为什么不塞进 `LegacySettings`
///
/// `LegacySettings` 镜像的是 1.4.3 的 prefs 键（`dns_vpn_prefs` 等容器），键名有
/// 兼容契约。这三张表是**本仓新增**的能力（1.4.3 没有图标集 / UA / 按需连接），
/// 混进那个命名会把「旧版兼容键」和「本仓自有键」搅在一起，将来做迁移时无法区分。
/// 因此单独一个容器 [container] 承载。
library;

import 'dart:convert';

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// 三张表的读写。
class ConfigResourceStore {
  const ConfigResourceStore(this._store);

  /// 本仓自有容器名；不与 1.4.3 的任何容器重名，避免污染兼容契约。
  static const container = 'diting_config_resources';

  static const _iconSetsKey = 'icon_sets_json';
  static const _userAgentsKey = 'user_agents_json';
  static const _selectedUaKey = 'selected_user_agent';
  static const _ssidRulesKey = 'ssid_rules_json';
  static const _onDemandKey = 'on_demand_enabled';

  final LegacyPrefsStore _store;

  /// 读回三张表。缺键或内容损坏时各自回落到初始值。
  ///
  /// 逐组回落而不是整份回落：一份坏的 UA JSON 不该让用户丢掉图标集。
  ConfigResourceSnapshot load() {
    final iconSets = _decodeList(_iconSetsKey, _iconSetFromMap);
    final userAgents = _decodeList(_userAgentsKey, _userAgentFromMap);
    final ssidRules = _decodeList(_ssidRulesKey, _ssidFromMap);
    final rawSelected = _store.read(container, _selectedUaKey);
    final selected = rawSelected is String ? rawSelected : null;
    return ConfigResourceSnapshot(
      iconSets: iconSets ?? mockIconSets,
      userAgents: userAgents ?? mockUserAgents,
      // 空串 = 用户显式选了「不覆写」；缺少键 = 从未设置，两者都归 null。
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

  /// `null` 表示「不覆写」；写入空串以便与「未设置过」区分。
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

  /// 解一组对象；缺键返回 `null`（保留「用初始值」的语义）。
  ///
  /// 空数组是**合法结果**：用户可能把 UA 列表删光了，此时不该又冒出四条默认值。
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
      // 单条坏数据只丢这一条，不牵连整组。
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

/// 一次读回的整份快照。
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
