// ignore_for_file: sort_child_properties_last
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// AI parameters and prompt (upstream `AgentApiParamsScreen`), persisted to
/// `agent_api_system_prompt` and `agent_api_temperature`.
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
                  state.systemPrompt.isEmpty
                      ? '未设置（将使用各分析场景的内置提示词）'
                      : state.systemPrompt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _editPrompt(context, notifier, state.systemPrompt),
              ),
            ],
            footer: '留空时域名分析与流量分析各用自己那份内置提示词；填写后两者都以此为准。',
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
                    onPressed: () => notifier.setSystemPrompt(entry.value),
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
            footer: '安全研判建议 0.2–0.4：温度越低，结论越稳定、越少自由发挥。',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: state.temperature.clamp(0, 2),
              min: 0,
              max: 2,
              divisions: 20,
              onChanged: notifier.setTemperature,
            ),
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
    final value = await showFloatingDialog<String>(
      context: context,
      child: _PromptFieldDialog(initial: initial),
    );
    if (value != null) notifier.setSystemPrompt(value);
  }
}

/// The controller must be owned by the dialog: disposing it right after `await` fires on
/// `pop` while the exit animation runs, and the `TextField` then trips
/// `'_dependents.isEmpty': is not true`.
class _PromptFieldDialog extends StatefulWidget {
  const _PromptFieldDialog({required this.initial});

  final String initial;

  @override
  State<_PromptFieldDialog> createState() => _PromptFieldDialogState();
}

class _PromptFieldDialogState extends State<_PromptFieldDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '系统提示词',
      hasFields: true,
      child: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
