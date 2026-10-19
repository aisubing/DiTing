import 'package:diting/router.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 三步引导：选模式 → 权限说明 → 上手要点。
///
/// 上游是 Activity 级的三步流程（`ModeOnboardingScreen`），每步水平滑入、顶部
/// 三段进度条、最后一步双按钮。演示层保留这套结构，但把「申请权限」换成
/// 「解释权限」：本阶段没有任何真实权限可申请，假装申请反而会让人以为
/// 点完按钮系统会弹窗。
///
/// 用 [PageView] 而不是 `IndexedStack`：三步是严格线性的前进/后退，PageView
/// 自带手势与位移，进度条可以直接读 `PageController.page`。
class ModeOnboardingPage extends ConsumerStatefulWidget {
  const ModeOnboardingPage({super.key});

  @override
  ConsumerState<ModeOnboardingPage> createState() => _ModeOnboardingPageState();
}

class _ModeOnboardingPageState extends ConsumerState<ModeOnboardingPage> {
  static const _steps = 3;

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _steps) {
      return;
    }
    await _controller.animateToPage(
      index,
      duration: commonDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// 结束引导：写完成标记并回首页。
  ///
  /// 用 `go(Routes.home)` 而不是 `pop()`：引导可能由模式选择页 `pushReplacement`
  /// 进来，也可能由设置页 push 进来，`pop` 的落点不确定；回首页是唯一确定的
  /// 语义（上游也是 CLEAR_TOP 回主界面）。
  void _finish() {
    ref.read(onboardingProvider.notifier).complete();
    ref.read(workModeSelectedProvider.notifier).markSelected();
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(workModeProvider);
    final last = _index == _steps - 1;
    return CommonScaffold(
      title: '引导',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.close,
          tooltip: '跳过引导',
          onPressed: () {
            ref.read(onboardingProvider.notifier).complete();
            context.go(Routes.home);
          },
        ),
      ],
      // 顶栏浮在正文之上（`extendBodyBehindAppBar`），正文从 y=0 起排。这一页
      // 的 body 是裸 `Column` 而不是 `PageBody`，不预留栏高就会把三段进度条画进
      // 状态栏、把首步的大圆钮画到顶栏底下（真机上量到内容起点 y=30 < 栏底 96）。
      body: AppBarClearance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepIndicator(steps: _steps, current: _index),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _index = index),
                children: [
                  _ChooseModeStep(mode: mode),
                  const _PermissionStep(),
                  _FinishStep(mode: mode),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                spacing: 10,
                children: [
                  if (_index > 0)
                    Expanded(
                      child: TonalButton(
                        size: TonalButtonSize.bar,
                        glyph: AppGlyphs.chevronBack,
                        label: '上一步',
                        onPressed: () => _goTo(_index - 1),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: TonalButton(
                      size: TonalButtonSize.bar,
                      glyph: last ? AppGlyphs.check : AppGlyphs.chevronForward,
                      label: last ? '开始使用' : '下一步',
                      onPressed: last ? _finish : () => _goTo(_index + 1),
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

/// 三段进度条：已过 40% 透明、当前主色、未至表面色。
///
/// 不做「第 1/3 步」文字：三段条本身已经是读数，再写一遍反而挤掉标题。
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.steps, required this.current});

  final int steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        spacing: 6,
        children: [
          for (var index = 0; index < steps; index++)
            Expanded(
              child: AnimatedContainer(
                duration: midDuration,
                curve: Curves.easeOut,
                height: 4,
                decoration: ShapeDecoration(
                  shape: AppShape.full,
                  color: index == current
                      ? colorScheme.primary
                      : index < current
                      ? colorScheme.primary.withValues(alpha: 0.4)
                      : colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 第 ① 步：确认工作模式。
///
/// 只展示、不在此页切换：引导的语义是「你已经选好了，现在告诉你它意味着
/// 什么」，再给一次选择入口会让上一步的点击显得没生效。
class _ChooseModeStep extends StatelessWidget {
  const _ChooseModeStep({required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      glyph: _glyphOf(mode),
      title: '你选择了${mode.title}',
      description: mode.summary,
      children: [
        _TipCard(
          glyph: AppGlyphs.info,
          title: '之后还能改',
          detail: '设置 → 重新选择工作模式，随时可以切换。切换会先停止当前模式的服务。',
        ),
        _TipCard(
          glyph: AppGlyphs.layers,
          title: '规则与缓存共用',
          detail: '三种模式共享同一套黑白名单与 DNS 缓存，不必为每个模式重配一遍。',
        ),
        _TipCard(
          glyph: AppGlyphs.swap,
          title: '模式互斥',
          detail: '同一时刻只有一个模式在运行；离开时会先停掉上一个模式。',
        ),
      ],
    );
  }

  static Glyph _glyphOf(AppWorkMode mode) => switch (mode) {
    AppWorkMode.normal => AppGlyphs.layers,
    AppWorkMode.server => AppGlyphs.dns,
    AppWorkMode.express => AppGlyphs.bolt,
  };
}

/// 第 ② 步：权限说明。
///
/// 权限清单按模式不同——服务器模式不建隧道，所以没有 VPN 权限这一项。把
/// 「为什么需要」和「拒绝会怎样」都写出来，是因为演示层没有真实申请流程，
/// 文案是用户唯一能判断后果的地方。
class _PermissionStep extends ConsumerWidget {
  const _PermissionStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workModeProvider);
    final permissions = switch (mode) {
      AppWorkMode.normal => const [
        (AppGlyphs.vpn, 'VPN 连接', '必需', '建立本地隧道接管流量；拒绝则无法启动'),
        (AppGlyphs.info, '通知', '必需', '前台服务常驻通知；拒绝则服务可能被系统回收'),
        (AppGlyphs.appsList, '应用列表', '可选', '按应用分流与统计；拒绝则只能按域名规则'),
        (AppGlyphs.bolt, '忽略电池优化', '可选', '避免后台被杀；拒绝则长时间待机可能断开'),
      ],
      AppWorkMode.server => const [
        (AppGlyphs.info, '通知', '必需', '前台服务常驻通知；拒绝则服务可能被系统回收'),
        (AppGlyphs.bolt, '忽略电池优化', '可选', '避免后台被杀；拒绝则局域网内会间歇不可用'),
      ],
      AppWorkMode.express => const [
        (AppGlyphs.vpn, 'VPN 连接', '必需', '建立窄路由隧道；拒绝则无法启动'),
        (AppGlyphs.info, '通知', '必需', '前台服务常驻通知；拒绝则服务可能被系统回收'),
        (AppGlyphs.bolt, '忽略电池优化', '可选', '避免后台被杀；拒绝则长时间待机可能断开'),
      ],
    };
    return _StepScaffold(
      glyph: AppGlyphs.lock,
      title: '需要这些权限',
      description: '全部权限只在本机使用，不会上传任何数据；拒绝「可选」项只影响对应功能。',
      children: [
        for (final (glyph, name, level, detail) in permissions)
          _PermissionRow(glyph: glyph, name: name, level: level, detail: detail),
      ],
    );
  }
}

/// 第 ③ 步：上手要点。
class _FinishStep extends StatelessWidget {
  const _FinishStep({required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context) {
    final tips = switch (mode) {
      AppWorkMode.normal => const [
        '点首页的大圆钮启动服务，第一次会弹出系统 VPN 授权。',
        '黑名单 / 白名单在「功能中心 → 规则与订阅」里维护。',
        '首页句子和透明度都能在设置里改。',
      ],
      AppWorkMode.server => const [
        '启动后把同网段设备的 DNS 指向「局域网接入」里显示的地址。',
        '端口可在「服务器模式」页改，默认 5353。',
        '本模式不建立 VPN，可与其它 VPN 同时运行。',
      ],
      AppWorkMode.express => const [
        '极速模式启动更快，但功能是普通模式的子集。',
        '多路竞速至少要选 2 家服务商。',
        '需要 HTTPS 检查或应用管控时请切回普通模式。',
      ],
    };
    return _StepScaffold(
      glyph: AppGlyphs.checkCircle,
      title: '可以开始了',
      description: '下面是三条最常用的上手要点。',
      children: [
        for (final (index, tip) in tips.indexed)
          _TipCard(
            glyph: AppGlyphs.check,
            title: '第 ${index + 1} 条',
            detail: tip,
          ),
      ],
    );
  }
}

/// 三步共用外壳：大图标 + 标题 + 说明 + 内容列表（可滚动）。
///
/// 内容整体在可视区里垂直居中：底部按钮是钉在屏底的，若内容贴着顶栏排，
/// 三步里最矮的那一步会在内容和按钮之间留下约 400dp 的死白（真机上量到
/// 406dp）。`SliverFillRemaining(hasScrollBody: false)` 给「至少一屏」的高度
/// 让 `Column` 有居中余地，内容超过一屏时又照常滚动。
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.glyph,
    required this.title,
    required this.description,
    required this.children,
  });

  final Glyph glyph;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      shape: AppShape.full,
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    child: GlyphIcon(glyph, size: 40, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.pageTitle.of(context, emphasized: true),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.footnote.of(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 一条要点卡片。
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.glyph,
    required this.title,
    required this.detail,
  });

  final Glyph glyph;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CommonCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            GlyphIcon(glyph, size: 20, color: colorScheme.primary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
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
      ),
    );
  }
}

/// 一条权限：图标 + 名称 + 等级徽章 + 说明。
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.glyph,
    required this.name,
    required this.level,
    required this.detail,
  });

  final Glyph glyph;
  final String name;
  final String level;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final required = level == '必需';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CommonCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: AppShape.md,
                color: colorScheme.surfaceContainerHigh,
              ),
              child: GlyphIcon(glyph, size: 22, color: colorScheme.primary),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyle.subheadline.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                      TonalChip(
                        label: level,
                        color: required
                            ? colorScheme.errorContainer
                            : colorScheme.secondaryContainer,
                        foregroundColor: required
                            ? colorScheme.onErrorContainer
                            : colorScheme.onSecondaryContainer,
                        onPressed: null,
                      ),
                    ],
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
      ),
    );
  }
}
