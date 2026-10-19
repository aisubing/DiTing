import 'package:diting/data/mock_profiles.dart';
import 'package:diting/routes/profiles_routes.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'add_profile_forms.dart';

/// 添加档案页（上游 `views/profiles/add.dart`，155 行）。
///
/// 上游是四条 `ListItem`，点开各自弹一个面板：扫码 / 文件 / 链接 / 自定义。
/// 这里保留同样的门类，但把扫码换成「手动创建」——演示版没有摄像头，扫码
/// 走不通，而手动创建（从零写一份配置）正是上游 `custom` 分支要做的事。
class AddProfilePage extends ConsumerWidget {
  const AddProfilePage({super.key});

  void _openForm(
    BuildContext context, {
    required AddProfileSource source,
    required String title,
  }) {
    showFormSheet<void>(
      context: context,
      builder: (_) => _ProfileFormSheet(source: source, title: title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '添加配置档案',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '选择一种来源。三种方式最后都会落到同一份档案：可编辑名称、更新周期，'
              '远程与合并档案还能随时改地址。',
              style: context.listSubtitleStyle,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListItem(
                    leading: GlyphIcon(
                      AppGlyphs.cloudDownload,
                      color: colorScheme.primary,
                    ),
                    title: const Text('从链接导入'),
                    subtitle: Text(
                      '订阅地址或分享链接，可设置自动更新周期',
                      style: context.listCaptionStyle,
                    ),
                    trailing: const DisclosureIndicator(),
                    onTap: () => _openForm(
                      context,
                      source: AddProfileSource.link,
                      title: '从链接导入',
                    ),
                  ),
                  ListItem(
                    leading: GlyphIcon(
                      AppGlyphs.importFile,
                      color: colorScheme.secondary,
                    ),
                    title: const Text('从文件导入'),
                    subtitle: Text(
                      '本地 YAML 配置，只在导入时读取一次',
                      style: context.listCaptionStyle,
                    ),
                    trailing: const DisclosureIndicator(),
                    onTap: () => _openForm(
                      context,
                      source: AddProfileSource.file,
                      title: '从文件导入',
                    ),
                  ),
                  ListItem(
                    leading: GlyphIcon(
                      AppGlyphs.customize,
                      color: colorScheme.tertiary,
                    ),
                    title: const Text('手动创建'),
                    subtitle: Text(
                      '一份空白配置，节点与规则自己维护',
                      style: context.listCaptionStyle,
                    ),
                    trailing: const DisclosureIndicator(),
                    onTap: () => _openForm(
                      context,
                      source: AddProfileSource.manual,
                      title: '手动创建',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '上限',
                    value: '$mockMaxProfilesCount',
                    unit: '个',
                  ),
                  const StatItem(label: '单文件', value: '10', unit: 'MB'),
                  const StatItem(label: '格式', value: 'YAML'),
                ],
              ),
            ),
          ),
          const SectionBlock(
            title: '说明',
            padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: ListFooter(
              text:
                  '远程订阅按更新周期自动拉取；本地文件与手动创建的配置不会自动更新，'
                  '需要时在档案卡片菜单里点「立即更新」。',
            ),
          ),
        ],
      ),
    );
  }
}

/// 添加方式。三种来源共用一张表单，差异只在「地址」这一行的含义。
enum AddProfileSource {
  link('订阅地址', 'https://example.com/subscribe?token=…'),
  file('文件路径', '/storage/emulated/0/Download/config.yaml'),
  manual('配置内容', '从零开始，稍后在自定义配置里添加节点');

  const AddProfileSource(this.fieldLabel, this.hint);

  final String fieldLabel;
  final String hint;

  ProfileKind get kind => switch (this) {
    link => ProfileKind.remote,
    file => ProfileKind.local,
    manual => ProfileKind.merged,
  };

  bool get needsAddress => this != manual;
}
