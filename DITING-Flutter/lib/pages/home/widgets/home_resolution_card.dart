import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 首页的解析模式卡。
///
/// 四选一分段控件 + 一句当前模式的说明。上游这一区在普通/服务器/极速三种模式
/// 下都显示，只是极速模式把多路选项藏掉；这里保持一致但不禁用任何项——演示
/// 阶段允许自由切换以便观察差异。
class HomeResolutionCard extends ConsumerWidget {
  const HomeResolutionCard({super.key, required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionModeProvider);
    return CommonCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              const GlyphIcon(AppGlyphs.shuffle, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('解析模式', style: context.listTitleStyle)),
              Text(
                resolution.label,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.primary),
              ),
            ],
          ),
          SegmentedControl<ResolutionMode>(
            segments: [
              for (final option in ResolutionMode.values)
                (option, option.label),
            ],
            value: resolution,
            onChanged: (value) =>
                ref.read(resolutionModeProvider.notifier).select(value),
          ),
          Text(
            _describe(resolution),
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _describe(ResolutionMode mode) => switch (mode) {
    ResolutionMode.single => '只用当前选中的服务商，最快但可用性取决于它。',
    ResolutionMode.smart => '按历史成功率挑一个，失败后自动换下一个。',
    ResolutionMode.parallel => '同时向所有服务商发起，取最先返回的结果。',
    ResolutionMode.primaryBackup => '主服务商优先，超时后才动备用。',
  };
}
