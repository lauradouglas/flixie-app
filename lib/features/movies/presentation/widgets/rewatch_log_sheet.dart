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
    _includeWatchedDate = true;
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
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              color: FlixieColors.medium,
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
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: FlixieColors.light),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: FlixieColors.tabBarBorder, height: 1),
          // Form body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rating (optional)',
                    style: TextStyle(
                      color: FlixieColors.light,
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
                        child: ChoiceChip(
                          label: Text('$value'),
                          avatar: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 17,
                            color:
                                isSelected ? Colors.white : FlixieColors.medium,
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (_) => setState(
                            () {
                              _rating = isSelected ? null : value;
                              if (_rating == null) _recommended = null;
                            },
                          ),
                          selectedColor: FlixieColors.primary,
                          backgroundColor: FlixieColors.surfaceElevated,
                          side: BorderSide(
                            color: isSelected
                                ? FlixieColors.primary
                                : FlixieColors.tabBarBorder,
                          ),
                          labelStyle: TextStyle(
                            color:
                                isSelected ? Colors.white : FlixieColors.light,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rating != null ? '$_rating / 10' : 'No rating',
                    style: const TextStyle(
                      color: FlixieColors.medium,
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
                      onPressed: _saving ||
                              (_rating != null && _recommended == null)
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
                      style: const TextStyle(
                        color: FlixieColors.danger,
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
        title: const Text(
          'Write a review after logging',
          style: TextStyle(
            color: FlixieColors.light,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Your rating and recommendation will carry over.',
          style: TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        onChanged: (value) => setState(() => _writeReview = value ?? false),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.tune_rounded, color: FlixieColors.medium, size: 18),
            SizedBox(width: 8),
            Text(
              'Details (optional)',
              style: TextStyle(
                color: FlixieColors.light,
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
            color: FlixieColors.surfaceElevated.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlixieColors.tabBarBorder.withValues(alpha: .7),
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
                  title: const Text(
                    'Watch date',
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _includeWatchedDate
                        ? 'Today by default - tap below to change it.'
                        : 'Leave off to simply mark it watched.',
                    style: const TextStyle(
                      color: FlixieColors.medium,
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
                      color: FlixieColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: FlixieColors.tabBarBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: FlixieColors.medium,
                          size: 17,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}',
                          style: const TextStyle(color: FlixieColors.light),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                'Personal note',
                style: TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Only visible to you and friends',
                style: TextStyle(color: FlixieColors.medium, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: FlixieColors.white),
                decoration: InputDecoration(
                  hintText: 'Add a personal note (optional)',
                  hintStyle: const TextStyle(color: FlixieColors.medium),
                  filled: true,
                  fillColor: FlixieColors.surface,
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
      return const Text(
        'Last time: Not rated',
        style: TextStyle(color: FlixieColors.medium, fontSize: 12),
      );
    }
    final difference = _rating == null ? null : _rating! - previous.round();
    final comparisonColor = difference == null
        ? FlixieColors.medium
        : difference == 0
            ? FlixieColors.warning
            : difference > 0
                ? FlixieColors.success
                : FlixieColors.danger;
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
          style: const TextStyle(
            color: FlixieColors.medium,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          children: [
            const TextSpan(text: 'Last time: '),
            TextSpan(
              text: '${previous.toStringAsFixed(0)}/10',
              style: const TextStyle(
                color: FlixieColors.light,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_rating != null) ...[
              const TextSpan(text: '  ·  This time: '),
              TextSpan(
                text: '$_rating/10',
                style: const TextStyle(
                  color: FlixieColors.white,
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
    final color = positive ? FlixieColors.success : FlixieColors.danger;
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
                    : FlixieColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? color : FlixieColors.tabBarBorder,
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
                color: selected ? color : FlixieColors.light,
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _RecommendationButton(
        selected: recommended == true,
        positive: true,
        onTap: () => onChanged(true),
      ),
      const SizedBox(width: 8),
      _RecommendationButton(
        selected: recommended == false,
        positive: false,
        onTap: () => onChanged(false),
      ),
    ];
    const label = Text(
      'Would you recommend it? *',
      style: TextStyle(
        color: FlixieColors.light,
        fontWeight: FontWeight.w700,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 335) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: buttons),
            ],
          );
        }
        return Row(children: [const Expanded(child: label), ...buttons]);
      },
    );
  }
}
