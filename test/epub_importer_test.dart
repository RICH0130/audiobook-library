import 'dart:io';

import 'package:audiobook_library/services/epub_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports chapters in spine order with TOC titles', () async {
    final f = File('/tmp/test.epub');
    if (!f.existsSync()) {
      markTestSkipped('sample epub not available');
      return;
    }
    final book = await EpubImporter.parse(f.readAsBytesSync());
    expect(book.title, '測試之書');
    expect(book.author, '王小明');
    expect(book.chapters.map((c) => c.title), ['第一章 開始', '第二章 專注']);
    expect(book.chapters.first.sentences.first, '第1章\n');
    expect(book.chapters.first.sentences, contains('專注力是可以練習的！\n'));
  });

  test('rejects non-epub bytes', () async {
    expect(() => EpubImporter.parse([1, 2, 3]), throwsA(isA<EpubImportException>()));
  });
}
