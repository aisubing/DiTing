import 'package:diting/data/mock_data.dart';
import 'package:diting/state/rules_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 批量导入页：一整块文本框 + 实时解析统计 + 一个提交按钮。
///
/// 为什么不做「选择文件」：演示项目没有文件系统权限，而真实使用中九成场景
/// 是从别处复制一段规则粘进来。把文本框做主角，用户一眼就知道该往里贴什么。
class BatchEditorPage extends ConsumerStatefulWidget {
  const BatchEditorPage({super.key});

  @override
  ConsumerState<BatchEditorPage> createState() => _BatchEditorPageState();
}

class _BatchEditorPageState extends ConsumerState<BatchEditorPage> {
  final _controller = TextEditingController();

  /// 目标表。默认黑名单——批量导入的绝大多数用途是加拦截规则。
  var _kind = RuleKind.block;

  @override
  void initState() {
    super.initState();
    // 解析统计随输入实时变化，所以监听 controller 而不是走 onChanged：
    // 粘贴、撤销、清空按钮都绕过 onChanged，但都会触发 controller 通知。
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  RuleLineParseResult get _parsed => parseRuleLines(
    _controller.text,
    existing: {
      for (final rule in ref.read(rulesOfKindProvider(_kind))) rule.pattern,
    },
  );

  Future<void> _submit() async {
    final parsed = _parsed;
    if (parsed.accepted.isEmpty) {
      return;
    }
    final count = ref
        .read(rulesProvider.notifier)
        .importRules(_kind, parsed.accepted);
    _controller.clear();
    if (!mounted) {
      return;
    }
    await showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '导入完成',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(UiLocalizations.of(context).submit),
          ),
        ],
        child: Text(_reportText(count: count, parsed: parsed)),
      ),
    );
    if (!mounted) {
      return;
    }
    // 导入完就回列表：用户来这里只为贴一段规则，留着空文本框没有意义。
    context.pop();
  }

  String _reportText({required int count, required RuleLineParseResult parsed}) {
    final lines = <String>['已向${_kind.title}导入 $count 条规则。'];
    if (parsed.duplicated.isNotEmpty) {
      lines.add('跳过 ${parsed.duplicated.length} 条重复规则。');
    }
    if (parsed.rejected.isNotEmpty) {
      lines.add(
        '${parsed.rejected.length} 条放行规则（含 #@#）未导入：'
        '该规则为放行规则，请在白名单中添加。',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final colorScheme = context.colorScheme;
    final canSubmit = parsed.accepted.isNotEmpty;

    return CommonScaffold(
      title: '批量添加规则',
      resizeToAvoidBottomInset: true,
      // 顶栏浮在正文之上（`extendBodyBehindAppBar`），正文自己让出「状态栏 +
      // 工具栏」的高度，否则「导入到」组头会画到状态栏底下。
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + context.appBarInset, 16, 16),
        children: [
          // 目标表放在文本框之上：先决定「导去哪」，再贴内容，顺序与用户
          // 的思考顺序一致；放下面会出现贴完才想起来选错表的情况。
          //
          // `padding: EdgeInsets.zero`：这一页的 `ListView` 已经自带 16 横向
          // 内边距，`generateSection` 默认再加一次会让卡片缩进 32。
          generateSection(
            padding: EdgeInsets.zero,
            title: '导入到',
            items: [
              ListItem<RuleKind>.options(
                title: const Text('目标规则表'),
                subtitle: const Text('导入的规则将写入所选规则表'),
                options: RuleKind.values,
                value: _kind,
                textBuilder: (kind) => kind.title,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 文本框高度固定 360：既能让用户看见一屏内容，又不至于把按钮顶出
          // 屏幕。maxLines 撑满配合 scrollController 让长文本内部滚动。
          //
          // `borderRadius` 必须显式给：`FilledInputTheme` 的默认值是
          // `AppRadius.full`（1000），那是为「单行胶囊高度」设计的——框一高，
          // 圆角就按短边收敛成真圆，360 高的文本框在真机上画成一个巨大的圆，
          // 提示文字挤在上缘、下面整片是空壳。多行块一律用卡片级圆角。
          SizedBox(
            height: 360,
            child: FilledInputTheme(
              borderRadius: AppRadius.lg,
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText:
                      '每行一条规则，例如：\n||ads.example.com^\n'
                      '||tracker.example.net^\n\n'
                      '空行会被忽略，重复规则自动跳过。',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 解析计数紧跟文本框：它是对「刚贴进来的这段内容」的解释，
          // 离得越远越像一份与当前输入无关的统计。
          CommonCard(
            child: StatStrip(
              stats: [
                StatItem(
                  label: '可导入',
                  value: '${parsed.accepted.length}',
                  color: colorScheme.success,
                ),
                StatItem(
                  label: '重复',
                  value: '${parsed.duplicated.length}',
                  color: colorScheme.warning,
                ),
                StatItem(
                  label: '无效',
                  value: '${parsed.rejected.length}',
                  color: parsed.rejected.isEmpty
                      ? null
                      : colorScheme.destructive,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 提交按钮放在正文末尾而不是顶栏：条数（「导入 N 条」）是用户按下
          // 前最后一个确认点，顶栏只放得下一个图标，说不清要导入多少条。
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: Text('导入 ${parsed.accepted.length} 条'),
            ),
          ),
          if (parsed.rejected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CommonCard(
                isError: true,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          GlyphIcon(
                            AppGlyphs.warning,
                            size: 16,
                            color: colorScheme.error,
                          ),
                          Text('以下规则未通过校验', style: context.listTitleStyle),
                        ],
                      ),
                      for (final line in parsed.rejected.take(5))
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.listCaptionStyle.copyWith(
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      Text(
                        '该规则为放行规则，请在白名单中添加',
                        style: context.listCaptionStyle.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (parsed.duplicated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CommonCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('已存在，将跳过', style: context.listTitleStyle),
                      for (final line in parsed.duplicated.take(3))
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.listCaptionStyle.copyWith(
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      if (parsed.duplicated.length > 3)
                        Text(
                          '等 ${parsed.duplicated.length} 条',
                          style: context.listCaptionStyle,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}
