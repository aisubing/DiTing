// ignore_for_file: sort_child_properties_last
import 'package:diting/data/mock_data.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 规则订阅自动更新（上游 `SubscriptionAutoUpdateIntervalScreen`）。
class AutoUpdateSettingsPage extends StatefulWidget {
  const AutoUpdateSettingsPage({super.key});

  @override
  State<AutoUpdateSettingsPage> createState() => _AutoUpdateSettingsPageState();
}

class _AutoUpdateSettingsPageState extends State<AutoUpdateSettingsPage> {
  static const _intervals = [1, 3, 6, 12, 24];

  bool _enabled = true;
  int _hours = 6;
  final Map<String, bool> _groups = {
    for (final group in mockSubscriptionGroups) group: true,
  };

  @override
  Widget build(BuildContext context) {
    final custom = !_intervals.contains(_hours);
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
                subtitle: const Text(
                  '在后台定期更新所有网络订阅，实际执行时间可能受系统调度影响',
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          generateSection(
            title: '更新频率',
            items: [
              for (final hours in _intervals)
                ListItem(
                  leading: GlyphIcon(
                    _hours == hours ? AppGlyphs.checkCircle : AppGlyphs.clock,
                    size: 20,
                  ),
                  title: Text('每 $hours 小时'),
                  trailing: _hours == hours ? const SelectionCheck() : null,
                  onTap: _enabled ? () => setState(() => _hours = hours) : null,
                ),
              ListItem(
                leading: GlyphIcon(
                  custom ? AppGlyphs.checkCircle : AppGlyphs.sliders,
                  size: 20,
                ),
                title: const Text('自定义更新时间'),
                subtitle: Text(
                  custom ? '每 $_hours 小时' : '输入 1 至 168 小时之间的更新时间',
                ),
                trailing: custom ? const SelectionCheck() : null,
                onTap: _enabled ? _editCustom : null,
              ),
            ],
            footer: '系统会在后台按此频率检查网络规则订阅，实际执行时间可能受系统调度影响。',
          ),
          generateSection(
            title: '分组自动更新',
            items: [
              for (final group in _groups.keys)
                ListItem.toggle(
                  leading: const GlyphIcon(AppGlyphs.layers),
                  title: Text(group),
                  value: _groups[group] ?? true,
                  onChanged: _enabled
                      ? (value) => setState(() => _groups[group] = value)
                      : null,
                ),
            ],
            footer: '仅会自动更新已开启的分组中的网络订阅。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editCustom() async {
    final controller = TextEditingController(text: '$_hours');
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
              if (parsed == null || parsed < 1 || parsed > 168) {
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
    if (value != null && mounted) {
      setState(() => _hours = value);
    }
  }
}

/// 镜像站模板（上游 `MirrorTemplateScreen`）。
class MirrorTemplatesPage extends StatefulWidget {
  const MirrorTemplatesPage({super.key});

  @override
  State<MirrorTemplatesPage> createState() => _MirrorTemplatesPageState();
}

class _MirrorTemplatesPageState extends State<MirrorTemplatesPage> {
  final List<({String name, String template})> _templates = [
    (name: 'GitHub 镜像', template: 'https://ghproxy.example.com/{url}'),
    (name: 'Cloudflare 加速', template: 'https://cf.example.com/{scheme}/{host}/{path}'),
    (name: '内网镜像', template: 'http://10.0.0.2:8080/{urlEncoded}'),
  ];

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '镜像站模板',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加模板',
          onPressed: _add,
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
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
                onTap: _showFormatGuide,
              ),
            ],
          ),
          generateSection(
            title: '已保存模板（${_templates.length}）',
            items: [
              for (var index = 0; index < _templates.length; index++)
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.layers, size: 20),
                  title: Text(_templates[index].name),
                  subtitle: Text(_templates[index].template),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '编辑',
                        onPressed: () => _edit(index),
                        icon: const GlyphIcon(AppGlyphs.edit, size: 20),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => setState(() => _templates.removeAt(index)),
                        icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                      ),
                    ],
                  ),
                ),
            ],
            footer: _templates.isEmpty ? '暂无模板。点击右上角「添加模板」开始使用。' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final result = await _editTemplate();
    if (result != null && mounted) {
      setState(() => _templates.add(result));
    }
  }

  Future<void> _edit(int index) async {
    final result = await _editTemplate(initial: _templates[index]);
    if (result != null && mounted) {
      setState(() => _templates[index] = result);
    }
  }

  Future<({String name, String template})?> _editTemplate({
    ({String name, String template})? initial,
  }) {
    final name = TextEditingController(text: initial?.name ?? '');
    final template = TextEditingController(text: initial?.template ?? '');
    return showFloatingDialog<({String name, String template})>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final match = RegExp(r'\{(url|scheme|urlEncoded|host|path|pathAndQuery)\}');
          final valid = template.text.startsWith('http') && match.hasMatch(template.text);
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
                  valid ? '可用占位符：{url}、{scheme}、{urlEncoded}、{host}、{path}、{pathAndQuery}'
                      : '必须使用 HTTP(S) 并包含至少一个占位符',
                  style: AppTextStyle.footnote.of(context).copyWith(
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

  void _showFormatGuide() {
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
