/// 赞助页（对齐旧版 `ui/SponsorScreen.kt`）。
///
/// 旧版是三段直白文案 + 一组外链行 + 页尾致谢，没有任何支付入口：
/// 赞助页本身只讲「做什么、怎么帮、不捐也行」。上一轮这份页面被扩成
/// 「赞助档位 / 共建方式 / 致谢名单」三组，还写了 ¥ 30/月、¥ 300/月的档位——
/// 旧版没有这些，属于凭空发明的商业化承诺，本轮全部删掉，回到旧版的三段结构。
///
/// 旧版两处外链都是 `ACTION_VIEW` 开浏览器；本仓不引 `url_launcher`，
/// 统一改为复制地址 + SnackBar 提示。
library;

import 'package:diting/pages/system/app_info.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
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
          const SizedBox(height: 4),
          generateSection(
            title: '在 GitHub 查看赞助方式',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.link),
                title: const Text('在 GitHub 查看 README 中的赞助方式'),
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

/// 页首两句：标题与说明（旧版 `headlineSmall` + `bodyLarge`）。
class _SponsorHero extends StatelessWidget {
  const _SponsorHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            '请作者喝杯蜜雪 🧋',
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          Text('如果这个项目帮助到了你，欢迎请作者喝杯蜜雪。', style: context.listSubtitleStyle),
        ],
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
