/// 系统域演示数据：访问控制应用表 / 免责条款 / 开发者选项 / 更新日志。
///
/// 数据层不依赖 widget 层，所以图标用 `AppGlyphs` 的常量名字符串记录，由页面
/// 侧的 `glyphByName` 解析（与 `lib/data/mock_data.dart` 同一约定）。
library;

/// 一个可授权的应用。
class MockPackage {
  const MockPackage({
    required this.name,
    required this.packageName,
    required this.category,
    required this.glyphName,
    this.isSystem = false,
    this.hasNetwork = true,
    this.installOrder = 0,
  });

  final String name;
  final String packageName;
  final String category;
  final String glyphName;

  /// 系统应用；访问控制默认把它们折叠掉。
  final bool isSystem;

  /// 没有网络权限的应用不会产生 DNS 请求，默认也应折叠。
  final bool hasNetwork;

  /// 安装顺序；`AccessSort.time` 用它排序，数字越小越新装。
  final int installOrder;
}

/// 访问控制列表。
///
/// 故意混入两个系统应用与一个无网络权限的应用，这样「来源」分组里的两个
/// 开关才有肉眼可见的效果——否则演示页上它们看起来像是坏的。
const mockPackages = <MockPackage>[
  MockPackage(
    name: '浏览器',
    packageName: 'com.example.browser',
    category: '工具',
    glyphName: 'language',
    installOrder: 0,
  ),
  MockPackage(
    name: '视频',
    packageName: 'com.example.video',
    category: '娱乐',
    glyphName: 'playPause',
    installOrder: 1,
  ),
  MockPackage(
    name: '即时通讯',
    packageName: 'com.example.im',
    category: '社交',
    glyphName: 'send',
    installOrder: 2,
  ),
  MockPackage(
    name: '应用商店',
    packageName: 'com.example.store',
    category: '工具',
    glyphName: 'cloudDownload',
    installOrder: 3,
  ),
  MockPackage(
    name: '邮件',
    packageName: 'com.example.mail',
    category: '办公',
    glyphName: 'cloudSync',
    installOrder: 4,
  ),
  MockPackage(
    name: '音乐',
    packageName: 'com.example.music',
    category: '娱乐',
    glyphName: 'playPause',
    installOrder: 5,
  ),
  MockPackage(
    name: '地图',
    packageName: 'com.example.maps',
    category: '出行',
    glyphName: 'locate',
    installOrder: 6,
  ),
  MockPackage(
    name: '记事本',
    packageName: 'com.example.notes',
    category: '办公',
    glyphName: 'compose',
    installOrder: 7,
  ),
  MockPackage(
    name: '天气',
    packageName: 'com.example.weather',
    category: '生活',
    glyphName: 'sun',
    installOrder: 8,
  ),
  MockPackage(
    name: '相机',
    packageName: 'com.example.camera',
    category: '系统',
    glyphName: 'camera',
    installOrder: 9,
  ),
  MockPackage(
    name: '系统更新',
    packageName: 'com.android.updater',
    category: '系统',
    glyphName: 'refresh',
    isSystem: true,
    installOrder: 10,
  ),
  MockPackage(
    name: '设置',
    packageName: 'com.android.settings',
    category: '系统',
    glyphName: 'settings',
    isSystem: true,
    installOrder: 11,
  ),
  MockPackage(
    name: '离线词典',
    packageName: 'com.example.dictionary',
    category: '工具',
    glyphName: 'textShort',
    hasNetwork: false,
    installOrder: 12,
  ),
];

/// 免责声明的一段条款。
class MockDisclaimerTerm {
  const MockDisclaimerTerm({required this.title, required this.content});

  final String title;
  final String content;
}

