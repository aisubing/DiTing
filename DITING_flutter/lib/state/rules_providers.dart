/// 规则域演示状态：黑名单 / 白名单 / 覆写三张表的唯一可变副本。
///
/// 为什么表放进 provider 而不是页面 `State`：规则页与批量导入页同时读写同一
/// 张表，页面 pop 之后用户在别处新增的规则不能跟着页面一起消失；而规则页
/// 每次进入都要重建，页面内 state 做不到跨页留存。
library;

import 'dart:async';

import 'package:diting/data/db/preset_whitelist.dart';
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 白名单预设规则的只读判定。
///
/// 判据放在数据层：Switch、行菜单、删除入口三处必须用同一个判断，分散在页面
/// 里迟早会出现「菜单能删、开关不能动」这类自相矛盾的状态。
bool isRuleProtected(
  MockRule rule, {
  required RuleKind kind,
  required bool allowPresetEditable,
}) =>
    kind == RuleKind.allow &&
    rule.source == RuleSource.preset &&
    !allowPresetEditable;

/// 三张规则表。
///
/// 用一张 `Map<RuleKind, List<MockRule>>` 而不是三个 provider：三种规则的结构
/// 完全一致（只有 kind 与 target 不同），拆成三个 notifier 会带来三份重复的
/// 增删改逻辑，而它们的差异只有「是否允许只读预设」这一条。
class RulesNotifier extends Notifier<Map<RuleKind, List<MockRule>>> {
  var _sequence = 0;

  RuleRepository? get _repo => ref.read(ruleRepositoryProvider);

  @override
  Map<RuleKind, List<MockRule>> build() {
    final initial = ref.watch(initialRulesProvider);
    return {
      for (final kind in RuleKind.values) kind: [...?initial[kind]],
    };
  }

  List<MockRule> rulesOf(RuleKind kind) => state[kind] ?? const [];

  /// 切换启停。只读行由调用方拦截，这里不再二次判断，避免同一规则写两遍。
  void toggle(RuleKind kind, String id, bool enabled) {
    _replace(kind, id, (rule) => _copy(rule, enabled: enabled));
    final repo = _repo;
    final dbId = int.tryParse(id);
    if (repo != null && dbId != null) {
      unawaited(repo.setEnabled(kind, dbId, enabled));
    }
  }

  /// 新增一条用户规则；pattern 与已有规则重复时返回 false。
  ///
  /// 去重放在这里而不是对话框里：批量导入走的是同一个入口，两处各写一遍校验
  /// 会出现「单个添加能拦、批量导入放过去」的漏洞。
  Future<bool> add(RuleKind kind, String pattern, {String? target}) async {
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (rulesOf(kind).any((rule) => rule.pattern == trimmed)) {
      return false;
    }
    final repo = _repo;
    if (repo != null) {
      final created = await repo.add(kind, trimmed, target: target);
      state = {
        ...state,
        kind: [created, ...rulesOf(kind)],
      };
      return true;
    }
    state = {
      ...state,
      kind: [
        MockRule(
          id: '${kind.name}-user-${_sequence++}',
          pattern: trimmed,
          kind: kind,
          source: RuleSource.user,
          target: target,
        ),
        ...rulesOf(kind),
      ],
    };
    return true;
  }

  /// 编辑规则内容。白名单预设行被编辑时把来源改写为用户自定义：上游
  /// `WhitelistViewModel` 同样这么做，否则升级时按来源清空预设会把用户改动
  /// 一起丢掉。
  Future<void> edit(
    RuleKind kind,
    String id,
    String pattern, {
    String? target,
  }) async {
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final matches = rulesOf(kind).where((rule) => rule.id == id);
    final current = matches.isEmpty ? null : matches.first;
    final repo = _repo;
    final dbId = int.tryParse(id);
    if (repo != null && dbId != null) {
      await repo.update(
        kind,
        dbId,
        trimmed,
        target: target,
        promotePreset: current?.source == RuleSource.preset,
      );
    }
    _replace(
      kind,
      id,
      (rule) => MockRule(
        id: rule.id,
        pattern: trimmed,
        kind: rule.kind,
        source: rule.source == RuleSource.preset
            ? RuleSource.user
            : rule.source,
        enabled: rule.enabled,
        important: rule.important,
        group: rule.group,
        subscriptionName: rule.subscriptionName,
        target: target ?? rule.target,
      ),
    );
  }

  Future<void> remove(RuleKind kind, String id) async {
    final repo = _repo;
    final dbId = int.tryParse(id);
    if (repo != null && dbId != null) {
      await repo.delete(kind, dbId);
    }
    state = {
      ...state,
      kind: [
        for (final rule in rulesOf(kind))
          if (rule.id != id) rule,
      ],
    };
  }

