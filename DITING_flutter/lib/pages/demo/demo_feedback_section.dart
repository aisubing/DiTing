part of 'demo_page.dart';

/// 反馈分区：验证 [CommonCircleLoading]、[NullStatus] 四种插画、
/// [SkeletonText] / [SkeletonPill] 骨架、[LineChart] 曲线，
/// 以及 [StatStrip] / [KeyValueRow] / [SectionBlock] 三个拼装件。
///
/// 这一区里的加载环与骨架屏都是**无限循环动画**：只要它们所在的 ticker 是活的，
/// 之后任何 `pumpAndSettle` 都永远等不到静止，整页会变成一个「测试黑洞」。
/// 所以整区套一层 [TickerMode]，默认关闭动画（首帧仍然是正确的静态形态），
/// 想看动效时点一下开关即可。
class _DemoFeedbackSection extends StatefulWidget {
  const _DemoFeedbackSection();

  @override
  State<_DemoFeedbackSection> createState() => _DemoFeedbackSectionState();
}

class _DemoFeedbackSectionState extends State<_DemoFeedbackSection> {
  bool _isLoading = false;
  bool _animate = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DemoAnimateSwitch(
          value: _animate,
          onChanged: (value) => setState(() => _animate = value),
        ),
        TickerMode(
          enabled: _animate,
          child: _DemoSectionBody(
            children: [
              const _DemoLabel(
                'CommonCircleLoading',
                trailing: 'size / color / page',
              ),
              _DemoLoadings(loading: _isLoading, onToggle: _toggleLoading),
              const _DemoLabel(
                'NullStatus · 四种插画',
                trailing: 'NullStatusIllustration',
              ),
              const _DemoNullStatuses(),
              const _DemoLabel('SkeletonText / SkeletonPill', trailing: '骨架屏'),
              const _DemoSkeletons(),
              const _DemoLabel(
                'LineChart',
                trailing: 'values / revision / capacity',
              ),
              const _DemoLineChart(),
              const _DemoLabel(
                'StatStrip / KeyValueRow / SectionBlock',
                trailing: '拼装件',
              ),
              const _DemoStats(),
              const _DemoLabel(
                'CommonScrollBar',
                trailing: 'thumbVisibility / onScrub',
              ),
              const _DemoScrollBar(),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleLoading() => setState(() => _isLoading = !_isLoading);
}

/// 循环动画总开关。默认关：`TickerMode(enabled: false)` 会让加载环与骨架屏
/// 停在首帧，既能看到正确的静态形态，又不会让 `pumpAndSettle` 卡死。
class _DemoAnimateSwitch extends StatelessWidget {
  const _DemoAnimateSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return _DemoSectionBody(
      children: [
        CommonCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onPressed: () => onChanged(!value),
          child: Row(
            spacing: 10,
            children: [
              const GlyphIcon(AppGlyphs.motion, size: commonCardIconSize),
              Expanded(
                child: Text(
                  value ? '循环动画：播放中' : '循环动画：暂停（默认）',
                  style: AppTextStyle.footnote.of(context),
                ),
              ),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
        Text(
          '加载环与骨架屏是无限循环动画，默认暂停以免任何 pumpAndSettle 卡住；'
          '点上面这一行即可播放。',
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 自绘滚动条：拖动时变粗、可抓取，`onScrub` 上报当前拖动速率。
/// 这里把速率显示出来，验证回调确实在拖动期间持续触发。
class _DemoScrollBar extends StatefulWidget {
  const _DemoScrollBar();

  @override
  State<_DemoScrollBar> createState() => _DemoScrollBarState();
}

class _DemoScrollBarState extends State<_DemoScrollBar> {
  final _controller = ScrollController();
  double? _scrubRate;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SizedBox(
            height: 132,
            child: CommonScrollBar(
              controller: _controller,
              thumbVisibility: true,
              onScrub: (rate) => setState(() => _scrubRate = rate),
              child: ListView.builder(
                controller: _controller,
                padding: const EdgeInsets.only(right: 14),
                itemCount: 20,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    spacing: 8,
                    children: [
                      const GlyphIcon(AppGlyphs.dragHandle, size: 16),
                      Expanded(
                        child: Text(
                          '可滚动内容 第 ${index + 1} 行',
                          style: AppTextStyle.footnote.of(context),
                        ),
                      ),
                      MetaChip(label: '${index + 1}'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(
            _scrubRate == null
                ? '拖动右侧滚动条时这里显示 scrub 速率'
                : 'scrub 速率 ${_scrubRate!.toStringAsFixed(3)}',
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'JetBrainsMono',
                ),
          ),
        ],
      ),
    );
  }
}

/// 加载环四种尺寸与页面级用法。点按切换「加载中」以便观察动画起停。
class _DemoLoadings extends StatelessWidget {
  const _DemoLoadings({required this.loading, required this.onToggle});

  final bool loading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      onPressed: onToggle,
      child: Column(
        spacing: 12,
        children: [
          Row(
            spacing: 22,
            children: [
              for (final size in const [20.0, 28.0, 40.0])
                Column(
                  spacing: 6,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Center(child: CommonCircleLoading(size: size)),
                    ),
                    Text(
                      size.toStringAsFixed(0),
                      style: AppTextStyle.caption2
                          .of(context)
                          .copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'JetBrainsMono',
                          ),
                    ),
                  ],
                ),
              Column(
                spacing: 6,
                children: [
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: CommonCircleLoading(
                        size: 28,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                  Text(
                    'color',
                    style: AppTextStyle.caption2
                        .of(context)
                        .copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'JetBrainsMono',
                        ),
                  ),
                ],
              ),
              const Expanded(
                child: SizedBox(
                  height: 44,
                  child: Center(child: CommonCircleLoading.page()),
                ),
              ),
            ],
          ),
          Text(
            loading ? '加载中（点按停止）' : '点按开始加载',
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 四种插画：data / search / error / wifi。空态的插画是入场动画（只播一次），
/// 所以它们放进 `pumpAndSettle` 也是安全的。
class _DemoNullStatuses extends StatelessWidget {
  const _DemoNullStatuses();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final (illustration, label, description) in _nullStatusSamples)
          CommonCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 220,
              child: NullStatus(
                label: label,
                description: description,
                illustration: illustration,
                action: TonalButton(
                  size: TonalButtonSize.section,
                  label: '动作',
                  onPressed: () => _demoToast(context, 'NullStatus · $label'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 四种插画 + 各自该出现的文案。空态是「用户唯一会盯着看很久」的界面，
/// 所以文案要写清楚下一步做什么，而不是只说「暂无数据」。
const _nullStatusSamples = <(NullStatusIllustration, String, String)>[
  (NullStatusIllustration.data, '还没有任何记录', '连接建立后，这里会按时间列出每一条请求。'),
  (NullStatusIllustration.search, '没有匹配的结果', '换一个关键词，或者清空搜索条件再试一次。'),
  (NullStatusIllustration.error, '加载失败', '请检查网络连接，然后重试。'),
  (NullStatusIllustration.wifi, '网络不可用', '当前没有可用的网络接口。'),
];

/// 骨架屏：文本行用 [SkeletonText]（宽度决定行宽），块用 [SkeletonPill]。
class _DemoSkeletons extends StatelessWidget {
  const _DemoSkeletons();

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              const SkeletonPill(width: 44, height: 44),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    SkeletonText(
                      width: double.infinity,
                      style: AppTextStyle.subheadline.of(context),
                    ),
                    SkeletonText(
                      width: 140,
                      style: AppTextStyle.caption1.of(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SkeletonText(
            width: double.infinity,
            style: AppTextStyle.footnote.of(context),
          ),
          SkeletonText(width: 200, style: AppTextStyle.footnote.of(context)),
        ],
      ),
    );
  }
}

/// 折线图：两条不同容量的曲线并排，验证 capacity 只影响横轴密度，
/// 不影响曲线本身的平滑度（Catmull-Rom + 高斯模糊）。
class _DemoLineChart extends StatelessWidget {
  const _DemoLineChart();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        SizedBox(
          height: 120,
          child: LineChart(
            values: mockTrafficSamples,
            revision: mockTrafficSamples.length,
            capacity: 30,
            minScale: 600,
            color: colorScheme.primary,
            baselineRatio: 0.78,
          ),
        ),
        SizedBox(
          height: 88,
          child: LineChart(
            values: mockTrafficSamples.sublist(0, 12),
            revision: 12,
            capacity: 12,
            minScale: 600,
            color: colorScheme.success,
            baselineRatio: 0.7,
          ),
        ),
        Text(
          '上：capacity 30 / baselineRatio 0.78　　下：capacity 12 / 0.7',
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'JetBrainsMono',
              ),
        ),
      ],
    );
  }
}

/// 三个拼装件：指标条、键值行、带标题的内容块。
class _DemoStats extends StatelessWidget {
  const _DemoStats();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        CommonCard(
          padding: EdgeInsets.zero,
          child: StatStrip(
            stats: [
              StatItem(label: '上传', value: '12.4', unit: 'MB/s'),
              StatItem(
                label: '下载',
                value: '86.2',
                unit: 'MB/s',
                color: colorScheme.primary,
              ),
              StatItem(label: '连接', value: '42'),
              StatItem(
                label: '内存',
                value: '318',
                unit: 'MB',
                color: colorScheme.success,
              ),
            ],
          ),
        ),
        CommonCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            spacing: 8,
            children: const [
              KeyValueRow(
                label: '运行时长',
                value: '2 天 07:41:12',
                monospace: true,
              ),
              KeyValueRow(label: '当前配置', value: '订阅 · 每日更新'),
              KeyValueRow(label: '规则数量', value: '1 284', monospace: true),
            ],
          ),
        ),
        SectionBlock(
          title: 'SectionBlock',
          footer: 'SectionBlock 自带标题与脚注，内容自己排。',
          child: CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '带标题、带脚注的内容块，用来把「一组卡片」和别的内容隔开。',
                style: AppTextStyle.footnote.of(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
