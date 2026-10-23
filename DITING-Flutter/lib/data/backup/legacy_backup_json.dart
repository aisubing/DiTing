/// 备份兼容层共用的 JSON 取值工具。
///
/// 1.4.3 的备份与 prefs 里同一个值可能有几种写法（`int` / `num` / 字符串数字、
/// 缺字段、`null`），这里统一收敛成「要么拿到值，要么 `null`」，避免每个读取
/// 点各写一遍判空。
library;

abstract final class BackupJson {
  /// 取对象；非对象（含 `null`）一律当缺失。
  static Map<Object?, Object?>? map(Object? value) =>
      value is Map ? Map<Object?, Object?>.from(value) : null;

  /// 取非空字符串；空白串视为缺失（旧版 `optString` + `takeIf isNotEmpty`）。
  static String? text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 取整数：接受 `int` / `num` / 字符串数字。
  static int? integer(Object? value) => switch (value) {
    int() => value,
    num() => value.round(),
    String() => int.tryParse(value),
    _ => null,
  };

  /// 取小数：旧版把透明度写在 XML 的 `<float>` 里，跨版本读出来可能是任一数值类型。
  static double? decimal(Object? value) => switch (value) {
    double() => value,
    num() => value.toDouble(),
    String() => double.tryParse(value),
    _ => null,
  };

  /// 取字符串数组，丢掉非字符串与空白项。
  static List<String> strings(Object? value) {
    if (value is! List) return const [];
    final result = <String>[];
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) result.add(item.trim());
    }
    return result;
  }
}
