import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Native share sheet is supported on mobile and macOS. Elsewhere (Linux) share_plus can only
/// build a `mailto:` link, so sharing has to fall back to something else.
bool get hasNativeShareSheet => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// Shares [text] through the native share sheet, or copies it to the clipboard where there is
/// none. Returns `true` when the sheet was used and `false` when the text went to the clipboard —
/// the caller then confirms it in its own words, because only the caller knows what was copied.
Future<bool> shareText(String text, {String? subject}) async {
  if (hasNativeShareSheet) {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    return true;
  }
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}
