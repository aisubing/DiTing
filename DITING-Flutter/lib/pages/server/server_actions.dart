/// 服务器模式三 Tab 共用的两个动作：改监听端口、重置运行统计。
///
/// 单独成文件而不是各页各写一份：端口在「概览」与「模式设置」都能改，统计在两处
/// 都有入口，校验文案与确认框口径必须一致，否则同一个动作在两张页面上会出现
/// 两种失败提示。
library;

import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 端口合法区间。上游 `DnsListenPortValidator` 同口径。
const serverPortMin = 1024;
const serverPortMax = 65535;

/// 弹出端口输入框；返回用户填的新端口（取消返回 null）。
Future<int?> promptServerPort(BuildContext context, int current) async {
  final result = await showFloatingDialog<String>(
    context: Navigator.of(context, rootNavigator: true).context,
    child: InputDialog(
      title: '本地监听端口',
      value: '$current',
      suffixText: '',
      hintText: '$serverPortMin–$serverPortMax',
      keyboardType: TextInputType.number,
      maxLength: 5,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        final parsed = int.tryParse(value?.trim() ?? '');
        if (parsed == null) {
          return '请输入数字';
        }
        if (parsed < serverPortMin || parsed > serverPortMax) {
          return '范围 $serverPortMin–$serverPortMax';
        }
        return null;
      },
    ),
  );
  return int.tryParse(result?.trim() ?? '');
}

/// 改端口：写进 `diting_dns_mode_prefs/local_listen_port`，下次启动服务才生效。
Future<void> editServerPort(BuildContext context, WidgetRef ref) async {
  final port = ref.read(serverPortProvider);
  final value = await promptServerPort(context, port);
  if (value == null) {
    return;
  }
  ref.read(serverPortProvider.notifier).set(value);
  if (context.mounted) {
    showServerHint(context, '端口已改为 $value，重启服务后生效');
  }
}

/// 重置运行统计前的二次确认（上游 `DnsMainScreen` 同样先弹确认框）。
Future<void> confirmResetServerStats(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showFloatingDialog<bool>(
    context: context,
    child: CommonDialog(
      title: '重置运行统计',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认重置'),
        ),
      ],
      child: const Text('将清空本次运行的全部统计数据，确认继续吗？'),
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  ref.read(serviceStatsProvider.notifier).reset();
  showServerHint(context, '运行统计已重置');
}

/// 服务器模式统一的行内提示。
void showServerHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}
