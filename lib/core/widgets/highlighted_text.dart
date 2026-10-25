import 'package:flutter/material.dart';

/// Renders [text] with case-insensitive matches of [query] highlighted.
class HighlightedText extends StatelessWidget {
  const HighlightedText(this.text, {super.key, this.query = '', this.style});

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final base = style ?? DefaultTextStyle.of(context).style;
    if (q.isEmpty) return Text(text, style: base);

    final highlight = base.copyWith(
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      color: Theme.of(context).colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.w700,
    );
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = lower.indexOf(q, start);
      if (i < 0) break;
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(text: text.substring(i, i + q.length), style: highlight));
      start = i + q.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
