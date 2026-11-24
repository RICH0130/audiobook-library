import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ClaudeException implements Exception {
  final String message;
  ClaudeException(this.message);
  @override
  String toString() => message;
}

/// Calls the Claude Messages API directly over HTTPS. Dart has no official
/// Anthropic SDK, so this uses raw HTTP. The API key is supplied by the user
/// in Settings and stored only on the device.
class ClaudeService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const model = 'claude-opus-5-5';

  /// Keep each request well inside the context window and cost-friendly.
  /// Longer chapters are split into parts and summarised part by part.
  static const _maxCharsPerRequest = 60000;

  final String apiKey;
  final http.Client _client;

  ClaudeService(this.apiKey, {http.Client? client})
      : _client = client ?? http.Client();

  static const _schema = {
    'type': 'object',
    'properties': {
      'one_line': {
        'type': 'string',
        'description': '一句話總結本章（30 字以內）',
      },
      'key_points': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '3 到 5 個重點，每點一句、具體、可直接行動或記憶',
      },
      'keywords': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '5 到 10 個關鍵詞，必須是原文中逐字出現的詞',
      },
    },
    'required': ['one_line', 'key_points', 'keywords'],
    'additionalProperties': false,
  };

  static const _system = '''你是協助 ADHD 讀者的閱讀助理。讀者需要快速抓到章節重點。
請用繁體中文（台灣用語）回答。若原文是其他語言，重點與總結用繁體中文寫，但關鍵詞保留原文寫法。
重點要短、具體、一眼看懂，避免空泛的形容。
關鍵詞必須是原文中逐字出現的詞或短語，這樣 App 才能在內文中把它標示出來。''';

  Future<ChapterInsight> analyzeChapter({
    required int bookId,
    required String bookTitle,
    required Chapter chapter,
  }) async {
    final text = chapter.fullText;
    final parts = <String>[];
    for (var i = 0; i < text.length; i += _maxCharsPerRequest) {
      parts.add(text.substring(
          i, (i + _maxCharsPerRequest).clamp(0, text.length)));
    }

    if (parts.length == 1) {
      final r = await _ask(
          '書名：$bookTitle\n章節：${chapter.title}\n\n<chapter>\n${parts.first}\n</chapter>');
      return _toInsight(bookId, chapter.index, r, text);
    }

    // Long chapter: analyse each part, then merge the partial results.
    final partials = <Map<String, dynamic>>[];
    for (var i = 0; i < parts.length; i++) {
      partials.add(await _ask(
          '書名：$bookTitle\n章節：${chapter.title}（第 ${i + 1}/${parts.length} 部分）\n\n<chapter>\n${parts[i]}\n</chapter>'));
    }
    final merged = await _ask(
        '以下是同一章各部分的分析結果，請合併成整章的結果（3 到 5 個重點、5 到 10 個關鍵詞，關鍵詞只能從下列關鍵詞中挑選）。\n'
        '書名：$bookTitle\n章節：${chapter.title}\n\n${jsonEncode(partials)}');
    return _toInsight(bookId, chapter.index, merged, text);
  }

  ChapterInsight _toInsight(
      int bookId, int chapterIndex, Map<String, dynamic> r, String text) {
    final keywords = ((r['keywords'] as List?) ?? [])
        .map((e) => e.toString().trim())
        .where((k) => k.isNotEmpty && text.contains(k))
        .toSet()
        .toList();
    return ChapterInsight(
      bookId: bookId,
      chapterIndex: chapterIndex,
      keywords: keywords,
      keyPoints: ((r['key_points'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      oneLine: (r['one_line'] ?? '').toString().trim(),
    );
  }

  Future<Map<String, dynamic>> _ask(String userContent) async {
    final body = {
      'model': model,
      'max_tokens': 16000,
      'system': _system,
      'output_config': {
        'effort': 'low',
        'format': {'type': 'json_schema', 'schema': _schema},
      },
      'fallbacks': 'default',
      'messages': [
        {'role': 'user', 'content': userContent},
      ],
    };

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 5));
    } catch (_) {
      throw ClaudeException('無法連線到 Claude，請檢查網路');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final err = decoded is Map ? decoded['error'] : null;
      final msg = err is Map ? (err['message'] ?? '') : '';
      switch (res.statusCode) {
        case 401:
          throw ClaudeException('API 金鑰無效，請到設定頁重新輸入');
        case 429:
          throw ClaudeException('請求太頻繁或額度不足，請稍後再試');
        case 529:
        case 500:
        case 502:
        case 503:
          throw ClaudeException('Claude 服務暫時忙碌，請稍後再試');
        default:
          throw ClaudeException('Claude 回傳錯誤（${res.statusCode}）：$msg');
      }
    }

    final stopReason = decoded['stop_reason'];
    if (stopReason == 'refusal') {
      throw ClaudeException('Claude 無法處理這一章的內容');
    }
    if (stopReason == 'max_tokens') {
      throw ClaudeException('回覆被截斷，請再試一次');
    }

    final content = (decoded['content'] as List?) ?? [];
    final textBlock = content.cast<Map>().firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => {},
        );
    final text = textBlock['text'] as String?;
    if (text == null) throw ClaudeException('Claude 沒有回傳內容');
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw ClaudeException('無法解析 Claude 的回覆');
    }
  }
}
