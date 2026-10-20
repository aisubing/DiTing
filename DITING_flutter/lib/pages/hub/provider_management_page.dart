// ignore_for_file: sort_child_properties_last
import 'package:diting/data/mock_data.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 服务商管理（上游 `ProviderManagementScreen`）。
///
/// 结构：当前服务摘要 → 协议切换 → 内置服务商 → 自定义服务商。
/// 内置项只能选中，自定义项可编辑/删除；与上游一致。
class ProviderManagementPage extends ConsumerStatefulWidget {
  const ProviderManagementPage({super.key});

  @override
  ConsumerState<ProviderManagementPage> createState() =>
      _ProviderManagementPageState();
}

class _ProviderManagementPageState
    extends ConsumerState<ProviderManagementPage> {
  late final List<MockProvider> _custom = [
    for (final provider in mockProviders)
      if (!provider.isPreset) provider,
  ];
  late String _selectedId = ref.read(selectedProviderProvider);
  ProviderProtocol _protocol = ProviderProtocol.doh;

  List<MockProvider> get _all => [
    for (final provider in mockProviders)
      if (provider.isPreset) provider,
    ..._custom,
  ];

  MockProvider? get _selected =>
      _all.where((provider) => provider.id == _selectedId).firstOrNull;

  void _select(MockProvider provider) {
    setState(() => _selectedId = provider.id);
    if (mockProviders.any((item) => item.id == provider.id)) {
      ref.read(selectedProviderProvider.notifier).select(provider.id);
    }
  }

  Future<void> _add() async {
    final draft = await showFloatingDialog<_ProviderDraft>(
      context: context,
      child: _ProviderEditor(protocol: _protocol),
    );
    if (draft == null || !mounted) {
      return;
    }
    final provider = MockProvider(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name,
      protocol: draft.protocol,
      address: draft.address,
      latencyMs: 0,
    );
    setState(() {
      _custom.add(provider);
      _protocol = provider.protocol;
      _selectedId = provider.id;
    });
  }

  Future<void> _edit(MockProvider provider) async {
    final draft = await showFloatingDialog<_ProviderDraft>(
      context: context,
      child: _ProviderEditor(protocol: provider.protocol, initial: provider),
    );
    if (draft == null || !mounted) {
      return;
    }
    final index = _custom.indexWhere((item) => item.id == provider.id);
    if (index < 0) {
      return;
    }
    setState(() {
      _custom[index] = MockProvider(
        id: provider.id,
        name: draft.name,
        protocol: draft.protocol,
        address: draft.address,
        latencyMs: provider.latencyMs,
      );
      _protocol = draft.protocol;
    });
  }

  Future<void> _delete(MockProvider provider) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除 DNS 服务商',
        destructive: true,
        child: Text('确定删除「${provider.name}」吗？删除后无法再作为解析服务使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _custom.removeWhere((item) => item.id == provider.id);
      if (_selectedId == provider.id) {
        _selectedId = mockProviders.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final list = _all
        .where((provider) => provider.protocol == _protocol)
        .toList(growable: false);
    final presets = list.where((provider) => provider.isPreset).toList();
    final customs = list.where((provider) => !provider.isPreset).toList();
    final selected = _selected;
    return CommonScaffold(
      title: '服务商管理',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '新增 DNS 服务商',
          onPressed: _add,
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 12,
                children: [
                  GlyphIcon(
                    AppGlyphs.dns,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text('当前用于解析 DNS', style: context.listTitleStyle),
                        Text(
                          selected == null
                              ? '未配置'
                              : '(${selected.protocol.label}) ${selected.name}',
                          style: context.listSubtitleStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: SegmentedControl<ProviderProtocol>(
              segments: [
                for (final protocol in ProviderProtocol.values)
                  (protocol, protocol.label),
              ],
              value: _protocol,
              onChanged: (value) => setState(() => _protocol = value),
            ),
          ),
          if (presets.isNotEmpty)
            generateSection(
              title: '内置服务商',
              items: [
                for (final provider in presets)
                  _ProviderRow(
                    provider: provider,
                    selected: provider.id == _selectedId,
                    onTap: () => _select(provider),
                  ),
              ],
            ),
          if (customs.isNotEmpty)
            generateSection(
              title: '自定义服务商',
              items: [
                for (final provider in customs)
                  _ProviderRow(
                    provider: provider,
                    selected: provider.id == _selectedId,
                    onTap: () => _select(provider),
                    onEdit: () => _edit(provider),
                    onDelete: () => _delete(provider),
                  ),
              ],
            )
          else
            generateSection(
              title: '自定义服务商',
              items: const [
                ListItem(
                  title: Text('暂无自定义服务商'),
                  subtitle: Text('点击右上角「+」添加 DoH、DoT 或传统 DNS 服务'),
                  leading: GlyphIcon(AppGlyphs.addCircle),
                ),
              ],
            ),
          const ListFooter(text: '内置服务商由应用维护，只能切换；自定义服务商可编辑或删除。'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final MockProvider provider;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: GlyphIcon(
        provider.protocol == ProviderProtocol.doh
            ? AppGlyphs.lock
            : AppGlyphs.dns,
        size: 20,
      ),
      title: Text(provider.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        provider.address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) const SelectionCheck(),
          if (onEdit != null)
            IconButton(
              tooltip: '编辑',
              onPressed: onEdit,
              icon: const GlyphIcon(AppGlyphs.edit, size: 20),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除',
              onPressed: onDelete,
              icon: const GlyphIcon(AppGlyphs.delete, size: 20),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ProviderDraft {
  const _ProviderDraft({
    required this.name,
    required this.protocol,
    required this.address,
  });

  final String name;
  final ProviderProtocol protocol;
  final String address;
}

class _ProviderEditor extends StatefulWidget {
  const _ProviderEditor({required this.protocol, this.initial});

  final ProviderProtocol protocol;
  final MockProvider? initial;

  @override
  State<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<_ProviderEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late ProviderProtocol _protocol = widget.protocol;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final address = _address.text.trim();
    final valid = switch (_protocol) {
      ProviderProtocol.doh => address.startsWith('https://'),
      _ => address.contains(':') && !address.contains('://'),
    };
    if (name.isEmpty) {
      setState(() => _error = '请填写名称');
      return;
    }
    if (!valid) {
      setState(() {
        _error = _protocol == ProviderProtocol.doh
            ? 'DoH 地址需以 https:// 开头'
            : '请填写 host:port 形式的地址';
      });
      return;
    }
    Navigator.of(context)
        .pop(_ProviderDraft(name: name, protocol: _protocol, address: address));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.initial == null ? '新增 DNS 服务商' : '编辑 DNS 服务商',
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          SegmentedControl<ProviderProtocol>(
            segments: [
              for (final protocol in ProviderProtocol.values)
                (protocol, protocol.label),
            ],
            value: _protocol,
            onChanged: (value) => setState(() {
              _protocol = value;
              _error = null;
            }),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          TextField(
            controller: _address,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _protocol == ProviderProtocol.doh
                  ? 'DoH 地址'
                  : '地址（host:port）',
              hintText: _protocol == ProviderProtocol.doh
                  ? 'https://dns.example.com/dns-query'
                  : '1.1.1.1:853',
            ),
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
