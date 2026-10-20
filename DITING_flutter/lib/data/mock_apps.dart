part of 'mock_data.dart';

/// 应用流量排行。
class MockAppTraffic {
  const MockAppTraffic({
    required this.name,
    required this.packageName,
    required this.bytes,
    required this.queries,
    required this.iconGlyphName,
  });

  final String name;
  final String packageName;
  final int bytes;
  final int queries;
  final String iconGlyphName;
}

const mockAppTraffic = <MockAppTraffic>[
  MockAppTraffic(
    name: '浏览器',
    packageName: 'com.example.browser',
    bytes: 428_000_000,
    queries: 8214,
    iconGlyphName: 'language',
  ),
  MockAppTraffic(
    name: '视频',
    packageName: 'com.example.video',
    bytes: 1_284_000_000,
    queries: 3120,
    iconGlyphName: 'playPause',
  ),
  MockAppTraffic(
    name: '即时通讯',
    packageName: 'com.example.im',
    bytes: 96_400_000,
    queries: 2740,
    iconGlyphName: 'send',
  ),
  MockAppTraffic(
    name: '应用商店',
    packageName: 'com.example.store',
    bytes: 742_000_000,
    queries: 1180,
    iconGlyphName: 'cloudDownload',
  ),
  MockAppTraffic(
    name: '邮件',
    packageName: 'com.example.mail',
    bytes: 12_800_000,
    queries: 642,
    iconGlyphName: 'cloudSync',
  ),
  MockAppTraffic(
    name: '系统更新',
    packageName: 'com.android.updater',
    bytes: 318_000_000,
    queries: 84,
    iconGlyphName: 'refresh',
  ),
];

/// 已安装应用（应用选择页）。
class MockInstalledApp {
  const MockInstalledApp({
    required this.name,
    required this.packageName,
    required this.category,
  });

  final String name;
  final String packageName;
  final String category;
}

const mockInstalledApps = <MockInstalledApp>[
  MockInstalledApp(name: '浏览器', packageName: 'com.example.browser', category: '工具'),
  MockInstalledApp(name: '视频', packageName: 'com.example.video', category: '娱乐'),
  MockInstalledApp(name: '即时通讯', packageName: 'com.example.im', category: '社交'),
  MockInstalledApp(name: '应用商店', packageName: 'com.example.store', category: '工具'),
  MockInstalledApp(name: '邮件', packageName: 'com.example.mail', category: '办公'),
  MockInstalledApp(name: '音乐', packageName: 'com.example.music', category: '娱乐'),
  MockInstalledApp(name: '地图', packageName: 'com.example.maps', category: '出行'),
  MockInstalledApp(name: '相机', packageName: 'com.example.camera', category: '系统'),
  MockInstalledApp(name: '记事本', packageName: 'com.example.notes', category: '办公'),
  MockInstalledApp(name: '天气', packageName: 'com.example.weather', category: '生活'),
  MockInstalledApp(name: '阅读', packageName: 'com.example.reader', category: '阅读'),
  MockInstalledApp(name: '游戏中心', packageName: 'com.example.games', category: '游戏'),
];

/// 流量环形图 / 实时速率的采样序列（KB/s）。
const mockTrafficSamples = <double>[
  182, 240, 198, 320, 412, 388, 296, 344, 508, 462,
  398, 274, 318, 402, 486, 522, 448, 372, 296, 340,
  418, 364, 288, 246, 312, 396, 442, 386, 322, 268,
];

/// 设置页的五个透明度滑杆值域（0.1–1.0，`steps: 8`）。
const opacitySliderSteps = 8;
const opacitySliderMin = 0.1;
const opacitySliderMax = 1.0;
