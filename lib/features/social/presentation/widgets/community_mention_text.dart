import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Keeps discussion text selectable while distinguishing @usernames.
class CommunityMentionText extends StatelessWidget {
  const CommunityMentionText(this.text, {super.key, this.style});

  final TextStyle? style;

  final String text;
  static final _mention =
      RegExp(r'(^|\s)(@[A-Za-z0-9_]+(?:[.-][A-Za-z0-9_]+)*)');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _mention.allMatches(text)) {
      final start = match.start + match.group(1)!.length;
      if (start > cursor)
        spans.add(TextSpan(text: text.substring(cursor, start)));
      spans.add(TextSpan(
        text: match.group(2),
        style: TextStyle(color: context.colors.primaryText),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return SelectableText.rich(TextSpan(children: spans), style: style);
  }
}
