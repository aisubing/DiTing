import 'package:diting/app/l10n/l10n.dart';
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
      title: context.l10n.onboardingTitle,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.close,
          tooltip: context.l10n.onboardingSkip,
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
                        label: context.l10n.onboardingPrev,
                        onPressed: () => _goTo(_index - 1),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: TonalButton(
                      size: TonalButtonSize.bar,
                      glyph: last ? AppGlyphs.check : AppGlyphs.chevronForward,
                      label: last ? context.l10n.onboardingStart : context.l10n.onboardingNext,
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
      title: context.l10n.onboardingChosen(mode.title(context.l10n)),
      description: mode.summary(context.l10n),
      children: [
        _TipCard(
          glyph: AppGlyphs.info,
          title: context.l10n.onboardingChangeable,
          detail: context.l10n.onboardingChangeableBody,
        ),
        _TipCard(
          glyph: AppGlyphs.layers,
          title: context.l10n.onboardingSharedRules,
          detail: context.l10n.onboardingSharedRulesBody,
        ),
        _TipCard(
          glyph: AppGlyphs.swap,
          title: context.l10n.onboardingExclusive,
          detail: context.l10n.onboardingExclusiveBody,
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
      AppWorkMode.normal => [
        (
          AppPermission.vpn,
          AppGlyphs.vpn,
          context.l10n.permVpn,
          context.l10n.permRequired,
          context.l10n.permVpnNormalBody,
        ),
        (
          AppPermission.notification,
          AppGlyphs.info,
          context.l10n.permNotification,
          context.l10n.permRequired,
          context.l10n.permNotificationBody,
        ),
        (
          AppPermission.appList,
          AppGlyphs.appsList,
          context.l10n.permAppList,
          context.l10n.permOptional,
          context.l10n.permAppListBody,
        ),
        (
          AppPermission.batteryOptimization,
          AppGlyphs.bolt,
          context.l10n.permBattery,
          context.l10n.permOptional,
          context.l10n.permBatteryBody,
        ),
      ],
      AppWorkMode.server => [
        (
          AppPermission.notification,
          AppGlyphs.info,
          context.l10n.permNotification,
          context.l10n.permRequired,
          context.l10n.permNotificationBody,
        ),
        (
          AppPermission.batteryOptimization,
          AppGlyphs.bolt,
          context.l10n.permBattery,
          context.l10n.permOptional,
          context.l10n.permBatteryServerBody,
        ),
      ],
      AppWorkMode.express => [
        (AppPermission.vpn, AppGlyphs.vpn, context.l10n.permVpn, context.l10n.permRequired, context.l10n.permVpnExpressBody),
        (
          AppPermission.notification,
          AppGlyphs.info,
          context.l10n.permNotification,
          context.l10n.permRequired,
          context.l10n.permNotificationBody,
        ),
        (
          AppPermission.batteryOptimization,
          AppGlyphs.bolt,
          context.l10n.permBattery,
          context.l10n.permOptional,
          context.l10n.permBatteryBody,
        ),
      ],
    };
    final snapshot = ref.watch(permissionStatesProvider).value;
    final grantedCount = permissions
        .where((item) => snapshot?.of(item.$1) == true)
        .length;
    return _StepScaffold(
      glyph: AppGlyphs.lock,
      title: context.l10n.permNeeded,
      description: snapshot == null
          ? context.l10n.permAllLocal
          : context.l10n.permGrantedCount(
              '$grantedCount',
              '${permissions.length}',
            ),
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
  _FinishStep({required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context) {
    final tips = switch (mode) {
      AppWorkMode.normal => [
        context.l10n.onboardingTipNormal1,
        context.l10n.onboardingTipNormal2,
        context.l10n.onboardingTipNormal3,
      ],
      AppWorkMode.server => [
        context.l10n.onboardingTipServer1,
        context.l10n.onboardingTipServer2,
        context.l10n.onboardingTipServer3,
      ],
      AppWorkMode.express => [
        context.l10n.onboardingTipExpress1,
        context.l10n.onboardingTipExpress2,
        context.l10n.onboardingTipExpress3,
      ],
    };
    return _StepScaffold(
      glyph: AppGlyphs.checkCircle,
      title: context.l10n.onboardingReady,
      description: context.l10n.onboardingReadyBody,
      children: [
        for (final (index, tip) in tips.indexed)
          _TipCard(
            glyph: AppGlyphs.check,
            title: context.l10n.onboardingTipIndex('${index + 1}'),
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
        content: Text(context.l10n.permStillDenied(name)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2600),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final required = level == context.l10n.permRequired;
    final state = ref.watch(permissionStatesProvider).value?.of(permission);
    final granted = state == true;
    final statusLabel = switch (state) {
      true => context.l10n.permGranted,
      false => context.l10n.permDenied,
      null => context.l10n.permUnknown,
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
                    label: context.l10n.permGrant,
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
