import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

/// The same score and recommendation controls in a sheet or a full page.
class TitleRatingEditor extends StatefulWidget {
  const TitleRatingEditor(
      {super.key,
      required this.onSave,
      this.initialRating,
      this.onBusyChanged,
      this.initialRecommendation,
      this.title = 'Rate this title',
      this.subtitle});
  final Future<void> Function(int, String?) onSave;
  final ValueChanged<bool>? onBusyChanged;
  final int? initialRating;
  final String? initialRecommendation, subtitle;
  final String title;
  @override
  State<TitleRatingEditor> createState() => _TitleRatingEditorState();
}

class _TitleRatingEditorState extends State<TitleRatingEditor> {
  late int? _rating = widget.initialRating;
  late String? _recommendation = widget.initialRecommendation;
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      await widget.onSave(_rating!, _recommendation);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your rating couldn’t be saved. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style: Theme.of(context).textTheme.headlineSmall),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(widget.subtitle!)
            ],
            const SizedBox(height: 24),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var score = 1; score <= 10; score++)
                FlixiePill.choice(
                    avatar: const Icon(Icons.star_outline_rounded, size: 18),
                    label: Text('$score'),
                    selected: score == _rating,
                    showCheckmark: false,
                    onSelected:
                        _busy ? null : (_) => setState(() => _rating = score))
            ]),
            const SizedBox(height: 24),
            const Text('Would you recommend it? (optional)'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final option in [
                ('recommend', 'Yes', Icons.thumb_up_alt_outlined),
                ('neutral', 'No opinion', Icons.remove_rounded),
                ('avoid', 'No', Icons.thumb_down_alt_outlined)
              ])
                FlixiePill.choice(
                    avatar: Icon(option.$3, size: 20),
                    label: Text(option.$2),
                    selected: _recommendation == option.$1,
                    showCheckmark: false,
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() =>
                            _recommendation = selected ? option.$1 : null))
            ]),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, semanticsLabel: _error),
            FilledButton(
                style: FilledButton.styleFrom(
                    disabledBackgroundColor: context.colors.surfaceElevated,
                    disabledForegroundColor: context.colors.medium),
                onPressed: _busy || _rating == null ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save rating')),
          ]);
}
