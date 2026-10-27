// ignore_for_file: sort_child_properties_last
import 'dart:convert';

import 'package:diting/data/db/bootstrap_log_repository.dart';
import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart';

/// Bootstrap resolution settings (upstream `BootstrapSettingsScreen`). Reads and writes
/// `bootstrap_enabled`, `bootstrap_preset_ids` and `bootstrap_custom_json` in
/// `dns_vpn_prefs`; counts come from `bootstrap_log`.
class BootstrapSettingsPage extends ConsumerWidget {
  const BootstrapSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    final enabled = settings.bootstrapEnabled;
    final selected = settings.bootstrapPresetIds.toSet();
    final custom = _readCustom(settings.bootstrapCustomJson);
    final stats = ref.watch(bootstrapStatsProvider);
    final statById = {
      for (final row in stats.value ?? const <BootstrapIpStat>[])
        if (row.id.isNotEmpty) row.id: row,
    };
    return CommonScaffold(
      title: '引导解析设置',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '新增 Bootstrap IP',
          onPressed: () => _add(context, ref, custom),
        ),
      ],
      body: PageBody(
        children: [
          generateSection(
            title: '全局开关',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.language),
                title: const Text('启用 Bootstrap IP'),
                subtitle: const Text('使用独立递归 DNS 解析加密服务商域名，支持智能权重优选与自动回退'),
                value: enabled,
                onChanged: (value) {
                  settings.setBootstrapEnabled(value);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
            ],
            footer:
                '开启后将通过加权算法动态优选 Bootstrap IP；'
                '关闭后将通过系统 DNS 解析加密上游域名。',
          ),
          generateSection(
            title: '内置 Bootstrap IP',
            items: [
              for (final entry in defaultBootstrapEntries)
                _BootstrapRow(
                  entry: entry,
                  selected: selected.contains(entry.id),
                  enabled: enabled,
                  stat: statById[entry.id],
                  onChanged: (value) {
                    final next = {...selected};
                    value ? next.add(entry.id) : next.remove(entry.id);
                    settings.setBootstrapPresetIds(next);
                    ref.read(legacySettingsRevisionProvider.notifier).bump();
                  },
                ),
            ],
          ),
          generateSection(
            title: '自定义 Bootstrap IP',
            items: [
              for (final entry in custom)
                _BootstrapRow(
                  entry: entry,
                  selected: entry.enabled,
                  enabled: enabled,
                  stat: statById[entry.id],
                  onChanged: (value) => _writeCustom(ref, [
                    for (final item in custom)
                      item.id == entry.id
                          ? BootstrapEntry(
                              item.id,
                              item.name,
                              item.ip,
                              enabled: value,
                            )
                          : item,
                  ]),
                  onDelete: () => _writeCustom(ref, [
                    for (final item in custom)
                      if (item.id != entry.id) item,
                  ]),
                ),
            ],
            footer: custom.isEmpty ? '暂无自定义 Bootstrap IP。点击右上角「新增」添加。' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<BootstrapEntry> custom,
  ) async {
    final draft = await showFloatingDialog<({String name, String ip})>(
      context: context,
      child: const _BootstrapEditor(),
    );
    if (draft == null) {
      return;
    }
    _writeCustom(ref, [
      ...custom,
      BootstrapEntry(
        'custom_${DateTime.now().microsecondsSinceEpoch}',
        draft.name.isEmpty ? draft.ip : draft.name,
        draft.ip,
      ),
    ]);
  }

  void _writeCustom(WidgetRef ref, List<BootstrapEntry> entries) {
    ref
        .read(legacySettingsProvider)
        .setBootstrapCustomJson(
          jsonEncode([
            for (final entry in entries)
              {
                'id': entry.id,
                'name': entry.name,
                'ip': entry.ip,
                'enabled': entry.enabled,
              },
          ]),
        );
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  /// `bootstrap_custom_json` is a JSON array of `{id,name,ip,enabled}`; entries without an
  /// IP are dropped like `BootstrapDnsSettingsStore` does.
  static List<BootstrapEntry> _readCustom(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final result = <BootstrapEntry>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final ip = (item['ip'] as String?)?.trim() ?? '';
      if (ip.isEmpty) continue;
      final id = (item['id'] as String?)?.trim();
      final name = (item['name'] as String?)?.trim();
      result.add(
        BootstrapEntry(
          id == null || id.isEmpty ? 'custom_$ip' : id,
          name == null || name.isEmpty ? ip : name,
          ip,
          enabled: item['enabled'] != false,
        ),
      );
    }
    return result;
  }
}

/// 24-hour aggregate of the legacy `bootstrap_log`; empty on a fresh install or when
/// bootstrap probing never ran.
final bootstrapStatsProvider = FutureProvider<List<BootstrapIpStat>>((
  ref,
) async {
  final mode = ref.watch(workModeProvider);
  final db = await LegacyDatabase.open(
    mode == AppWorkMode.express
        ? LegacyDatabase.expressFile
        : LegacyDatabase.mainFile,
  );
  if (db == null) return const [];
  return _readStats(db);
});

Future<List<BootstrapIpStat>> _readStats(Database db) async {
  try {
    return await BootstrapLogRepository(db).recentStats();
  } on DatabaseException {
    // Older installs may predate the table; an empty list is the honest answer.
    return const [];
  }
}

class _BootstrapRow extends StatelessWidget {
  const _BootstrapRow({
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    this.stat,
    this.onDelete,
  });

  final BootstrapEntry entry;
  final bool selected;
  final bool enabled;
  final BootstrapIpStat? stat;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  String get _subtitle {
    final row = stat;
    if (row == null || row.attempts == 0) {
      return '${entry.ip} · 暂无样本';
    }
    final success = (row.successes * 100 / row.attempts).round();
    final latency = row.averageElapsedMs == null
        ? ''
        : ' · 平均 ${row.averageElapsedMs!.round()}ms';
    return '${entry.ip}$latency · 样本 ${row.attempts} · 成功 $success%'
        '${row.failures > 0 ? ' · 失败 ${row.failures}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final failing = (stat?.failures ?? 0) > 0;
    return ListItem(
      leading: GlyphIcon(
        failing ? AppGlyphs.warning : AppGlyphs.status,
        size: 20,
      ),
      title: Text(entry.name),
      subtitle: Text(_subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonCheckBox(
            value: selected,
            onChanged: enabled ? (value) => onChanged(value ?? true) : null,
          ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除',
              onPressed: enabled ? onDelete : null,
              icon: const GlyphIcon(AppGlyphs.delete, size: 20),
            ),
        ],
      ),
      onTap: enabled ? () => onChanged(!selected) : null,
    );
  }
}

class _BootstrapEditor extends StatefulWidget {
  const _BootstrapEditor();

  @override
  State<_BootstrapEditor> createState() => _BootstrapEditorState();
}

class _BootstrapEditorState extends State<_BootstrapEditor> {
  final _name = TextEditingController();
  final _ip = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _ip.dispose();
    super.dispose();
  }

  void _save() {
    final ip = _ip.text.trim();
    final valid = RegExp(
      r'^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)$|^[0-9a-fA-F:]+$',
    ).hasMatch(ip);
    if (!valid) {
      setState(() => _error = '请填写合法的 IPv4 或 IPv6 地址');
      return;
    }
    Navigator.of(context).pop((name: _name.text.trim(), ip: ip));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '新增 Bootstrap IP',
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称（可选）'),
          ),
          TextField(
            controller: _ip,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'IP 地址'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: context.colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
