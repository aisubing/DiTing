/// 开发者选项（上游 `views/developer.dart`，118 行）。
///
/// 上游很短：一个总开关 + 五个实验动作。总开关关闭时整块动作区禁用（不是隐藏）
/// ——开发者模式常被误触关闭，隐藏会让人以为功能没了。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 开发者选项页。
class DeveloperPage extends ConsumerWidget {
  const DeveloperPage({super.key});

  Future<void> _run(
    BuildContext context,
    MockDeveloperAction action,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (action.destructive) {
      final confirmed = await showFloatingDialog<bool>(
        context: context,
        child: CommonDialog(
          title: action.title,
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('执行'),
            ),
          ],
          child: Text('${action.subtitle}\n\n该动作会改写演示状态，执行后需要手动恢复。'),
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    messenger?.showSnackBar(
      SnackBar(
        content: Text('${action.title}：已完成（演示）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(developerModeProvider);
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '开发者选项',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      GlyphIcon(
                        AppGlyphs.wrench,
                        size: 22,
                        color: enabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('开发者模式', style: context.listTitleStyle),
                            Text(
                              enabled ? '实验动作已解锁' : '关闭时下面的动作不可用',
                              style: context.listCaptionStyle,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: (value) => ref
                            .read(developerModeProvider.notifier)
                            .toggle(value),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: ShapeDecoration(
                      shape: AppShape.md,
                      color: colorScheme.warningContainer,
                    ),
                    child: Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlyphIcon(
                          AppGlyphs.warning,
                          size: 16,
                          color: colorScheme.onWarningContainer,
                        ),
                        Expanded(
                          child: Text(
                            '这些动作会直接改写内存状态，可能让界面进入不一致的样子；'
                            '它们只用于验证 UI 的异常分支，不要在生产环境打开。',
                            style: AppTextStyle.footnote
                                .of(context)
                                .copyWith(
                                  color: colorScheme.onWarningContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '实验动作',
            items: [
              for (final action in mockDeveloperActions)
                ListItem(
                  title: Text(
                    action.title,
                    style: action.destructive && enabled
                        ? TextStyle(color: colorScheme.error)
                        : null,
                  ),
                  subtitle: Text(action.subtitle),
                  leading: GlyphIcon(
                    glyphByName(action.glyphName),
                    color: enabled
                        ? (action.destructive
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                  onTap: enabled ? () => _run(context, action) : null,
                ),
            ],
            footer: '「崩溃核心」只会弹一个致命错误对话框，不会真的让进程退出；'
                '「清空全部数据」在演示层只重置本页状态。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
