/// 关于页 / 更新页 / 赞助页共用的应用标识、外部地址与「复制并提示」动作。
///
/// 版本号不在这里：唯一真源是 `pubspec.yaml` 的 `version:`，读取见
/// `appVersionProvider`（`lib/state/app_version_provider.dart`）。发版只改
/// pubspec 即可同步关于页、更新页、预设播种与清理动作里的版本；上一轮这里手写的
/// `appVersionName` 常量正是「改了 pubspec、界面还显示旧版本」的来源。
///
/// 「复制并提示」也放在这里：旧版这三处都是 `ACTION_VIEW` 直接开浏览器 / QQ，
/// 本仓不引 `url_launcher`（设计冻结：页面不新增能力依赖），统一改为写剪贴板
/// 并提示。三个页面各自写一份 SnackBar 会把时长与措辞写散。
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 旧版 `AboutScreen.PROJECT_REPOSITORY_URL`。
const projectRepositoryUrl = 'https://github.com/haoze-evolluling/DITING';

/// 旧版 `SponsorScreen.SPONSOR_README_URL`。
const sponsorReadmeUrl = '$projectRepositoryUrl#sponsorship';

/// 旧版「加入 QQ 群」的目标群号。
const qqGroupNumber = '1078502371';

/// 复制 [text] 到剪贴板，然后弹一条 [message]。
///
/// 写剪贴板是异步的，`context` 可能在 await 之后失效（用户已经离开页面），
/// 所以每一步都重新查 `mounted`，不用捕获下来的 `ScaffoldMessenger`。
Future<void> copyToClipboard(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2000),
    ),
  );
}
