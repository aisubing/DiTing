// ignore_for_file: sort_child_properties_last
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// AI 厂商管理（上游 `AiProviderManageScreen`）。
class AgentProvidersPage extends ConsumerWidget {
  const AgentProvidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentApiProvider);
    final notifier = ref.read(agentApiProvider.notifier);
    final groups = <String, List<AiProviderPreset>>{};
    for (final preset in aiProviderPresets) {
      groups.putIfAbsent(preset.group, () => []).add(preset);
    }
    final added = state.providers.map((provider) => provider.presetId).toSet();
    return CommonScaffold(
      title: 'AI 厂商管理',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加自定义厂商',
          onPressed: () => _edit(context, ref),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '点选下方预设厂商会自动预填接口地址；模型不预置硬编码，'
                '填好 API Key 后即可在线拉取并点选。编辑时若 API Key 留空则保留原密钥。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          generateSection(
            title: '我的厂商',
            items: [
              if (state.providers.isEmpty)
                const ListItem(
                  title: Text('暂无厂商'),
                  subtitle: Text('从下方预设厂商目录点选，或点击右上角添加自定义厂商'),
                  leading: GlyphIcon(AppGlyphs.info),
                ),
              for (final provider in state.providers)
                ListItem(
                  leading: GlyphIcon(
                    provider.id == state.activeProviderId
                        ? AppGlyphs.checkCircle
                        : AppGlyphs.devices,
                    size: 20,
                    color: provider.id == state.activeProviderId
                        ? context.colorScheme.primary
                        : null,
                  ),
                  title: Text(provider.name),
                  subtitle: Text(
                    '${provider.model} · ${provider.baseUrl} · '
                    '${provider.hasKey ? '密钥已配置' : '缺少密钥'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '编辑',
                        onPressed: () =>
                            _edit(context, ref, existing: provider),
                        icon: const GlyphIcon(AppGlyphs.edit, size: 20),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _delete(context, notifier, provider),
                        icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                      ),
                    ],
                  ),
                  onTap: () => notifier.update(
                    (current) =>
                        current.copyWith(activeProviderId: provider.id),
                  ),
                ),
            ],
          ),
          for (final entry in groups.entries)
            generateSection(
              title: entry.key,
              items: [
                for (final preset in entry.value)
                  ListItem(
                    leading: GlyphIcon(
                      added.contains(preset.id)
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.addCircle,
                      size: 20,
                    ),
                    title: Text(preset.name),
                    subtitle: Text(preset.baseUrl),
                    trailing: TonalChip(
                      label: added.contains(preset.id) ? '已添加' : '添加',
                      color: added.contains(preset.id)
                          ? context.raisedSurfaceLevel.colorOf(
                              context.colorScheme,
                            )
                          : context.colorScheme.primary,
                      foregroundColor: added.contains(preset.id)
                          ? context.colorScheme.onSurfaceVariant
                          : context.colorScheme.onPrimary,
                      onPressed: added.contains(preset.id)
                          ? null
                          : () => _edit(context, ref, preset: preset),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    AiProviderConfig? existing,
    AiProviderPreset? preset,
  }) async {
    final result = await showFloatingDialog<_ProviderFormResult>(
      context: context,
      child: _ProviderEditor(existing: existing, preset: preset),
    );
    if (result == null) {
      return;
    }
    final current = ref.read(agentApiProvider);
    final id =
        existing?.id ?? 'provider_${DateTime.now().microsecondsSinceEpoch}';
    ref
        .read(agentApiProvider.notifier)
        .saveProvider(
          AiProviderConfig(
            id: id,
            name: result.name,
            baseUrl: result.baseUrl,
            model: result.model,
            presetId: preset?.id ?? existing?.presetId ?? '',
            hasKey: result.key.isNotEmpty || (existing?.hasKey ?? false),
          ),
        );
    if (current.providers.isEmpty) {
      ref
          .read(agentApiProvider.notifier)
          .update((state) => state.copyWith(activeProviderId: id));
    }
  }

  Future<void> _delete(
    BuildContext context,
    AgentApiNotifier notifier,
    AiProviderConfig provider,
  ) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除厂商',
        destructive: true,
        child: Text('确定要删除「${provider.name}」吗？相关 API Key 也会从本机移除。'),
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
    if (confirmed == true) {
      notifier.deleteProvider(provider.id);
    }
  }
}

class _ProviderFormResult {
  const _ProviderFormResult({
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.key,
  });

  final String name;
  final String baseUrl;
  final String model;
  final String key;
}

class _ProviderEditor extends StatefulWidget {
  const _ProviderEditor({this.existing, this.preset});

