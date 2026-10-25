import 'package:diting/data/native/tile_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the one-shot contract of `consumeStartRequest`: the native side clears the extra when
/// read, so the tile must never be able to start a tunnel twice from one tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(tileChannelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mockResult(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  test('读取 native 的一次性启动请求', () async {
    mockResult((call) => call.method == 'consumeStartRequest' ? true : null);
    expect(await TileBridge().consumeStartRequest(), isTrue);
  });

  test('无请求时为 false', () async {
    mockResult((_) => false);
    expect(await TileBridge().consumeStartRequest(), isFalse);
  });

  test('通道缺失（桌面端）降级为 false', () async {
    // No mock handler installed at all: the call throws MissingPluginException.
    expect(await TileBridge().consumeStartRequest(), isFalse);
  });

  test('native 报错降级为 false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'boom'),
        );
    expect(await TileBridge().consumeStartRequest(), isFalse);
  });
}
