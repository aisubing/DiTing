import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 首页电源按钮：停止 / 启动中 / 运行 / 停止中 四态。
///
/// 上游 `PowerToggleButton.kt` 是「glow + halo + 圆钮 + 文案」四层同步 250ms
/// 变色/变尺寸；这里保留同一结构，用 `AnimatedContainer` 驱动，视觉层次与
/// 上游一致：运行态是主色实心、停止态是表面色描边。
class HomePowerButton extends StatelessWidget {
  const HomePowerButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.runningLabel = '停止',
    this.stoppedLabel = '开启',
    this.busyLabel = '启动中',
  });

  final PowerState state;
  final VoidCallback onPressed;
  final String runningLabel;
  final String stoppedLabel;
  final String busyLabel;

  static const _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final running = state.isRunning;
    final busy = state.isBusy;
    final label = switch (state) {
      PowerState.starting || PowerState.stopping => busyLabel,
      PowerState.running => runningLabel,
      PowerState.stopped || PowerState.error => stoppedLabel,
    };
    final foreground = running ? colorScheme.onPrimary : colorScheme.primary;
    return Semantics(
      button: true,
      label: label,
      value: state.label,
      child: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // halo：只在运行态出现，比按钮大一圈、透明度很低。
              AnimatedContainer(
                duration: _duration,
                width: running ? 172 : 148,
                height: running ? 172 : 148,
                decoration: ShapeDecoration(
                  shape: const CircleBorder(),
                  color: colorScheme.primary.withValues(
                    alpha: running ? 0.10 : 0,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _duration,
                width: running ? 148 : 124,
                height: running ? 148 : 124,
                decoration: ShapeDecoration(
                  shape: const CircleBorder(),
                  color: colorScheme.primary.withValues(
                    alpha: running ? 0.16 : 0.06,
                  ),
                ),
              ),
              _ButtonFace(
                state: state,
                foreground: foreground,
                onPressed: busy ? null : onPressed,
              ),
              // 文案压在圆钮下方，跟着状态变；busy 时显示「启动中」。
              Positioned(
                bottom: 34,
                child: AnimatedSwitcher(
                  duration: _duration,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: AppTextStyle.subheadline
                        .of(context, emphasized: true)
                        .copyWith(
                          color: running
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonFace extends StatelessWidget {
  const _ButtonFace({
    required this.state,
    required this.foreground,
    required this.onPressed,
  });

  final PowerState state;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final running = state.isRunning;
    final size = running ? 100.0 : 92.0;
    return Semantics(
      button: true,
      child: AnimatedContainer(
        duration: HomePowerButton._duration,
        width: size,
        height: size,
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: running
              ? colorScheme.primary
              : colorScheme.surfaceContainerHigh,
          shadows: [
            BoxShadow(
              color: (running ? colorScheme.primary : Colors.black).withValues(
                alpha: running ? 0.32 : 0.10,
              ),
              blurRadius: running ? 28 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(
              child: state.isBusy
                  ? CommonCircleLoading(size: 42, color: foreground)
                  : GlyphIcon(
                      running ? AppGlyphs.bolt : AppGlyphs.playPause(0),
                      size: 42,
                      fill: 1,
                      color: foreground,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
