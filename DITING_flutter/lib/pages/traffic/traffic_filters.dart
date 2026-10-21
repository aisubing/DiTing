part of 'traffic_page.dart';

/// 时间窗口与排序的可选项：旧版多出的两档在本仓没有数据源，做成**禁用项**
/// 并说明原因——静默删除会让用户以为旧版也没这两个功能。
class _RangeOption {
  const _RangeOption({
    required this.label,
    this.window,
    this.unavailableReason,
  });

  final String label;

  /// `null` 表示这一档在本仓不可用（见 [unavailableReason]）。
  final TrafficWindow? window;

  final String? unavailableReason;
}

/// 旧版 `TrafficTimeRange` 五档，逐字对齐 `AppTrafficStatsModels.kt:5`。
///
/// 「本次会话」在本仓没有数据来源：那是一份进程内实时累计，而落库的
/// `app_traffic_daily` 只按天存一行（`AppTrafficRepository` 的注释里写明了）。
/// 这里把它显示成禁用项而不是删掉，用户仍能看出旧版有这一档。
const _rangeOptions = <_RangeOption>[
  _RangeOption(
    label: '本次会话',
    unavailableReason: '「本次会话」需要内核按会话回报流量，本仓只有按天落库的历史记录',
  ),
  _RangeOption(label: '今日', window: TrafficWindow.today),
  _RangeOption(label: '本周', window: TrafficWindow.week),
  _RangeOption(label: '本月', window: TrafficWindow.month),
  // 旧版 displayName 是「全部历史」，enum 里的简称是「全部」。
  _RangeOption(label: '全部历史', window: TrafficWindow.all),
];

/// 旧版 `TrafficSortMode` 四档，逐字对齐 `AppTrafficStatsModels.kt:13`。
const _sortOptions = <_SortOption>[
  _SortOption(label: '按总流量', sort: TrafficSort.total),
  _SortOption(label: '按下载流量', sort: TrafficSort.download),
  _SortOption(label: '按上传流量', sort: TrafficSort.upload),
  _SortOption(label: '按实时网速', unavailableReason: '「按实时网速」需要每秒速率，本仓的按天表里没有速率列'),
];

class _SortOption {
  const _SortOption({required this.label, this.sort, this.unavailableReason});

  final String label;
  final TrafficSort? sort;
  final String? unavailableReason;
}

/// 一个可选档位气泡。禁用档保留在行里，点击时说明为什么不可用。
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.unavailableReason,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final disabled = unavailableReason != null;
    final foreground = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
        : selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    return TonalChip(
      label: label,
      color: selected
          ? colorScheme.primary
          : context.raisedSurfaceLevel.colorOf(colorScheme),
      foregroundColor: foreground,
      // 禁用档也保留点击手势：点了要能弹出「为什么不可用」，而不是毫无反应。
      onPressed: disabled ? onPressed : (selected ? null : onPressed),
    );
  }
}

/// 筛选条：搜索 + 排序 + 隐藏系统应用（旧版 `TrafficFilterBar.kt`）。
///
/// 搜索放在正文里而不是顶栏：旧版就是正文里的一行 `RuleSearchField`，
/// 顶栏搜索按钮会把这一行挤掉，且与「排序、隐藏系统应用」分成两处不好用。
class _TrafficFilterBar extends StatelessWidget {
  const _TrafficFilterBar({
    required this.searchController,
    required this.sort,
    required this.hideSystemApps,
    required this.onSearchChanged,
    required this.onSortSelected,
    required this.onHideSystemAppsChanged,
  });

  final TextEditingController searchController;
  final TrafficSort sort;
  final bool hideSystemApps;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_SortOption> onSortSelected;
  final ValueChanged<bool> onHideSystemAppsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledInputTheme(
            child: TextField(
              controller: searchController,
              autocorrect: false,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: '搜索应用或包名...',
                prefixIcon: GlyphIcon(AppGlyphs.search),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in _sortOptions)
                _OptionChip(
                  label: option.label,
                  selected: option.sort == sort,
                  unavailableReason: option.unavailableReason,
                  onPressed: () => onSortSelected(option),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CommonCard(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: ListItem.toggle(
              leading: const GlyphIcon(AppGlyphs.appsList, size: 20),
              title: const Text('隐藏系统应用'),
              subtitle: const Text('按系统应用标记与厂商预装前缀识别，隐藏后不计入排行'),
              value: hideSystemApps,
              onChanged: (value) => onHideSystemAppsChanged(value),
            ),
          ),
        ),
      ],
    );
  }
}

/// 归因说明入口（旧版 `AttributionBannerCard`）。
class _AttributionBanner extends StatelessWidget {
  const _AttributionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonCard(
        onPressed: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            GlyphIcon(AppGlyphs.info, size: 18, color: colorScheme.warning),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text('为什么系统设置将全部流量算给谛听？', style: context.listTitleStyle),
                  Text(
                    '因 Android VPN 机制，系统将代理出站归属于守护进程。'
                    '谛听自身不偷跑流量，点按查看统计口径。',
                    style: context.listCaptionStyle,
                  ),
                ],
              ),
            ),
            GlyphIcon(
              AppGlyphs.chevronForward,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 「实时速率」位置的**如实占位**。
///
/// 旧版这里是一张 `TrafficGaugeCard`：标题「实时速率」+ 上下行 B/s。本仓没有
/// 每秒速率来源（引擎只报累计字节数），所以既不留一个没有数字的标题，也不画
/// 假曲线——只说明缺什么、真实数字在哪。
class _RateUnavailableCard extends StatelessWidget {
  const _RateUnavailableCard({required this.windowLabel});

  final String windowLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  AppGlyphs.speed,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                Text('实时速率', style: context.listTitleStyle),
              ],
            ),
            Text(
              '暂无实时速率：它需要内核每秒回报的速率序列，本仓的按天流量表只存'
              '「日期 + 包名 + 上下行累计字节」。上面的 $windowLabel 下行 / 上行'
              '与下方排行都是真实数字。',
              style: context.listCaptionStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// 旧版 `SystemAppClassifier.isKnownSystemPackagePrefix` 的逐条转写。
///
/// 流量表里没有 `isSystem` 列，旧版也是用这份前缀表兜底（见
/// `AppTrafficStatsViewModel.isSystemApp` 的第 2 步）。
const _knownSystemPrefixes = <String>[
  'android',
  'com.android.',
  'android.uid.',
  'com.google.android.gms',
  'com.google.android.gsf',
  'com.google.android.ext.services',
  'com.google.android.networkstack',
  'com.google.android.providers.media.module',
  // 小米 / HyperOS / MIUI
  'com.miui.',
  'com.xiaomi.',
  // 华为 / 荣耀
  'com.huawei.',
  'com.hihonor.',
  // OPPO / 一加 / realme
  'com.coloros.',
  'com.heytap.',
  'com.oplus.',
  // vivo / iQOO
  'com.vivo.',
  'com.bbk.',
  // 三星 One UI
  'com.samsung.',
  'com.sec.',
  // 联想 / 摩托罗拉
  'com.lenovo.',
  'com.motorola.',
  // 魅族 Flyme
  'com.meizu.',
  // 芯片与底层硬件服务
  'com.qualcomm.',
  'com.qti.',
  'com.mediatek.',
];

bool isKnownSystemPackagePrefix(String packageName) {
  if (packageName.trim().isEmpty) return false;
  if (packageName == 'android') return true;
  for (final prefix in _knownSystemPrefixes) {
    if (packageName.startsWith(prefix)) return true;
  }
  return false;
}
