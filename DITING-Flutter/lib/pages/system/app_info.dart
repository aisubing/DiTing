/// 关于页 / 更新页 / 赞助页共用的应用标识、外部地址与「复制并提示」动作。
///
/// 版本号与 `pubspec.yaml` 的 `version: 2.0.1+20001` 手工对齐：旧版读
/// `BuildConfig.VERSION_NAME`，Flutter 侧没有 package_info 依赖，只能手写；
/// 发版时两处同改。上一轮这里还写着 `1.0.0`，关于页因此一直显示一个不存在的版本。
///
/// 「复制并提示」也放在这里：旧版这三处都是 `ACTION_VIEW` 直接开浏览器 / QQ，
/// 本仓不引 `url_launcher`（设计冻结：页面不新增能力依赖），统一改为写剪贴板
/// 并提示。三个页面各自写一份 SnackBar 会把时长与措辞写散。
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 展示用版本名（不含 build 号）。
const appVersionName = '2.0.1';

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
