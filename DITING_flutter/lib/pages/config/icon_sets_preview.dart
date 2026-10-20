part of 'icon_sets_page.dart';

/// 图标集预览：按网格铺开集内所有图标名。
///
/// 演示层不加载真实图片（图标集来自网络，且演示环境不联网），每一格用
/// `iconTile` 字形占位、底下标注图标名。格子数量与排版是真实的：换成真图片
/// 只需要把 [GlyphIcon] 换成 `Image.network`，布局不用动。
Future<void> showIconSetPreview(BuildContext context, MockIconSet iconSet) =>
    showSheet<void>(
      context: context,
      builder: (_) => _IconSetPreviewSheet(iconSet: iconSet),
    );

class _IconSetPreviewSheet extends StatelessWidget {
  const _IconSetPreviewSheet({required this.iconSet});

  final MockIconSet iconSet;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: iconSet.name,
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
        children: [
          if (iconSet.icons.isEmpty)
            SizedBox(
              height: 260,
              child: NullStatus(
                label: '这个图标集是空的',
                description: '编辑图标集，把图标名一行一个填进去',
                illustration: NullStatusIllustration.icons,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '共 ${iconSet.icons.length} 个图标 · ${iconSet.fromUrl ? '远程' : '本地'}',
                style: context.listCaptionStyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: iconSet.icons.length,
                itemBuilder: (context, index) =>
                    _IconTile(name: iconSet.icons[index]),
              ),
            ),
            const ListFooter(text: '图标按名称匹配：分组里写 icon: 名字，就会取这里同名的图标。'),
          ],
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

/// 一个图标格：字形占位 + 图标名。
class _IconTile extends StatelessWidget {
  const _IconTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.md,
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
        children: [
          GlyphIcon(
            AppGlyphs.iconTile,
            size: 28,
            color: colorScheme.onSurfaceVariant,
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.listCaptionStyle,
          ),
        ],
      ),
    );
  }
}
