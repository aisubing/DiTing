/// Font family options shown by the appearance settings page.
library;

/// Font family options. Only JetBrainsMono and Twemoji ship with the app; other names fall back to
/// the system default.
class MockFontFamily {
  const MockFontFamily({
    required this.family,
    required this.label,
    required this.description,
    this.bundled = false,
  });

  /// Value for `TextStyle.fontFamily`; null means the system default.
  final String? family;
  final String label;
  final String description;

  final bool bundled;
}

const mockFontFamilies = <MockFontFamily>[
  MockFontFamily(
    family: null,
    label: '系统默认',
    description: '跟随宿主平台的中文界面字体，最稳妥的选择',
  ),
  MockFontFamily(
    family: 'JetBrainsMono',
    label: 'JetBrains Mono',
    description: '等宽，日志与规则列表的默认字体',
    bundled: true,
  ),
  MockFontFamily(
    family: 'Twemoji',
    label: 'Twemoji',
    description: '彩色 Emoji 字体，只影响表情符号',
    bundled: true,
  ),
  MockFontFamily(
    family: 'HarmonyOS Sans SC',
    label: 'HarmonyOS Sans SC',
    description: '鸿蒙系统中文黑体，仅在该系统可用',
  ),
  MockFontFamily(
    family: 'MiSans',
    label: 'MiSans',
    description: '小米系统字体，部分机型预装',
  ),
  MockFontFamily(
    family: 'Noto Sans SC',
    label: 'Noto Sans SC',
    description: 'Android 常见预装中文无衬线体',
  ),
  MockFontFamily(
    family: 'Source Han Serif SC',
    label: '思源宋体',
    description: '衬线中文字体，正文阅读更接近纸面',
  ),
  MockFontFamily(
    family: 'Courier New',
    label: 'Courier New',
    description: '经典等宽英文字体，中文会回退',
  ),
];
