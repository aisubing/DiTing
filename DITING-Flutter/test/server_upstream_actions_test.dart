import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/server_upstream_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 服务器模式自定义上游的增删改。
///
/// 这三条语义在界面上看不出错，只有回读 `custom_upstreams` 才能发现：
/// 1. 自定义 id 必须不是 `preset_` 开头（否则被当成内置、变得不可编辑）；
/// 2. 非 DoH 地址落盘前去掉 IPv6 方括号（否则引擎拼出 `[[::1]]:53`）；
/// 3. 删掉当前选中项要回落到第一个内置（否则 selected 指向不存在的记录）。
void main() {
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final store = MemoryLegacyPrefsStore();
    return ProviderContainer(
      overrides: [legacyPrefsStoreProvider.overrideWithValue(store)],
    );
  }

  setUp(() => container = makeContainer());
  tearDown(() => container.dispose());

  ServerUpstreamActions actions() =>
      container.read(serverUpstreamActionsProvider);

  List<ServerUpstream> custom() => parseServerCustomUpstreams(
    container.read(legacySettingsProvider).serverCustomUpstreamsJson,
  );

  test('新增后落盘，id 带 custom_ 前缀', () {
    final saved = actions().add(
      name: '我的 DoH',
      protocol: DnsProtocol.doh,
      address: 'https://dns.example.com/dns-query',
      port: 443,
    );
    expect(saved, isNotNull);
    expect(saved!.id.startsWith('preset_'), isFalse);
    expect(saved.id.startsWith('custom_'), isTrue);

    final list = custom();
    expect(list, hasLength(1));
    expect(list.single.name, '我的 DoH');
    expect(list.single.protocol, DnsProtocol.doh);
    expect(list.single.address, 'https://dns.example.com/dns-query');
  });

  test('新增会进入完整上游列表（内置在前，自定义在后）', () {
    actions().add(
      name: '自定义 DNS',
      protocol: DnsProtocol.dns,
      address: '9.9.9.9',
      port: 53,
    );
    final all = container.read(serverUpstreamListProvider);
    expect(all.length, serverPresetUpstreams.length + 1);
    expect(all.last.name, '自定义 DNS');
  });

  test('非 DoH 地址落盘时去掉 IPv6 方括号', () {
    final saved = actions().add(
      name: 'IPv6 DNS',
      protocol: DnsProtocol.dns,
      address: '[2001:db8::1]',
      port: 53,
    );
    expect(saved!.address, '2001:db8::1');
    expect(custom().single.address, '2001:db8::1');
  });

  test('DoH 地址保留原样（不做去括号处理）', () {
    final saved = actions().add(
      name: 'DoH',
      protocol: DnsProtocol.doh,
      address: 'https://doh.example/dns-query',
      port: 443,
    );
    expect(saved!.address, 'https://doh.example/dns-query');
  });

  test('校验不过时不落盘', () {
    expect(
      actions().add(
        name: '  ',
        protocol: DnsProtocol.dns,
        address: '1.1.1.1',
        port: 53,
      ),
      isNull,
    );
    expect(
      actions().add(
        name: '明文 DoH',
        protocol: DnsProtocol.doh,
        address: 'http://doh.example/dns-query',
        port: 443,
      ),
      isNull,
    );
    expect(
      actions().add(
        name: '端口越界',
        protocol: DnsProtocol.dns,
        address: '1.1.1.1',
        port: 70000,
      ),
      isNull,
    );
    expect(custom(), isEmpty);
  });

  test('编辑自定义项会更新内容且保持 id', () {
    final saved = actions().add(
      name: '原名',
      protocol: DnsProtocol.dns,
      address: '1.1.1.1',
      port: 53,
    )!;
    final ok = actions().update(
      ServerUpstream(
        id: saved.id,
        name: '新名',
        protocol: DnsProtocol.dot,
        address: 'dns.example.com',
        port: 853,
      ),
    );
    expect(ok, isTrue);
    final list = custom();
    expect(list, hasLength(1));
    expect(list.single.id, saved.id);
    expect(list.single.name, '新名');
    expect(list.single.protocol, DnsProtocol.dot);
    expect(list.single.port, 853);
  });

  test('内置项不可编辑也不可删除', () {
    final preset = serverPresetUpstreams.first;
    expect(actions().update(preset), isFalse);
    expect(actions().remove(preset.id), isFalse);
    expect(custom(), isEmpty);
  });

  test('删除当前选中的自定义项 → 回落到第一个内置', () {
    final saved = actions().add(
      name: '待删',
      protocol: DnsProtocol.dns,
      address: '1.2.3.4',
      port: 53,
    )!;
    container.read(serverSelectedUpstreamProvider.notifier).select(saved.id);
    expect(
      container.read(legacySettingsProvider).serverSelectedUpstreamId,
      saved.id,
    );

    expect(actions().remove(saved.id), isTrue);
    expect(
      container.read(legacySettingsProvider).serverSelectedUpstreamId,
      serverPresetUpstreams.first.id,
    );
    expect(custom(), isEmpty);
  });

  test('删除未选中的自定义项不会改动当前选择', () {
    final a = actions().add(
      name: 'A',
      protocol: DnsProtocol.dns,
      address: '1.1.1.1',
      port: 53,
    )!;
    final b = actions().add(
      name: 'B',
      protocol: DnsProtocol.dns,
      address: '2.2.2.2',
      port: 53,
    )!;
    container.read(serverSelectedUpstreamProvider.notifier).select(a.id);

    actions().remove(b.id);
    expect(
      container.read(legacySettingsProvider).serverSelectedUpstreamId,
      a.id,
    );
    expect(custom(), hasLength(1));
  });

  test('连续新增的 id 互不相同', () {
    final ids = <String>{};
    for (var index = 0; index < 20; index++) {
      final saved = actions().add(
        name: 'N$index',
        protocol: DnsProtocol.dns,
        address: '10.0.0.$index',
        port: 53,
      )!;
      ids.add(saved.id);
    }
    expect(ids, hasLength(20));
  });

  test('选中的自定义上游会被 buildServerDnsConfig 用上', () {
    final saved = actions().add(
      name: '我的上游',
      protocol: DnsProtocol.dns,
      address: '9.9.9.9',
      port: 53,
    )!;
    container.read(serverSelectedUpstreamProvider.notifier).select(saved.id);

    final config = buildServerDnsConfig(container.read(legacySettingsProvider));
    expect(config.upstream.name, '我的上游');
    expect(config.upstream.address, '9.9.9.9');
  });

  test('encode 只写五个字段（与旧版序列化一致）', () {
    final json = encodeServerCustomUpstreams([
      const ServerUpstream(
        id: 'custom_x',
        name: 'X',
        protocol: DnsProtocol.dot,
        address: 'dot.example',
        port: 853,
      ),
    ]);
    expect(json, contains('"id"'));
    expect(json, contains('"name"'));
    expect(json, contains('"protocol"'));
    expect(json, contains('"address"'));
    expect(json, contains('"port"'));
    expect(json.contains('isCustom'), isFalse);
    expect(json, contains('DOT'));
  });

  group('validateServerUpstream', () {
    test('名称为空 → 拒绝', () {
      expect(
        validateServerUpstream(
          name: '',
          protocol: DnsProtocol.dns,
          address: '1.1.1.1',
          port: 53,
        ),
        isA<UpstreamInvalid>(),
      );
    });

    test('DoH 非 https → 拒绝', () {
      final result = validateServerUpstream(
        name: 'x',
        protocol: DnsProtocol.doh,
        address: 'dns.example.com',
        port: 443,
      );
      expect(result, isA<UpstreamInvalid>());
      expect((result as UpstreamInvalid).message, contains('https://'));
    });

    test('合法 DoH → 通过', () {
      expect(
        validateServerUpstream(
          name: 'x',
          protocol: DnsProtocol.doh,
          address: 'https://dns.example.com/dns-query',
          port: 443,
        ),
        isA<UpstreamOk>(),
      );
    });

    test('合法 DoT（853）→ 通过', () {
      expect(
        validateServerUpstream(
          name: 'x',
          protocol: DnsProtocol.dot,
          address: 'dot.example.com',
          port: 853,
        ),
        isA<UpstreamOk>(),
      );
    });

    test('方括号 IPv6 → 通过', () {
      expect(
        validateServerUpstream(
          name: 'x',
          protocol: DnsProtocol.dns,
          address: '[2001:db8::1]',
          port: 53,
        ),
        isA<UpstreamOk>(),
      );
    });

    test('端口 0 → 拒绝', () {
      expect(
        validateServerUpstream(
          name: 'x',
          protocol: DnsProtocol.dns,
          address: '1.1.1.1',
          port: 0,
        ),
        isA<UpstreamInvalid>(),
      );
    });
  });
}
