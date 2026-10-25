import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
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
    this.embedded = false,
    this.onBusyChanged,
    this.onClose,
    this.movieId,
    this.showId,
    required this.userId,
    required this.onSubmitted,
    this.mediaTitle,
    this.initialWatchedAt,
    this.initialRating,
    this.initialRecommended,
    this.watchEntryId,
    this.watchEntries = const [],
    this.initialTitle = '',
    this.initialBody = '',
    this.initialContainsSpoilers = false,
  }) : assert((movieId == null) != (showId == null));

  final ValueChanged<bool>? onBusyChanged;
  final bool embedded;
  final VoidCallback? onClose;
  final String? mediaTitle, initialWatchedAt;
  final int? movieId;
  final int? showId;
  final String userId;
  final void Function(Review review) onSubmitted;
  final double? initialRating;
  final bool? initialRecommended;
  final String? watchEntryId;
  final List<MovieWatchEntry> watchEntries;
  final String initialTitle, initialBody;
  final bool initialContainsSpoilers;

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
  bool _editingRating = false;

  @override
  void initState() {
    super.initState();
    _watchEntryId = widget.watchEntryId;
    _titleController.text = widget.initialTitle;
    _bodyController.text = widget.initialBody;
    _containsSpoilers = widget.initialContainsSpoilers;
    final initial = widget.initialRating;
    _rating = initial != null && initial >= 1 && initial <= 10
        ? initial.round()
        : null;
    _recommended = widget.initialRecommended ?? true;
    _editingRating = _rating == null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        _rating == null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    widget.onBusyChanged?.call(true);

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
        await context
            .read<AnalyticsController>()
            .reviewCreated(
              contentType: widget.showId == null ? 'movie' : 'show',
              contentId: widget.movieId ?? widget.showId!,
              source: widget.embedded
                  ? 'onboarding'
                  : widget.showId == null
                      ? 'movie_detail'
                      : 'show_detail',
            )
            .catchError((Object _) {});
        if (!mounted) return;
        widget.onSubmitted(created);
        if (!widget.embedded) Navigator.of(context).pop(created);
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
      if (mounted) {
        setState(() => _isSubmitting = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  String _watchLabel(MovieWatchEntry entry) {
    final date = DateTime.tryParse(entry.watchedAt ?? '');
    final index =
        widget.watchEntries.length - widget.watchEntries.indexOf(entry);
    return 'Watch $index · ${date == null ? 'No date' : MaterialLocalizations.of(context).formatMediumDate(date.toLocal())}';
  }

  static const _paper = Color(0xFFEDE1FB);
  static const _paperInk = Color(0xFF301B46);
  static const _paperMuted = Color(0xFF684983);
  static const _paperLine = Color(0xFFC7B3DC);

  bool get _hasWatchChoice =>
      widget.movieId != null &&
      (widget.watchEntries.isNotEmpty || widget.watchEntryId != null);

  String? get _watchDate {
    final entry = widget.watchEntries
        .where((entry) => entry.id == _watchEntryId)
        .firstOrNull;
    final raw = entry?.watchedAt ??
        (_watchEntryId == widget.watchEntryId ? widget.initialWatchedAt : null);
    final date = DateTime.tryParse(raw ?? '');
    return date == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  }

  Widget _paperField(
          {required String label,
          required String hint,
          required TextEditingController controller,
          bool body = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: _paperInk, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !_isSubmitting,
          minLines: body ? 6 : 1,
          maxLines: body ? null : 3,
          textCapitalization: TextCapitalization.sentences,
          textInputAction:
              body ? TextInputAction.newline : TextInputAction.next,
          cursorColor: _paperInk,
          style: const TextStyle(color: _paperInk, fontSize: 15, height: 1.6),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _paperMuted),
            filled: false,
            contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            border: body
                ? InputBorder.none
                : const UnderlineInputBorder(
                    borderSide: BorderSide(color: _paperLine)),
            enabledBorder: body
                ? InputBorder.none
                : const UnderlineInputBorder(
                    borderSide: BorderSide(color: _paperLine)),
            focusedBorder: body
                ? InputBorder.none
                : const UnderlineInputBorder(
                    borderSide: BorderSide(color: _paperMuted, width: 1.5)),
            errorStyle: const TextStyle(color: Color(0xFF8D273B)),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? (body ? 'Add your thoughts.' : 'Give your review a title.')
              : null,
        ),
      ]);

  Widget _notebook() => Container(
      key: const ValueKey('review-notebook'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      decoration:
          BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                  widget.mediaTitle ??
                      (widget.showId == null
                          ? 'Your movie review'
                          : 'Your show review'),
                  style: const TextStyle(
                      color: _paperInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              if (_watchEntryId != null && _watchDate != null)
                Text(_watchDate!,
                    style: const TextStyle(color: _paperMuted, fontSize: 12)),
            ]),
        const SizedBox(height: 24),
        _paperField(
            label: 'Review title',
            hint: 'Still thinking about that ending',
            controller: _titleController),
        const SizedBox(height: 20),
        _paperField(
            label: 'Your review',
            hint: 'What made this one memorable?',
            controller: _bodyController,
            body: true),
      ]));

  Widget _watchChoice() => DropdownButtonFormField<String>(
        key: const ValueKey('review-watch-choice'),
        initialValue: _watchEntryId ?? '',
        isExpanded: true,
        style: TextStyle(color: context.colors.light, fontSize: 13),
        itemHeight: null,
        selectedItemBuilder: (context) => [
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Standalone review')),
          if (widget.watchEntryId != null &&
              !widget.watchEntries
                  .any((entry) => entry.id == widget.watchEntryId))
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Linked to your saved watch')),
          for (final entry in widget.watchEntries)
            Align(
                alignment: Alignment.centerLeft,
                child: Text(_watchLabel(entry))),
        ],
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.link_rounded,
              color: context.colors.primaryText, size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: false,
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.tabBarBorder)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.primaryText)),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Standalone review')),
          if (widget.watchEntryId != null &&
              !widget.watchEntries
                  .any((entry) => entry.id == widget.watchEntryId))
            DropdownMenuItem(
                value: widget.watchEntryId,
                child: const Text('The watch you just logged')),
          for (final entry in widget.watchEntries)
            DropdownMenuItem(
                value: entry.id,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_watchLabel(entry)))),
        ],
        onChanged: _isSubmitting
            ? null
            : (value) =>
                setState(() => _watchEntryId = value == '' ? null : value),
      );

  Widget _ratingEditor() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Semantics(
                  label: _rating == null
                      ? 'No rating selected'
                      : 'Rating $_rating out of 10',
                  child: ExcludeSemantics(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_rating == null ? 'Your rating' : '$_rating / 10',
                            style: TextStyle(
                                color: _rating == null
                                    ? context.colors.light
                                    : context.colors.warning,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        if (_rating != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                  spacing: 1,
                                  children: List.generate(
                                      10,
                                      (i) => Icon(Icons.star_rounded,
                                          size: 18,
                                          color: i < _rating!
                                              ? context.colors.warning
                                              : context.colors.tabBarBorder)))),
                      ]))),
              TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _editingRating = !_editingRating),
                  child: Text(_editingRating ? 'Done' : 'Change rating')),
            ]),
        if (_editingRating) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 7,
              runSpacing: 7,
              children: List.generate(
                  10,
                  (i) => ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: FlixiePill.choice(
                          label: Text('${i + 1}'),
                          selected: _rating == i + 1,
                          showCheckmark: false,
                          onSelected: _isSubmitting
                              ? null
                              : (_) => setState(() {
                                    _rating = i + 1;
                                    _editingRating = false;
                                  }))))),
          if (_rating == null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Choose your rating to post a review.',
                    style:
                        TextStyle(color: context.colors.medium, fontSize: 12))),
        ],
      ]);

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final inset = MediaQuery.viewInsetsOf(context)
            .bottom
            .clamp(0.0, double.infinity)
            .toDouble();
        final available =
            (constraints.maxHeight - inset).clamp(0.0, constraints.maxHeight);
        final height = widget.embedded
            ? available
            : (size.height * .9).clamp(0.0, available);
        final compact = height < 300;
        return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SizedBox(
                      height: height,
                      child: Material(
                        color: context.colors.surface,
                        borderRadius: widget.embedded
                            ? BorderRadius.zero
                            : const BorderRadius.vertical(
                                top: Radius.circular(24)),
                        clipBehavior: Clip.antiAlias,
                        child: SafeArea(
                            top: false,
                            child: Column(children: [
                              if (!compact && !widget.embedded) ...[
                                Container(
                                    margin: const EdgeInsets.only(
                                        top: 12, bottom: 4),
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: context.colors.medium,
                                        borderRadius:
                                            BorderRadius.circular(4))),
                                Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(24, 0, 12, 0),
                                    child: Row(children: [
                                      const Expanded(
                                          child: FlixieWordmark(fontSize: 21)),
                                      IconButton(
                                          tooltip: 'Close review',
                                          onPressed: _isSubmitting
                                              ? null
                                              : () => widget.onClose != null
                                                  ? widget.onClose!()
                                                  : Navigator.of(context).pop(),
                                          icon:
                                              const Icon(Icons.close_rounded)),
                                    ])),
                              ],
                              Expanded(
                                  child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding:
                                    const EdgeInsets.fromLTRB(24, 6, 24, 24),
                                child: Form(
                                    key: _formKey,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (!compact && !widget.embedded) ...[
                                            Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(
                                                            'Dear ${widget.showId == null ? 'movie' : 'TV'} diary…',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headlineSmall
                                                                ?.copyWith(
                                                                    fontSize:
                                                                        26,
                                                                    height:
                                                                        1.15,
                                                                    letterSpacing:
                                                                        -.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700)),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            _watchEntryId ==
                                                                    null
                                                                ? 'A little space for your take.'
                                                                : 'Your watch is saved.\nNow for your take.',
                                                            style: TextStyle(
                                                                color: context
                                                                    .colors
                                                                    .medium,
                                                                fontSize: 13,
                                                                height: 1.5)),
                                                      ])),
                                                  const SizedBox(width: 12),
                                                  Image.asset(
                                                      'assets/icon/pip_emote_hot_take.png',
                                                      width: 88,
                                                      height: 96,
                                                      fit: BoxFit.contain,
                                                      excludeFromSemantics:
                                                          true),
                                                ]),
                                            const SizedBox(height: 12),
                                          ],
                                          _notebook(),
                                          if (_hasWatchChoice) ...[
                                            const SizedBox(height: 14),
                                            _watchChoice()
                                          ],
                                          const SizedBox(height: 18),
                                          _ratingEditor(),
                                          const SizedBox(height: 18),
                                          Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                FlixiePill.choice(
                                                    label:
                                                        const Text('Recommend'),
                                                    avatar: const Icon(
                                                        Icons
                                                            .thumb_up_alt_outlined,
                                                        size: 16),
                                                    selected: _recommended,
                                                    showCheckmark: false,
                                                    onSelected: _isSubmitting
                                                        ? null
                                                        : (value) => setState(
                                                            () => _recommended =
                                                                value)),
                                                FlixiePill.choice(
                                                    label: const Text(
                                                        'Contains spoilers'),
                                                    avatar: const Icon(
                                                        Icons
                                                            .visibility_off_outlined,
                                                        size: 16),
                                                    selected: _containsSpoilers,
                                                    showCheckmark: false,
                                                    onSelected: _isSubmitting
                                                        ? null
                                                        : (value) => setState(() =>
                                                            _containsSpoilers =
                                                                value)),
                                              ]),
                                        ])),
                              )),
                              Container(
                                  padding: EdgeInsets.fromLTRB(24,
                                      compact ? 6 : 12, 24, compact ? 6 : 16),
                                  decoration: BoxDecoration(
                                      border: Border(
                                          top: BorderSide(
                                              color: context
                                                  .colors.tabBarBorder))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(50),
                                              backgroundColor:
                                                  FlixieColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          15))),
                                          onPressed:
                                              _isSubmitting || _rating == null
                                                  ? null
                                                  : _submit,
                                          icon: _isSubmitting
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white))
                                              : const Icon(Icons.send_rounded,
                                                  size: 18),
                                          label: Text(
                                              _isSubmitting
                                                  ? 'Posting…'
                                                  : 'Post review',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                        if (!compact && inset == 0) ...[
                                          const SizedBox(height: 9),
                                          Text(
                                              'Shared following your privacy settings.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: context.colors.medium,
                                                  fontSize: 11)),
                                        ],
                                      ])),
                            ])),
                      ))),
            ));
      });
}