  /// 清空自定义规则，返回被清掉的条数（供确认框与提示复用）。
  Future<int> clearCustom(RuleKind kind) async {
    final repo = _repo;
    final removed = repo == null
        ? rulesOf(kind).where((rule) => rule.source == RuleSource.user).length
        : await repo.clearUser(kind);
    state = {
      ...state,
      kind: [
        for (final rule in rulesOf(kind))
          if (rule.source != RuleSource.user) rule,
      ],
    };
    return removed;
  }

  /// 重置默认白名单：把预设行恢复成初始内容，用户行与订阅行不动。
  Future<int> resetPreset(RuleKind kind) async {
    final repo = _repo;
    if (repo != null && kind == RuleKind.allow) {
      final content = await rootBundle.loadString('assets/https_passthrough.txt');
      final entries = parsePresetWhitelist(content);
      if (entries.isEmpty) {
        return 0;
      }
      final count = await repo.resetPresetWhitelist(entries);
      state = {...state, kind: await repo.loadKind(kind)};
      return count;
    }
    final initial = {
      for (final rule in mockRulesOf(kind))
        if (rule.source == RuleSource.preset) rule.id: rule,
    };
    final kept = [
      for (final rule in rulesOf(kind))
        if (rule.source != RuleSource.preset) rule,
    ];
    state = {
      ...state,
      kind: [...kept, ...initial.values],
    };
    return initial.length;
  }

  /// 批量导入：逐行去重后追加，返回实际写入的条数。
  Future<int> importRules(
    RuleKind kind,
    List<String> patterns, {
    String? target,
  }) async {
    final existing = {for (final rule in rulesOf(kind)) rule.pattern};
    final repo = _repo;
    final added = <MockRule>[];
    for (final pattern in patterns) {
      final trimmed = pattern.trim();
      if (trimmed.isEmpty || !existing.add(trimmed)) {
        continue;
      }
      if (repo != null) {
        added.add(await repo.add(kind, trimmed, target: target));
      } else {
        added.add(
          MockRule(
            id: '${kind.name}-user-${_sequence++}',
            pattern: trimmed,
            kind: kind,
            source: RuleSource.user,
            target: target,
          ),
        );
      }
    }
    if (added.isEmpty) {
      return 0;
    }
    state = {
      ...state,
      kind: [...added.reversed, ...rulesOf(kind)],
    };
    return added.length;
  }

  void _replace(RuleKind kind, String id, MockRule Function(MockRule) update) {
    state = {
      ...state,
      kind: [
        for (final rule in rulesOf(kind))
          if (rule.id == id) update(rule) else rule,
      ],
    };
  }
}

MockRule _copy(MockRule rule, {bool? enabled, bool? important}) => MockRule(
  id: rule.id,
  pattern: rule.pattern,
  kind: rule.kind,
  source: rule.source,
  enabled: enabled ?? rule.enabled,
  important: important ?? rule.important,
  group: rule.group,
  subscriptionName: rule.subscriptionName,
  target: rule.target,
);

final rulesProvider =
    NotifierProvider<RulesNotifier, Map<RuleKind, List<MockRule>>>(
      RulesNotifier.new,
    );

/// 某一类规则的只读视图，页面只订阅自己那一类，改别的种类不会让它重建。
final rulesOfKindProvider = Provider.family<List<MockRule>, RuleKind>(
  (ref, kind) => ref.watch(rulesProvider)[kind] ?? const [],
);

/// 「允许编辑默认白名单」开关。
///
/// 默认关闭是安全侧默认值：白名单放宽直接等于放行流量，误触代价远大于多一步
/// 确认，因此必须先显式开启才能动预设行。
class AllowPresetEditableNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final allowPresetEditableProvider =
    NotifierProvider<AllowPresetEditableNotifier, bool>(
      AllowPresetEditableNotifier.new,
    );

/// 规则来源筛选；`null` 表示「全部」。
typedef RuleSourceFilter = RuleSource?;

/// 把一行文本解析成「可导入 / 重复 / 无效」三类，供批量导入页与单条校验共用。
///
/// 三条拒绝理由都来自上游：空行忽略、重复行跳过、含 `#@#` 的是放行规则，
/// 必须去白名单添加——黑名单页里静默导入一条放行规则等于给用户一个安全错觉。
class RuleLineParseResult {
  const RuleLineParseResult({
    required this.accepted,
    required this.duplicated,
    required this.rejected,
  });

  final List<String> accepted;
  final List<String> duplicated;
  final List<String> rejected;
}

/// 逐行解析粘贴内容；[existing] 是目标表里已有的 pattern。
RuleLineParseResult parseRuleLines(String text, {Set<String> existing = const {}}) {
  final accepted = <String>[];
  final duplicated = <String>[];
  final rejected = <String>[];
  final seen = {...existing};
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.contains('#@#')) {
      rejected.add(line);
      continue;
    }
    if (!seen.add(line)) {
      duplicated.add(line);
      continue;
    }
    accepted.add(line);
  }
  return RuleLineParseResult(
    accepted: accepted,
    duplicated: duplicated,
    rejected: rejected,
  );
}
