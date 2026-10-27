import 'package:diting/data/native/permissions_bridge.dart';
import 'package:diting/router.dart';
import 'package:diting/state/permission_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/icon_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Three-step onboarding: choose mode, request permissions, key tips. Step 2 both explains each
/// permission and opens the real system dialog, because a page that only describes them leaves the
/// service unprotected: without POST_NOTIFICATIONS the foreground notification is dropped, and
/// without the VPN consent the tunnel cannot start at all.
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

  /// Finish onboarding: write the flag and return home. go(Routes.home) rather than pop,
  /// because this page is reached both by pushReplacement and by push.
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
      // The app bar floats over the body (extendBodyBehindAppBar) and this page uses a bare Column,
      // so
      // without this clearance the progress bar and hero icon would be drawn under the status bar.
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

/// Three-segment progress bar: passed 40% opaque, current primary, pending surface.
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

/// Step 1: confirm the work mode. Display only, since the mode was already chosen.
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

/// Step 2: request the permissions this mode needs. Every row is a real request: `VPN 连接` opens
/// the system consent dialog, `通知` the runtime permission (or the notification settings screen
/// below Android 13), `忽略电池优化` the allowlist dialog, and `应用列表` the vendor permission with a
/// settings fallback. Denial consequences are spelled out, since the service degrades silently.
class _PermissionStep extends ConsumerWidget {
  const _PermissionStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workModeProvider);
    final permissions = switch (mode) {
      AppWorkMode.normal => const [
        (
          AppPermission.vpn,
          AppGlyphs.vpn,
          'VPN 连接',
          '必需',
          '建立本地隧道接管流量；拒绝则无法启动',
        ),
        (
          AppPermission.notification,
          AppGlyphs.info,
          '通知',
          '必需',
          '前台服务常驻通知；拒绝则服务可能被系统回收',
        ),
        (
          AppPermission.appList,
          AppGlyphs.appsList,
          '应用列表',
          '可选',
          '按应用分流与统计；拒绝则只能按域名规则',
        ),
        (
          AppPermission.batteryOptimization,
          AppGlyphs.bolt,
          '忽略电池优化',
          '可选',
          '避免后台被杀；拒绝则长时间待机可能断开',
        ),
      ],
      AppWorkMode.server => const [
        (
          AppPermission.notification,
          AppGlyphs.info,
          '通知',
          '必需',
          '前台服务常驻通知；拒绝则服务可能被系统回收',
        ),
        (
          AppPermission.batteryOptimization,
          AppGlyphs.bolt,
          '忽略电池优化',
          '可选',
          '避免后台被杀；拒绝则局域网内会间歇不可用',
        ),
      ],
      AppWorkMode.express => const [
        (AppPermission.vpn, AppGlyphs.vpn, 'VPN 连接', '必需', '建立窄路由隧道；拒绝则无法启动'),
        (
          AppPermission.notification,
          AppGlyphs.info,
          '通知',
          '必需',
          '前台服务常驻通知；拒绝则服务可能被系统回收',
        ),
        (
          AppPermission.batteryOptimization,
          AppGlyphs.bolt,
          '忽略电池优化',
          '可选',
          '避免后台被杀；拒绝则长时间待机可能断开',
        ),
      ],
    };
    final snapshot = ref.watch(permissionStatesProvider).value;
    final grantedCount = permissions
        .where((item) => snapshot?.of(item.$1) == true)
        .length;
    return _StepScaffold(
      glyph: AppGlyphs.lock,
      title: '需要这些权限',
      description: snapshot == null
          ? '全部权限只在本机使用，不会上传任何数据。'
          : '已授予 $grantedCount / ${permissions.length} 项；'
                '全部权限只在本机使用，不会上传任何数据。',
      children: [
        for (final (permission, glyph, name, level, detail) in permissions)
          _PermissionRow(
            permission: permission,
            glyph: glyph,
            name: name,
            level: level,
            detail: detail,
          ),
      ],
    );
  }
}

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

/// Centered because the buttons are pinned to the bottom.
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
                  child: IconBadge(
                    glyph: glyph,
                    size: 88,
                    glyphSize: 40,
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    foregroundColor: colorScheme.primary,
                    shape: AppShape.full,
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
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
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
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
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

/// One permission row with its live state; tapping it asks the system, so the step is actionable
/// instead of a wall of text. A denied permission stays tappable: a second tap opens the settings
/// screen that can still change it.
class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({
    required this.permission,
    required this.glyph,
    required this.name,
    required this.level,
    required this.detail,
  });

  final AppPermission permission;
  final Glyph glyph;
  final String name;
  final String level;
  final String detail;

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(permissionStatesProvider.notifier);
    final snapshot = await notifier.request(permission);
    if (!context.mounted) {
      return;
    }
    if (snapshot.of(permission) == true) {
      return;
    }
    // A permanently denied permission only changes through the settings screen.
    final opened = await notifier.openSystemSettings(permission);
    if (!context.mounted || !opened) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$name 仍未授予，请在系统设置里允许后返回本页'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2600),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final required = level == '必需';
    final state = ref.watch(permissionStatesProvider).value?.of(permission);
    final granted = state == true;
    final statusLabel = switch (state) {
      true => '已授予',
      false => '未授予',
      null => '状态未知',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CommonCard(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: granted ? null : () => _request(context, ref),
          borderRadius: AppRadius.md,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              IconBadge(
                glyph: granted ? AppGlyphs.checkCircle : glyph,
                size: 44,
                glyphSize: 22,
                color: granted
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                foregroundColor: granted
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
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
                        TonalChip(
                          label: statusLabel,
                          color: granted
                              ? colorScheme.secondaryContainer
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: granted
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                          onPressed: null,
                        ),
                      ],
                    ),
                    Text(
                      detail,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!granted)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TonalButton(
                    size: TonalButtonSize.bar,
                    label: '去授予',
                    onPressed: () => _request(context, ref),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
