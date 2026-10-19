/// 免责声明（上游 `views/disclaimer.dart`，516 行）。
///
/// 上游 516 行里大半是条款文本本身。本文件把条款搬进数据层
/// （`mock_system.dart` 的 `mockDisclaimerTerms`），页面只负责排版与同意流程，
/// 这样才守得住 550 行上限，也让条款可以独立维护。
///
/// 同意流程有两种强度：页内勾选（轻）与逐字复述（重）。复述对话框在
/// `disclaimer_restate.dart`。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'disclaimer_restate.dart';

/// 免责声明页。
///
/// [requireConsent] 为真时页脚常驻一条同意栏；为假时只做展示（从设置页进入
/// 的情形）——同一个页面两种用法，避免再写一份只读副本。
class DisclaimerPage extends ConsumerWidget {
  const DisclaimerPage({super.key, this.requireConsent = true});

  final bool requireConsent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted = ref.watch(disclaimerAcceptedProvider);
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '免责声明',
      body: Column(
        children: [
          Expanded(
            child: PageBody(
              dockSpacer: false,
              children: [
                const _DisclaimerIntro(),
                const SizedBox(height: 8),
                for (final term in mockDisclaimerTerms)
                  _DisclaimerTerm(term: term),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(
                        AppGlyphs.gavel,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Text(
                          '本页文本为演示内容，与正式发布版本的条款可能不同；'
                          '正式条款以仓库 NOTICE.md 与随包 LICENSE 为准。',
                          style: context.listCaptionStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (requireConsent)
            _ConsentBar(
              accepted: accepted,
              onAccept: () => _accept(context, ref),
              onDecline: () => _decline(context),
            ),
        ],
      ),
    );
  }

  /// 接受前必须复述一句声明：让「同意」这个动作有成本，而不是随手一点。
  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final confirmed = await showRestateDialog(
      context: context,
      statement: disclaimerRestateStatement,
      title: '确认已知悉',
      description: '请逐字输入下面这句话，以确认你已阅读并理解上述条款。',
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    ref.read(disclaimerAcceptedProvider.notifier).agree();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已记录同意状态'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _decline(BuildContext context) async {
    final leave = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '不同意条款',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
        child: const Text('不同意条款将无法继续使用本软件。'
            '若你只是想再读一遍条款，选「返回」即可。'),
      ),
    );
    if (leave == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// 页首介绍块。
class _DisclaimerIntro extends StatelessWidget {
  const _DisclaimerIntro();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              spacing: 10,
              children: [
                GlyphIcon(
                  AppGlyphs.gavel,
                  size: 26,
                  color: colorScheme.primary,
                ),
                Text(
                  '使用前请阅读',
                  style: AppTextStyle.title2.of(context, emphasized: true),
                ),
              ],
            ),
            Text(
              '谛听是一款开源的本地域名解析与流量观测工具。'
              '软件本身不提供、不代理、也不转发任何网络接入服务，'
              '全部数据都在本机处理。',
              style: context.listSubtitleStyle,
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
                    size: 18,
                    color: colorScheme.onWarningContainer,
                  ),
                  Expanded(
                    child: Text(
                      '请在遵守所在地法律法规的前提下使用本软件。'
                      '将本软件用于任何未经授权的网络环境，后果由使用者自行承担。',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onWarningContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一段条款：标题 + 正文。
class _DisclaimerTerm extends StatelessWidget {
  const _DisclaimerTerm({required this.term});

  final MockDisclaimerTerm term;

  @override
  Widget build(BuildContext context) {
    return SectionBlock(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              term.title,
              style: AppTextStyle.subheadline.of(context, emphasized: true),
            ),
            Text(
              term.content,
              style: AppTextStyle.footnote.of(context).copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 页脚同意栏。
class _ConsentBar extends StatelessWidget {
  const _ConsentBar({
    required this.accepted,
    required this.onAccept,
    required this.onDecline,
  });

  final bool accepted;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: ShapeDecoration(
        color: SurfaceLevel.card.colorOf(colorScheme),
        shape: AppShape.top(AppCorner.xl),
        shadows: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        spacing: 10,
        children: [
          if (accepted)
            Row(
              spacing: 6,
              children: [
                GlyphIcon(AppGlyphs.checkCircle, color: colorScheme.success),
                Text('已同意', style: context.listTitleStyle),
              ],
            )
          else ...[
            Expanded(
              child: TonalButton(
                label: '不同意',
                size: TonalButtonSize.section,
                onPressed: onDecline,
              ),
            ),
            Expanded(
              flex: 2,
              child: TonalButton(
                label: '阅读并同意',
                glyph: AppGlyphs.check,
                size: TonalButtonSize.section,
                onPressed: onAccept,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
