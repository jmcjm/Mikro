import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import '../models/translation_language.dart';
import 'api_errors.dart';
import 'chat_completion.dart';

class TranslationApi {
  TranslationApi(this._dio);

  final Dio _dio;

  // English prompt, like every other one here: the instruction language must not pull the
  // output language, and here the output language is stated explicitly anyway.
  static String systemPrompt(TranslationLanguage target) =>
      'You translate the user\'s text into ${target.englishName}. Translate everything, '
      'faithfully: keep the meaning, tone and level of detail, do not summarise, add or omit '
      'anything. Keep the structure exactly — Markdown headings, lists, task checkboxes, '
      'emphasis, emoji, line breaks. Speaker labels at the start of a line (such as "Speaker '
      '1:" or a name followed by a colon) stay as labels; translate generic words in them, '
      'never change names. If part of the text is already in ${target.englishName}, keep it. '
      'Return only the translation, without code fences or commentary.';

  Future<String> translate({
    required String text,
    required TranslationLanguage target,
    required ServiceConfig config,
  }) async {
    final content = await chatCompletion(_dio,
        config: config, system: systemPrompt(target), user: text);
    final translated = stripFence(content);
    if (translated.isEmpty) throw MikroApiException(ApiErrorKind.noContent, 'empty translation');
    return translated;
  }

  /// Small models wrap the answer in a code fence despite the prompt.
  static String stripFence(String raw) {
    final s = raw.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n?```$').firstMatch(s);
    return (fence != null ? fence.group(1)! : s).trim();
  }
}
