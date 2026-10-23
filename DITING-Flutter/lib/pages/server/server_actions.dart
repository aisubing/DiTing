/// Port change and stats reset shared by the three server tabs, so failure copy cannot drift.
library;

import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const serverPortMin = 1024;
const serverPortMax = 65535;

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

void showServerHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}