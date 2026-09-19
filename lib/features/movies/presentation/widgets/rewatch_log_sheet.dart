import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class RewatchLogSheet extends StatefulWidget {
  const RewatchLogSheet({
    super.key,
    this.initial,
    required this.onSubmit,
    this.showReviewOption = false,
    this.onReviewSelected,
    this.isRewatch = false,
    this.previousWatch,
  });

  final MovieWatchEntry? initial;
  final Future<void> Function({
    required String? watchedAt,
    required double? rating,
    required bool? recommended,
    required String? notes,
  }) onSubmit;
  final bool showReviewOption;
  final ValueChanged<bool>? onReviewSelected;
  final bool isRewatch;
  final MovieWatchEntry? previousWatch;

  @override
  State<RewatchLogSheet> createState() => _RewatchLogSheetState();
}

class _RewatchLogSheetState extends State<RewatchLogSheet> {
  late DateTime _watchedAt;
  late TextEditingController _notesController;
  // null means "no rating"; 1-10 when set
  int? _rating;
  bool? _recommended;
  bool _saving = false;
  late bool _includeWatchedDate;
  bool _writeReview = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _watchedAt =
        DateTime.tryParse(widget.initial?.watchedAt ?? '') ?? DateTime.now();
    final existingRating = widget.initial?.rating;
    _rating = existingRating?.round();
    _includeWatchedDate =
        widget.initial == null || widget.initial!.watchedAt != null;
    _recommended = widget.initial?.recommended;
    _notesController = TextEditingController(text: widget.initial?.notes ?? '')
      ..addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNoteChanged);
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.medium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initial != null
                      ? 'Edit Watch Entry'
                      : widget.isRewatch
                          ? 'Log Rewatch'
                          : 'Log Watch',
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.light),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: context.colors.tabBarBorder, height: 1),
          // Form body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rating (optional)',
                    style: TextStyle(
                      color: context.colors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: List.generate(10, (i) {
                      final value = i + 1;
                      final isSelected = _rating == value;
                      return ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 42),
                        child: FlixiePill.choice(
                            label: Text('$value'),
                            avatar: Icon(
                                isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 17),
                            selected: isSelected,
                            showCheckmark: false,
                            onSelected: (_) => setState(
                                  () {
                                    _rating = isSelected ? null : value;
                                    if (_rating == null) _recommended = null;
                                  },
                                )),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rating != null ? '$_rating / 10' : 'No rating',
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.isRewatch) ...[
                    const SizedBox(height: 8),
                    _buildRewatchComparison(),
                  ],
                  const SizedBox(height: 12),
                  _RecommendationPicker(
                    recommended: _recommended,
                    onChanged: (value) => setState(() => _recommended = value),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailsSection(context),
                  if (widget.showReviewOption) ...[
                    const SizedBox(height: 10),
                    _buildReviewOption(),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlixieColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              setState(() => _saving = true);
                              try {
                                await widget.onSubmit(
                                  watchedAt: _includeWatchedDate
                                      ? _watchedAt.toUtc().toIso8601String()
                                      : null,
                                  rating: _rating?.toDouble(),
                                  recommended: _recommended,
                                  notes: _notesController.text.trim().isEmpty
                                      ? null
                                      : _notesController.text.trim(),
                                );
                                if (mounted) {
                                  setState(() {
                                    _saving = false;
                                    _saveError = null;
                                  });
                                  widget.onReviewSelected?.call(_writeReview);
                                  navigator.pop();
                                }
                              } catch (error) {
                                if (mounted) {
                                  setState(() {
                                    _saving = false;
                                    _saveError = error is ApiException
                                        ? error.message
                                        : 'Could not save this watch entry. Try again.';
                                  });
                                }
                              }
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.initial == null
                                  ? _rating == null
                                      ? 'Mark watched without rating'
                                      : 'Rate & mark watched'
                                  : 'Save Changes',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: context.colors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewOption() {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        value: _writeReview,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          'Write a review after logging',
          style: TextStyle(
            color: context.colors.light,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Your rating and recommendation will carry over.',
          style: TextStyle(color: context.colors.medium, fontSize: 12),
        ),
        onChanged: (value) => setState(() => _writeReview = value ?? false),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, color: context.colors.medium, size: 18),
            const SizedBox(width: 8),
            Text(
              'Details (optional)',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.tabBarBorder.withValues(alpha: .7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: _includeWatchedDate,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Watch date',
                    style: TextStyle(
                      color: context.colors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _includeWatchedDate
                        ? 'Today by default - tap below to change it.'
                        : 'Leave off to simply mark it watched.',
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _includeWatchedDate = value ?? false),
                ),
              ),
              if (_includeWatchedDate) ...[
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _watchedAt,
                      firstDate: DateTime(1970),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _watchedAt = date);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.tabBarBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: context.colors.medium,
                          size: 17,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}',
                          style: TextStyle(color: context.colors.light),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Personal note',
                style: TextStyle(
                  color: context.colors.light,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Only visible to you and friends',
                style: TextStyle(color: context.colors.medium, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: context.colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a personal note (optional)',
                  hintStyle: TextStyle(color: context.colors.medium),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewatchComparison() {
    final previous = widget.previousWatch?.rating;
    if (previous == null) {
      return Text(
        'Last time: Not rated',
        style: TextStyle(color: context.colors.medium, fontSize: 12),
      );
    }
    final difference = _rating == null ? null : _rating! - previous.round();
    final comparisonColor = difference == null
        ? context.colors.medium
        : difference == 0
            ? context.colors.warning
            : difference > 0
                ? context.colors.success
                : context.colors.danger;
    final comparisonLabel = difference == null
        ? ''
        : difference == 0
            ? ' = Same rating'
            : difference > 0
                ? ' ↑${difference.abs()} Higher this time'
                : ' ↓${difference.abs()} Lower this time';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: comparisonColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: comparisonColor.withValues(alpha: .3)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: context.colors.medium,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          children: [
            const TextSpan(text: 'Last time: '),
            TextSpan(
              text: '${previous.toStringAsFixed(0)}/10',
              style: TextStyle(
                color: context.colors.light,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_rating != null) ...[
              const TextSpan(text: '  ·  This time: '),
              TextSpan(
                text: '$_rating/10',
                style: TextStyle(
                  color: context.colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: comparisonLabel,
                style: TextStyle(
                  color: comparisonColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationButton extends StatelessWidget {
  const _RecommendationButton({
    required this.selected,
    required this.positive,
    required this.onTap,
  });

  final bool selected;
  final bool positive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = positive ? context.colors.success : context.colors.danger;
    final label = positive ? 'Recommend' : 'Don’t recommend';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? color.withValues(alpha: .18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: .22)
                    : context.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? color : context.colors.tabBarBorder,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: .18),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                positive
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_down_alt_rounded,
                color: selected ? color : context.colors.light,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationPicker extends StatelessWidget {
  const _RecommendationPicker({
    required this.recommended,
    required this.onChanged,
  });

  final bool? recommended;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _RecommendationButton(
        selected: recommended == true,
        positive: true,
        onTap: () => onChanged(true),
      ),
      FlixiePill.choice(
          label: const Text('No opinion'),
          selected: recommended == null,
          onSelected: (_) => onChanged(null)),
      _RecommendationButton(
        selected: recommended == false,
        positive: false,
        onTap: () => onChanged(false),
      ),
    ];
    final label = Text(
      'Would you recommend it?',
      style: TextStyle(
        color: context.colors.light,
        fontWeight: FontWeight.w700,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: buttons),
      ],
    );
  }
}
