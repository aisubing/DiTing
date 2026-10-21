/// 真机 UI 取证通道，仅 debug/profile 生效。
///
/// 截图只能告诉我「看起来不对」，量不出「差了多少 dp」。这里把 VM Service 当成
/// 探针：跳路由、把屏幕上所有文本与容器的实际全局矩形导出来、累计 RenderFlex
/// 溢出消息，让边距/对齐/裁切问题在真机上可量化，而不是靠肉眼猜。
///
/// 释放构建里 `kDebugMode` 是常量 false，调用点被树摇掉，不留在产物中。
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:diting/ui/inherited.dart';
import 'package:diting/ui/navigator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final List<String> _diagnostics = <String>[];
final List<String> _notes = <String>[];

const List<String> _structureTypes = <String>[
  'AppBar',
  'CommonScaffold',
  'NavigationDock',
  'ListHeader',
  'SegmentedControl',
  'PageBody',
  'FloatingHeader',
  'Scaffold',
  // 卡片/图块/空状态这类「占住一块地方但没有文本」的容器也要登记，
  // 否则留白体检会把它们当成空档。
  'Card',
  'Tile',
  'Image',
  'Chart',
  'EditableText',
  // 输入框外壳：`EditableText` 只是里面那行字（高 18），量不到 360 高的框，
  // 于是「框内空白」被报成 262dp 留白（/rules/batch）。
  'InputDecorator',
  'TextField',
  'NullStatus',
  // 下面几类同样是「画上了东西的块」，此前漏登记导致首页大圆钮、扫码取景框、
  // 主题预览的小屏幕各被量成 190–660dp 的假空档。
  'Button',
  'CustomPaint',
  'GlyphIcon',
  'Screen',
  'Frame',
];

void installDebugProbe() {
  if (!kDebugMode) return;
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // 全部布局类错误都要留痕：只筛「overflowed」会丢掉
    // 「RenderBox was given infinite size」这类同样让内容消失的错误。
    final text = details.exceptionAsString().split('\n').first;
    if (text.contains('RenderBox') ||
        text.contains('overflowed') ||
        text.contains('viewport') ||
        text.contains('infinite') ||
        text.contains('assertion')) {
      if (_diagnostics.length < 60) _diagnostics.add(text);
    }
    previous?.call(details);
  };

  developer.registerExtension('ext.diting.go', (
    String name,
    Map<String, String> args,
  ) async {
    final loc = args['loc'] ?? '/';
    _diagnostics.clear();
    // 上一页留下的浮层/对话框是 `PopupRoute`，`go` 只换页面栈不会关掉它们；
    // 不关就会把浮层的文本当成新页的内容上报（真机上出现过一次）。
    rootNavigatorKey.currentState?.popUntil((route) => route is! PopupRoute);
    final context = rootNavigatorKey.currentContext;
    if (context != null) GoRouter.of(context).go(loc);
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'ok': context != null, 'loc': loc}),
    );
  });

  developer.registerExtension('ext.diting.back', (
    String name,
    Map<String, String> args,
  ) async {
    final nav = rootNavigatorKey.currentState;
    final popped = nav?.canPop() ?? false;
    if (popped) nav!.pop();
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'popped': popped}),
    );
  });

  developer.registerExtension('ext.diting.probe', (
    String name,
    Map<String, String> args,
  ) async {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'error': 'no root element'}),
      );
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final dpr = view.devicePixelRatio;
    final size = view.physicalSize / dpr;
    final vp = view.viewPadding;
    final vi = view.viewInsets;
    final texts = <Map<String, Object?>>[];
    final boxes = <Map<String, Object?>>[];
    final seen = <String>{};
    _notes.clear();

    void visit(Element element, double vpBottom, bool hz, bool inBar) {
      var clipBottom = vpBottom;
      final widget = element.widget;
      if (widget is Scrollable) {
        final dir = widget.axisDirection;
        if (dir == AxisDirection.left || dir == AxisDirection.right) {
          hz = true;
        } else {
          // 滚动视口的底边：视口之外（被裁掉）的行没有画到屏幕上，不能按屏幕
          // 坐标算「侵入系统栏」。列表停在中间时，最后一行天然顶到视口底边。
          final box = element.renderObject;
          if (box is RenderBox && box.hasSize) {
            final bottom =
                (box.localToGlobal(Offset.zero) + Offset(0, box.size.height))
                    .dy;
            if (bottom < clipBottom) clipBottom = bottom;
          }
        }
      }
      // 底栏六个 tab 由 IndexedStack 保活，未选中支被包成不可见 Visibility，
      // 但仍参与布局；不剪掉就会把后台页的文本当成当前页上报。
      if (widget is Visibility && !widget.visible) return;
      if (widget is Offstage && widget.offstage) return;
      if (widget is SliverPadding) {
        final pad = widget.padding;
        final top = pad is EdgeInsets ? pad.top : -999.0;
        _notes.add('SliverPadding t=${_r(top)}');
      }
      final type = widget.runtimeType.toString();
      // 顶栏与浮条自己的标题/按钮本来就落在栏区内，不能当成「正文画进顶栏」。
      if (type == 'AppBar' || type == 'NavigationDock') inBar = true;
      if (type == 'PageBody') {
        final mq = MediaQuery.of(element);
        _notes.add(
          'PageBody padTop=${_r(mq.padding.top)} '
          'float=${_r(FloatingBarScope.of(element) ?? -1)}',
        );
      }
      final renderObject = element.renderObject;
      if (renderObject is RenderBox && renderObject.hasSize) {
        final rect =
            renderObject.localToGlobal(Offset.zero) & renderObject.size;
        if (widget is RichText) {
          final label = widget.text.toPlainText();
          final style = widget.text.style;
          if (label.trim().isNotEmpty && label.length < 200) {
            final key = '$label@${rect.left.round()},${rect.top.round()}';
            if (seen.add(key)) {
              texts.add(<String, Object?>{
                's': label,
                'x': _r(rect.left),
                'y': _r(rect.top),
                'w': _r(rect.width),
                'h': _r(rect.height),
                'fs': style?.fontSize,
                'hz': hz,
                'bar': inBar,
                'vb': _r(clipBottom),
                'clip': !hz && _r(rect.right) > size.width + 0.6,
                'off':
                    rect.bottom < 0 || rect.top > size.height || rect.right < 0,
              });
            }
          }
        } else if (_structureTypes.any(type.contains)) {
          boxes.add(<String, Object?>{
            'k': type,
            'x': _r(rect.left),
            'y': _r(rect.top),
            'w': _r(rect.width),
            'h': _r(rect.height),
          });
        }
      }
      element.visitChildren((child) => visit(child, clipBottom, hz, inBar));
    }

    visit(root, size.height, false, false);
    final payload = <String, Object?>{
      'screen': <String, Object?>{
        'w': _r(size.width),
        'h': _r(size.height),
        'dpr': dpr,
      },
      'pad': <String, Object?>{
        'top': _r(vp.top),
        'bottom': _r(vp.bottom),
        'left': _r(vp.left),
        'right': _r(vp.right),
        'insBottom': _r(vi.bottom),
      },
      'texts': texts,
      'boxes': boxes,
      'diag': _diagnostics,
      'notes': _notes,
    };
    return developer.ServiceExtensionResponse.result(jsonEncode(payload));
  });
}

double _r(double v) => (v * 10).roundToDouble() / 10;
