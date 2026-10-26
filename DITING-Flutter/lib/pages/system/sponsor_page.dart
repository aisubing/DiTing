/// Sponsor page, aligned with `ui/SponsorScreen.kt`; QR codes come from the README.
library;

import 'package:diting/pages/system/app_info.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class SponsorPage extends StatelessWidget {
  const SponsorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '赞助',
      body: PageBody(
        children: [
          const _SponsorHero(),
          const _PaymentSection(),
          generateSection(
            title: '在 GitHub 查看赞助方式',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.link),
                title: const Text('查看 README 中的赞助说明'),
                subtitle: Text(
                  sponsorReadmeUrl.replaceFirst('https://', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const GlyphIcon(AppGlyphs.openExternal, size: 20),
                onTap: () => openLinkOrCopy(
                  context,
                  sponsorReadmeUrl,
                  '未能打开浏览器，README 地址已复制',
                ),
              ),
            ],
          ),
          generateSection(
            title: '致谢名单',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.verified),
                title: const Text('赞助者名单'),
                subtitle: const Text('感谢每一位支持项目的朋友'),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(HubPaths.sponsorList),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.account),
                title: const Text('共建者名单'),
                subtitle: const Text('感谢提出建议与帮助测试的伙伴'),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => context.push(HubPaths.coBuilders),
              ),
            ],
          ),
          generateSection(
            title: '你的每一笔支持都会用于',
            items: const [
              _BulletRow(text: '持续开发新功能'),
              _BulletRow(text: '修复 Bug'),
              _BulletRow(text: '购买词元'),
            ],
          ),
          generateSection(
            title: '即使不捐赠，也欢迎',
            items: const [
              _BulletRow(text: '点一个 Star⭐'),
              _BulletRow(text: '提交 Issue'),
              _BulletRow(text: '提交 PR'),
              _BulletRow(text: '分享给更多人'),
            ],
          ),
          const ListFooter(text: '感谢每一位支持项目的朋友！'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Header card: icon, title, description and tags. A card rather than bare text keeps the
/// header consistent with the app info page.
class _SponsorHero extends StatelessWidget {
  const _SponsorHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: AppShape.md,
                    color: colorScheme.primaryContainer,
                  ),
                  child: GlyphIcon(
                    AppGlyphs.star,
                    size: 28,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        '// SUPPORT THE PROJECT',
                        style: AppTextStyle.caption2.of(context).copyWith(
                          color: colorScheme.primary,
                          fontFamily: appMonospaceFontFamily,
                        ),
                      ),
                      Text(
                        '请作者喝杯蜜雪 🧋',
                        style: AppTextStyle.title2.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '如果这个项目帮助到了你，欢迎请作者喝杯蜜雪。'
              '付款时请备注昵称，以便同步加入赞助者名单。',
              style: context.listSubtitleStyle,
            ),
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                MetaChip(label: '支付宝'),
                MetaChip(label: '微信支付'),
                MetaChip(label: '备注昵称'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListHeader(title: '扫码赞助'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 12,
            children: const [
              Expanded(
                child: _PaymentCard(
                  asset: 'assets/pay/alipay_code.png',
                  label: '支付宝',
                  glyph: AppGlyphs.qrCode,
                ),
              ),
              Expanded(
                child: _PaymentCard(
                  asset: 'assets/pay/wechatpay_code.png',
                  label: '微信支付',
                  glyph: AppGlyphs.qrCode,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One QR code card: white background, since a code needs a light surround to scan, plus its name.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.asset,
    required this.label,
    required this.glyph,
  });

  final String asset;
  final String label;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      padding: EdgeInsets.zero,
      onPressed: () => _showFullscreen(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          spacing: 8,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // A code needs a static light background and must not follow dark theme
                // inversion, or it cannot be scanned.
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: GlyphIcon(AppGlyphs.qrCode, size: 32),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                GlyphIcon(glyph, size: 16, color: context.colorScheme.primary),
                Text(label, style: context.listSubtitleStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context) {
    showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '$label 收款码',
        width: 320,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
        child: Column(
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.white,
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            ),
            Text(
              '付款时请备注昵称，以便同步加入赞助者名单。',
              style: context.listCaptionStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A bulleted list row matching the legacy `SponsorList`.
class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: Text(
        '•',
        style: AppTextStyle.body
            .of(context)
            .copyWith(color: context.colorScheme.primary),
      ),
      title: Text(text),
    );
  }
}