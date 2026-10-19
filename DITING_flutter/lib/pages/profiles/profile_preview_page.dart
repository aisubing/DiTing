import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 运行配置预览页（上游 `views/profiles/preview.dart` → `EditorPage` 只读模式）。
///
/// 上游是一个代码编辑器，这里只做只读预览：等宽字体 + 行号槽 + 横向滚动。
/// 行号槽不跟着横向滚动，所以它固定在左侧；正文折行关闭（`softWrap: false`），
/// 因为 YAML 的缩进就是语义，把一行折成两行会让层级看起来错乱。
class ProfilePreviewPage extends ConsumerWidget {
  const ProfilePreviewPage({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      profilesProvider.select(
        (state) =>
            state.profiles.where((item) => item.id == profileId).firstOrNull,
      ),
    );
    final lines = mockProfileYaml.split('\n');
    return CommonScaffold(
      title: profile?.name ?? '运行配置',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.copy,
          tooltip: '复制全部',
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: mockProfileYaml));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('已复制到剪贴板'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(milliseconds: 1600),
              ),
            );
          },
        ),
      ],
      body: Column(
        children: [
          _PreviewHeader(profile: profile, lineCount: lines.length),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 12,
                  bottom: NavigationDock.insetOf(context) + 12,
                ),
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LineNumberGutter(lineCount: lines.length),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        child: _YamlBody(lines: lines),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 页首摘要：这份配置有多少节点、多少规则、什么时候更新的。
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.profile, required this.lineCount});

  final MockProfile? profile;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        spacing: 8,
        children: [
          GlyphIcon(AppGlyphs.code, size: 18, color: colorScheme.primary),
          Expanded(
            child: Text(
              profile == null
                  ? '只读预览'
                  : '${profile!.kind.label} · ${profile!.updatedAt}',
              style: context.listCaptionStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MetaChip(label: '$lineCount 行'),
          const MetaChip(label: '只读'),
        ],
      ),
    );
  }
}

/// 行号槽：等宽、右对齐，与正文行高严格一致（同一条 `height`）。
class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = AppTextStyle.caption1
        .of(context)
        .copyWith(
          fontFamily: 'JetBrainsMono',
          height: _lineHeight / AppTextStyle.caption1.size,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        );
    return Container(
      width: 44,
      padding: const EdgeInsets.only(right: 8),
      alignment: Alignment.topRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 1; i <= lineCount; i++)
            SizedBox(
              height: _lineHeight,
              child: Text('$i', style: style, textAlign: TextAlign.right),
            ),
        ],
      ),
    );
  }
}

/// YAML 正文：按行渲染，键 / 顶层段 / 字符串 / 数字各用一种颜色。
///
/// 不做真正的词法分析，只按 `:` 与缩进分层：演示要的是「一眼看出高亮有层次」，
/// 而一个能解析任意 YAML 的高亮器既跑不动（几千行时逐字符扫描）也不需要。
class _YamlBody extends StatelessWidget {
  const _YamlBody({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          _YamlLine(line: line, colorScheme: colorScheme),
      ],
    );
  }
}

/// 一行 YAML。缩进保留原始空格（用等宽字体，空格宽度就是层级）。
class _YamlLine extends StatelessWidget {
  const _YamlLine({required this.line, required this.colorScheme});

  final String line;
  final ColorScheme colorScheme;

  static const _base = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 12,
    height: 19 / 12,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;
    return SizedBox(
      height: _lineHeight,
      child: Row(
        children: [
          if (indent > 0) SizedBox(width: indent * 6.6),
          Text.rich(TextSpan(style: _base, children: _spans(trimmed))),
        ],
      ),
    );
  }

  /// 把一行拆成若干着色片段。
  List<TextSpan> _spans(String text) {
    if (text.isEmpty) {
      return const [TextSpan(text: ' ')];
    }
    if (text.startsWith('#')) {
      return [
        TextSpan(
          text: text,
          style: _base.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ];
    }
    final colon = text.indexOf(':');
    if (colon > 0) {
      final key = text.substring(0, colon);
      final rest = text.substring(colon + 1);
      final isSection = !key.startsWith('-') && rest.trim().isEmpty;
      final keyColor = switch (isSection) {
        true => colorScheme.primary,
        false => colorScheme.onSurface,
      };
      return [
        TextSpan(
          text: key,
          style: _base.copyWith(
            color: keyColor,
            fontWeight: isSection ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        TextSpan(
          text: ':',
          style: _base.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        ..._valueSpans(rest),
      ];
    }
    if (text.startsWith('- ')) {
      return [
        TextSpan(
          text: '- ',
          style: _base.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        ..._valueSpans(text.substring(2)),
      ];
    }
    return _valueSpans(text);
  }

  List<TextSpan> _valueSpans(String value) {
    final trimmed = value.trimLeft();
    final leading = value.substring(0, value.length - trimmed.length);
    final isNumber = double.tryParse(trimmed) != null;
    final isQuoted =
        (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"));
    final color = isNumber
        ? colorScheme.tertiary
        : isQuoted
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;
    return [
      TextSpan(text: leading, style: _base),
      TextSpan(
        text: trimmed,
        style: _base.copyWith(color: color),
      ),
    ];
  }
}

/// 正文行高：行号槽与正文必须用同一个值，否则滚到几百行时两栏会错位。
const _lineHeight = 19.0;
