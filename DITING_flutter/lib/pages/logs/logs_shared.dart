/// 日志页与日志下钻页共用的格式化函数与状态小件。
///
/// 独立成文件而不是塞进页面：四个下钻页都要 `dnsTypeName` / `clockOf` /
/// `countOf`，各写一份必然出现「缓存页写 A、竞速页写 TYPE1」的分叉。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

// `dnsTypeName` 的定义搬到了 `data/dns_type_name.dart`（概览聚合层也要用），
// 这里重新导出，页面侧的 import 不必跟着改。
export 'package:diting/data/dns_type_name.dart' show dnsTypeName;

/// 剩余秒数 → `57 分钟` / `3 小时`（旧版 `formatDuration`，三级、不取余）。
String remainingLabel(int seconds) {
  if (seconds <= 0) return '已过期';
  if (seconds >= 3600) return '${seconds ~/ 3600} 小时';
  if (seconds >= 60) return '${seconds ~/ 60} 分钟';
  return '$seconds 秒';
}

/// 毫秒时间戳 → `MM-dd HH:mm:ss`（旧版缓存页的 `cacheTimeFormatter`）。
///
/// 用固定的两位补零格式而不是 `intl`：全应用只有这一处要这个形态，多引一个
/// 依赖不划算。
String shortDateTimeOf(int milliseconds) {
  if (milliseconds <= 0) return '无';
  final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 毫秒时间戳 → `HH:mm:ss`（旧版 `formatClockTime`）。
String clockOf(int milliseconds) {
  if (milliseconds <= 0) return '无';
  final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 千分位整数（旧版 `formatCount` = `NumberFormat.getIntegerInstance`）。
String countOf(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 百分比：`12.3%`，整数不带小数点（旧版 `formatPercent`）。
String percentOf(double ratio) {
  final rounded = (ratio.clamp(0.0, 1.0) * 1000).round() / 10;
  return rounded % 1 == 0 ? '${rounded.toInt()}%' : '$rounded%';
}

/// 毫秒：`38 ms`（旧版 `formatMs`）。
String millisOf(num milliseconds) => '${milliseconds.round()} ms';

/// 日志仪表盘的整页说明块（旧版 `DashboardHero`）。
///
/// 三套模式各有一句自己的标题与说明，逐字照抄旧版：
/// - 记录全部：「请求日志仪表盘 / 全部 DNS、HTTPS、缓存、竞速与规则拦截的实时概览」
/// - 仅拦截与错误：「重点请求仪表盘 / DNS 与 HTTPS 拦截、错误、旁路记录及解析状态概览」
/// - 关闭日志：「服务状态与解析概览 / 当前处于隐私模式，不记录请求明细。…」
///
/// 它不是卡片：旧版这块没有外框，就是页面顶部两行字。做成卡片会与下面第一张
/// 统计卡连成一片，看不出「这是整页的说明」。
class LogsDashboardHero extends StatelessWidget {
  const LogsDashboardHero({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            title,
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          Text(
            description,
            style: AppTextStyle.subheadline.of(
              context,
            ).copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 日志下钻页统一的加载态。
class LogsPageLoading extends StatelessWidget {
  const LogsPageLoading({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const CommonCircleLoading.page(),
          Text(
            label,
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 日志下钻页统一的空态。
///
/// 返回 [NullStatus] 而不是包一层 `Widget`：`NullStatusSwitcher.nullStatus`
/// 的参数类型就是 `NullStatus?`，包一层就拿不到「插画 + 文案 + 动作」那套
/// 内部布局，只能塞进 `child` 里，于是空态会被当成正文重复绘制。
NullStatus logsEmpty({
  required String label,
  String? description,
  Widget? action,
  NullStatusIllustration illustration = NullStatusIllustration.logs,
}) => NullStatus(
  label: label,
  description: description,
  action: action,
  illustration: illustration,
);

/// 三档时间范围选择器（旧版 `RuleFilterChipRow` 的同等物）。
///
/// 竞速页、Bootstrap 页、订阅拦截页三处都用它：三页的范围档位不同（`7 天` 与
/// `近 7 天`），但样式与位置必须一致，否则用户在三个页面之间切换会觉得是三个
/// 不同组件。泛型化而不是各写一份。
class LogStatsRangeSelector<T> extends StatelessWidget {
  const LogStatsRangeSelector({
    super.key,
    required this.values,
    required this.labelOf,
    required this.value,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in values)
            TonalChip(
              label: labelOf(option),
              color: option == value
                  ? colorScheme.primary
                  : context.raisedSurfaceLevel.colorOf(colorScheme),
              foregroundColor: option == value
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              onPressed: () => onChanged(option),
            ),
        ],
      ),
    );
  }
}
