/// 免责声明正文：一处定义，多处引用。
///
/// 旧版 1.4.3 的免责文本出现在两处，但都是「用户真正同意过的法律文本」：
/// 1. 首次启动的 `使用须知与免责声明` 弹窗（`ui/MainActivityDialogs.kt`）；
/// 2. 域名规则引导的第二步「免责条款与合规声明」（`ui/SettingsGuide.kt`）。
///
/// 本仓首启弹窗在应用层（`lib/app/initial_agreement.dart` 的
/// `InitialAgreementDialog`），回看入口在关于页。两边如果各存一份文案，任何一次
/// 措辞修订都只会改一处——用户同意过的版本与之后读到的版本就此分叉。
///
/// 因此这里**不复制文本**：直接引用 `InitialAgreementDialog.message`（那份是
/// 用户实际点过「同意」的字面文本），只负责把它排成可读的卡片。[DisclaimerTermCard]
/// 则渲染十段条款（`mock_system.dart` 的 `mockDisclaimerTerms`）。
library;

import 'package:diting/app/initial_agreement.dart';
import 'package:diting/data/mock_system.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 整页阅读用的页首：定位说明 + 一条醒目提醒。
class DisclaimerIntroCard extends StatelessWidget {
  const DisclaimerIntroCard({super.key});

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

/// 首启须知正文（关于页 / 免责声明页的回看入口用）。
///
/// 文本来自 `InitialAgreementDialog.message`——与首启弹窗共用同一份常量，
/// 页面上不做任何改写或摘录。
class InitialAgreementCard extends StatelessWidget {
  const InitialAgreementCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  AppGlyphs.checkCircle,
                  size: 18,
                  color: colorScheme.success,
                ),
                Expanded(
                  child: Text(
                    '首次启动时确认的文本',
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                const MetaChip(label: '不可修改'),
              ],
            ),
            Text(
              InitialAgreementDialog.message,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一段条款：标题 + 正文。
class DisclaimerTermCard extends StatelessWidget {
  const DisclaimerTermCard({super.key, required this.term});

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
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
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
