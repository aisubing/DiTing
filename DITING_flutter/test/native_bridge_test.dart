import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/data/native/outbound_proxy_bridge.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// 三条原生通道的 Dart 侧守门。
///
/// 这层不做 UI，只钉住「契约本身」——校验顺序、JSON 形状、枚举回落和空实现。
/// 它们全是纯函数，因此不需要 MethodChannel 也不需要插件注册：真的把断言跑到
/// channel 上只会得到 `MissingPluginException`，什么也证明不了。
void main() {
  group('OutboundProxyConfig.validationError', () {
    /// 合法基线：每条例只改一个字段，失败时能直接看出是哪一条判据错了。
    OutboundProxyConfig base({
      String host = '127.0.0.1',
      int port = 7890,
      String proxyAppPackage = 'com.other.app',
      String username = '',
      String password = '',
    }) => OutboundProxyConfig(
      enabled: true,
      host: host,
      port: port,
      proxyAppPackage: proxyAppPackage,
      username: username,
      password: password,
    );

    const self = 'com.haoze.diting';
    const installed = {'com.other.app'};

    test('合法配置没有错误', () {
      expect(
        base().validationError(
          selfPackage: self,
          installedPackages: installed,
        ),
        isNull,
      );
    });

    test('::1 与 127.0.0.1 都接受，其余一律拒绝', () {
      for (final host in ['127.0.0.1', '::1']) {
        expect(
          base(host: host).validationError(selfPackage: self),
          isNull,
          reason: '$host 是合法的回环地址',
        );
      }
      for (final host in ['localhost', '0.0.0.0', '192.168.1.1', '[::1]', '']) {
        expect(
          base(host: host).validationError(selfPackage: self),
          '代理地址仅支持 127.0.0.1 或 ::1',
          reason: '$host 不该被接受',
        );
      }
    });

    test('端口边界：0 与 65536 拒绝，1 与 65535 接受', () {
      for (final port in [0, 65536, -1, 100000]) {
        expect(
          base(port: port).validationError(selfPackage: self),
          '代理端口必须在 1 到 65535 之间',
          reason: '$port 越界',
        );
      }
      for (final port in [1, 65535]) {
        expect(base(port: port).validationError(selfPackage: self), isNull);
      }
    });

    test('代理应用为空（含纯空白）报「请选择」', () {
      for (final value in ['', '   ', '\t']) {
        expect(
          base(proxyAppPackage: value).validationError(selfPackage: self),
          '请选择提供本地代理端口的应用',
        );
      }
    });

    test('不能选谛听自身', () {
      expect(
        base(proxyAppPackage: self).validationError(selfPackage: self),
        '不能选择 DITING 自身作为代理应用',
      );
    });

    test('未安装的应用报「未安装」', () {
      expect(
        base(proxyAppPackage: 'com.gone.app').validationError(
          selfPackage: self,
          installedPackages: installed,
        ),
        '所选代理应用未安装',
      );
    });

    test('installedPackages 为 null 时跳过「未安装」判据', () {
      // 枚举失败（通道缺失）不等于「没装」；此时应当放行而不是拦住保存。
      expect(
        base(proxyAppPackage: 'com.gone.app').validationError(
          selfPackage: self,
          installedPackages: null,
        ),
        isNull,
      );
    });

    test('账号或密码 256 个字符报「过长」，255 通过', () {
      final ok = 'a' * 255;
      final tooLong = 'a' * 256;
      expect(base(username: ok).validationError(selfPackage: self), isNull);
      expect(base(password: ok).validationError(selfPackage: self), isNull);
      expect(
        base(username: tooLong).validationError(selfPackage: self),
        '代理账号或密码过长',
      );
      expect(
        base(password: tooLong).validationError(selfPackage: self),
        '代理账号或密码过长',
      );
    });

    test('判据顺序：地址先于端口、端口先于应用', () {
      // 上游按顺序返回第一条错误，界面文案也因此固定；顺序被换掉会让人看到
      // 「请选择应用」而不是真正的地址写错。
      expect(
        OutboundProxyConfig(enabled: true, host: 'bad', port: 0, proxyAppPackage: '')
            .validationError(selfPackage: self),
        '代理地址仅支持 127.0.0.1 或 ::1',
      );
      expect(
        OutboundProxyConfig(enabled: true, port: 0, proxyAppPackage: '')
            .validationError(selfPackage: self),
        '代理端口必须在 1 到 65535 之间',
      );
    });
  });

  group('OutboundProxyConfig.toEngineJson', () {
    test('protocol 用小写 storageValue', () {
      expect(
        const OutboundProxyConfig(protocol: OutboundProxyProtocol.socks5)
            .toEngineJson(),
        contains('"protocol":"socks5"'),
      );
      expect(
        const OutboundProxyConfig(protocol: OutboundProxyProtocol.http)
            .toEngineJson(),
        contains('"protocol":"http"'),
      );
    });

    test('enabled 是布尔而不是字符串', () {
      final json = const OutboundProxyConfig(enabled: true).toEngineJson();
      expect(json, contains('"enabled":true'));
      expect(json, isNot(contains('"enabled":"true"')));
    });

    test('密码里的引号与反斜杠被正确转义', () {
      const config = OutboundProxyConfig(
        username: r'us"er\name',
        password: r'p@ss"wor\d',
      );
      final json = config.toEngineJson();
      // 反斜杠先转成 \\，引号转成 \" —— 顺序反了会产出 \\"，JSON 直接坏掉。
      expect(json, contains(r'"username":"us\"er\\name"'));
      expect(json, contains(r'"password":"p@ss\"wor\\d"'));
    });

    test('字段集合固定且顺序稳定', () {
      final json = const OutboundProxyConfig().toEngineJson();
      expect(
        json,
        '{"enabled":false,"protocol":"socks5","host":"127.0.0.1",'
        '"port":7890,"username":"","password":""}',
      );
    });

    test('port 必须是 JSON 数字，不能带引号', () {
      // 回归：Go 侧 `outboundProxyConfig.Port int`（`Android/tunnel/flow_outbound.go:29`）
      // 由 `json.Unmarshal` 解析，`"port":"7890"` 会整份配置解析失败，
      // `Engine.configureOutboundProxy` 返回错误后代理静默不生效。1.4.3 的
      // Kotlin 生产者（`OutboundProxyConfig.toNativeJson`）写的是数字。
      for (final port in [1, 7890, 65535]) {
        final json = OutboundProxyConfig(port: port).toEngineJson();
        expect(json, contains('"port":$port,'));
        expect(json, isNot(contains('"port":"$port"')));
      }
    });
  });

  group('OutboundProxyProtocol.fromStorageValue', () {
    test('已知值原样映射', () {
      expect(
        OutboundProxyProtocol.fromStorageValue('socks5'),
        OutboundProxyProtocol.socks5,
      );
      expect(
        OutboundProxyProtocol.fromStorageValue('http'),
        OutboundProxyProtocol.http,
      );
    });

    test('未知值与 null 回落到 socks5', () {
      for (final value in ['quic', 'SOCKS5', 'HTTP', '', null]) {
        expect(
          OutboundProxyProtocol.fromStorageValue(value),
          OutboundProxyProtocol.socks5,
          reason: '$value 应当回落到 socks5',
        );
      }
    });
  });

  group('CaCertificateState.ready', () {
    test('只有 available 且 installed 同时为真才 ready', () {
      expect(
        const CaCertificateState(available: true, installed: true).ready,
        isTrue,
      );
      expect(
        const CaCertificateState(available: true, installed: false).ready,
        isFalse,
      );
      expect(
        const CaCertificateState(available: false, installed: true).ready,
        isFalse,
      );
      expect(
        const CaCertificateState(available: false, installed: false).ready,
        isFalse,
      );
    });

    test('missing() 一定不 ready', () {
      expect(const CaCertificateState.missing().ready, isFalse);
      expect(const CaCertificateState.missing().available, isFalse);
      expect(const CaCertificateState.missing().fingerprintSha256, isNull);
    });

    test('fromMap 只认 boolean true', () {
      final state = CaCertificateState.fromMap({
        'available': true,
        'installed': 'true', // 字符串不是 true
        'fingerprintSha256': 'AB:CD',
        'pem': 'PEM',
        'error': null,
      });
      expect(state.available, isTrue);
      expect(state.installed, isFalse);
      expect(state.ready, isFalse);
      expect(state.fingerprintSha256, 'AB:CD');
      expect(state.pem, 'PEM');
    });

    test('空 map 得到全 false', () {
      final state = CaCertificateState.fromMap(const {});
      expect(state.available, isFalse);
      expect(state.installed, isFalse);
      expect(state.error, isNull);
    });
  });

  group('InstalledApp.matches', () {
    const app = InstalledApp(
      packageName: 'com.Example.Maps',
      label: '地图 Maps',
      isSystem: false,
      uid: 10123,
    );

    test('空查询匹配一切', () {
      expect(app.matches(''), isTrue);
    });

    test('匹配标签与包名，大小写不敏感', () {
      for (final query in [
        '地图',
        'maps',
        'MAPS',
        'com.example',
        'COM.EXAMPLE.MAPS',
        'example',
      ]) {
        expect(app.matches(query), isTrue, reason: '$query 应当命中');
      }
    });

    test('不匹配的内容返回 false', () {
      for (final query in ['邮箱', 'com.other', ' 地图']) {
        // 前导空格不做 trim：页面在防抖回调里已经 trim 过，这里保持原样匹配，
        // 避免两处都 trim 却不一致。
        expect(app.matches(query), isFalse, reason: '$query 不该命中');
      }
    });
  });

  group('InstalledApp.fromMap', () {
    test('缺失字段取安全默认值', () {
      final app = InstalledApp.fromMap(const {});
      expect(app.packageName, '');
      expect(app.label, '');
      expect(app.isSystem, isFalse);
      expect(app.uid, -1);
    });

    test('isSystem 只认 boolean true，uid 接受 num', () {
      final app = InstalledApp.fromMap(const {
        'packageName': 'com.x',
        'label': 'X',
        'isSystem': 1,
        'uid': 10001.0,
      });
      expect(app.isSystem, isFalse);
      expect(app.uid, 10001);
    });
  });

  group('EmptyInstalledAppsSource', () {
    test('list / resolveUids / isSelf 都不抛', () async {
      const source = EmptyInstalledAppsSource();
      expect(await source.list(), isEmpty);
      expect(await source.resolveUids(['com.x']), isEmpty);
      expect(await source.isSelf('com.haoze.diting'), isFalse);
    });

    test('resolveUids 对空入参也返回空 map', () async {
      const source = EmptyInstalledAppsSource();
      expect(await source.resolveUids(const []), isEmpty);
    });
  });

  group('AppListFilter / AppListSort', () {
    const system = InstalledApp(
      packageName: 'com.android.systemui',
      label: 'System UI',
      isSystem: true,
      uid: 1000,
    );
    const userA = InstalledApp(
      packageName: 'com.b.app',
      label: 'Alpha',
      isSystem: false,
      uid: 10101,
    );
    const userB = InstalledApp(
      packageName: 'com.a.app',
      label: 'beta',
      isSystem: false,
      uid: 10102,
    );

    test('过滤枚举与 1.4.3 的四个名字一致', () {
      expect(
        AppListFilter.values.map((item) => item.storageValue),
        ['ALL', 'SYSTEM', 'USER', 'SELECTED'],
      );
      expect(
        AppListSort.values.map((item) => item.storageValue),
        ['LABEL_ASC', 'LABEL_DESC', 'PACKAGE_ASC', 'PACKAGE_DESC'],
      );
    });

    test('未知存储值回落到 USER / LABEL_ASC', () {
      expect(AppListFilter.fromStorageValue('SOMETHING'), AppListFilter.user);
      expect(AppListFilter.fromStorageValue(null), AppListFilter.user);
      expect(AppListSort.fromStorageValue('RANDOM'), AppListSort.labelAsc);
    });

    test('system / user 按 isSystem 分档，selected 按集合', () {
      expect(AppListFilter.system.accept(system, const {}), isTrue);
      expect(AppListFilter.system.accept(userA, const {}), isFalse);
      expect(AppListFilter.user.accept(userA, const {}), isTrue);
      expect(AppListFilter.user.accept(system, const {}), isFalse);
      expect(
        AppListFilter.selected.accept(userA, const {'com.b.app'}),
        isTrue,
      );
      expect(AppListFilter.selected.accept(userA, const {}), isFalse);
    });

    test('排序：标签升/降序，同级用包名升序兜底', () {
      final apps = [system, userA, userB];
      final asc = [...apps]..sort(AppListSort.labelAsc.compare);
      // 'Alpha' < 'beta' < 'System UI'（比较前统一小写）。
      expect(asc.map((app) => app.label), ['Alpha', 'beta', 'System UI']);
      final desc = [...apps]..sort(AppListSort.labelDesc.compare);
      expect(desc.map((app) => app.label), ['System UI', 'beta', 'Alpha']);
      final byPackage = [...apps]..sort(AppListSort.packageAsc.compare);
      // 逐字符比较：'com.a.app' 与 'com.android.systemui' 在 'com.a' 后分岔，
      // '.'(46) < 'n'(110)，所以前者更小；'com.android…' 的 'a' 又小于 'com.b'。
      expect(byPackage.map((app) => app.packageName), [
        'com.a.app',
        'com.android.systemui',
        'com.b.app',
      ]);
      final byPackageDesc = [...apps]..sort(AppListSort.packageDesc.compare);
      expect(byPackageDesc.map((app) => app.packageName), [
        'com.b.app',
        'com.android.systemui',
        'com.a.app',
      ]);
    });

    test('visibleInstalledApps 同时应用过滤、搜索与排序', () {
      final visible = visibleInstalledApps(
        apps: [system, userA, userB],
        query: 'app',
        filter: AppListFilter.user,
        sort: AppListSort.packageAsc,
        selected: const {},
      );
      expect(visible.map((app) => app.packageName), ['com.a.app', 'com.b.app']);
    });

    test('SELECTED 过滤配合搜索只留下命中的已选项', () {
      final visible = visibleInstalledApps(
        apps: [system, userA, userB],
        query: 'beta',
        filter: AppListFilter.selected,
        sort: AppListSort.labelAsc,
        selected: const {'com.a.app', 'com.b.app'},
      );
      expect(visible.map((app) => app.packageName), ['com.a.app']);
    });
  });
}
