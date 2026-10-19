import 'package:diting/data/mock_data.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 功能中心：5 类 19 卡，2 列网格，按下缩放到 0.90。
///
/// 上游 `FeatureHubScreen.kt` 的卡片是 84dp 高、按下缩放 0.90（spring
/// NoBouncy）。这里用 `GestureDetector` + `AnimatedScale` 复刻同一手感，
/// 因为设计系统里没有现成的「按下缩放」容器。
class FeatureHubPage extends StatelessWidget {
  const FeatureHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '功能中心',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.settings,
          tooltip: '设置',
          onPressed: () => context.push('/settings'),
        ),
      ],
      body: CustomScrollView(
        slivers: [
          for (final category in mockFeatureCategories)
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

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.card});

  final MockFeatureCard card;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  /// 字号放大时同步放宽卡片高度。
  ///
  /// `MediaQuery.textScalerOf` 已经过全局 `clampTextScale` 夹取，所以这里直接
  /// 用它，不额外 `clamp`——否则两处上界不一致，1.4 倍时又会差几像素。
  static double _heightScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_CardGrid._cardHeight) /
      _CardGrid._cardHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      button: true,
      label: '${widget.card.title}，${widget.card.subtitle}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          context.push(widget.card.route);
        },
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
                GlyphIcon(
                  glyphByName(widget.card.glyphName),
                  size: 20,
                  color: colorScheme.primary,
                ),
                Text(
                  widget.card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline
                      .of(context, emphasized: true)
                      .copyWith(color: colorScheme.onSurface),
                ),
                Text(
                  widget.card.subtitle,
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