/// 上游 `disclaimer.dart` 的十段条款，一一对应（`_terms()`）。
const mockDisclaimerTerms = <MockDisclaimerTerm>[
  MockDisclaimerTerm(
    title: '一、软件性质',
    content:
        '谛听是一款开源的本地域名解析与流量观测工具，不以任何形式提供网络接入服务。'
        '软件本身不含任何服务器、节点或订阅内容，也不代替任何网络服务商。',
  ),
  MockDisclaimerTerm(
    title: '二、使用方式',
    content:
        '用户应仅在自有设备与自有网络上使用本软件。将本软件用于任何网络接入、'
        '绕过计费或在未授权网络上运行的行为，均超出软件设计用途。',
  ),
  MockDisclaimerTerm(
    title: '三、责任范围',
    content:
        '因使用或无法使用本软件导致的任何直接或间接损失，包括但不限于数据丢失、'
        '服务中断、设备损坏，作者与贡献者均不承担责任。',
  ),
  MockDisclaimerTerm(
    title: '四、第三方组件',
    content:
        '本软件的界面组件层移植自 DITING（GPL-3.0-or-later），'
        '并使用了 JetBrains Mono、Twemoji 等第三方资源。各组件的许可条款见仓库 '
        'NOTICE.md，使用本软件即表示同时接受这些条款。',
  ),
  MockDisclaimerTerm(
    title: '五、无担保',
    content:
        '本软件按「现状」提供，不附带任何明示或暗示的担保，'
        '包括但不限于适销性、特定用途适用性与不侵权的担保。',
  ),
  MockDisclaimerTerm(
    title: '六、责任限制',
    content:
        '在法律允许的最大范围内，作者不对任何间接、附带、特殊或后果性损害负责，'
        '即使已被告知此类损害的可能性。',
  ),
  MockDisclaimerTerm(
    title: '七、隐私',
    content:
        '本软件默认不收集、不上传任何用户数据。日志与规则仅保存在本地；'
        '若用户主动配置 WebDAV 备份，数据将上传至用户自行指定的服务器。',
  ),
  MockDisclaimerTerm(
    title: '八、许可',
    content:
        '本软件以 GPL-3.0-or-later 发布。你可以自由使用、修改与再分发，'
        '但衍生作品必须沿用同一许可并保留原始版权声明。',
  ),
  MockDisclaimerTerm(
    title: '九、条款变更',
    content:
        '作者保留随时修改本免责声明的权利。变更后的条款随新版本一同发布，'
        '继续使用即视为接受修改后的条款。',
  ),
  MockDisclaimerTerm(
    title: '十、接受条款',
    content:
        '在继续使用本软件前，请确认你已阅读、理解并同意上述全部条款。'
        '若不同意，请立即停止使用并卸载本软件。',
  ),
];

/// 开发者模式下的一个实验动作。
class MockDeveloperAction {
  const MockDeveloperAction({
    required this.title,
    required this.subtitle,
    required this.glyphName,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final String glyphName;

  /// 危险动作（清空数据等）用错误色，并在执行前二次确认。
  final bool destructive;
}

const mockDeveloperActions = <MockDeveloperAction>[
  MockDeveloperAction(
    title: '消息测试',
    subtitle: '依次弹出成功 / 警告 / 错误三种反馈',
    glyphName: 'info',
  ),
  MockDeveloperAction(
    title: '日志压测',
    subtitle: '一次写入 1000 条随机日志',
    glyphName: 'logs',
  ),
  MockDeveloperAction(
    title: '崩溃核心',
    subtitle: '演示致命错误弹窗（不会真的崩溃）',
    glyphName: 'error',
    destructive: true,
  ),
  MockDeveloperAction(
    title: '清空全部数据',
    subtitle: '删除配置、规则与日志，恢复出厂状态',
    glyphName: 'clearAll',
    destructive: true,
  ),
  MockDeveloperAction(
    title: '压缩数据库',
    subtitle: '回收已删除记录占用的空间',
    glyphName: 'memory',
  ),
];

/// 恢复备份时可勾选的恢复项。
enum RestoreOption {
  config('配置与设置'),
  rules('规则与订阅'),
  logs('日志与统计'),
  profiles('配置档案');

  const RestoreOption(this.label);

  final String label;

  String get description => switch (this) {
    config => '外观、底栏、解析模式等全部应用设置',
    rules => '黑名单 / 白名单 / 覆写规则与订阅地址',
    logs => '历史查询日志与流量统计',
    profiles => '导入过的配置文件与自定义节点',
  };
}
