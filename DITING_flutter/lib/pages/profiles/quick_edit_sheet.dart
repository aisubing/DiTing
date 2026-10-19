import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 快速编辑的对象。
enum QuickEditKind {
  rules('规则', '每行一条：类型,内容,目标'),
  proxies('节点', '每行一条：名称,类型,地址,端口');

  const QuickEditKind(this.label, this.hint);

  final String label;
  final String hint;
}

/// 打开快速编辑面板（上游 `views/profiles/custom/quick_edit.dart`）。
///
/// 上游是一个代码编辑器 + `EditorSchema`；演示版用等宽多行输入框 + 两个按钮
/// （格式化 / 应用）。区别在于应用前会把文本解析回结构体，解析失败就在输入框
/// 下方报错而不关面板——上游同样把 `FormatException` 翻成一句人话。
Future<void> showQuickEditSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String profileId,
  required String title,
  required QuickEditKind kind,
}) {
  return showFormSheet<void>(
    context: context,
    builder: (_) =>
        _QuickEditSheet(profileId: profileId, title: title, kind: kind),
  );
}

class _QuickEditSheet extends ConsumerStatefulWidget {
  const _QuickEditSheet({
    required this.profileId,
    required this.title,
    required this.kind,
  });

  final String profileId;
  final String title;
  final QuickEditKind kind;

  @override
  ConsumerState<_QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends ConsumerState<_QuickEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: _initialText(),
  );
  String? _error;

  String _initialText() => switch (widget.kind) {
    QuickEditKind.rules => [
      for (final rule in ref.read(customRulesProvider)) rule.text,
    ].join('\n'),
    QuickEditKind.proxies => [
      for (final proxy in ref.read(customProxiesProvider))
        '${proxy.name},${proxy.protocol.value},${proxy.server},${proxy.port}',
    ].join('\n'),
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 格式化：去掉空行与首尾空格。不重排内容——用户手写的顺序可能是有意的。
  void _format() {
    final lines = _controller.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    _controller.text = lines;
    setState(() => _error = null);
  }

  void _apply() {
    final lines = _controller.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      setState(() => _error = '至少保留一行内容');
      return;
    }
    switch (widget.kind) {
      case QuickEditKind.rules:
        _applyRules(lines);
      case QuickEditKind.proxies:
        _applyProxies(lines);
    }
  }

  void _applyRules(List<String> lines) {
    final targets = {
      for (final group in ref.read(proxyGroupsProvider)) group.name,
      for (final target in MockRuleTarget.values) target.value,
    };
    final parsed = <MockCustomRule>[];
    for (final (index, line) in lines.indexed) {
      final parts = line.split(',');
      if (parts.length < 3) {
        setState(() => _error = '第 ${index + 1} 行：需要三段「类型,内容,目标」');
        return;
      }
      final type = _ruleTypeOf(parts.first);
      if (type == null) {
        setState(() => _error = '第 ${index + 1} 行：未知的规则类型「${parts.first}」');
        return;
      }
      final target = parts[2].trim();
      if (!targets.contains(target)) {
        setState(() => _error = '第 ${index + 1} 行：目标「$target」不在任何组或内置策略里');
        return;
      }
      final flags = parts.skip(3).map((flag) => flag.trim()).toSet();
      parsed.add(
        MockCustomRule(
          id: 'r-quick-$index',
          type: type,
          content: parts[1].trim(),
          target: target,
          noResolve: flags.contains('no-resolve'),
          src: flags.contains('src'),
          disabled: flags.contains('disabled'),
        ),
      );
    }
    ref.read(customRulesProvider.notifier).replaceAll(parsed);
    Navigator.of(context).pop();
  }

  void _applyProxies(List<String> lines) {
    final parsed = <MockProxy>[];
    for (final (index, line) in lines.indexed) {
      final parts = line.split(',');
      if (parts.length < 4) {
        setState(() => _error = '第 ${index + 1} 行：需要四段「名称,类型,地址,端口」');
        return;
      }
      final protocol = _protocolOf(parts[1]);
      if (protocol == null) {
        setState(() => _error = '第 ${index + 1} 行：未知的协议「${parts[1]}」');
        return;
      }
      final port = int.tryParse(parts[3].trim());
      if (port == null || port <= 0 || port > 65535) {
        setState(() => _error = '第 ${index + 1} 行：端口「${parts[3]}」无效');
        return;
      }
      parsed.add(
        MockProxy(
          id: 'n-quick-$index',
          name: parts[0].trim(),
          protocol: protocol,
          server: parts[2].trim(),
          port: port,
          latencyMs: 0,
        ),
      );
    }
    ref.read(customProxiesProvider.notifier).replaceAll(parsed);
    Navigator.of(context).pop();
  }

  CustomRuleType? _ruleTypeOf(String value) {
    for (final type in CustomRuleType.values) {
      if (type.value.toLowerCase() == value.trim().toLowerCase()) {
        return type;
      }
    }
    return null;
  }

  ProxyProtocol? _protocolOf(String value) {
    for (final protocol in ProxyProtocol.values) {
      if (protocol.value.toLowerCase() == value.trim().toLowerCase() ||
          protocol.label.toLowerCase() == value.trim().toLowerCase()) {
        return protocol;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: widget.title,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '应用',
        onPressed: _apply,
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.wrap,
          tooltip: '格式化',
          onPressed: _format,
        ),
      ],
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text(
            '${widget.kind.label} · ${widget.kind.hint}',
            style: context.listCaptionStyle,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(fontFamily: 'JetBrainsMono', height: 1.6),
              decoration: InputDecoration(
                hintText: widget.kind.hint,
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Row(
              spacing: 6,
              children: [
                GlyphIcon(AppGlyphs.error, size: 16, color: colorScheme.error),
                Expanded(
                  child: Text(
                    error,
                    style: context.listCaptionStyle.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '应用会整体替换当前${widget.kind.label}列表。这里的校验只保证格式与引用'
            '存在，不校验内核语义。',
            style: context.listCaptionStyle,
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}
