/// 赞助页（对齐旧版 `ui/SponsorScreen.kt`，并补上真实的收款码）。
///
/// 旧版只讲「做什么、怎么帮、不捐也行」，没有任何支付入口，只给一个
/// GitHub README 外链——用户在 App 内根本看不到收款码，得跳浏览器再翻 README。
/// 本轮把 README 里那两张真实收款码（`docs/assets/alipay_code.png` /
/// `wechatpay_code.png`）直接放进页面，点开可放大到全屏对话框，长按/扫码都够清楚。
///
/// 不写任何档位与金额：旧版没有商业承诺，上一轮虚构的「¥30/月」档位已删除，
/// 这里只保留「每一份支持都同样珍贵」的说法。
///
/// 旧版外链是 `ACTION_VIEW` 开浏览器；本仓不引 `url_launcher`，统一改为
/// 复制地址 + SnackBar 提示。
library;

import 'package:diting/pages/system/app_info.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 赞助页。
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
                onTap: () => copyToClipboard(
                  context,
                  sponsorReadmeUrl,
                  'README 地址已复制，可在浏览器中打开',
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

/// 页首卡片：图标 + 标题 + 说明 + 标签。
///
/// 用卡片而不是裸文字，是为了和「应用信息」等页面的页首保持一致——上一版这里是
/// 三段左对齐文字直接压在背景上，与全站「卡片承载信息块」的视觉规则不符。
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
                          fontFamily: 'JetBrainsMono',
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

/// 两张收款码并排，点击放大大图。
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

/// 一张收款码卡片：白底（二维码必须有浅色底才扫得出来）+ 名称。
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
                // 二维码需要静止的浅色底，不跟随深色主题反色，否则扫不出来。
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

/// 一条带圆点的列表项：旧版 `SponsorList` 的「•」+ 文本。
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
