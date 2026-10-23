/// Scanner skeleton (upstream `pages/scan.dart`): viewfinder, animation, torch and gallery,
/// no real camera. The scan window is capped at 400dp and at 0.67 of the short side, the
/// upstream rule.
library;

import 'dart:math' as math;

import 'package:diting/pages/system/demo_page_notice.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  /// Torch state, UI only, not wired to hardware.
  var _torch = false;

  /// Permission state; switchable in the demo to review the denied layout.
  var _permissionDenied = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fakeScan() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('演示环境不识别二维码；真实实现会在这里回填解析结果'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The scanner is always dark: a camera preview is unreadable on a light background
    // and QR contrast depends on a dark surround.
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: context.colorScheme.primary,
          brightness: Brightness.dark,
        ),
      ),
      child: CommonScaffold(
        title: '扫码',
        backgroundColor: Colors.black,
        iconActions: [
          IconButtonData(
            glyph: _torch ? AppGlyphs.torchOff : AppGlyphs.torch,
            tooltip: _torch ? '关闭手电筒' : '打开手电筒',
            isSelected: _torch,
            onPressed: () => setState(() => _torch = !_torch),
          ),
          IconButtonData(
            glyph: AppGlyphs.photos,
            tooltip: '从相册选择',
            onPressed: () => _fakeScan(),
          ),
        ],
        menuItems: [
          CommonPopupMenuItem(
            label: _permissionDenied ? '模拟已授权' : '模拟权限被拒',
            glyph: AppGlyphs.camera,
            onPressed: () =>
                setState(() => _permissionDenied = !_permissionDenied),
          ),
        ],
        body: _permissionDenied
            ? _PermissionDenied(
                onRetry: () => setState(() => _permissionDenied = false),
              )
            : _ScanLayout(
                animation: _controller,
                torch: _torch,
                onTorchToggle: () => setState(() => _torch = !_torch),
                onAlbum: _fakeScan,
              ),
      ),
    );
  }
}

/// Viewfinder layout: centered scan window with hints below (upstream `_ScanLayout`).
class _ScanLayout extends StatelessWidget {
  const _ScanLayout({
    required this.animation,
    required this.torch,
    required this.onTorchToggle,
    required this.onAlbum,
  });

  final Animation<double> animation;
  final bool torch;
  final VoidCallback onTorchToggle;
  final VoidCallback onAlbum;

  /// Scan window side: at most 400 and at most 0.67 of the short side.
  static double _windowSize(Size size) =>
      math.min(400, size.shortestSide * 0.67);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final size = _windowSize(media);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // The body starts at y=0 (`extendBodyBehindAppBar`), so reserve the app bar first.
            SizedBox(height: context.appBarInset),
            const DemoPageNotice(dark: true),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: AppShape.xl,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.04),
                                Colors.white.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ScanEffectPainter(animation: animation),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: CustomPaint(
                            painter: _CornerBracketPainter(
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '将二维码放入框内，保持 10–20 厘米距离',
                textAlign: TextAlign.center,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 24,
              children: [
                _RoundAction(
                  glyph: torch ? AppGlyphs.torchOff : AppGlyphs.torch,
                  label: torch ? '关闭' : '手电筒',
                  active: torch,
                  onPressed: onTorchToggle,
                ),
                _RoundAction(
                  glyph: AppGlyphs.photos,
                  label: '从相册',
                  active: false,
                  onPressed: onAlbum,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '演示环境不调用相机：这一屏只验证取景框、扫描线与按钮布局。',
              textAlign: TextAlign.center,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: Colors.white.withValues(alpha: 0.4)),
            ),
            SizedBox(height: 20 + MediaQuery.paddingOf(context).bottom),
          ],
        );
      },
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.glyph,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final Glyph glyph;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: AppShape.circle,
              color: active
                  ? colorScheme.primary
                  : Colors.white.withValues(alpha: 0.12),
            ),
            child: GlyphIcon(
              glyph,
              size: 24,
              color: active ? colorScheme.onPrimary : Colors.white,
            ),
          ),
        ),
        Text(
          label,
          style: AppTextStyle.caption1
              .of(context)
              .copyWith(color: Colors.white.withValues(alpha: 0.75)),
        ),
      ],
    );
  }
}

/// Denied permission state (the permission branch of upstream `_ScannerError`).
class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: NullStatus(
        label: '相机权限未开启',
        description:
            '扫码需要相机权限。请在系统设置里允许「谛听」使用相机，'
            '或改为从相册选择图片。',
        illustration: NullStatusIllustration.camera,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            TonalButton(
              label: '重新授权',
              glyph: AppGlyphs.refresh,
              size: TonalButtonSize.section,
              onPressed: onRetry,
            ),
            TextButton(onPressed: onRetry, child: const Text('从相册选择')),
          ],
        ),
      ),
    );
  }
}

/// Scan effect: a brightening border plus a sweeping light band (upstream `_ScanEffectPainter`).
class _ScanEffectPainter extends CustomPainter {
  _ScanEffectPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = AppShape.xl.getOuterPath(rect);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.35 + animation.value * 0.25);
    canvas
      ..drawPath(shape, borderPaint)
      ..save()
      ..clipPath(shape);

    final beamY = size.height * animation.value;
    final beam = Rect.fromLTWH(0, beamY - 24, size.width, 48);
    canvas.drawRect(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ).createShader(beam),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanEffectPainter old) => false;
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const length = 28.0;
    const stroke = 3.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final corners = <(Offset, Offset, Offset)>[
      (const Offset(0, length), Offset.zero, const Offset(length, 0)),
      (
        Offset(size.width - length, 0),
        Offset(size.width, 0),
        Offset(size.width, length),
      ),
      (
        Offset(0, size.height - length),
        Offset(0, size.height),
        Offset(length, size.height),
      ),
      (
        Offset(size.width - length, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - length),
      ),
    ];
    for (final (start, corner, end) in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(end.dx, end.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.color != color;
}