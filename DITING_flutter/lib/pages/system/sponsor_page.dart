/// 赞助与共建（上游没有独立页，`views/about.dart` 里的链接项）。
///
/// 这一页把上游 about 页底部的三个外链拆成单独页面：赞助档位、共建方式、
/// 致谢名单。演示层不接支付，点档位只会弹说明。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 赞助与共建页。
class SponsorPage extends StatelessWidget {
  const SponsorPage({super.key});

  void _notify(BuildContext context, String what) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$what：演示环境不接支付与外链'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '赞助与共建',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      GlyphIcon(
                        AppGlyphs.star,
                        size: 26,
                        color: colorScheme.primary,
                      ),
                      Text(
                        '让谛听继续被听见',
                        style: AppTextStyle.title2.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '谛听没有订阅、没有广告、也没有遥测。'
                    '所有代码公开在仓库里，维护者的时间来自赞助与共建。',
                    style: context.listSubtitleStyle,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const [
                      MetaChip(label: '无广告'),
                      MetaChip(label: '无遥测'),
                      MetaChip(label: 'GPL-3.0+'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '赞助档位',
            items: [
              for (final tier in mockSponsorTiers)
                ListItem(
                  title: Text(tier.title),
                  subtitle: Text(tier.perks.join(' · ')),
                  leading: GlyphIcon(
                    glyphByName(tier.glyphName),
                    color: colorScheme.primary,
                  ),
                  trailing: TonalButton(
                    label: tier.amount,
                    size: TonalButtonSize.compact,
                    onPressed: () => _notify(context, tier.title),
                  ),
                  onTap: () => _notify(context, tier.title),
                ),
            ],
            footer: '档位只影响致谢名单与议題优先级，不影响任何功能——'
                '所有功能对所有人开放。',
          ),
          generateSection(
            title: '共建方式',
            items: [
              ListItem(
                title: const Text('提 issue'),
                subtitle: const Text('报告缺陷、提出需求，附上复现步骤最有效'),
                leading: const GlyphIcon(AppGlyphs.info),
                trailing: const GlyphIcon(AppGlyphs.openExternal, size: 20),
                onTap: () => _notify(context, '打开 issue 页'),
              ),
              ListItem(
                title: const Text('翻译'),
                subtitle: const Text('补全界面文案与文档，无需编程经验'),
                leading: const GlyphIcon(AppGlyphs.language),
                trailing: const GlyphIcon(AppGlyphs.openExternal, size: 20),
                onTap: () => _notify(context, '打开翻译协作页'),
              ),
              ListItem(
                title: const Text('提交代码'),
                subtitle: const Text('遵循 AGENTS.md 的规范与 550 行上限'),
                leading: const GlyphIcon(AppGlyphs.code),
                trailing: const GlyphIcon(AppGlyphs.openExternal, size: 20),
                onTap: () => _notify(context, '打开仓库'),
              ),
            ],
          ),
          generateSection(
            title: '致谢',
            items: [
              for (final contributor in mockContributors)
                ListItem(
                  title: Text(contributor),
                  leading: const GlyphIcon(AppGlyphs.account),
                  trailing: TonalChip(
                    label: '致谢',
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            footer: '界面组件层移植自 FlClash 0.9.1（GPL-3.0-or-later），'
                '排版参考了 Apple 的人机界面指南。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
