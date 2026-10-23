part of 'traffic_page.dart';

/// Ranges with no data source stay visible but disabled, so upstream parity stays visible.
class _RangeOption {
  const _RangeOption({
    required this.label,
    this.window,
    this.unavailableReason,
  });

  final String label;

  /// null means this option is unavailable in this build (see [unavailableReason]).
  final TrafficWindow? window;

  final String? unavailableReason;
}

/// The five upstream TrafficTimeRange values. "This session" has no source here: the daily
/// table stores one row per app per day, with no in-process running total.
const _rangeOptions = <_RangeOption>[
  _RangeOption(
    label: '本次会话',
    unavailableReason: '「本次会话」需要内核按会话回报流量，本仓只有按天落库的历史记录',
  ),
  _RangeOption(label: '今日', window: TrafficWindow.today),
  _RangeOption(label: '本周', window: TrafficWindow.week),
  _RangeOption(label: '本月', window: TrafficWindow.month),
  _RangeOption(label: '全部历史', window: TrafficWindow.all),
];

/// The four upstream TrafficSortMode values, matching AppTrafficStatsModels.kt.
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

/// Filter bar: search, sort, hide system apps (upstream TrafficFilterBar.kt). Search sits
/// in the body rather than the app bar, matching upstream's inline RuleSearchField.
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
          // Same ChipRow shape as the range row above: a bare Wrap leaves TonalChip at its
          // 18dp text height, and it wraps to a second line on narrow screens.
          child: ChipRow(
            children: [
              for (final option in _sortOptions)
                FilterPill(
                  label: option.label,
                  selected: option.sort == sort,
                  disabled: option.unavailableReason != null,
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

/// Attribution explainer entry (upstream AttributionBannerCard).
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

/// Live rate block: show the native rate when available, otherwise say so. The monitor only
/// covers the current session, so the label must say "this session".
class _LiveRateCard extends ConsumerWidget {
  const _LiveRateCard({required this.windowLabel});

  final String windowLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final series = ref.watch(speedSeriesProvider);
    final last = series.last;
    final missing = series.unsupported;
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
            if (missing)
              Text(
                '本模式不统计实时速率：极速模式的窄路由不经过引擎的流量计数器，'
                '本仓也没有它的累计表。上面的 $windowLabel 下行 / 上行与下方排行'
                '都是真实数字。',
                style: context.listCaptionStyle,
              )
            else ...[
              Text(
                series.samples.isEmpty
                    ? '—'
                    : '↓ ${obsFormatBytes(last.down.round())} /s   '
                          '↑ ${obsFormatBytes(last.up.round())} /s',
                style: context.listTitleStyle,
              ),
              Text(
                '来自引擎的每秒速率（本次会话），与常驻通知里的读数同源；'
                '上面的 $windowLabel 下行 / 上行是 `app_traffic_daily` 的累计字节，'
                '两者口径不同，数字不必相等。',
                style: context.listCaptionStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Package-prefix fallback for system apps. The traffic table has no isSystem column, so
/// upstream also falls back to this list (AppTrafficStatsViewModel.isSystemApp).
const _knownSystemPrefixes = <String>[
  'android',
  'com.android.',
  'android.uid.',
  'com.google.android.gms',
  'com.google.android.gsf',
  'com.google.android.ext.services',
  'com.google.android.networkstack',
  'com.google.android.providers.media.module',
  'com.miui.',
  'com.xiaomi.',
  'com.huawei.',
  'com.hihonor.',
  'com.coloros.',
  'com.heytap.',
  'com.oplus.',
  'com.vivo.',
  'com.bbk.',
  'com.samsung.',
  'com.sec.',
  'com.lenovo.',
  'com.motorola.',
  'com.meizu.',
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