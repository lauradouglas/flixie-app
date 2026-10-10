import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class ExpandableProfileBio extends StatefulWidget {
  const ExpandableProfileBio({super.key, required this.text});
  final String text;
  @override
  State<ExpandableProfileBio> createState() => _ExpandableProfileBioState();
}

class _ExpandableProfileBioState extends State<ExpandableProfileBio> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style.copyWith(
            color: context.colors.light, fontSize: 14, height: 1.45);
        final painter = TextPainter(
          text: TextSpan(text: widget.text.trim(), style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final long = painter.didExceedMaxLines;
        painter.dispose();
        if (!long) return Text(widget.text.trim(), style: style);
        final baseStyle = DefaultTextStyle.of(context).style.merge(style);
        final linkStyle = baseStyle.copyWith(
            color: context.colors.primaryText, fontWeight: FontWeight.w500);
        TextSpan span(String text) => TextSpan(style: baseStyle, children: [
              TextSpan(text: text),
              TextSpan(
                  text: _expanded ? '  Read less' : '… Read more',
                  style: linkStyle),
            ]);
        var visible = widget.text.trim();
        if (!_expanded) {
          final characters = visible.characters.toList();
          var low = 0, high = characters.length;
          final measure = TextPainter(
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 3);
          while (low < high) {
            final mid = (low + high + 1) ~/ 2;
            measure.text = span(characters.take(mid).join().trimRight());
            measure.layout(maxWidth: constraints.maxWidth);
            if (measure.didExceedMaxLines) {
              high = mid - 1;
            } else {
              low = mid;
            }
          }
          measure.dispose();
          visible = characters.take(low).join().trimRight();
          final lastSpace = visible.lastIndexOf(' ');
          if (lastSpace >= 0 && lastSpace > visible.length - 20) {
            visible = visible.substring(0, lastSpace).trimRight();
          }
        }
        return Semantics(
          button: true,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text.rich(span(visible)),
          ),
        );
      });
}
