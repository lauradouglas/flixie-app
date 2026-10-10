import 'package:flutter/material.dart';

/// A synopsis preview bounded by rendered lines rather than punctuation.
class MediaSynopsis extends StatelessWidget {
  const MediaSynopsis({
    super.key,
    required this.text,
    required this.style,
    required this.expanded,
    required this.onToggle,
    required this.actionColor,
  });

  final String text;
  final TextStyle style;
  final bool expanded;
  final VoidCallback onToggle;
  final Color actionColor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final effectiveStyle =
              DefaultTextStyle.of(context).style.merge(style);
          final painter = TextPainter(
            text: TextSpan(text: text, style: effectiveStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 3,
          )..layout(maxWidth: constraints.maxWidth);
          final needsExpansion = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: style,
                  maxLines: expanded ? null : 3,
                  overflow: TextOverflow.clip),
              if (needsExpansion)
                TextButton(
                  onPressed: onToggle,
                  style: TextButton.styleFrom(
                    foregroundColor: actionColor,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(expanded ? 'Show less' : 'Read more'),
                ),
            ],
          );
        },
      );
}
