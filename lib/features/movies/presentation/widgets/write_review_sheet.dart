import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    this.movieId,
    this.showId,
    required this.userId,
    required this.onSubmitted,
    this.initialRating,
    this.initialRecommended,
    this.watchEntryId,
    this.watchEntries = const [],
  }) : assert((movieId == null) != (showId == null));

  final int? movieId;
  final int? showId;
  final String userId;
  final void Function(Review review) onSubmitted;
  final double? initialRating;
  final bool? initialRecommended;
  final String? watchEntryId;
  final List<MovieWatchEntry> watchEntries;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  final ReviewReactionsController _reviewReactions =
      ReviewReactionsController.instance;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _watchEntryId;
  int? _rating;
  late bool _recommended;
  bool _containsSpoilers = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _watchEntryId = widget.watchEntryId;
    final initial = widget.initialRating;
    _rating = initial != null && initial >= 1 && initial <= 10
        ? initial.round()
        : null;
    _recommended = widget.initialRecommended ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _rating == null || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final draft = Review(
        id: '',
        userId: widget.userId,
        movieId: widget.movieId,
        watchEntryId: _watchEntryId,
        showId: widget.showId,
        rating: _rating!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        upvotes: 0,
        downvotes: 0,
        containsSpoilers: _containsSpoilers,
        language: 'en',
        recommended: _recommended,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final created = await _reviewReactions.addReview(draft);
      if (mounted) {
        await context.read<AnalyticsController>().reviewCreated(
              contentType: widget.showId == null ? 'movie' : 'show',
              contentId: widget.movieId ?? widget.showId!,
              source: widget.showId == null ? 'movie_detail' : 'show_detail',
            );
        if (!mounted) return;
        widget.onSubmitted(created);
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
                'Couldn’t submit your review. Your draft is still here.'),
            action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  if (mounted) _submit();
                }),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _watchLabel(MovieWatchEntry entry) {
    final date = DateTime.tryParse(entry.watchedAt ?? '');
    final index =
        widget.watchEntries.length - widget.watchEntries.indexOf(entry);
    return 'Watch $index · ${date == null ? 'No date' : MaterialLocalizations.of(context).formatMediumDate(date.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaLabel = widget.showId != null ? 'show' : 'movie';
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      padding: EdgeInsets.only(bottom: bottomInset),
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
                Expanded(
                    child: Text(
                  'Write a Review',
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.light),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: context.colors.tabBarBorder, height: 1),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.movieId != null &&
                        (widget.watchEntries.isNotEmpty ||
                            widget.watchEntryId != null)) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _watchEntryId ?? '',
                        isExpanded: true,
                        itemHeight: null,
                        // Menu rows need generous tap padding, but the selected
                        // value must fit inside the closed field from first paint.
                        selectedItemBuilder: (context) => [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Standalone review'),
                          ),
                          if (widget.watchEntryId != null &&
                              !widget.watchEntries.any(
                                  (entry) => entry.id == widget.watchEntryId))
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('The watch you just logged'),
                            ),
                          for (final entry in widget.watchEntries)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(_watchLabel(entry)),
                            ),
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Link to a watch'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Standalone review')),
                          if (widget.watchEntryId != null &&
                              !widget.watchEntries.any(
                                  (entry) => entry.id == widget.watchEntryId))
                            DropdownMenuItem(
                                value: widget.watchEntryId,
                                child: const Text('The watch you just logged')),
                          for (final entry in widget.watchEntries)
                            DropdownMenuItem(
                                value: entry.id,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(_watchLabel(entry)),
                                )),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() =>
                                _watchEntryId = value == '' ? null : value),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Rating
                    Text(
                      'Rating',
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
                        final isSelected = value == _rating;
                        return ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 42,
                          ),
                          child: FlixiePill.choice(
                              label: Text('$value'),
                              avatar: Icon(
                                  isSelected
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 17),
                              selected: isSelected,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _rating = value)),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rating == null
                          ? 'Choose your rating to submit a review'
                          : '$_rating / 10',
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      'Title',
                      style: TextStyle(
                        color: context.colors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: context.colors.white),
                      decoration: InputDecoration(
                        hintText: 'Give your review a title',
                        hintStyle: TextStyle(color: context.colors.medium),
                        filled: true,
                        fillColor: context.colors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Body
                    Text(
                      'Review',
                      style: TextStyle(
                        color: context.colors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyController,
                      style: TextStyle(color: context.colors.white),
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText:
                            'Share your thoughts about the $mediaLabel...',
                        hintStyle: TextStyle(color: context.colors.medium),
                        filled: true,
                        fillColor: context.colors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    // Toggles
                    _ToggleTile(
                      label: 'I recommend this $mediaLabel',
                      value: _recommended,
                      onChanged: (v) => setState(() => _recommended = v),
                    ),
                    const SizedBox(height: 8),
                    _ToggleTile(
                      label: 'Contains spoilers',
                      value: _containsSpoilers,
                      onChanged: (v) => setState(() => _containsSpoilers = v),
                    ),
                    const SizedBox(height: 28),
                    // Submit
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: SizedBox(
                        key: const ValueKey('button'),
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
                          onPressed:
                              _isSubmitting || _rating == null ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit Review',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ), // Flexible
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: context.colors.light, fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FlixieColors.primary,
          ),
        ],
      ),
    );
  }
}
