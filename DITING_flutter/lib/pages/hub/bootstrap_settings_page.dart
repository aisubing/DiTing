// ignore_for_file: sort_child_properties_last
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 引导解析设置（上游 `BootstrapSettingsScreen`）。
///
/// 全局开关 + 内置节点 + 自定义节点；节点行显示 IP、权重、样本与健康状态。
/// 演示数据固定，新增/删除只改当前页面状态。
class BootstrapSettingsPage extends StatefulWidget {
  const BootstrapSettingsPage({super.key});

  @override
  State<BootstrapSettingsPage> createState() => _BootstrapSettingsPageState();
}

class _BootstrapEntry {
  _BootstrapEntry({
    required this.id,
    required this.name,
    required this.ip,
    required this.preset,
    this.samples = 0,
    this.successRate = 0,
    this.latencyMs,
    this.consecutiveFailures = 0,
  });

  final String id;
  final String name;
  final String ip;
  final bool preset;
  bool enabled = true;
  int samples;
  double successRate;
  int? latencyMs;
  int consecutiveFailures;

  String get subtitle {
    final status = switch (consecutiveFailures) {
      0 when samples == 0 => '暂无样本',
      0 => '成功 ${(successRate * 100).round()}%',
      final count => '连续失败 $count',
    };
    final latency = latencyMs == null ? '' : ' · 延迟 ${latencyMs}ms';
    return '$ip · 权重 ${preset ? '1.00' : '0.85'}$latency · 样本 $samples · $status';
  }
}

class _BootstrapSettingsPageState extends State<BootstrapSettingsPage> {
  bool _enabled = true;
  final List<_BootstrapEntry> _entries = [
    _BootstrapEntry(
      id: 'ali',
      name: '阿里公共 DNS',
      ip: '223.5.5.5',
      preset: true,
      samples: 128,
      successRate: 0.992,
      latencyMs: 9,
    ),
    _BootstrapEntry(
      id: 'tencent',
      name: '腾讯 DNSPod',
      ip: '119.29.29.29',
      preset: true,
      samples: 126,
      successRate: 0.984,
      latencyMs: 14,
    ),
    _BootstrapEntry(
      id: 'cloudflare',
      name: 'Cloudflare',
      ip: '1.1.1.1',
      preset: true,
      samples: 92,
      successRate: 0.913,
      latencyMs: 68,
    ),
    _BootstrapEntry(
      id: 'local',
      name: '本地递归',
      ip: '192.168.1.1',
      preset: false,
      samples: 41,
      successRate: 0.756,
      latencyMs: 6,
      consecutiveFailures: 1,
    ),
  ];

  List<_BootstrapEntry> get _presets =>
      _entries.where((entry) => entry.preset).toList();
  List<_BootstrapEntry> get _customs =>
      _entries.where((entry) => !entry.preset).toList();

  Future<void> _add() async {
    final draft = await showFloatingDialog<({String name, String ip})>(
      context: context,
      child: const _BootstrapEditor(),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      _entries.add(
        _BootstrapEntry(
          id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
          name: draft.name.isEmpty ? draft.ip : draft.name,
          ip: draft.ip,
          preset: false,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '引导解析设置',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '新增 Bootstrap IP',
          onPressed: _add,
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
                subtitle: const Text(
                  '使用独立递归 DNS 解析加密服务商域名，支持智能权重优选与自动回退',
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
            footer: '开启后将通过加权算法动态优选 Bootstrap IP；'
                '关闭后将通过系统 DNS 解析加密上游域名。',
          ),
          generateSection(
            title: '内置 Bootstrap IP',
            items: [
              for (final entry in _presets)
                _BootstrapRow(
                  entry: entry,
                  enabled: _enabled,
                  onChanged: (value) => setState(() => entry.enabled = value),
                ),
            ],
          ),
          generateSection(
            title: '自定义 Bootstrap IP',
            items: [
              for (final entry in _customs)
                _BootstrapRow(
                  entry: entry,
                  enabled: _enabled,
                  onChanged: (value) => setState(() => entry.enabled = value),
                  onDelete: () => setState(() => _entries.remove(entry)),
                ),
            ],
            footer: _customs.isEmpty
                ? '暂无自定义 Bootstrap IP。点击右上角「新增」添加。'
                : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BootstrapRow extends StatelessWidget {
  const _BootstrapRow({
    required this.entry,
    required this.enabled,
    required this.onChanged,
    this.onDelete,
  });

  final _BootstrapEntry entry;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: GlyphIcon(
        entry.consecutiveFailures > 0 ? AppGlyphs.warning : AppGlyphs.status,
        size: 20,
      ),
      title: Text(entry.name),
      subtitle: Text(entry.subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonCheckBox(
            value: entry.enabled,
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
      onTap: enabled ? () => onChanged(!entry.enabled) : null,
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
              style: AppTextStyle.footnote.of(context).copyWith(
                color: context.colorScheme.error,
              ),
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
