import 'package:flutter/material.dart';

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
  bool _writeReview = false;
  late bool _includeWatchedDate;

  @override
  void initState() {
    super.initState();
    _watchedAt =
        DateTime.tryParse(widget.initial?.watchedAt ?? '') ?? DateTime.now();
    final existingRating = widget.initial?.rating;
    _rating = existingRating?.round();
    _includeWatchedDate = true;
    _recommended = widget.initial?.recommended;
    _notesController = TextEditingController(text: widget.initial?.notes ?? '');
  }

  @override
  void dispose() {
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
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _includeWatchedDate,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Add a specific watch date',
                        style: TextStyle(
                          color: FlixieColors.light,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Optional - leave this off to simply mark it watched.',
                        style: TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _includeWatchedDate = value ?? false),
                    ),
                  ),
                  if (_includeWatchedDate)
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _watchedAt,
                          firstDate: DateTime(1970),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _watchedAt = date);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: FlixieColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: FlixieColors.tabBarBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: FlixieColors.medium, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              '${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}',
                              style: const TextStyle(color: FlixieColors.light),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
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
                  if (_rating != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Would you recommend it? *',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Choose Yes or No when adding a rating.',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Yes, recommend'),
                          selected: _recommended == true,
                          onSelected: (_) =>
                              setState(() => _recommended = true),
                        ),
                        ChoiceChip(
                          label: const Text("No, don't recommend"),
                          selected: _recommended == false,
                          onSelected: (_) =>
                              setState(() => _recommended = false),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Notes
                  const Text(
                    'Notes',
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: FlixieColors.white),
                    decoration: InputDecoration(
                      hintText: 'Notes (optional)',
                      hintStyle: const TextStyle(color: FlixieColors.medium),
                      filled: true,
                      fillColor: FlixieColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (widget.showReviewOption) ...[
                    const SizedBox(height: 14),
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _writeReview,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Write a review after saving',
                          style: TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Continue to the public review form.',
                          style: TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _writeReview = value ?? false),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                              final messenger = ScaffoldMessenger.of(context);
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
                                widget.onReviewSelected?.call(_writeReview);
                                if (mounted) navigator.pop();
                              } catch (_) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not save this watch entry',
                                      ),
                                    ),
                                  );
                                  setState(() => _saving = false);
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
