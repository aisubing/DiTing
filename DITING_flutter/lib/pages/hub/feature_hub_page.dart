import 'package:diting/data/mock_data.dart';
import 'package:diting/state/feature_hub_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 功能中心：按上游 `FeatureHubScreen.kt` 的 7 类 28 卡、2 列网格迁移。
///
/// 只迁布局与模块：分类标题、卡片顺序、隐藏开关、日志卡长按都沿用旧版；
/// 视觉仍走本仓设计系统（`CommonScaffold` / `ListHeader` / 卡片表面与字号）。
/// 极速模式不另做一份 UI，按上游 18 项门控白名单过滤同一数据源。
class FeatureHubPage extends ConsumerWidget {
  const FeatureHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final express = ref.watch(workModeProvider) == AppWorkMode.express;
    final hidden = ref.watch(hiddenFeatureKeysProvider);
    final categories = visibleFeatureCategories(
      express: express,
      hiddenKeys: hidden,
    );
    return CommonScaffold(
      title: '功能中心',
      body: CustomScrollView(
        slivers: [
          // 顶栏浮在正文之上，正文自己让出栏高。
          SliverToBoxAdapter(child: SizedBox(height: context.appBarInset)),
          for (final category in categories)
            SliverToBoxAdapter(child: _CategorySection(category: category)),
          SliverToBoxAdapter(
            child: SizedBox(height: NavigationDock.insetOf(context)),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});

  final MockFeatureCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(title: category.title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CardGrid(cards: category.cards),
          ),
        ],
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});

  final List<MockFeatureCard> cards;

  static const _gap = 10.0;

  /// 卡片基础高度（1.0 字号下）。
  ///
  /// 必须随字号放大：卡片里是「图标 + 标题 + 副标题」三行固定内容，1.4 倍字号
  /// 时三行文字比 92dp 高约 6dp，固定高度会直接溢出。用 `textScaler` 线性放大
  /// 与 `clampTextScale` 的上界（1.4）对齐即可，不做更细的拟合。
  static const _cardHeight = 92.0;

  @override
  Widget build(BuildContext context) {
    // 2 列等宽网格。用 Row/Column 而不是 GridView：卡片数量是个位数，
    // 且 GridView 在 Column 里需要 shrinkWrap，反而更贵。
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      final left = cards[i];
      final right = i + 1 < cards.length ? cards[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: Row(
            spacing: _gap,
            children: [
              Expanded(child: _FeatureCard(card: left)),
              if (right != null)
                Expanded(child: _FeatureCard(card: right))
              else
                const Spacer(),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _FeatureCard extends ConsumerStatefulWidget {
  const _FeatureCard({required this.card});

  final MockFeatureCard card;

  @override
  ConsumerState<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends ConsumerState<_FeatureCard> {
  bool _pressed = false;

  /// 字号放大时同步放宽卡片高度。
  ///
  /// `MediaQuery.textScalerOf` 已经过全局 `clampTextScale` 夹取，所以这里直接
  /// 用它，不额外 `clamp`——否则两处上界不一致，1.4 倍时又会差几像素。
  static double _heightScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_CardGrid._cardHeight) /
      _CardGrid._cardHeight;

  void _open() => context.push(widget.card.route);

  void _longPress() {
    final route = widget.card.longPressRoute;
    if (route == null) {
      return;
    }
    ref.read(logLongPressHintProvider.notifier).acknowledge();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final card = widget.card;
    final showLongPressHint =
        card.longPressRoute != null && ref.watch(logLongPressHintProvider);
    return Semantics(
      button: true,
      label: '${card.title}，${card.description}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _open();
        },
        onLongPress: card.longPressRoute == null ? null : _longPress,
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            height: _CardGrid._cardHeight * _heightScale(context),
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(
              shape: AppShape.md,
              color: SurfaceLevel.card.colorOf(colorScheme),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Row(
                  children: [
                    GlyphIcon(
                      glyphByName(card.glyphName),
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const Spacer(),
                    if (showLongPressHint)
                      Text(
                        '可长按',
                        style: AppTextStyle.caption2
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
                Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline
                      .of(context, emphasized: true)
                      .copyWith(color: colorScheme.onSurface),
                ),
                Text(
                  card.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
