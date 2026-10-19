import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 仪表盘取色。
///
/// 上游 `views/dashboard/style.dart:6-61`。与页面其它部分的区别是**多一层
/// 明度**：仪表盘卡片自己带投影、内部还有 block/inset 两级嵌套，直接用
/// `colorScheme.surface` 会让嵌套层糊在一起。
class DashboardColors {
  const DashboardColors._({
    required this.page,
    required this.card,
    required this.tone,
    required this.tone2,
    required this.track,
    required this.series2,
    required this.ok,
    required this.warn,
  });

  factory DashboardColors.of(BuildContext context) {
    final colorScheme = context.colorScheme;
    final card = SurfaceLevel.card.colorOf(colorScheme);
    return DashboardColors._(
      page: SurfaceLevel.page.colorOf(colorScheme),
      card: card,
      tone: SurfaceLevel.block.colorOf(colorScheme),
      tone2: SurfaceLevel.inset.colorOf(colorScheme),
      track: colorScheme.surfaceContainerHighest,
      // 上行曲线用主色混 45% 卡片底色，与下载曲线区分又同属一个色族。
      series2: Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.45),
        card,
      ),
      ok: colorScheme.success,
      warn: colorScheme.warning,
    );
  }

  final Color page;
  final Color card;
  final Color tone;
  final Color tone2;
  final Color track;
  final Color series2;
  final Color ok;
  final Color warn;
}

/// 阴影。
///
/// 上游注释特别强调：设计稿给的是 CSS `blur`，它是 Flutter `blurRadius` 的
/// 两倍；同时 Flutter 把半径 r 转成 sigma = 0.577r + 0.5。直接照抄 CSS 值会
/// 重三分之一，因此每个值都过一遍 [blur]。
abstract final class DashboardShadows {
  static List<BoxShadow> e1(BuildContext context) =>
      context.colorScheme.brightness == Brightness.dark ? _e1Dark : _e1Light;

  static List<BoxShadow> e2(BuildContext context) =>
      context.colorScheme.brightness == Brightness.dark ? _e2Dark : _e2Light;

  static BoxShadow _shadow(
    int alpha,
    double y,
    double cssBlur, [
    double spread = 0,
  ]) => BoxShadow(
    color: Color.fromARGB(alpha, 0, 0, 0),
    offset: Offset(0, y),
    blurRadius: blur(cssBlur),
    spreadRadius: spread,
  );

  static double blur(double cssBlur) =>
      cssBlur <= 1 ? 0 : (cssBlur / 2 - 0.5) / 0.57735;

  static final _e1Light = [
    _shadow(0x0D, 0.5, 1),
    _shadow(0x0A, 2, 6),
    _shadow(0x17, 12, 32, -6),
  ];

  static final _e1Dark = [_shadow(0x80, 1, 2), _shadow(0x8C, 10, 28, -6)];

  static final _e2Light = [
    _shadow(0x0F, 1, 3),
    _shadow(0x14, 10, 24),
    _shadow(0x38, 32, 64, -12),
  ];

  static final _e2Dark = [_shadow(0x80, 2, 6), _shadow(0xB3, 32, 64, -12)];
}

/// 圆角。
///
/// 脱离 `AppCorner` 刻度：仪表盘卡片比应用内任何表面都高，圆角要更大才能
/// 保持同样的视觉比例。
abstract final class DashboardCorner {
  static const desktopCard = 32.0;
  static const mobileCard = 34.0;
  static const block = 20.0;
  static const mobileBlock = 22.0;
  static const tab = 16.0;
  static const badge = 14.0;
}

/// 仪表盘文字角色。所有数字都用等宽（tabular）数字，否则速率跳动时整行左右抖。
abstract final class DashboardText {
  static TextStyle cardTitle(BuildContext context) => AppTextStyle.footnote
      .of(context, emphasized: true)
      .copyWith(color: context.colorScheme.onSurfaceVariant);

  static TextStyle mobileCardTitle(BuildContext context) =>
      AppTextStyle.subheadline.of(context, emphasized: true);

  static TextStyle label(BuildContext context, {Color? color}) => AppTextStyle
      .caption1
      .of(context)
      .toTabular
      .copyWith(color: color ?? context.colorScheme.onSurfaceVariant);

  static TextStyle figure(
    BuildContext context,
    AppTextStyle style, {
    Color? color,
  }) => style
      .of(context, emphasized: true)
      .toTabular
      .copyWith(color: color, letterSpacing: -0.02 * style.size);

  static TextStyle unit(
    BuildContext context, [
    AppTextStyle style = AppTextStyle.subheadline,
  ]) => style
      .of(context, emphasized: true)
      .copyWith(color: context.colorScheme.onSurfaceVariant);

  static TextStyle rowTitle(BuildContext context) =>
      AppTextStyle.subheadline.of(context, emphasized: true);
}

/// 卡片内边距随密度收紧。
EdgeInsets dashboardCardPadding(DashboardDensity density) => switch (density) {
  DashboardDensity.standard => const EdgeInsets.symmetric(
    horizontal: 22,
    vertical: 20,
  ),
  DashboardDensity.compact => const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  ),
  DashboardDensity.mobile => const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 18,
  ),
};

double dashboardCardRadius(DashboardDensity density) =>
    density.isDesktop ? DashboardCorner.desktopCard : DashboardCorner.mobileCard;

/// 字节数 →「1.2 MB」。1000 进制，与流量页口径一致。
String dashboardTraffic(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// 带千分位的计数；超过十万改用紧凑写法，避免撑破窄卡片。
String dashboardCount(int count) {
  if (count >= 100000) {
    return '${(count / 1000).toStringAsFixed(0)}k';
  }
  final digits = count.abs().toString();
  final buffer = StringBuffer(count < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 速率文案：`12.3 KB/s`。
String dashboardSpeed(num bytesPerSecond) =>
    '${dashboardTraffic(bytesPerSecond)}/s';
