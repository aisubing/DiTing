/// 1.4.3 `subscription` / `subscription_group` / `subscription_auto_update_item`
/// 三张表的 Dart 模型与枚举常量。
///
/// 枚举值逐字照抄 `data/entity/SubscriptionEntity.kt` 与
/// `SubscriptionAutoUpdateItemEntity.kt`：这些字符串直接写进数据库，任何大小写
/// 或拼写偏差都会让升级用户的行读不出来（`kind` 还参与 `(url, kind)` 唯一索引）。
library;

/// `SubscriptionSourceType`：行来自网络订阅还是本地文件。
enum SubscriptionSourceType {
  remote('remote', '网络订阅'),
  local('local', '本地文件');

  const SubscriptionSourceType(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static SubscriptionSourceType fromStorage(String? value) =>
      value == local.storageValue ? local : remote;
}

/// `SubscriptionKind`：一条订阅只承载一种规则类型。
///
/// `displayNameOf` 与上游 `SubscriptionKind.displayName` 逐字一致
/// （「黑白名单规则」/「hosts 规则」），`normalize` 的回落也是 `domain`。
enum SubscriptionKind {
  domain('domain', '黑白名单规则'),
  hosts('hosts', 'hosts 规则');

  const SubscriptionKind(this.storageValue, this.displayName);

  final String storageValue;

  /// 用户可见名称，照抄 `SubscriptionKind.displayName`。
  final String displayName;

  static SubscriptionKind normalize(String? value) =>
      value?.trim().toLowerCase() == hosts.storageValue ? hosts : domain;

  static bool isCanonical(String? value) =>
      value?.trim().toLowerCase() == domain.storageValue ||
      value?.trim().toLowerCase() == hosts.storageValue;
}

/// `SubscriptionImportState`：三态视觉的数据来源。
enum SubscriptionImportState {
  ready('ready'),
  importing('importing'),
  failed('failed');

  const SubscriptionImportState(this.storageValue);

  final String storageValue;

  static SubscriptionImportState fromStorage(String? value) => switch (value) {
    'importing' => importing,
    'failed' => failed,
    _ => ready,
  };
}

/// `SubscriptionAutoUpdateItemStatus`。
enum SubscriptionAutoUpdateStatus {
  pendingRetry('pending_retry'),
  success('success'),
  failed('failed');

  const SubscriptionAutoUpdateStatus(this.storageValue);

  final String storageValue;

  static SubscriptionAutoUpdateStatus fromStorage(String? value) =>
      switch (value) {
        'success' => success,
        'failed' => failed,
        _ => pendingRetry,
      };
}

/// 一行 `subscription`。字段与表列一一对应；`enabled` / `mirrorFallback` 在库里
/// 是 INTEGER 0/1，这里统一成 bool。
class SubscriptionRecord {
  const SubscriptionRecord({
    required this.id,
    required this.url,
    required this.name,
    required this.sourceType,
    required this.kind,
    required this.enabled,
    required this.ruleCount,
    required this.lastUpdated,
    required this.addedAt,
    required this.importState,
    required this.lastAttemptAt,
    required this.consecutiveFailureCount,
    required this.mirrorFallback,
    this.importError,
    this.httpEtag,
    this.httpLastModified,
    this.ruleSetHash,
    this.mirrorTemplate,
    this.groupId,
  });

  final int id;
  final String url;
  final String name;
  final SubscriptionSourceType sourceType;
  final SubscriptionKind kind;
  final bool enabled;

  /// 上一次成功导入的规则条数。本轮口径见 [SubscriptionLineCount] 的注释。
  final int ruleCount;

  /// 上次成功导入的时间（epoch ms）；0 表示从未成功。
  final int lastUpdated;
  final int addedAt;
  final SubscriptionImportState importState;
  final String? importError;
  final String? httpEtag;
  final String? httpLastModified;
  final String? ruleSetHash;

  /// 上次尝试（成功 / 304 / 失败）的时间（epoch ms）。
  final int lastAttemptAt;

  /// 连续失败次数，成功或 304 后清零；UI 用它提示「连续失败 N 次」。
  final int consecutiveFailureCount;
  final String? mirrorTemplate;
  final bool mirrorFallback;
  final int? groupId;

  bool get isRemote => sourceType == SubscriptionSourceType.remote;

  static SubscriptionRecord fromRow(Map<String, Object?> row) => SubscriptionRecord(
    id: (row['id'] as num?)?.toInt() ?? 0,
    url: row['url'] as String? ?? '',
    name: row['name'] as String? ?? '',
    sourceType: SubscriptionSourceType.fromStorage(row['sourceType'] as String?),
    kind: SubscriptionKind.normalize(row['kind'] as String?),
    enabled: _flag(row['enabled']) ?? true,
    ruleCount: (row['ruleCount'] as num?)?.toInt() ?? 0,
    lastUpdated: (row['lastUpdated'] as num?)?.toInt() ?? 0,
    addedAt: (row['addedAt'] as num?)?.toInt() ?? 0,
    importState: SubscriptionImportState.fromStorage(row['importState'] as String?),
    importError: row['importError'] as String?,
    httpEtag: row['httpEtag'] as String?,
    httpLastModified: row['httpLastModified'] as String?,
    ruleSetHash: row['ruleSetHash'] as String?,
    lastAttemptAt: (row['lastAttemptAt'] as num?)?.toInt() ?? 0,
    consecutiveFailureCount: (row['consecutiveFailureCount'] as num?)?.toInt() ?? 0,
    mirrorTemplate: row['mirrorTemplate'] as String?,
    mirrorFallback: _flag(row['mirrorFallback']) ?? true,
    groupId: (row['groupId'] as num?)?.toInt(),
  );

  static bool? _flag(Object? value) => switch (value) {
    final num number => number.toInt() != 0,
    final bool flag => flag,
    _ => null,
  };
}

/// 一行 `subscription_group`。
class SubscriptionGroupRecord {
  const SubscriptionGroupRecord({
    required this.id,
    required this.name,
    required this.autoUpdateEnabled,
    required this.addedAt,
  });

  final int id;
  final String name;
  final bool autoUpdateEnabled;
  final int addedAt;

  static SubscriptionGroupRecord fromRow(Map<String, Object?> row) =>
      SubscriptionGroupRecord(
        id: (row['id'] as num?)?.toInt() ?? 0,
        name: row['name'] as String? ?? '',
        autoUpdateEnabled:
            SubscriptionRecord._flag(row['autoUpdateEnabled']) ?? true,
        addedAt: (row['addedAt'] as num?)?.toInt() ?? 0,
      );
}

/// 一行 `subscription_auto_update_item`（后台批量更新的逐条结果）。
class SubscriptionAutoUpdateItemRecord {
  const SubscriptionAutoUpdateItemRecord({
    required this.batchId,
    required this.subscriptionId,
    required this.status,
    required this.changed,
    required this.ruleCount,
  });

  final String batchId;
  final int subscriptionId;
  final SubscriptionAutoUpdateStatus status;
  final bool changed;
  final int ruleCount;

  static SubscriptionAutoUpdateItemRecord fromRow(Map<String, Object?> row) =>
      SubscriptionAutoUpdateItemRecord(
        batchId: row['batchId'] as String? ?? '',
        subscriptionId: (row['subscriptionId'] as num?)?.toInt() ?? 0,
        status: SubscriptionAutoUpdateStatus.fromStorage(row['status'] as String?),
        changed: (row['changed'] as num?)?.toInt() == 1,
        ruleCount: (row['ruleCount'] as num?)?.toInt() ?? 0,
      );
}
