import 'package:flutter/material.dart';

import '../../models/movie_watch_entry.dart';
import '../../theme/app_theme.dart';

class RewatchLogSheet extends StatefulWidget {
  const RewatchLogSheet({
    super.key,
    this.initial,
    required this.onSubmit,
  });

  final MovieWatchEntry? initial;
  final Future<void> Function({
    required String watchedAt,
    required double? rating,
    required String? notes,
  }) onSubmit;

  @override
  State<RewatchLogSheet> createState() => _RewatchLogSheetState();
}

class _RewatchLogSheetState extends State<RewatchLogSheet> {
  late DateTime _watchedAt;
  late TextEditingController _notesController;
  // null means "no rating"; 1-10 when set
  int? _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _watchedAt = DateTime.tryParse(widget.initial?.watchedAt ?? '') ?? DateTime.now();
    final existingRating = widget.initial?.rating;
    _rating = existingRating != null ? existingRating.round() : null;
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
        color: Color(0xFF0D1B2A),
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
                  widget.initial == null ? 'Log Watch' : 'Edit Watch Entry',
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
          const Divider(color: Color(0xFF1E2D40), height: 1),
          // Form body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Watched-on date picker
                  const Text(
                    'Watched on',
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        color: const Color(0xFF1B2E42),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: FlixieColors.medium, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}',
                            style:
                                const TextStyle(color: FlixieColors.light),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Star rating (1-10)
                  const Text(
                    'Rating',
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(10, (i) {
                      final value = i + 1;
                      final isSelected = _rating != null && value <= _rating!;
                      return GestureDetector(
                        onTap: () => setState(() {
                          // Tapping the currently-selected last star clears the rating
                          _rating = (_rating == value) ? null : value;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            color: isSelected
                                ? Colors.amber
                                : FlixieColors.medium,
                            size: 28,
                          ),
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
                      fillColor: const Color(0xFF1B2E42),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
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
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await widget.onSubmit(
                                watchedAt: _watchedAt.toUtc().toIso8601String(),
                                rating: _rating?.toDouble(),
                                notes: _notesController.text.trim().isEmpty
                                    ? null
                                    : _notesController.text.trim(),
                              );
                              if (mounted) Navigator.pop(context);
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
                                  ? 'Log Watch'
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
