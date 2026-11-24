import 'package:epubx/epubx.dart';

import 'text_utils.dart';

class ImportedChapter {
  final String title;
  final List<String> sentences;
  ImportedChapter(this.title, this.sentences);
}

class ImportedBook {
  final String title;
  final String author;
  final List<ImportedChapter> chapters;
  ImportedBook(this.title, this.author, this.chapters);
}

class EpubImportException implements Exception {
  final String message;
  EpubImportException(this.message);
  @override
  String toString() => message;
}

class EpubImporter {
  static Future<ImportedBook> parse(List<int> bytes) async {
    final EpubBook book;
    try {
      book = await EpubReader.readBook(bytes);
    } catch (e) {
      throw EpubImportException('無法讀取這個 EPUB 檔（可能已損壞或有 DRM 加密）');
    }

    // Map content file name -> TOC title, from the nested table of contents.
    final tocTitles = <String, String>{};
    void collect(List<EpubChapter>? list) {
      for (final c in list ?? const <EpubChapter>[]) {
        final file = c.ContentFileName;
        final title = c.Title?.trim();
        if (file != null && title != null && title.isNotEmpty) {
          tocTitles.putIfAbsent(file, () => title);
        }
        collect(c.SubChapters);
      }
    }

    collect(book.Chapters);

    final html = book.Content?.Html ?? {};
    final manifest = {
      for (final item in book.Schema?.Package?.Manifest?.Items ?? [])
        if (item.Id != null && item.Href != null) item.Id!: item.Href!,
    };

    final chapters = <ImportedChapter>[];
    var untitled = 0;
    for (final ref in book.Schema?.Package?.Spine?.Items ?? []) {
      final href = manifest[ref.IdRef];
      if (href == null) continue;
      final file = html[href] ?? html[Uri.decodeFull(href)];
      final content = file?.Content;
      if (content == null) continue;
      final text = htmlToText(content);
      if (text.replaceAll(RegExp(r'\s'), '').length < 20) continue;
      final sentences = splitSentences(text);
      untitled++;
      final title = tocTitles[href] ??
          tocTitles[Uri.decodeFull(href)] ??
          _firstLineTitle(text) ??
          '第 $untitled 節';
      chapters.add(ImportedChapter(title, sentences));
    }

    // Fallback for books whose spine could not be resolved.
    if (chapters.isEmpty) {
      void walk(List<EpubChapter>? list) {
        for (final c in list ?? const <EpubChapter>[]) {
          final text = htmlToText(c.HtmlContent ?? '');
          if (text.length >= 20) {
            chapters.add(ImportedChapter(
                c.Title ?? '第 ${chapters.length + 1} 節', splitSentences(text)));
          }
          walk(c.SubChapters);
        }
      }

      walk(book.Chapters);
    }

    if (chapters.isEmpty) {
      throw EpubImportException('這本書裡找不到可閱讀的文字內容');
    }

    final author = (book.AuthorList ?? [])
        .whereType<String>()
        .where((a) => a.trim().isNotEmpty)
        .join('、');
    return ImportedBook(
      (book.Title ?? '').trim().isEmpty ? '未命名書籍' : book.Title!.trim(),
      author.isEmpty ? (book.Author ?? '未知作者') : author,
      chapters,
    );
  }

  static String? _firstLineTitle(String text) {
    final first = text.split('\n').first.trim();
    if (first.isEmpty || first.length > 30) return null;
    return first;
  }
}
