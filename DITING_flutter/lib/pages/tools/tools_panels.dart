part of 'tools_page.dart';

/// 面板共用的输入行外框。
///
/// `FilledInputTheme` 而不是裸 `TextField`：设计系统里独立出现的输入框统一是填充
/// 圆角，裸框会退回 Material 默认的描边样式，和卡片叠在一起很突兀。
class _ToolField extends StatelessWidget {
  const _ToolField({
    required this.controller,
    required this.hintText,
    required this.glyph,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final Glyph glyph;
  final ValueChanged<String>? onSubmitted;

  /// 需要在输入过程中就同步到 provider 的字段（例如测速域名要落盘）用这个；
  /// 只在提交时读一次的字段可以省掉。
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledInputTheme(
      child: TextField(
        controller: controller,
        enabled: enabled,
        autocorrect: false,
        textInputAction: TextInputAction.go,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: GlyphIcon(glyph),
        ),
      ),
    );
  }
}

/// 面板共用的「走隧道」开关行。
///
/// 三个工具各有一个独立开关，落盘在 `network_tools_settings`（键名照抄旧版
/// `NetworkToolsSettingsStore`）。默认关 = 走物理网络。
class _ViaTunnelRow extends ConsumerWidget {
  const _ViaTunnelRow({
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
  });

  final String storageKey;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListItem.toggle(
      leading: const GlyphIcon(AppGlyphs.link, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled
          ? (next) => setNetworkToolFlag(ref, storageKey, next)
          : null,
    );
  }
}

/// 面板共用的提示条：失败态、fallback 说明、输入错误都走它。
class _ToolNotice extends StatelessWidget {
  const _ToolNotice({
    required this.text,
    this.isError = false,
    this.glyph = AppGlyphs.info,
  });

  final String text;
  final bool isError;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = isError ? colorScheme.error : colorScheme.warning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(12),
        isError: isError,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            GlyphIcon(glyph, size: 18, color: color),
            Expanded(
              child: Text(
                text,
                style: context.listCaptionStyle.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 面板共用的「结果卡片 + 组脚」。
class _ToolSection extends StatelessWidget {
  const _ToolSection({required this.rows, this.footer});

  final List<KeyValueRow> rows;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: CommonCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        if (footer case final footer?) ListFooter(text: footer),
      ],
    );
  }
}

/// 面板共用的执行按钮行：忙碌态由 [running] 决定，禁用而不是隐藏。
class _RunButton extends StatelessWidget {
  const _RunButton({
    required this.glyph,
    required this.label,
    required this.runningLabel,
    required this.running,
    required this.onPressed,
  });

  final Glyph glyph;
  final String label;
  final String runningLabel;
  final bool running;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TonalButton(
        glyph: glyph,
        label: running ? runningLabel : label,
        onPressed: running ? null : onPressed,
      ),
    );
  }
}

/// 面板共用的结果格式化：`1.2 ms` / `—`。
String _msText(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)} ms';
