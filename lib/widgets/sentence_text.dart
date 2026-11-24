import 'package:flutter/material.dart';

/// Renders one sentence with: keyword emphasis, the word currently being
/// spoken underlined, and an optional highlight colour from a note.
class SentenceText extends StatelessWidget {
  final String text;
  final List<String> keywords;
  final bool isCurrent;
  final int spokenStart;
  final int spokenEnd;
  final Color? highlight;
  final double fontSize;

  const SentenceText({
    super.key,
    required this.text,
    required this.keywords,
    required this.isCurrent,
    required this.spokenStart,
    required this.spokenEnd,
    required this.highlight,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = text.trimRight();
    // The TTS engine receives the trimmed text, so offsets are relative to it.
    final leading = display.length - display.trimLeft().length;
    final base = TextStyle(
      fontSize: fontSize,
      height: 1.7,
      color: scheme.onSurface,
    );

    // Per-character flags: keyword / spoken.
    final n = display.length;
    final kw = List<bool>.filled(n, false);
    for (final k in keywords) {
      if (k.isEmpty) continue;
      var from = 0;
      while (true) {
        final i = display.indexOf(k, from);
        if (i < 0) break;
        for (var j = i; j < i + k.length && j < n; j++) {
          kw[j] = true;
        }
        from = i + k.length;
      }
    }
    final spoken = List<bool>.filled(n, false);
    if (isCurrent && spokenStart >= 0 && spokenEnd > spokenStart) {
      for (var j = spokenStart + leading; j < spokenEnd + leading && j < n; j++) {
        if (j >= 0) spoken[j] = true;
      }
    }

    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= n; i++) {
      if (i == n || kw[i] != kw[start] || spoken[i] != spoken[start]) {
        spans.add(TextSpan(
          text: display.substring(start, i),
          style: TextStyle(
            fontWeight: kw[start] ? FontWeight.bold : null,
            color: kw[start] ? scheme.primary : null,
            decoration: spoken[start] ? TextDecoration.underline : null,
            decorationColor: scheme.tertiary,
            decorationThickness: 2.5,
          ),
        ));
        start = i;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? scheme.secondaryContainer
            : highlight?.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: isCurrent && highlight != null
            ? Border(left: BorderSide(color: highlight!, width: 4))
            : null,
      ),
      child: Text.rich(TextSpan(style: base, children: spans)),
    );
  }
}
