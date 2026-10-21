/// 组件画廊：把 `lib/ui` 的公开 API 逐类挂到屏幕上。
///
/// 这一页不承载业务，它是设计系统的验收面：字号、颜色、表面、形状、图标、
/// 按钮、标签、输入、列表行、卡片、浮层、反馈——每一类都铺全量而不是挑几个，
/// 这样任何一处回归（圆角变方、表面色阶错位、图标轮廓断线、按钮高度漂移）
/// 都能被截图对比发现。
///
/// 按 AGENTS.md 的 550 行上限拆成库根 + part：本文件只放页面骨架、分区索引
/// 与几个跨分区共用的小外壳，每个分区各占一个 part（私有 widget 一律
/// `_Demo` 前缀）。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

part 'demo_card_section.dart';
part 'demo_chip_section.dart';
part 'demo_color_scheme_section.dart';
part 'demo_color_section.dart';
part 'demo_feedback_section.dart';
part 'demo_glyph_catalog.dart';
part 'demo_icon_section.dart';
part 'demo_input_section.dart';
part 'demo_list_section.dart';
part 'demo_overlay_section.dart';
part 'demo_shape_section.dart';
part 'demo_button_section.dart';
part 'demo_type_section.dart';

/// 画廊页骨架。
///
/// 正文用 [ListView]（懒构建）：分区很多，一次性全部构建会让反馈区里
/// [CommonCircleLoading]/[SkeletonPill] 的循环动画在首帧就跑起来，既白烧
/// 帧又让 `pumpAndSettle` 永远等不到静止。滚到哪建到哪，首屏只承担排版与
/// 颜色两个分区。
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '组件画廊',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.palette,
          tooltip: '画廊共 ${_demoSections.length} 个分区',
          onPressed: null,
        ),
      ],
      body: ListView(
        padding: EdgeInsets.only(top: context.appBarInset),
        children: [
          const _DemoIntro(),
          for (final section in _demoSections) ...[
            ListHeader(title: section.title),
            section.child,
          ],
          const SizedBox(height: 24),
          const DockSpacer(),
        ],
      ),
    );
  }
}

/// 一个分区：标题 + 该分区的内容。
class _DemoSection {
  const _DemoSection(this.title, this.child);

  final String title;
  final Widget child;
}

/// 分区顺序是有意排的：把带循环动画的分区（反馈）放到最后，首屏保持静态。
const _demoSections = <_DemoSection>[
  _DemoSection('排版 · AppTextStyle 全 13 档', _DemoTypeSection()),
  _DemoSection('颜色与表面', _DemoColorSection()),
  _DemoSection('ColorScheme 角色色', _DemoSchemeSection()),
  _DemoSection('形状与圆角', _DemoShapeSection()),
  _DemoSection('图标 · AppGlyphs', _DemoIconSection()),
  _DemoSection('按钮', _DemoButtonSection()),
  _DemoSection('标签与选择标记', _DemoChipSection()),
  _DemoSection('输入控件', _DemoInputSection()),
  _DemoSection('列表行 · ListItem 七种构造器', _DemoListSection()),
  _DemoSection('卡片、设置行与拼装件', _DemoCardSection()),
  _DemoSection('浮层与弹窗', _DemoOverlaySection()),
  _DemoSection('反馈、骨架与图表', _DemoFeedbackSection()),
];

/// 页首说明 + 分区索引：先说清这页在看什么，再把所有分区名铺成标签。
class _DemoIntro extends StatelessWidget {
  const _DemoIntro();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              spacing: 8,
              children: [
                GlyphIcon(AppGlyphs.palette, color: colorScheme.primary),
                Expanded(
                  child: Text(
                    'lib/ui 公开 API 全量陈列',
                    style: AppTextStyle.headline.of(context),
                  ),
                ),
              ],
            ),
            Text(
              '这一页不演示业务，只把设计系统的每一类组件铺满：字号、颜色、表面、'
              '形状、图标、按钮、标签、输入、列表行、卡片、浮层、反馈。任何一处'
              '视觉回归都应该在这里被一眼看出。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final section in _demoSections)
                  CommonChip(label: section.title),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 分区外壳：统一左右 16 的内边距与 10 的行距，让所有分区看起来属于同一页。
class _DemoSectionBody extends StatelessWidget {
  const _DemoSectionBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: children,
      ),
    );
  }
}

/// 分区内的子组标题：比 [ListHeader] 轻一档，用来切分同一分区里的子组。
class _DemoLabel extends StatelessWidget {
  const _DemoLabel(this.text, {this.trailing});

  final String text;

  /// 右侧附注，通常写这个子组用到的 API 名。
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyle.footnote
                  .of(context, emphasized: true)
                  .copyWith(color: colorScheme.onSurface),
            ),
          ),
          if (trailing case final trailing?)
            Flexible(
              child: Text(
                trailing,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.caption2
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
