import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

const _blockTags = {
  'p', 'div', 'br', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'blockquote', 'section', 'article', 'tr', 'pre', 'hr', 'dd', 'dt',
};

/// Converts XHTML chapter content into plain text with paragraph breaks.
String htmlToText(String html) {
  final doc = html_parser.parse(html);
  doc.querySelectorAll('script, style, head, rt, rp').forEach((e) => e.remove());
  final buf = StringBuffer();

  void walk(dom.Node node) {
    if (node is dom.Text) {
      buf.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
      return;
    }
    if (node is dom.Element) {
      final tag = node.localName ?? '';
      final isBlock = _blockTags.contains(tag);
      if (isBlock) buf.write('\n');
      for (final c in node.nodes) {
        walk(c);
      }
      if (isBlock) buf.write('\n');
    }
  }

  walk(doc.body ?? doc.documentElement!);
  return buf
      .toString()
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
}

final _sentenceEnd = RegExp(r'[。！？!?；;…]+[」』”’）)]*|\.(?=\s)|\n');

/// Splits text into sentences suitable for TTS and highlighting.
/// Each sentence keeps its trailing punctuation. Paragraph breaks become
/// their own boundary so a paragraph never merges with the next one.
List<String> splitSentences(String text) {
  final out = <String>[];
  for (final para in text.split('\n')) {
    var start = 0;
    for (final m in _sentenceEnd.allMatches(para)) {
      final s = para.substring(start, m.end).trim();
      if (s.isNotEmpty) out.add(s);
      start = m.end;
    }
    final rest = para.substring(start).trim();
    if (rest.isNotEmpty) out.add(rest);
    if (out.isNotEmpty && !out.last.endsWith('\n')) {
      out[out.length - 1] = '${out.last}\n';
    }
  }
  // Break very long sentences at commas so TTS chunks stay manageable.
  final result = <String>[];
  for (final s in out) {
    if (s.length <= 160) {
      result.add(s);
      continue;
    }
    var buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(ch);
      if (buf.length >= 80 && '，,、：:'.contains(ch)) {
        result.add(buf.toString());
        buf = StringBuffer();
      }
    }
    if (buf.isNotEmpty) result.add(buf.toString());
  }
  return result;
}
