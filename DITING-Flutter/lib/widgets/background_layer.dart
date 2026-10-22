/// 全局软件背景层：在整棵界面之下垫一张壁纸，并叠一层与旧版一致的遮罩。
///
/// 1.4.3 `AppThemeSurface` 的做法是：开启自定义背景时把页面 `background` 设为透明，
/// 在 `Surface` 里先画 `ContentScale.Crop` 的壁纸，再叠一层黑色遮罩（深色 0.34，
/// 浅色 0.16），最后才是页面内容。这里复用同一套参数。
///
/// 壁纸路径来自原生缓存（`BackgroundBridge.resolve`），Dart 用 `Image.file` 渲染。
/// resolve 只做一次并缓存：每次 rebuild 都重新发起原生调用会让壁纸闪一下。
library;

import 'dart:io';

import 'package:diting/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AppBackgroundLayer extends ConsumerStatefulWidget {
  const AppBackgroundLayer({super.key, required this.uri, required this.child});

  /// 当前壁纸的原始 URI（用它去原生侧换本地缓存路径）。
  final String uri;
  final Widget child;

  @override
  ConsumerState<AppBackgroundLayer> createState() => _AppBackgroundLayerState();
}

class _AppBackgroundLayerState extends ConsumerState<AppBackgroundLayer> {
  late Future<String?> _path;

  @override
  void initState() {
    super.initState();
    _path = _resolve();
  }

  @override
  void didUpdateWidget(AppBackgroundLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) _path = _resolve();
  }

  Future<String?> _resolve() =>
      ref.read(backgroundBridgeProvider).resolve(widget.uri);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<String?>(
          future: _path,
          builder: (context, snapshot) {
            final path = snapshot.data;
            if (path == null) return const SizedBox.shrink();
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            );
          },
        ),
        // 遮罩：壁纸偏亮时压暗，保证文字对比度。与旧版 0.34 / 0.16 一致。
        ColoredBox(color: Colors.black.withValues(alpha: dark ? 0.34 : 0.16)),
        widget.child,
      ],
    );
  }
}
