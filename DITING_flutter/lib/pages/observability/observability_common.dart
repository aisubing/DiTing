/// 观测域四个页面共用：格式化、确认框、链路与状态小件。
///
/// 为什么集中在一个文件：连接 / 请求 / DNS 三页的「字节数」「速率」「时长」
/// 口径必须一致——同一个页面里下行写 1.2 MB、详情写 1228 KB 是最容易出的一类
/// 不一致；链路的「节点 → 策略组」箭头样式同理。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 字节数：B / KB / MB / GB，1000 进制。
///
/// 与流量页同一口径（运营商账单也是 1000），全站不能一半 1000 一半 1024。
String obsFormatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// 速率：`82.4 KB/s`。不足 1 KB 时给整字节，避免出现 `0.0 KB/s`。
String obsFormatSpeed(int bytesPerSecond) {
  if (bytesPerSecond < 1000) {
    return '$bytesPerSecond B/s';
  }
  return '${obsFormatBytes(bytesPerSecond)}/s';
}

/// 时长：`42 秒` / `12 分 4 秒` / `1 小时 8 分`。
String obsFormatDuration(int seconds) {
  if (seconds < 60) {
    return '$seconds 秒';
  }
  if (seconds < 3600) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '$minutes 分' : '$minutes 分 $rest 秒';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分';
}

/// 延迟：`0 ms`（缓存命中）到 `2000 ms`（超时）。
String obsFormatLatency(int milliseconds) =>
    milliseconds == 0 ? '缓存命中' : '$milliseconds ms';

/// 统一的二次确认框，返回用户是否确认。
///
/// 确认文案由调用方给（「关闭」「更新」），取消一律取 `UiLocalizations`，
/// 免得每处再写一遍「取消」。
Future<bool> showObsConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final localizations = UiLocalizations.of(context);
  final confirmed = await showFloatingDialog<bool>(
    context: context,
    child: CommonDialog(
      title: title,
      destructive: destructive,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(localizations.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(message),
    ),
  );
  return confirmed == true;
}

/// 轻提示。演示页里操作结果不必弹框，用底部提示条即可。
void showObsTip(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}

/// 首次加载占位：一个转圈 + 一句说明。
///
/// 不用 `SkeletonText` 拼十行假行：连接表列宽随窗口变化，假行宽对不上真行，
/// 加载完成的一瞬间会跳一下。
class ObservabilityLoading extends StatelessWidget {
  const ObservabilityLoading({super.key, required this.label});

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

/// 「节点 → 策略组」链路。
///
/// 上游用 `RecordArrow` 画箭头；这里直接用小号 `chevronForward`，宽度与 chip
/// 的圆角基线能对齐。chip 不可点：链路在列表里只是信息，点它没有可去的地方，
/// 可点的样式会让人误以为能展开。
class ObsChainTrail extends StatelessWidget {
  const ObsChainTrail({super.key, required this.chains});

  final List<String> chains;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, chain) in chains.indexed) ...[
          if (index > 0)
            GlyphIcon(
              AppGlyphs.chevronForward,
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          TonalChip(
            label: chain,
            color: context.raisedSurfaceLevel.colorOf(colorScheme),
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

/// 链路的一步：圆点 + 竖线 + 节点名 + 角色说明。
///
/// 竖线用 `Stack` + `Positioned` 撑满整行，而不是 `IntrinsicHeight` 里放
/// `Expanded`：后者要为每行做一次固有高度测量，条目一多就是明显的布局开销。
class ChainStepRow extends StatelessWidget {
  const ChainStepRow({
    super.key,
    required this.label,
    required this.detail,
    required this.isLast,
  });

  final String label;
  final String detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          if (!isLast)
            Positioned(
              left: 2.75,
              top: 13,
              bottom: 0,
              child: SizedBox(
                width: 1.5,
                child: ColoredBox(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: isLast
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    shape: AppShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 7),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2, bottom: isLast ? 8 : 14),
                  child: Row(
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.subheadline
                              .of(context)
                              .copyWith(
                                color: isLast
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      Text(
                        detail,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 空态：插画 + 文案 + 可选动作。
///
/// 返回 `NullStatus` 而不是包一层 widget——`NullStatusSwitcher.nullStatus`
/// 的形参就是 `NullStatus?`，包一层只是多一次拆包。
NullStatus obsEmpty({
  required String label,
  required NullStatusIllustration illustration,
  String? description,
  Widget? action,
}) => NullStatus(
  label: label,
  description: description,
  illustration: illustration,
  action: action,
);

/// 读取失败态：说明 + 重试。
///
/// 旧库只读且可能被原服务占用（WAL 未合并），失败是**可恢复**的，所以给重试
/// 按钮而不是把整页变成错误页——列表页的「一片红」比一条说明加一个按钮更让
/// 人以为数据丢了。
class ObsFailure extends StatelessWidget {
  const ObsFailure({
    super.key,
    required this.label,
    required this.description,
    required this.onRetry,
  });

  final String label;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            GlyphIcon(AppGlyphs.error, size: 30, color: colorScheme.error),
            Text(label, style: context.listTitleStyle),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
