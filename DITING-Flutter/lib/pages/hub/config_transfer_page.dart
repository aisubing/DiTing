// ignore_for_file: sort_child_properties_last
import 'package:diting/data/backup/backup_importer.dart';
import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/state/backup_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Backup and migration (upstream `ConfigTransferScreen`): export writes through the system
/// document
/// picker, import reads and merges the chosen file. Both share the [BackupGroup] checklist.
class ConfigTransferPage extends ConsumerStatefulWidget {
  const ConfigTransferPage({super.key});

  @override
  ConsumerState<ConfigTransferPage> createState() => _ConfigTransferPageState();
}

class _ConfigTransferPageState extends ConsumerState<ConfigTransferPage> {
  final Set<BackupGroup> _selected = {...BackupGroup.values};

  /// The running action; while non-null both entries are disabled so no second picker opens.
  String? _busy;

  bool get _allSelected => _selected.length == BackupGroup.values.length;
  bool get _noneSelected => _selected.isEmpty;

  void _toggleAll() {
    setState(() {
      _selected.clear();
      if (!_allSelected) _selected.addAll(BackupGroup.values);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(backupStatsProvider).value;
    return CommonScaffold(
      title: '备份与迁移',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _metric(context, 'DNS 服务商', _figure(stats?.providers)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    context,
                    '规则订阅',
                    _figure(stats?.subscriptions),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    '自定义规则',
                    _figure(stats?.customRules),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    context,
                    '名单应用',
                    _figure(stats?.listedApps),
                  ),
                ),
              ],
            ),
          ),
          for (final group in _sections)
            generateSection(
              title: group.title,
              actions: group.title == '应用配置备份'
                  ? [
                      IconButtonData(
                        glyph: _allSelected
                            ? AppGlyphs.deselect
                            : AppGlyphs.selectAll,
                        tooltip: _allSelected ? '全不选' : '全选',
                        onPressed: _toggleAll,
                      ),
                    ]
                  : const [],
              items: [
                for (final item in group.groups)
                  ListItem(
                    leading: GlyphIcon(
                      _selected.contains(item)
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.rules,
                      size: 20,
                    ),
                    title: Text(item.title),
                    subtitle: Text(item.description),
                    trailing: _selected.contains(item)
                        ? const SelectionCheck()
                        : null,
                    onTap: () => setState(() {
                      if (!_selected.remove(item)) _selected.add(item);
                    }),
                  ),
              ],
            ),
          generateSection(
            title: '导入导出',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.export),
                title: const Text('导出应用配置 (JSON)'),
                subtitle: Text(
                  _noneSelected
                      ? '请先勾选要导出的分组'
                      : '将勾选的 ${_selected.length} 组配置保存为 JSON 文件',
                ),
                onTap: _noneSelected || _busy != null ? null : _export,
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.importFile),
                title: const Text('导入应用配置 (JSON)'),
                subtitle: const Text('从备份文件合并配置，自动跳过本机已存在项目'),
                onTap: _busy != null ? null : _import,
              ),
            ],
            footer:
                '导出的配置文件包含个人自定义设置，请妥善保管；导入时将合并配置并'
                '自动跳过已存在的条目。出站代理的账号密码不在备份范围内。',
          ),
          generateSection(
            title: '云端备份',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.cloudSync),
                title: const Text('WebDAV 云同步'),
                subtitle: const Text('把配置文件同步到自建 WebDAV 服务器'),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(HubPaths.configTransferWebdav),
              ),
            ],
          ),
          if (_busy != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                spacing: 8,
                children: [
                  const CommonCircleLoading(size: 16),
                  Expanded(
                    child: Text(_busy!, style: context.listCaptionStyle),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static List<({String title, List<BackupGroup> groups})> get _sections => [
    (
      title: '应用配置备份',
      groups: const [
        BackupGroup.providers,
        BackupGroup.bootstrap,
        BackupGroup.cache,
        BackupGroup.outbound,
      ],
    ),
    (
      title: '规则与订阅配置',
      groups: const [
        BackupGroup.subscriptions,
        BackupGroup.domainRules,
        BackupGroup.rewriteDomain,
        BackupGroup.rewriteCname,
        BackupGroup.addressRules,
      ],
    ),
    (
      title: '应用控制与流量管理',
      groups: const [
        BackupGroup.excluded,
        BackupGroup.blocked,
        BackupGroup.allowlist,
        BackupGroup.httpInspection,
      ],
    ),
    (
      title: '个性化与通用设置',
      groups: const [BackupGroup.appearance, BackupGroup.system],
    ),
  ];

  /// A dash while the counts load; showing 0 would read as "no rules on this device".
  String _figure(int? value) => value == null ? '—' : '$value';

  Widget _metric(BuildContext context, String label, String value) =>
      CommonCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(value, style: context.listTitleStyle),
            Text(label, style: context.listCaptionStyle),
          ],
        ),
      );

  Future<void> _export() async {
    setState(() => _busy = '正在生成备份文件…');
    try {
      final actions = ref.read(backupActionsProvider);
      final export = await actions.export(_selected);
      if (!mounted) return;
      if (export.isEmpty) {
        _toast('所选分组没有可导出的内容');
        return;
      }
      setState(() => _busy = '等待选择保存位置…');
      final saved = await actions.saveToDocument(export);
      if (!mounted) return;
      if (saved.cancelled) {
        _toast('已取消保存');
      } else if (saved.saved) {
        _toast(
          '已导出 ${export.included.length} 组、共 ${export.totalItems} 项'
          '${export.skipped.isEmpty ? '' : '；跳过 ${export.skipped.length} 项'}',
        );
      } else {
        _toast(saved.error ?? '导出失败');
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = '等待选择备份文件…');
    final BackupImportResult result;
    try {
      result = await ref.read(backupActionsProvider).importFromDocument();
    } finally {
      // Clear the progress before the dialog opens, otherwise "waiting for the backup file"
      // stays behind it and looks like the import is still running.
      if (mounted) setState(() => _busy = null);
    }
    if (!mounted) return;
    if (result.cancelled) {
      _toast('已取消导入');
      return;
    }
    await showFloatingDialog<void>(
      context: context,
      child: _ImportResultDialog(result: result),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Reports only what happened: added, updated and skipped counts per group.
class _ImportResultDialog extends StatelessWidget {
  const _ImportResultDialog({required this.result});

  final BackupImportResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonDialog(
      title: '导入应用配置',
      trailing: MetaChip(
        label: result.failed ? '导入失败' : '导入完成',
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (result.failed) ...[
            Text(
              result.fatalError!,
              style: TextStyle(color: colorScheme.error),
            ),
          ] else ...[
            Text(
              '导入汇总：新增 ${result.added} 项，更新 ${result.updated} 项，'
              '跳过 ${result.skipped} 项',
              style: context.listTitleStyle,
            ),
            if (result.sourceName != null)
              Text('来源文件：${result.sourceName}', style: context.listCaptionStyle),
            if (result.occurredAt != null)
              Text(
                '备份导出于 ${_dateText(result.occurredAt!)}',
                style: context.listCaptionStyle,
              ),
            for (final outcome in result.changed)
              Text(
                '  + ${outcome.group.title} · '
                '${_outcomeText(outcome)}',
              ),
            for (final outcome in result.failedGroups)
              Text(
                '  ! ${outcome.group.title}：${outcome.error}',
                style: TextStyle(color: colorScheme.error),
              ),
            if (result.changed.isEmpty && result.failedGroups.isEmpty)
              const Text('  （备份中的条目本机都已存在，没有需要变更的内容）'),
            if (result.subscriptionCount > 0)
              Text('包含 ${result.subscriptionCount} 个订阅，请进入订阅管理执行规则更新。'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }

  String _outcomeText(BackupGroupOutcome outcome) {
    final parts = <String>[];
    if (outcome.added > 0) parts.add('新增 ${outcome.added}');
    if (outcome.updated > 0) parts.add('更新 ${outcome.updated}');
    if (outcome.skipped > 0) parts.add('跳过 ${outcome.skipped}');
    return parts.isEmpty ? '无变化' : parts.join('，');
  }

  static String _dateText(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}