  final AiProviderConfig? existing;
  final AiProviderPreset? preset;

  @override
  State<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<_ProviderEditor> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.preset?.name ?? '',
  );
  late final _baseUrl = TextEditingController(
    text: widget.existing?.baseUrl ?? widget.preset?.baseUrl ?? '',
  );
  late final _model = TextEditingController(text: widget.existing?.model ?? '');
  final _key = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final model = _model.text.trim();
    if (name.isEmpty || !baseUrl.startsWith('http') || model.isEmpty) {
      setState(() => _error = '请填写名称、以 http(s) 开头的接口地址与模型名');
      return;
    }
    Navigator.of(context).pop(
      _ProviderFormResult(
        name: name,
        baseUrl: baseUrl,
        model: model,
        key: _key.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.existing == null ? '添加厂商' : '编辑厂商',
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '厂商名称'),
          ),
          TextField(
            controller: _baseUrl,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '接口地址',
              hintText: 'https://api.example.com/v1',
            ),
          ),
          TextField(
            controller: _model,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini',
            ),
          ),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'API Key',
              helperText: widget.existing?.hasKey == true
                  ? '留空则保留原密钥'
                  : '仅保存在本机',
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

/// AI 参数与提示词（上游 `AgentApiParamsScreen`）。
class AgentParamsPage extends ConsumerWidget {
  const AgentParamsPage({super.key});

  static const _templates = <String, String>{
    '安全威胁分析':
        '你是一名网络安全与 DNS 威胁情报专家。擅长对域名安全性、防盗链、'
        'DGA 随机特征、恶意软件外联及追踪探针进行分析，并给出明确的处置建议。',
    '极简技术审查':
        '你是一名资深网络协议工程师。请对给定的域名和流量快速给出最精炼的'
        '技术分类、风险等级与规则处置建议，格式化输出，杜绝多余套话。',
    '隐私与遥测审查':
        '你是一名数字隐私与数据保护合规审计师。重点分析该域名是否涉及未经授权的'
        '用户行为遥测、设备指纹追踪或广告归因统计。',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentApiProvider);
    final notifier = ref.read(agentApiProvider.notifier);
    final temperatureLabel = state.temperature <= 0.3
        ? '严谨精确（适合安全分析与结构化输出）'
        : state.temperature <= 0.8
        ? '平衡适中（推荐日常综合分析场景）'
        : '发散多变（输出内容更为丰富自由）';
    return CommonScaffold(
      title: '参数与提示词',
      body: PageBody(
        children: [
          generateSection(
            title: '系统提示词',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.compose),
                title: const Text('系统提示词设定'),
                subtitle: Text(
                  state.systemPrompt.isEmpty ? '未设置' : state.systemPrompt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _editPrompt(context, notifier, state.systemPrompt),
              ),
            ],
            footer: '在日志、仪表盘或缓存页面发起 AI 分析时，将使用此系统提示词引导模型。',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in _templates.entries)
                  TonalChip(
                    label: entry.key,
                    color: context.raisedSurfaceLevel.colorOf(
                      context.colorScheme,
                    ),
                    foregroundColor: context.colorScheme.onSurfaceVariant,
                    onPressed: () => notifier.update(
                      (current) => current.copyWith(systemPrompt: entry.value),
                    ),
                  ),
              ],
            ),
          ),
          generateSection(
            title: '采样温度（Temperature）',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.motion),
                title: const Text('生成随机度与创造性'),
                subtitle: Text(temperatureLabel),
                trailing: Text(
                  state.temperature.toStringAsFixed(1),
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.primary),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: state.temperature,
              min: 0,
              max: 2,
              divisions: 20,
              onChanged: (value) => notifier.update(
                (current) =>
                    current.copyWith(temperature: (value * 10).round() / 10),
              ),
            ),
          ),
          generateSection(
            title: '输出限制',
            items: [
              ListItem<int>.options(
                leading: const GlyphIcon(AppGlyphs.textShort),
                title: const Text('最大输出长度'),
                subtitle: const Text('控制单次分析的回复长度上限'),
                options: const [512, 1024, 2048, 4096],
                value: 1024,
                textBuilder: (value) => '$value tokens',
                onChanged: (_) {},
              ),
            ],
            footer: '演示页面不真正调用模型；参数仅用于展示设置项与交互。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editPrompt(
    BuildContext context,
    AgentApiNotifier notifier,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    final value = await showFloatingDialog<String>(
      context: context,
      child: CommonDialog(
        title: '系统提示词',
        hasFields: true,
        child: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '例如：你是一名网络安全与 DNS 威胁情报专家……',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      notifier.update((current) => current.copyWith(systemPrompt: value));
    }
  }
}
