// ignore_for_file: sort_child_properties_last
import 'package:diting/data/db/mirror_template_repository.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/auto_update_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 规则订阅自动更新（上游 `SubscriptionAutoUpdateIntervalScreen`）。
///
/// ## 这里没有本地 state
/// 旧版把总开关与间隔写在数据集 prefs 里（`subscription_auto_update_enabled` /
/// `subscription_auto_update_interval_hours`），分组开关写在
/// `subscription_group.autoUpdateEnabled` 列里。页面上一轮的 `_enabled` /
/// `_hours` / `_groups` 是内存变量：退出再进来就回到「已开启 · 每 6 小时」，
/// 与规则控制页显示的数字也对不上。现在全部读 [autoUpdateSettingsProvider] 与
/// [autoUpdateGroupsProvider]，写入口在 [autoUpdateActionsProvider]。
///
/// ## 关于「后台调度」
/// 旧版写完设置会调 `SubscriptionAutoUpdateScheduler.sync()` 去重排 WorkManager。
/// 本仓原生侧没有移植那个调度器，因此 footer 如实说明「设置已保存，后台调度
/// 需原生侧接入」——不写「会在后台按此频率更新」这种做不到的承诺。
class AutoUpdateSettingsPage extends ConsumerWidget {
  const AutoUpdateSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(autoUpdateSettingsProvider);
    final groups = ref.watch(autoUpdateGroupsProvider).value;
    final actions = ref.read(autoUpdateActionsProvider);
    final enabled = settings.enabled;
    return CommonScaffold(
      title: '自动更新设置',
      body: PageBody(
        children: [
          generateSection(
            title: '自动更新',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.refresh),
                title: const Text('自动更新规则订阅'),
                subtitle: const Text('记录总开关；后台调度由原生侧执行'),
                value: enabled,
                onChanged: actions.setEnabled,
              ),
            ],
          ),
          generateSection(
            title: '更新频率',
            items: [
              for (final hours
                  in LegacySettings.subscriptionAutoUpdatePresetHours)
                ListItem(
                  leading: GlyphIcon(
                    settings.intervalHours == hours
                        ? AppGlyphs.checkCircle
                        : AppGlyphs.clock,
                    size: 20,
                  ),
                  title: Text('每 $hours 小时'),
                  trailing: settings.intervalHours == hours
                      ? const SelectionCheck()
                      : null,
                  onTap: enabled ? () => actions.setIntervalHours(hours) : null,
                ),
              ListItem(
                leading: GlyphIcon(
                  settings.isCustom ? AppGlyphs.checkCircle : AppGlyphs.sliders,
                  size: 20,
                ),
                title: const Text('自定义更新时间'),
                subtitle: Text(
                  settings.isCustom
                      ? '每 ${settings.intervalHours} 小时'
                      : '输入 1 至 168 小时之间的更新时间',
                ),
                trailing: settings.isCustom ? const SelectionCheck() : null,
                onTap: enabled ? () => _editCustom(context, ref, settings) : null,
              ),
            ],
            footer:
                '间隔保存在当前工作模式的数据集里（普通 / 极速 / 服务器各自独立）。'
                '本机尚未接入后台调度器：设置会保存，实际执行需原生侧任务队列。',
          ),
          generateSection(
            title: '分组自动更新',
            items: [
              if (groups == null)
                const ListItem(
                  leading: GlyphIcon(AppGlyphs.layers),
                  title: Text('读取分组中…'),
                )
              else if (groups.isEmpty)
                const ListItem(
                  leading: GlyphIcon(AppGlyphs.layers),
                  title: Text('还没有分组'),
                  subtitle: Text('在规则订阅页新建分组后，可以在这里单独开关'),
                )
              else
                for (final group in groups)
                  ListItem.toggle(
                    leading: const GlyphIcon(AppGlyphs.layers),
                    title: Text(group.name),
                    value: group.autoUpdateEnabled,
                    onChanged: enabled
                        ? (value) => actions.setGroupEnabled(group.id, value)
                        : null,
                  ),
            ],
            footer: '仅会自动更新已开启的分组中的网络订阅；写入 `subscription_group` 表。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editCustom(
    BuildContext context,
    WidgetRef ref,
    AutoUpdateSettings settings,
  ) async {
    final controller = TextEditingController(text: '${settings.intervalHours}');
    final value = await showFloatingDialog<int>(
      context: context,
      child: CommonDialog(
        title: '自定义更新时间',
        hasFields: true,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '更新间隔（小时）',
            helperText: '1–168 小时',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed == null ||
                  parsed <
                      LegacySettings.minSubscriptionAutoUpdateIntervalHours ||
                  parsed >
                      LegacySettings.maxSubscriptionAutoUpdateIntervalHours) {
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      ref.read(autoUpdateActionsProvider).setIntervalHours(value);
    }
  }
}

/// 镜像站模板（上游 `MirrorTemplateScreen`）。
///
/// 模板存在旧库 `mirror_template` 表里（`id` / `name` / `template` / `addedAt`），
/// 由 `MirrorTemplateRepository` 读写。上一轮这里是三条内存常量
/// （GitHub 镜像 / Cloudflare 加速 / 内网镜像），刷新就回来、重启就丢。
class MirrorTemplatesPage extends ConsumerWidget {
  const MirrorTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(mirrorTemplatesProvider);
    final rows = templates.value;
    return CommonScaffold(
      title: '镜像站模板',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加模板',
          onPressed: () => _add(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '保存常用的订阅下载镜像。添加规则订阅时，可以直接选择这里的模板。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          generateSection(
            title: '操作',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: const Text('镜像站格式示例'),
                subtitle: const Text('了解占位符如何组成镜像地址'),
                onTap: () => _showFormatGuide(context),
              ),
            ],
          ),
          if (templates.hasError)
            generateSection(
              title: '已保存模板',
              items: const [
                ListItem(
                  leading: GlyphIcon(AppGlyphs.error),
                  title: Text('无法读取镜像站模板'),
                  subtitle: Text('旧库尚未就绪或该表不可用'),
                ),
              ],
            )
          else
            generateSection(
              title: '已保存模板（${rows?.length ?? 0}）',
              items: [
                for (final row in rows ?? const <MirrorTemplateRecord>[])
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.layers, size: 20),
                    title: Text(row.name),
                    subtitle: Text(row.template),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '编辑',
                          onPressed: () => _edit(context, ref, row),
                          icon: const GlyphIcon(AppGlyphs.edit, size: 20),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () =>
                              ref.read(mirrorTemplateActionsProvider).remove(
                                row.id,
                              ),
                          icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                        ),
                      ],
                    ),
                  ),
              ],
              footer: rows == null
                  ? '正在读取镜像站模板…'
                  : rows.isEmpty
                  ? '暂无模板。点击右上角「添加模板」开始使用。'
                  : null,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await _editTemplate(context);
    if (result == null) return;
    final id = await ref
        .read(mirrorTemplateActionsProvider)
        .create(name: result.name, template: result.template);
    if (id == null && context.mounted) {
      // 同名唯一索引会拒绝插入：明确告知，而不是静默什么都不发生。
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('同名模板已存在，请换一个名称'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MirrorTemplateRecord row,
  ) async {
    final result = await _editTemplate(
      context,
      initial: (name: row.name, template: row.template),
    );
    if (result == null) return;
    final ok = await ref
        .read(mirrorTemplateActionsProvider)
        .update(id: row.id, name: result.name, template: result.template);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('保存失败：名称与已有模板重复'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<({String name, String template})?> _editTemplate(
    BuildContext context, {
    ({String name, String template})? initial,
  }) {
    final name = TextEditingController(text: initial?.name ?? '');
    final template = TextEditingController(text: initial?.template ?? '');
    return showFloatingDialog<({String name, String template})>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final match = RegExp(
            r'\{(url|scheme|urlEncoded|host|path|pathAndQuery)\}',
          );
          final valid =
              template.text.startsWith('http') && match.hasMatch(template.text);
          return CommonDialog(
            title: initial == null ? '添加镜像站模板' : '编辑镜像站模板',
            hasFields: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                TextField(
                  controller: name,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: '模板名称',
                    hintText: '例如：GitHub 镜像',
                  ),
                ),
                TextField(
                  controller: template,
                  autocorrect: false,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: '模板地址',
                    hintText: 'https://mirror.example.com/{url}',
                  ),
                ),
                Text(
                  valid
                      ? '可用占位符：{url}、{scheme}、{urlEncoded}、{host}、{path}、{pathAndQuery}'
                      : '必须使用 HTTP(S) 并包含至少一个占位符',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(
                        color: valid
                            ? context.colorScheme.onSurfaceVariant
                            : context.colorScheme.error,
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: valid && name.text.trim().isNotEmpty
                    ? () => Navigator.of(context).pop((
                        name: name.text.trim(),
                        template: template.text.trim(),
                      ))
                    : null,
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      name.dispose();
      template.dispose();
    });
  }

  void _showFormatGuide(BuildContext context) {
    showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '镜像站格式',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: const [
            Text('镜像地址由固定前缀与占位符组成，下载订阅时会把占位符替换成真实链接。'),
            Text('{url}：完整订阅地址'),
            Text('{scheme}：http 或 https'),
            Text('{urlEncoded}：URL 编码后的完整地址'),
            Text('{host}：订阅域名'),
            Text('{path}：路径部分'),
            Text('{pathAndQuery}：路径与查询参数'),
            Text('示例：https://ghproxy.example.com/{url}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
