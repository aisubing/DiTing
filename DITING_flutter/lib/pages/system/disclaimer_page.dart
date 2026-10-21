/// 免责声明页（只读回看）。
///
/// 1.4.3 没有独立的免责声明页：免责文本出现在两处——首次启动的
/// `使用须知与免责声明` 弹窗（`ui/MainActivityDialogs.kt`）与域名规则引导的
/// 第二步（`ui/SettingsGuide.kt` 的「免责条款与合规声明」）。上一轮 Flutter 版
/// 把它做成 `/disclaimer` 独立路由 + 页内「逐字复述」同意流程，两样都不是旧版的
/// 东西：路由已随「旧版为准」清理删除，复述流程也与首启弹窗重复。
///
/// 现在这一页只做**回看**：首启时用户在应用层的弹窗里已经同意过
/// （`lib/app/initial_agreement.dart` 写 `initial_agreement_accepted`），
/// 这里从关于页进入，不再要求任何二次确认。正文与弹窗共用
/// `disclaimer_content.dart`，避免用户同意过的版本与之后读到的版本分叉。
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/pages/system/disclaimer_content.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 免责声明页。
class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '免责声明',
      body: PageBody(
        children: [
          const DisclaimerIntroCard(),
          const SizedBox(height: 12),
          const ListHeader(title: '使用须知与免责声明'),
          const InitialAgreementCard(),
          const SizedBox(height: 12),
          const ListHeader(title: '条款全文'),
          for (final term in mockDisclaimerTerms)
            DisclaimerTermCard(term: term),
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
    );
  }
}
