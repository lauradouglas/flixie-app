import 'package:flutter/material.dart';

import '../../models/review.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    required this.movieId,
    required this.userId,
    required this.onSubmitted,
  });

  final int movieId;
  final String userId;
  final void Function(Review review) onSubmitted;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  int _rating = 5;
  bool _recommended = true;
  bool _containsSpoilers = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool _submitted = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final draft = Review(
        id: '',
        userId: widget.userId,
        movieId: widget.movieId,
        showId: null,
        rating: _rating,
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

      final created = await UserService.addMovieReview(draft);
      if (mounted) {
        widget.onSubmitted(created);
        setState(() => _submitted = true);
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to submit review: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                const Text(
                  'Write a Review',
                  style: TextStyle(
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
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating
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
                        final isSelected = value <= _rating;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = value),
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
                      '$_rating / 10',
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Title',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: FlixieColors.white),
                      decoration: InputDecoration(
                        hintText: 'Give your review a title',
                        hintStyle: const TextStyle(color: FlixieColors.medium),
                        filled: true,
                        fillColor: const Color(0xFF1B2E42),
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
                    const Text(
                      'Review',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyController,
                      style: const TextStyle(color: FlixieColors.white),
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts about the movie...',
                        hintStyle: const TextStyle(color: FlixieColors.medium),
                        filled: true,
                        fillColor: const Color(0xFF1B2E42),
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
                      label: 'I recommend this movie',
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
                      child: _submitted
                          ? Container(
                              key: const ValueKey('success'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Review submitted!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('button'),
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FlixieColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _submit,
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
        color: const Color(0xFF1B2E42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: FlixieColors.light, fontSize: 14)),
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
