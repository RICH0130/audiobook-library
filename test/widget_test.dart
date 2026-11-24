import 'dart:io';

import 'package:audiobook_library/models/models.dart';
import 'package:audiobook_library/services/pdf_exporter.dart';
import 'package:audiobook_library/services/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  group('htmlToText', () {
    test('keeps paragraphs and drops tags', () {
      const html = '<html><head><title>x</title><style>p{}</style></head>'
          '<body><h1>第一章</h1><p>今天天氣很好。<b>我們</b>去公園！</p><p>第二段</p></body></html>';
      expect(htmlToText(html), '第一章\n今天天氣很好。我們去公園！\n第二段');
    });
  });

  group('splitSentences', () {
    test('splits Chinese punctuation and marks paragraph ends', () {
      final s = splitSentences('今天天氣很好。我們去公園！\n第二段');
      expect(s, ['今天天氣很好。', '我們去公園！\n', '第二段\n']);
    });

    test('keeps closing quotes with the sentence', () {
      final s = splitSentences('他說：「好啊。」然後走了。');
      expect(s, ['他說：「好啊。」', '然後走了。\n']);
    });

    test('splits English on period followed by space', () {
      final s = splitSentences('Hello world. This is a test.');
      expect(s, ['Hello world.', 'This is a test.\n']);
    });

    test('breaks very long sentences at commas', () {
      final long = List.filled(30, '這是一段很長的文字，').join();
      final s = splitSentences(long);
      expect(s.length, greaterThan(1));
      expect(s.join(), '$long\n');
    });
  });

  test('PDF export renders Chinese with a TTF font', () async {
    final fontFile = File('/tmp/fonttest/f.ttf');
    if (!fontFile.existsSync()) {
      markTestSkipped('font not available');
      return;
    }
    final font = pw.Font.ttf(fontFile.readAsBytesSync().buffer.asByteData());
    final bytes = await PdfExporter.build(
      book: Book(id: 1, title: '測試書', author: '作者', chapterCount: 1),
      chapters: [
        Chapter(bookId: 1, index: 0, title: '第一章', sentences: ['今天天氣很好。'])
      ],
      insights: {
        0: ChapterInsight(
          bookId: 1,
          chapterIndex: 0,
          keywords: ['天氣'],
          keyPoints: ['重點一：天氣很好', '重點二：出門走走'],
          oneLine: '一句話總結',
        ),
      },
      notes: [
        Note(bookId: 1, chapterIndex: 0, sentenceIndex: 0, quote: '今天天氣很好。', text: '我的想法'),
      ],
      font: font,
    );
    File('/tmp/fonttest/out.pdf').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(1000));
  });
}
