part of 'profiles_page.dart';

/// 一张档案卡片。
///
/// 用 `CommonCard` + `ListItem` 而不是自绘：选中态的填充、按下动画、明暗两套
/// 颜色都由设计系统管；长按手势挂在外层 `GestureDetector`，因为 `CommonCard`
/// 只是按钮，没有长按语义。
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isCurrent,
    required this.isSelected,
    required this.isUpdating,
    required this.onTap,
    required this.onLongPress,
    required this.menuItems,
  });

  final MockProfile profile;

  /// 当前生效的档案：显示对勾徽标与主色描边。
  final bool isCurrent;
  final bool isSelected;
  final bool isUpdating;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final List<CommonPopupMenuItem> Function() menuItems;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDownloading = profile.isDownloading;
    return GestureDetector(
      onLongPress: onLongPress,
      child: CommonCard(
        isSelected: isSelected || isCurrent,
        fillsSelection: isSelected,
        onPressed: onTap,
        radius: AppCorner.xl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  GlyphIcon(
                    _kindGlyph(profile.kind),
                    size: 20,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline
                          .of(context, emphasized: true)
                          .copyWith(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                    ),
                  ),
                  if (isCurrent) const SelectionBadge(size: 22),
                  CommonPopupBox(
                    targetBuilder: (open) => IconButton(
                      tooltip: UiLocalizations.of(context).more,
                      onPressed: isUpdating ? null : open,
                      icon: const GlyphIcon(AppGlyphs.more),
                    ),
                    popupBuilder: (_) => CommonPopupMenu(items: menuItems()),
                  ),
                ],
              ),
              Row(
                spacing: 6,
                children: [
                  _KindBadge(kind: profile.kind, inverted: isSelected),
                  if (profile.autoUpdate != AutoUpdateInterval.off)
                    MetaChip(label: profile.autoUpdate.label),
                  if (isUpdating) MetaChip(label: '更新中'),
                ],
              ),
              Text(
                profile.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listCaptionStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              if (isDownloading)
                _DownloadProgress(
                  progress: profile.downloadProgress!,
                  wavy: profile.wavyProgress,
                ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      profile.updatedAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle,
                    ),
                  ),
                  MetaChip(label: '${profile.ruleCount} 规则'),
                  MetaChip(label: '${profile.proxyCount} 节点'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Glyph _kindGlyph(ProfileKind kind) => switch (kind) {
  ProfileKind.local => AppGlyphs.importFile,
  ProfileKind.remote => AppGlyphs.cloudSync,
  ProfileKind.merged => AppGlyphs.customize,
};

/// 类型徽标：本地 / 远程 / 合并。
///
/// 三者的颜色刻意不同（主色 / 次色 / 三级色），因为类型决定了「更新」按钮是否
/// 有意义——远程能更新、本地不能，用同一种颜色会让用户以为都能点。
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, this.inverted = false});

  final ProfileKind kind;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (color, foreground) = switch (kind) {
      ProfileKind.remote => (colorScheme.primary, colorScheme.onPrimary),
      ProfileKind.local => (colorScheme.secondary, colorScheme.onSecondary),
      ProfileKind.merged => (colorScheme.tertiary, colorScheme.onTertiary),
    };
    return TonalChip(
      label: kind.label,
      color: inverted
          ? foreground.withValues(alpha: 0.2)
          : color.withValues(alpha: 0.14),
      foregroundColor: inverted ? foreground : color,
    );
  }
}

/// 下载进度：普通进度条或波浪进度条。
///
/// 波浪那条是上游 `ProfilesCard` 的写法——进度头部是一条正弦，随下载缓慢起伏。
/// 演示里只给一张卡开波浪，否则满屏都在动，反而看不出它在动。
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.wavy});

  final double progress;
  final bool wavy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Row(
          children: [
            Text(
              wavy ? '正在同步订阅（波浪样式）' : '正在下载订阅',
              style: context.listCaptionStyle,
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: context.listCaptionStyle.copyWith(
                fontFamily: 'JetBrainsMono',
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 8,
          child: wavy
              ? _WaveProgressBar(progress: progress, height: 8)
              : ClipRSuperellipse(
                  borderRadius: AppRadius.full,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: AppRadius.full,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 波浪进度条：轨道 + 已填充段 + 右端的一段正弦高光。
class _WaveProgressBar extends StatefulWidget {
  const _WaveProgressBar({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  State<_WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<_WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final shape = AppShape.all(widget.height / 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final filled = (constraints.maxWidth * widget.progress).clamp(
          0.0,
          constraints.maxWidth,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: shape,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: filled,
              height: widget.height,
              decoration: ShapeDecoration(
                color: colorScheme.primary,
                shape: shape,
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _WaveHeadPainter(
                    phase: _controller.value,
                    color: Color.alphaBlend(
                      colorScheme.primary.withValues(alpha: 0.55),
                      colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 进度条右端的一小段波纹高光；本体是一条正弦，振幅不超过条高的一半。
class _WaveHeadPainter extends CustomPainter {
  const _WaveHeadPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 8) {
      return;
    }
    final width = size.width.clamp(0.0, 24.0);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()..moveTo(size.width - width, size.height);
    const steps = 12;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      path.lineTo(
        size.width - width + width * t,
        size.height * (0.5 + 0.5 * math.sin(6.28318530718 * (t + phase))),
      );
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveHeadPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
