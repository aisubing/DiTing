/// Per-app DNS allow/block lists and block-all-outbound; writes and invalidations stay together
/// here.
library;

import 'dart:async';

import 'package:diting/data/db/rule_index_bridge.dart';
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppScopedRules {
  const AppScopedRules({
    required this.block,
    required this.allow,
    required this.fullBlock,
    this.available = true,
    this.error,
  });

  const AppScopedRules.unavailable([this.error])
    : block = const [],
      allow = const [],
      fullBlock = false,
      available = false;

  final List<MockRule> block;
  final List<MockRule> allow;

  /// Whether "block all outbound" is on (a `*$app=<pkg>` row exists).
  final bool fullBlock;

  /// Whether the rule DB is readable; false means "show an error", not "no rules".
  final bool available;

  final String? error;
}

final appScopedRulesProvider =
    FutureProvider.family<AppScopedRules, String>((ref, packageName) async {
      final repository = ref.watch(ruleRepositoryProvider);
      if (repository == null) {
        return const AppScopedRules.unavailable('当前环境无法读写规则库');
      }
      try {
        final rules = await repository.loadForApp(packageName);
        final fullBlock = await repository.hasFullBlock(packageName);
        return AppScopedRules(
          block: [
            for (final rule in rules)
              if (rule.kind == RuleKind.block) rule,
          ],
          allow: [
            for (final rule in rules)
              if (rule.kind == RuleKind.allow) rule,
          ],
          fullBlock: fullBlock,
        );
      } catch (error) {
        return AppScopedRules.unavailable('读取应用规则失败：$error');
      }
    });

/// Write entry point; refreshes the matching provider on success.
class AppScopedRulesController {
  AppScopedRulesController(this._ref);

  final Ref _ref;

  RuleRepository? get _repository => _ref.read(ruleRepositoryProvider);

  /// Keeps the native rule tries in step with app-scoped writes (same main database).
  void _refreshIndexes() {
    unawaited(refreshRuleIndexes(RuleIndexDataset.normal));
  }

  /// Adds a block / allow rule. Returns false if the DB is unavailable or the rule already exists.
  Future<bool> addRule(
    String packageName,
    RuleKind kind,
    String pattern, {
    bool important = false,
  }) async {
    final repository = _repository;
    if (repository == null) return false;
    final created = await repository.addForApp(
      kind,
      pattern,
      packageName,
      important: important,
    );
    if (created != null) {
      _refreshIndexes();
      _ref.invalidate(appScopedRulesProvider(packageName));
    }
    return created != null;
  }

  Future<void> toggle(String packageName, MockRule rule, bool enabled) async {
    final repository = _repository;
    final id = int.tryParse(rule.id);
    if (repository == null || id == null) return;
    await repository.setEnabled(rule.kind, id, enabled);
    _refreshIndexes();
    _ref.invalidate(appScopedRulesProvider(packageName));
  }

  Future<void> delete(String packageName, MockRule rule) async {
    final repository = _repository;
    final id = int.tryParse(rule.id);
    if (repository == null || id == null) return;
    await repository.delete(rule.kind, id);
    _refreshIndexes();
    _ref.invalidate(appScopedRulesProvider(packageName));
  }

  /// Toggles "block all outbound" and returns the new state.
  Future<bool> setFullBlock(String packageName, bool enabled) async {
    final repository = _repository;
    if (repository == null) return false;
    final next = await repository.setFullBlock(packageName, enabled);
    _refreshIndexes();
    _ref.invalidate(appScopedRulesProvider(packageName));
    return next;
  }
}

final appScopedRulesControllerProvider = Provider<AppScopedRulesController>(
  AppScopedRulesController.new,
);
