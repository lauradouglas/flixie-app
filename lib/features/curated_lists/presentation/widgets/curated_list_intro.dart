import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../models/curated_list.dart';

class CuratedListIntro extends StatefulWidget {
  const CuratedListIntro({super.key, required this.list, this.now});
  final CuratedList list;
  final DateTime? now;
  @override
  State<CuratedListIntro> createState() => _CuratedListIntroState();
}

class _CuratedListIntroState extends State<CuratedListIntro> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final timing = list.timingLabelAt(widget.now ?? DateTime.now());
    final theme = Theme.of(context);
    final accent = context.colors.primaryText;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, box) {
        final date = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 20, color: accent),
          const SizedBox(width: 10),
          Flexible(
              child: Text(list.dates,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 14, color: context.colors.light))),
        ]);
        if (timing == null) return date;
        final remaining = Text(timing,
            style: theme.textTheme.bodySmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)]));
        if (box.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                date,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: remaining)
              ]);
        }
        return Row(children: [
          Expanded(child: date),
          const SizedBox(width: 12),
          remaining
        ]);
      }),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, box) {
        final count = Text('${list.requiredCount}',
            style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 56,
                height: 1,
                color: accent,
                fontWeight: FontWeight.w800,
                fontVariations: const [FontVariation('wght', 800)]));
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('films to watch & rate',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  height: 1.25,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontVariations: const [FontVariation('wght', 800)])),
          const SizedBox(height: 6),
          Text(
              list.completionTarget == null
                  ? 'Complete all ${list.filmCount} films.'
                  : 'Choose any ${list.requiredCount} from ${list.filmCount} films.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14, height: 1.35, color: context.colors.light)),
        ]);
        if (box.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [count, const SizedBox(height: 10), details]);
        }
        return Row(children: [
          count,
          const SizedBox(width: 16),
          Expanded(child: details)
        ]);
      }),
      if (list.description.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(list.description,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14, height: 1.4, color: context.colors.light)),
      ],
    ]);
  }
}
