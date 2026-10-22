/// 应用独立规则里「DNS 专属黑/白名单」「默认拦截全部外联」的真实数据源。
///
/// 这两块此前是页面上的只读说明位（「尚未接通」），因为 `RuleRepository` 只
/// 覆盖 `appScope IS NULL` 的全局规则。现在仓储补上了按应用的读写
/// （[RuleRepository.loadForApp] / `addForApp` / `setFullBlock`），这里把它们
/// 包成可监听的 provider：
/// - 读取：[appScopedRulesProvider]（按包名 family）；
/// - 写入：`AppScopedRulesController` 把仓储操作 + `invalidate` 收在一处，
///   避免页面里四处 `ref.invalidate` 漏掉一处。
///
/// 规则库不可用（非 Android 宿主、测试、首次安装未建库）时返回
/// [AppScopedRules.unavailable]，页面据此显示「读不到规则库」而不是伪造空白。
library;

import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 某个应用在规则库里的一条规则（block / allow）。
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

  /// 是否已开启「默认拦截全部外联」（存在 `*$app=<pkg>`）。
  final bool fullBlock;

  /// 规则库是否可读。false 时页面应显示错误，而不是「没有规则」。
  final bool available;

  final String? error;
}

/// 读取某应用的全部应用级规则。
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

/// 写入入口：所有改动都经过这里，成功后刷新对应的 provider。
class AppScopedRulesController {
  AppScopedRulesController(this._ref);

  final Ref _ref;

  RuleRepository? get _repository => _ref.read(ruleRepositoryProvider);

  /// 追加一条 block / allow 规则。返回 false 表示规则库不可用或已存在。
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
      _ref.invalidate(appScopedRulesProvider(packageName));
    }
    return created != null;
  }

  /// 启用/停用一条规则。
  Future<void> toggle(String packageName, MockRule rule, bool enabled) async {
    final repository = _repository;
    final id = int.tryParse(rule.id);
    if (repository == null || id == null) return;
    await repository.setEnabled(rule.kind, id, enabled);
    _ref.invalidate(appScopedRulesProvider(packageName));
  }

  /// 删除一条规则。
  Future<void> delete(String packageName, MockRule rule) async {
    final repository = _repository;
    final id = int.tryParse(rule.id);
    if (repository == null || id == null) return;
    await repository.delete(rule.kind, id);
    _ref.invalidate(appScopedRulesProvider(packageName));
  }

  /// 切换「默认拦截全部外联」，返回新状态。
  Future<bool> setFullBlock(String packageName, bool enabled) async {
    final repository = _repository;
    if (repository == null) return false;
    final next = await repository.setFullBlock(packageName, enabled);
    _ref.invalidate(appScopedRulesProvider(packageName));
    return next;
  }
}

final appScopedRulesControllerProvider = Provider<AppScopedRulesController>(
  AppScopedRulesController.new,
);
