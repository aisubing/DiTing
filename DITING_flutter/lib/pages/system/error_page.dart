/// 错误页（上游 `pages/error.dart`，344 行）。
///
/// 上游的 `InitErrorScreen` 是启动失败时的兜底屏：错误摘要、可展开的堆栈、
/// 复制按钮、清空数据（危险）与重启。它不是「404 页面」，而是「核心起不来，
/// 你得手动处理」——所以每个按钮都带着后果说明。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 错误页。
class ErrorPage extends StatefulWidget {
  const ErrorPage({super.key});

  @override
  State<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage> {
  var _stackExpanded = false;

  /// 复制整段错误报告：标题 + 全部堆栈，粘贴到 issue 里即可。
  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(
      ClipboardData(
        text: '=== ERROR ===\n'
            '${mockErrorDetail.code}: ${mockErrorDetail.title}\n\n'
            '${mockErrorDetail.description}\n\n'
            '=== STACK ===\n${mockErrorDetail.stack}',
      ),
    );
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('错误报告已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _clearData() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空全部数据',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
        child: const Text('将删除配置、规则、日志与缓存，恢复出厂状态。'
            '该操作不可撤销；若只是想保留配置，请先返回并用「备份与恢复」导出。'),
      ),
    );
    if (confirmed != true) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('已清空（演示：仅重置页面状态）'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _restart() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('正在重启核心…（演示：不会真的重启）'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '出错了',
      menuItems: [
        CommonPopupMenuItem(
          label: '复制错误报告',
          glyph: AppGlyphs.copy,
          onPressed: _copy,
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: colorScheme.errorContainer,
                          shape: AppShape.circle,
                        ),
                        child: GlyphIcon(
                          AppGlyphs.error,
                          size: 26,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              mockErrorDetail.title,
                              style: AppTextStyle.title3.of(
                                context,
                                emphasized: true,
                              ),
                            ),
                            Text(
                              mockErrorDetail.code,
                              style: context.listCaptionStyle.copyWith(
                                fontFamily: 'JetBrainsMono',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    mockErrorDetail.description,
                    style: context.listSubtitleStyle.copyWith(height: 1.6),
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: TonalButton(
                          label: '重启核心',
                          glyph: AppGlyphs.refresh,
                          size: TonalButtonSize.section,
                          onPressed: _restart,
                        ),
                      ),
                      Expanded(
                        child: TonalButton(
                          label: '复制报告',
                          glyph: AppGlyphs.copy,
                          size: TonalButtonSize.section,
                          onPressed: _copy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionBlock(
            title: '堆栈',
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _stackExpanded = !_stackExpanded),
                    child: Row(
                      spacing: 8,
                      children: [
                        GlyphIcon(
                          AppGlyphs.code,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Text(
                            _stackExpanded ? '收起堆栈' : '展开完整堆栈',
                            style: context.listTitleStyle,
                          ),
                        ),
                        GlyphIcon(
                          _stackExpanded
                              ? AppGlyphs.chevronUp
                              : AppGlyphs.chevronDown,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  // 用 `AnimatedSwitcher` 而不是 `AnimatedCrossFade`：
                  // 后者内部是靠 `Positioned` 撑开的 `Stack`，在没有高度上界的
                  // 列表里会断言失败（`AnimatedCrossFade` 只适合高度已定的容器）。
                  AnimatedSwitcher(
                    duration: midDuration,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.topStart,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      key: ValueKey(_stackExpanded),
                      _stackExpanded
                          ? mockErrorDetail.stack.trim()
                          : mockErrorDetail.stack
                                .trim()
                                .split('\n')
                                .take(2)
                                .join('\n'),
                      style: AppTextStyle.footnote.of(context).copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '还可以试试',
            items: [
              ListItem(
                title: const Text('查看日志'),
                subtitle: const Text('核心启动过程的完整输出，含端口占用信息'),
                leading: const GlyphIcon(AppGlyphs.logs),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _toast(context, '打开日志页'),
              ),
              ListItem(
                title: const Text('重置内核配置'),
                subtitle: const Text('把内核参数恢复为默认值，不影响规则与订阅'),
                leading: const GlyphIcon(AppGlyphs.reset),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _toast(context, '重置内核配置'),
              ),
            ],
          ),
          generateSection(
            title: '危险操作',
            footer: '清空数据是不可撤销的。若还有机会进入应用，请先导出备份。',
            items: [
              ListItem(
                title: Text(
                  '清空全部数据',
                  style: TextStyle(color: colorScheme.error),
                ),
                subtitle: const Text('删除配置、规则、日志与缓存，恢复出厂状态'),
                leading: GlyphIcon(AppGlyphs.delete, color: colorScheme.error),
                onTap: _clearData,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String what) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('$what（演示）'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
}
