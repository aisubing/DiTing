import 'package:diting/router.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 工作模式选择页：三张大卡 + 展开特性清单 + 「继续」。
///
/// 上游是「点卡片 → 1000ms 全屏 morph → 立即写 Store → 转引导」。演示层不做
/// 全屏 morph（那需要 Activity 级转场），改用卡片自身的 `AnimatedSize` 展开：
/// 点选先就地展示这个模式到底提供什么，用户能比较完再决定，比动画结束后才
/// 知道选了什么更可控。
///
/// 状态写入时机仍是「点选即写」，这样返回首页时标题与卡片已经是新模式；
/// 「继续」只负责离开。
class ModeSelectPage extends ConsumerStatefulWidget {
  const ModeSelectPage({super.key});

  @override
  ConsumerState<ModeSelectPage> createState() => _ModeSelectPageState();
}

class _ModeSelectPageState extends ConsumerState<ModeSelectPage> {
  /// 展开中的卡片。与 `workModeProvider` 分开存：用户可能点开看一眼又不选它，
  /// 展开是「浏览态」，写入才是「决定」。
  AppWorkMode? _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = ref.read(workModeProvider);
  }

  void _select(AppWorkMode mode) {
    // 再点一次已选中的卡片视为确认：这是移动端列表的通行手势，也避免用户
    // 明明选好了还要去找底部按钮。
    if (_expanded == mode && ref.read(workModeProvider) == mode) {
      _confirm(mode);
      return;
    }
    setState(() => _expanded = mode);
    ref.read(workModeProvider.notifier).select(mode);
  }

  void _confirm(AppWorkMode mode) {
    ref.read(workModeProvider.notifier).select(mode);
    ref.read(workModeSelectedProvider.notifier).markSelected();
    // 引导未完成时顺势进引导，而不是回首页——否则用户会看到一个没解释过
    // 权限的首页。
    if (ref.read(onboardingProvider)) {
      context.pop();
    } else {
      context.pushReplacement(Routes.modeOnboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(workModeProvider);
    final expanded = _expanded ?? current;
    return CommonScaffold(
      title: '选择工作模式',
      body: PageBody(
        children: [
          const _ModeSelectIntro(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                for (final mode in AppWorkMode.values)
                  _WorkModeCard(
                    mode: mode,
                    selected: current == mode,
                    expanded: expanded == mode,
                    onPressed: () => _select(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TonalButton(
              size: TonalButtonSize.bar,
              glyph: AppGlyphs.chevronForward,
              label: '继续',
              onPressed: () => _confirm(expanded),
            ),
          ),
          const ListFooter(
            text: '随时可以在设置里重新选择；切换模式会先停止当前模式的服务，'
                '两个模式不会同时运行。',
          ),
        ],
      ),
    );
  }
}

class _ModeSelectIntro extends StatelessWidget {
  const _ModeSelectIntro();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        '三种模式共用一套规则与缓存，区别在接管方式：普通模式走全隧道，'
        '服务器模式只做局域网 DNS，极速模式是纯 Kotlin 窄路由。',
        style: AppTextStyle.footnote.of(context).copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 一张模式卡：标题 + 徽章 + 摘要，选中后原地展开特性清单。
///
/// 展开用 `AnimatedSize` 而不是 `ExpansionTile`：后者会插入自己的分隔线与
/// 点击语义，和整张卡可点的手势冲突（点标题展开、点别处选中，用户分不清）。
class _WorkModeCard extends StatelessWidget {
  const _WorkModeCard({
    required this.mode,
    required this.selected,
    required this.expanded,
    required this.onPressed,
  });

  final AppWorkMode mode;
  final bool selected;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return CommonCard(
      isSelected: selected,
      onPressed: onPressed,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 12,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: AppShape.md,
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.14)
                      : colorScheme.surfaceContainerHigh,
                ),
                child: GlyphIcon(_glyphOf(mode), size: 24, color: accent),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Row(
                      spacing: 6,
                      children: [
                        Flexible(
                          child: Text(
                            mode.title,
                            style: AppTextStyle.headline.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ),
                        MetaChip(label: mode.badge),
                      ],
                    ),
                    Text(
                      mode.summary,
                      style: AppTextStyle.footnote.of(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) const SelectionCheck(),
            ],
          ),
          AnimatedSize(
            duration: commonDuration,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _ModeFeatureList(mode: mode)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  static Glyph _glyphOf(AppWorkMode mode) => switch (mode) {
    AppWorkMode.normal => AppGlyphs.layers,
    AppWorkMode.server => AppGlyphs.dns,
    AppWorkMode.express => AppGlyphs.bolt,
  };
}

/// 展开后的特性清单：每行「图标 + 一句话」。
///
/// 文案直接对应 `docs/refactor/03-navigation-and-main-ui.md` §4.7 的 feature 步，
/// 保证选择页和引导页说的是同一件事。
class _ModeFeatureList extends StatelessWidget {
  const _ModeFeatureList({required this.mode});

  final AppWorkMode mode;

  static const _features = <AppWorkMode, List<(Glyph, String, String)>>{
    AppWorkMode.normal: [
      (AppGlyphs.vpn, '全隧道接管', 'Go 栈接管全部流量，可按应用分流'),
      (AppGlyphs.rules, '全功能规则', '黑白名单、覆写、HTTPS 检查全部可用'),
      (AppGlyphs.verified, '可选 HTTPS 检查', '需要安装并信任本地 CA 证书'),
      (AppGlyphs.dataUsage, '应用流量统计', '按应用记录上下行与查询数'),
    ],
    AppWorkMode.server: [
      (AppGlyphs.dns, '局域网 DNS 服务', '监听 0.0.0.0，供同一网段设备使用'),
      (AppGlyphs.lock, '不占 VPN 槽位', '本机不建立隧道，可与其它 VPN 共存'),
      (AppGlyphs.layers, '共享规则与缓存', '与普通模式共用同一套规则库'),
      (AppGlyphs.memory, '低功耗', '只处理 DNS 查询，无流量转发'),
    ],
    AppWorkMode.express: [
      (AppGlyphs.bolt, '纯 Kotlin 实现', '窄路由，启动与切换都更快'),
      (AppGlyphs.split, '四种上游调度', '单服务商 / 智能 / 竞速 / 主备'),
      (AppGlyphs.memory, '64 分片 LRU 缓存', '命中率高、内存占用可控'),
      (AppGlyphs.devices, '兼容更旧系统', 'Android 7+（需 64 位）'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final features = _features[mode] ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          for (final (glyph, title, detail) in features)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: GlyphIcon(glyph, size: 18, color: colorScheme.primary),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 1,
                    children: [
                      Text(
                        title,
                        style: AppTextStyle.subheadline.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      Text(
                        detail,
                        style: AppTextStyle.caption1.of(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
