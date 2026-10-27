/// Disclaimer page, read-only; `initial_agreement_accepted` was accepted at first run.
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/pages/system/disclaimer_content.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

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
