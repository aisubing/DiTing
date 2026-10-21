import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 「刷新手势」的触发器：自增即让所有读日志表的 provider 重新查询。
///
/// 与 `dnsLogRevisionProvider` 分开是为了让「刷新按钮」和「清空日志」两类动作
/// 可区分——清空已经有一整套 provider 依赖真实表变更，这里只服务于「用户想再
/// 看一眼」。
class LogRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final logRefreshTickProvider = NotifierProvider<LogRefreshTickNotifier, int>(
  LogRefreshTickNotifier.new,
);

/// 日志模式三选一（旧版 `DnsLogModeScreen`）。
///
/// 三档的文案照抄 `DnsLogMode`：记录全部 / 仅拦截和错误 / 关闭。这里用一整块卡
/// 把三项**连同说明**一起铺开，而不是塞进分段控件后只留标签：旧版正文里每个
/// 选项下面都跟着一句「记什么、不记什么」，那正是用户选它的依据；只留三个短
/// 标签会让人反复来回点着猜。
class LogModeSelector extends StatelessWidget {
  const LogModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LegacyLogMode value;
  final ValueChanged<LegacyLogMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mode in LegacyLogMode.values)
            _LogModeTile(
              mode: mode,
              selected: mode == value,
              accent: colorScheme.primary,
              onTap: () => onChanged(mode),
            ),
        ],
      ),
    );
  }
}

class _LogModeTile extends StatelessWidget {
  const _LogModeTile({
    required this.mode,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final LegacyLogMode mode;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: FocusRing(
        shape: AppShape.all(AppCorner.md),
        standsOff: selected,
        child: Material(
          color: selected ? accent.withValues(alpha: 0.10) : Colors.transparent,
          shape: AppShape.all(AppCorner.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                spacing: 12,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? accent : colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        Text(mode.label, style: context.listTitleStyle),
                        Text(
                          mode.description,
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
