part of 'mock_data.dart';

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

/// No mock installed-app list: the `com.haoze.diting/apps` channel replaced it.

/// Sampled traffic curve for the donut chart and live rate, in KB/s.
const mockTrafficSamples = <double>[
  182,
  240,
  198,
  320,
  412,
  388,
  296,
  344,
  508,
  462,
  398,
  274,
  318,
  402,
  486,
  522,
  448,
  372,
  296,
  340,
  418,
  364,
  288,
  246,
  312,
  396,
  442,
  386,
  322,
  268,
];

/// Value range of the five transparency sliders (0.1 to 1.0, `steps: 8`).
const opacitySliderSteps = 8;
const opacitySliderMin = 0.1;
const opacitySliderMax = 1.0;
