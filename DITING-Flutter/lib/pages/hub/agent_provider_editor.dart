// ignore_for_file: sort_child_properties_last
import 'package:diting/data/agent/agent_api_client.dart';
import 'package:diting/state/agent_providers.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ProviderFormResult {
  const ProviderFormResult({
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

/// Provider edit dialog: name, base URL, model, key plus two real actions - "fetch models"
/// calls `GET {base}/models`, "test connection" sends a minimal `chat/completions` request.
class AgentProviderEditor extends ConsumerStatefulWidget {
  const AgentProviderEditor({super.key, this.existing, this.preset});

  final AiProviderConfig? existing;
  final AiProviderPreset? preset;

  @override
  ConsumerState<AgentProviderEditor> createState() =>
      _AgentProviderEditorState();
}

class _AgentProviderEditorState extends ConsumerState<AgentProviderEditor> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.preset?.name ?? '',
  );
  late final _baseUrl = TextEditingController(
    text: widget.existing?.baseUrl ?? widget.preset?.baseUrl ?? '',
  );
  late final _model = TextEditingController(text: widget.existing?.model ?? '');
  final _key = TextEditingController();
  String? _error;
  String? _notice;
  bool _busy = false;
  List<String> _models = const [];

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  String get _effectiveKey {
    final typed = _key.text.trim();
    if (typed.isNotEmpty) return typed;
    return widget.existing?.apiKey ?? '';
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
      ProviderFormResult(
        name: name,
        baseUrl: baseUrl,
        model: model,
        key: _key.text.trim(),
      ),
    );
  }

  Future<void> _fetchModels() async {
    if (_busy) return;
    final baseUrl = _baseUrl.text.trim();
    final key = _effectiveKey;
    if (baseUrl.isEmpty) {
      setState(() => _error = '请先填写接口地址');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final models = await fetchAgentModels(
        ref,
        baseUrl: baseUrl,
        apiKey: key,
      );
      if (!mounted) return;
      setState(() {
        _models = models;
        _busy = false;
        _notice = '拉取到 ${models.length} 个模型，点下方标签选择';
      });
    } on AgentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '拉取模型失败：$error';
      });
    }
  }

  Future<void> _testConnection() async {
    if (_busy) return;
    final baseUrl = _baseUrl.text.trim();
    final key = _effectiveKey;
    final model = _model.text.trim();
    if (baseUrl.isEmpty || model.isEmpty) {
      setState(() => _error = '测试连接需要接口地址与模型名');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await testAgentConnection(
        ref,
        AgentChatConfig(baseUrl: baseUrl, apiKey: key, model: model),
      );
      if (!mounted) return;
      final usage = result.hasUsage
          ? '，用量 ${result.totalTokens} tokens'
          : '';
      setState(() {
        _busy = false;
        _notice = '连接成功：${result.model}$usage';
      });
    } on AgentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '连接失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
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
              hintText: '点「拉取模型」从厂商返回的列表里选',
            ),
          ),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'API Key',
              helperText: widget.existing?.hasKey == true
                  ? '留空则保留原密钥'
                  : '仅保存在本机（旧版同一套掩码）',
            ),
          ),
          if (_models.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final model in _models)
                  TonalChip(
                    label: model,
                    color: model == _model.text.trim()
                        ? colorScheme.primaryContainer
                        : context.raisedSurfaceLevel.colorOf(colorScheme),
                    foregroundColor: model == _model.text.trim()
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    onPressed: () => setState(() => _model.text = model),
                  ),
              ],
            ),
          Row(
            spacing: 8,
            children: [
              TonalButton(
                label: _busy ? '请求中…' : '拉取模型',
                glyph: AppGlyphs.cloudDownload,
                size: TonalButtonSize.section,
                onPressed: _busy ? null : _fetchModels,
              ),
              TonalButton(
                label: '测试连接',
                glyph: AppGlyphs.checkCircle,
                size: TonalButtonSize.section,
                onPressed: _busy ? null : _testConnection,
              ),
            ],
          ),
          if (_notice != null)
            Text(
              _notice!,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.success),
            ),
          if (_error != null)
            Text(
              _error!,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.error),
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