import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Builds the ADHD key-points PDF: one-line summary, key points, keywords and
/// the reader's own notes for every chapter.
class PdfExporter {
  static Future<Uint8List> build({
    required Book book,
    required List<Chapter> chapters,
    required Map<int, ChapterInsight> insights,
    required List<Note> notes,
    bool includeNotes = true,
    pw.Font? font,
  }) async {
    final regular = font ?? await loadChineseFont();
    final bold = regular;

    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    const accent = PdfColor.fromInt(0xFF5B4BDB);
    final doc = pw.Document(title: '${book.title}｜重點整理', author: book.author);

    final notesByChapter = <int, List<Note>>{};
    for (final n in notes) {
      notesByChapter.putIfAbsent(n.chapterIndex, () => []).add(n);
    }

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Text(book.title,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            pw.Text(book.title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('${book.author}｜ADHD 重點整理',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Divider(color: accent, thickness: 2),
            pw.SizedBox(height: 8),
          ];

          for (final ch in chapters) {
            final ins = insights[ch.index];
            final chNotes = includeNotes ? (notesByChapter[ch.index] ?? []) : <Note>[];
            if (ins == null && chNotes.isEmpty) continue;

            widgets.add(pw.Header(
              level: 1,
              decoration: const pw.BoxDecoration(),
              child: pw.Text(ch.title,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
            ));

            if (ins != null) {
              if (ins.oneLine.isNotEmpty) {
                widgets.add(pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1EFFF),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(ins.oneLine,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ));
              }
              for (var i = 0; i < ins.keyPoints.length; i++) {
                widgets.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 18,
                        child: pw.Text('${i + 1}.',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, color: accent)),
                      ),
                      pw.Expanded(
                          child: pw.Text(ins.keyPoints[i],
                              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2))),
                    ],
                  ),
                ));
              }
              if (ins.keywords.isNotEmpty) {
                widgets.add(pw.SizedBox(height: 4));
                widgets.add(pw.Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ins.keywords
                      .map((k) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: accent, width: 0.6),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Text(k,
                                style: const pw.TextStyle(fontSize: 9, color: accent)),
                          ))
                      .toList(),
                ));
              }
            }

            if (chNotes.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Text('我的筆記',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));
              for (final n in chNotes) {
                widgets.add(pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4),
                  padding: const pw.EdgeInsets.only(left: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                        left: pw.BorderSide(color: PdfColor.fromInt(n.color), width: 3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('「${n.quote.trim()}」',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      if (n.text.isNotEmpty)
                        pw.Text(n.text, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ));
              }
            }
            widgets.add(pw.SizedBox(height: 14));
          }
          return widgets;
        },
      ),
    );
    return doc.save();
  }

  static const _fontUrl =
      'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf';

  /// Noto Sans TC (~12 MB) is downloaded once on first export and cached in
  /// the app's support folder, so the app download stays small.
  static Future<pw.Font> loadChineseFont() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'NotoSansTC.ttf'));
    if (!await file.exists() || await file.length() < 1000000) {
      final res = await http.get(Uri.parse(_fontUrl));
      if (res.statusCode != 200) {
        throw Exception('無法下載中文字型（${res.statusCode}）');
      }
      await file.writeAsBytes(res.bodyBytes, flush: true);
    }
    return pw.Font.ttf((await file.readAsBytes()).buffer.asByteData());
  }

  static Future<void> share(Uint8List bytes, String bookTitle) async {
    final safe = bookTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$safe-重點整理.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: '$bookTitle 重點整理',
    ));
  }
}
