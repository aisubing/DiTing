import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 赞助者名单（上游 `SponsorListScreen`）。
class SponsorListPage extends StatefulWidget {
  const SponsorListPage({super.key});

  @override
  State<SponsorListPage> createState() => _SponsorListPageState();
}

class _SponsorListPageState extends State<SponsorListPage> {
  static const _names = [
    'alone',
    '睿上源',
    '理塘丁真',
    '天涯浮客',
    'AceTaffy1883',
    '心疼头头哥',
    '恐龙复生',
    'xo人头马',
    '过江龙傲天',
    '狸',
    'lucasyr',
    '轻',
    '冰糖葫芦 shador',
    '七月柠檬',
    '一葉冰心',
  ];

  bool _newestFirst = false;

  @override
  Widget build(BuildContext context) {
    final names = _newestFirst ? _names.reversed.toList() : _names;
    return CommonScaffold(
      title: '赞助者名单',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新名单',
          onPressed: () => _hint(context, '名单已更新，头像已刷新'),
        ),
        IconButtonData(
          glyph: AppGlyphs.sort,
          tooltip: _newestFirst ? '切换为由早到晚' : '切换为由晚到早',
          onPressed: () => setState(() => _newestFirst = !_newestFirst),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '感谢每一位支持谛听项目的朋友！名单默认按赞助时间由早到晚排列，'
                '可通过右上角按钮切换为由晚到早；与赞助金额无关，每一份支持都同样珍贵。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          generateSection(
            title: '赞助者（${names.length}）',
            items: [
              for (var index = 0; index < names.length; index++)
                _MemberRow(name: names[index], index: index, badge: '赞助者'),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _hint(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

/// 共建者名单（上游 `CoBuilderListScreen`）。
class CoBuildersPage extends StatefulWidget {
  const CoBuildersPage({super.key});

  @override
  State<CoBuildersPage> createState() => _CoBuildersPageState();
}

class _CoBuildersPageState extends State<CoBuildersPage> {
  static const _names = [
    'AceTaffy1883',
    'alone',
    '恐龙复生',
    '乐野',
    '理塘丁真',
    '睿上源',
    '天涯浮客',
    '妄炁',
    'widiOA',
    '心疼头头哥',
    '遇屿',
  ];

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '共建者名单',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新名单',
          onPressed: () => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('名单已更新，头像已刷新'),
              behavior: SnackBarBehavior.floating,
            ),
          ),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '感谢每一位为谛听提出建议、帮助测试的共建者！名单按用户名称的字母顺序排列，'
                '中文名称按拼音排序。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          generateSection(
            title: '共建者（${_names.length}）',
            items: [
              for (var index = 0; index < _names.length; index++)
                _MemberRow(name: _names[index], index: index, badge: '共建者'),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.index,
    required this.badge,
  });

  final String name;
  final int index;
  final String badge;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF5B8DEF),
      Color(0xFF34A853),
      Color(0xFFF2994A),
      Color(0xFF9B51E0),
      Color(0xFFEB5757),
      Color(0xFF2D9CDB),
    ];
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return ListItem(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors[index % colors.length].withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: AppTextStyle.subheadline
              .of(context, emphasized: true)
              .copyWith(color: colors[index % colors.length]),
        ),
      ),
      title: Text(name),
      trailing: MetaChip(label: badge),
    );
  }
}
