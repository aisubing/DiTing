// ignore_for_file: sort_child_properties_last
import 'package:diting/data/db/mirror_template_repository.dart';
import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/hub/mirror_global_section.dart';
import 'package:diting/state/auto_update_providers.dart';
import 'package:diting/state/auto_update_runner.dart';
import 'package:diting/state/global_mirror_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/page_intro.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Subscription auto-update (upstream `SubscriptionAutoUpdateIntervalScreen`). No local state: the
/// switch and interval live in `subscription_auto_update_enabled` / `..._interval_hours`.
class AutoUpdateSettingsPage extends ConsumerWidget {
  const AutoUpdateSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(autoUpdateSettingsProvider);
    final groups = ref.watch(autoUpdateGroupsProvider).value;
    final actions = ref.read(autoUpdateActionsProvider);
    final candidates = ref.watch(autoUpdatableSubscriptionsProvider).value;
    final lastRun = ref.watch(autoUpdateLastRunProvider);
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
                subtitle: const Text('启动应用或回到前台时检查是否到期'),
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
                onTap: enabled
                    ? () => _editCustom(context, ref, settings)
                    : null,
              ),
            ],
            footer:
                '间隔保存在当前工作模式的数据集里（普通 / 极速 / 服务器各自独立）。'
                '本机没有后台任务队列：应用在前台（含启动与切回前台）时才检查到期并执行，'
                '进程被完全关闭期间不会更新。',
          ),
          generateSection(
            title: '执行状态',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.clock),
                title: const Text('下次预计更新'),
                subtitle: Text(_nextUpdateText(enabled, settings, candidates)),
              ),
              ListItem(
                leading: GlyphIcon(
                  lastRun == null ? AppGlyphs.info : AppGlyphs.checkCircle,
                  size: 20,
                ),
                title: const Text('上次自动更新'),
                subtitle: Text(
                  lastRun == null
                      ? '本次会话还没有执行过自动更新'
                      : '${lastRun.summary ?? ''}'
                            '（${lastRun.ranCount} 个订阅）',
                ),
              ),
            ],
            footer: '判据是每条订阅的「上次尝试时间」与上面的间隔；正在手动更新时本轮会让路。',
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
    final value = await showFloatingDialog<int>(
      context: context,
      child: _IntervalDialog(initial: settings.intervalHours),
    );
    if (value != null) {
      ref.read(autoUpdateActionsProvider).setIntervalHours(value);
    }
  }

  /// The "next update" line, covering switch off, no candidates and the earliest due one;
  /// [AutoUpdateRunner.nextDueAt] derives it from the real `lastAttemptAt`.
  String _nextUpdateText(
    bool enabled,
    AutoUpdateSettings settings,
    List<SubscriptionRecord>? candidates,
  ) {
    if (!enabled) {
      return '自动更新已关闭';
    }
    if (candidates == null) {
      return '正在读取订阅…';
    }
    if (candidates.isEmpty) {
      return '没有可自动更新的订阅（需为远程、已启用、且所在分组已开启）';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = AutoUpdateRunner.nextDueAt(
      candidates,
      settings.intervalHours,
      now,
    );
    if (due == null) {
      return '没有可自动更新的订阅';
    }
    if (due <= now) {
      return '已到期：回到前台时会立即执行';
    }
    final when = DateTime.fromMillisecondsSinceEpoch(due);
    final remaining = due - now;
    final hours = remaining ~/ 3600000;
    final minutes = (remaining % 3600000) ~/ 60000;
    final left = hours > 0 ? '$hours 小时 $minutes 分钟后' : '$minutes 分钟后';
    return '${_formatMoment(when)}（$left）';
  }

  static String _formatMoment(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.month} 月 ${time.day} 日 '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

/// Custom interval dialog. The controller is owned by the dialog: disposing it right after
/// `await` trips a framework assertion while the exit animation still shows the `TextField`.
class _IntervalDialog extends StatefulWidget {
  const _IntervalDialog({required this.initial});

  final int initial;

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text);
    if (parsed == null ||
        parsed < LegacySettings.minSubscriptionAutoUpdateIntervalHours ||
        parsed > LegacySettings.maxSubscriptionAutoUpdateIntervalHours) {
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '自定义更新时间',
      hasFields: true,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _submit(),
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
        TextButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

/// Mirror templates (upstream `MirrorTemplateScreen`), stored in the legacy
/// `mirror_template` table through `MirrorTemplateRepository` so they survive a restart.
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
          PageIntroCard(
            text:
                '保存常用的下载镜像。开启全局镜像后，订阅与软件更新默认都走所选模板；'
                '添加订阅时也可以单独指定模板。',
          ),
          if (rows != null) GlobalMirrorSection(templates: rows),
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
                          onPressed: () async {
                            await ref
                                .read(mirrorTemplateActionsProvider)
                                .remove(row.id);
                            ref
                                .read(globalMirrorProvider.notifier)
                                .templateRemoved(row.template);
                          },
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
      // The unique index on the name rejects the insert; report it instead of silently
      // doing nothing.
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
    if (ok) {
      ref
          .read(globalMirrorProvider.notifier)
          .templateChanged(row.template, result.template);
    }
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
    return showFloatingDialog<({String name, String template})>(
      context: context,
      child: _TemplateDialog(initial: initial),
    );
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

/// Mirror template editor. The controller is owned by the dialog: disposing it from
/// `whenComplete` fires on `pop` while the `TextField` is still animating out.
class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({this.initial});

  final ({String name, String template})? initial;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  static final _placeholder = RegExp(
    r'\{(url|scheme|urlEncoded|host|path|pathAndQuery)\}',
  );

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _template = TextEditingController(
    text: widget.initial?.template ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _template.dispose();
    super.dispose();
  }

  bool get _valid =>
      _template.text.startsWith('http') &&
      _placeholder.hasMatch(_template.text);

  void _submit() {
    if (!_valid || _name.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context)
        .pop((name: _name.text.trim(), template: _template.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.initial == null ? '添加镜像站模板' : '编辑镜像站模板',
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '模板名称',
              hintText: '例如：GitHub 镜像',
            ),
          ),
          TextField(
            controller: _template,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '模板地址',
              hintText: 'https://mirror.example.com/{url}',
            ),
          ),
          Text(
            _valid
                ? '可用占位符：{url}、{scheme}、{urlEncoded}、{host}、{path}、{pathAndQuery}'
                : '必须使用 HTTP(S) 并包含至少一个占位符',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(
                  color: _valid
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
          onPressed: _valid && _name.text.trim().isNotEmpty ? _submit : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
