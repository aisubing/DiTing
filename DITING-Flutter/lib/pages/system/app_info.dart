/// App identity, external links and copy-to-clipboard shared by the about, update and
/// sponsor pages. The version comes from `pubspec.yaml` via `appVersionProvider`; without
/// `url_launcher` links copy.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Legacy `AboutScreen.PROJECT_REPOSITORY_URL`.
const projectRepositoryUrl = 'https://github.com/haoze-evolluling/DITING';

/// Legacy `SponsorScreen.SPONSOR_README_URL`.
const sponsorReadmeUrl = '$projectRepositoryUrl#sponsorship';

/// Target group number of the legacy "join QQ group" action.
const qqGroupNumber = '1078502371';

/// Copy [text] to the clipboard, then show [message]. The clipboard write is async
/// and the context may be gone afterwards, so `mounted` is re-checked each step.
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