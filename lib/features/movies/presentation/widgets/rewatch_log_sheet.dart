import 'package:flixie_app/features/movies/models/external_watch_invite.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/movies/data/movie_watch_plan_choice.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'watch_companion_picker.dart';

Future<T?> showMovieWatchLogSheet<T>(
        {required BuildContext context, required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).shortestSide >= 600
                ? (MediaQuery.sizeOf(context).width >
                        MediaQuery.sizeOf(context).height
                    ? 820
                    : 560)
                : MediaQuery.sizeOf(context).width),
        builder: builder);

class RewatchLogSheet extends StatefulWidget {
  const RewatchLogSheet(
      {super.key,
      this.initial,
      required this.onSubmit,
      this.showReviewOption = false,
      this.onReviewSelected,
      this.isRewatch = false,
      this.previousWatch,
      this.watchPlans,
      this.onPlanSelected,
      this.isPlanReview = false,
      this.movieTitle,
      this.movieYear,
      this.loadFriends,
      this.onDetailsChanged,
      this.companion,
      this.companions = const [],
      this.initialWatchedAt,
      this.initialDateUnknown = false});
  final MovieWatchEntry? initial, previousWatch;
  final Future<void> Function(
      {required String? watchedAt,
      required double? rating,
      required bool? recommended,
      required String? notes}) onSubmit;
  final bool showReviewOption, isRewatch, isPlanReview, initialDateUnknown;
  final ValueChanged<bool>? onReviewSelected;
  final Future<List<MovieWatchPlanChoice>>? watchPlans;
  final ValueChanged<MovieWatchPlanChoice?>? onPlanSelected;
  final String? movieTitle, movieYear, initialWatchedAt;
  final FriendshipUser? companion;
  final List<FriendshipUser> companions;
  final Future<List<Friendship>> Function()? loadFriends;
  final ValueChanged<WatchLogDetails>? onDetailsChanged;
  @override
  State<RewatchLogSheet> createState() => _RewatchLogSheetState();
}

class _RewatchLogSheetState extends State<RewatchLogSheet> {
  late DateTime _date;
  late bool _known;
  int? _rating;
  bool? _recommended;
  bool _saving = false, _writeReview = false;
  late TextEditingController _notes;
  List<FriendshipUser> _selectedCompanions = [];
  FriendshipUser? get _companion => _selectedCompanions.firstOrNull;
  set _companion(FriendshipUser? value) =>
      _selectedCompanions = [if (value != null) value];
  String? _externalName;
  MovieWatchPlanChoice? _plan;
  String? _error;
  @override
  void initState() {
    super.initState();
    _date = (DateTime.tryParse(
                widget.initial?.watchedAt ?? widget.initialWatchedAt ?? '') ??
            DateTime.now())
        .toLocal();
    _known = widget.initial != null
        ? widget.initial!.watchedAt != null
        : !widget.initialDateUnknown;
    _rating = widget.initial?.rating?.round();
    _recommended = widget.initial?.recommended;
    _selectedCompanions = widget.companions.isNotEmpty
        ? [...widget.companions]
        : widget.companion != null
            ? [widget.companion!]
            : [...?widget.initial?.allCompanions];
    _notes = TextEditingController(text: widget.initial?.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _details() => widget.onDetailsChanged?.call(WatchLogDetails(
      companion: _companion,
      companions: List.unmodifiable(_selectedCompanions),
      externalCompanionName: _externalName,
      reviewBody: widget.initial?.reviewBody ?? '',
      containsSpoilers: widget.initial?.reviewContainsSpoilers ?? false));
  Future<void> _pick() async {
    final selected = await showModalBottomSheet<Object>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => WatchCompanionPicker(
            loadFriends: widget.loadFriends!,
            selected: _selectedCompanions,
            lockedIds: widget.initial?.planId != null
                ? widget.initial!.allCompanions
                    .map((friend) => friend.id)
                    .toSet()
                : const {}));
    if (!mounted || _saving || selected == null) return;
    setState(() {
      _selectedCompanions = selected is List<FriendshipUser>
          ? selected
          : selected is FriendshipUser
              ? [selected]
              : [];
      _externalName = selected is ExternalWatchCompanion ? selected.name : null;
    });
    _details();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    _details();
    try {
      await widget.onSubmit(
          watchedAt: _known ? _date.toUtc().toIso8601String() : null,
          rating: _rating?.toDouble(),
          recommended: _recommended,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      if (!mounted) return;
      widget.onReviewSelected?.call(_writeReview);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Couldn’t save your watch. Your details are still here. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700));
  Widget _hint(String text) => Text(text,
      style:
          TextStyle(color: context.colors.medium, fontSize: 12, height: 1.4));
  Widget _dateField() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.calendar_today_outlined,
              color: context.colors.primaryText, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label(_known
                    ? MaterialLocalizations.of(context).formatMediumDate(_date)
                    : 'Date unknown'),
                if (_known) _hint('Watched on')
              ])),
          TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final result = await showModalBottomSheet<DateTime>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          builder: (c) => SizedBox(
                              height: MediaQuery.sizeOf(c).height * .72,
                              child: Column(children: [
                                Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('Watched on',
                                        style:
                                            Theme.of(c).textTheme.titleLarge)),
                                Expanded(
                                    child: CalendarDatePicker(
                                        initialDate:
                                            _date.isAfter(DateTime.now())
                                                ? DateTime.now()
                                                : _date,
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                        onDateChanged: (d) =>
                                            Navigator.pop(c, d)))
                              ])));
                      if (mounted && result != null) {
                        setState(() {
                          _date = result;
                          _known = true;
                        });
                      }
                    },
              child: const Text('Change'))
        ]),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: !_known,
            onChanged:
                _saving ? null : (v) => setState(() => _known = !(v ?? false)),
            title: const Text('I don’t remember the date')),
      ]);
  Widget _companions() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _label('Watched with')),
          if (widget.loadFriends != null && _plan == null)
            TextButton(
                onPressed: _saving ? null : _pick,
                child: Text(_companion == null && _externalName == null
                    ? 'Add someone'
                    : 'Add people'))
        ]),
        for (final friend in _selectedCompanions)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.all(3),
                child: ProfileAvatarView(
                    avatar: friend.avatar,
                    profileBadges: friend.profileBadges,
                    fallbackText: friend.displayName,
                    fallbackColor: avatarColorFromIconColor(friend.iconColor),
                    size: 44)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _label(friend.displayName),
                  const SizedBox(height: 4),
                  _hint(widget.isPlanReview || widget.initial?.planId != null
                      ? 'Linked to your watch together'
                      : 'They’ll get a prompt to log their own watch.')
                ])),
            if (widget.loadFriends != null &&
                _plan == null &&
                !(widget.initial?.allCompanions
                        .any((person) => person.id == friend.id) ??
                    false))
              IconButton(
                  tooltip: 'Remove companion',
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _selectedCompanions.removeWhere(
                                (person) => person.id == friend.id);
                            _details();
                          }),
                  icon: const Icon(Icons.close_rounded, size: 18))
          ]),
        if (_selectedCompanions.isEmpty &&
            (_externalName != null || widget.initial?.externalInvite != null))
          Row(children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _label(_externalName ??
                      widget.initial!.externalInvite!.displayName),
                  _hint('Save your watch, then share their invite to Flixie.')
                ])),
            if (_externalName != null)
              IconButton(
                  tooltip: 'Remove companion',
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _externalName = null;
                            _details();
                          }),
                  icon: const Icon(Icons.close))
          ])
        else if (_selectedCompanions.isEmpty)
          _hint(
              _plan?.label ?? 'Just you for now. Adding friends is optional.'),
      ]);
  Widget _planChoices() => FutureBuilder<List<MovieWatchPlanChoice>>(
      future: widget.watchPlans,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _hint(
              'Couldn’t load watch plans. You can still save a separate watch.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
            padding: const EdgeInsets.only(top: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Was this part of a watch plan?'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FlixiePill.choice(
                    label: const Text('Separate watch'),
                    selected: _plan == null,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() {
                              _plan = null;
                              widget.onPlanSelected?.call(null);
                            })),
                for (final plan in snapshot.data!)
                  FlixiePill.choice(
                      label: Text(plan.label),
                      selected: _plan?.id == plan.id,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() {
                                _plan = plan;
                                _externalName = null;
                                _companion = plan.companion;
                                _writeReview = false;
                                widget.onPlanSelected?.call(plan);
                                _details();
                              }))
              ])
            ]));
      });
  void _selectRating(int value) =>
      setState(() => _rating = _rating == value ? null : value);

  Widget _ratingField() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _label('Your rating')),
          if (_rating != null)
            TextButton(
                onPressed:
                    _saving ? null : () => setState(() => _rating = null),
                child: const Text('Clear'))
          else
            _hint('Optional')
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = box.maxWidth >= 320 || scale < 1.3 ? 5 : 4;
          final width = (box.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(10, (i) {
                final n = i + 1;
                return SizedBox(
                    width: width,
                    child: Semantics(
                        label: 'Rate $n out of 10',
                        selected: _rating == n,
                        button: true,
                        enabled: !_saving,
                        excludeSemantics: true,
                        onTap: _saving ? null : () => _selectRating(n),
                        child: TextButton(
                            onPressed: _saving ? null : () => _selectRating(n),
                            style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: _rating == n
                                    ? context.colors.warning
                                        .withValues(alpha: .14)
                                    : context.colors.surfaceElevated,
                                foregroundColor: context.colors.primaryText,
                                shape: RoundedRectangleBorder(
                                    side: _rating == n
                                        ? BorderSide(
                                            color: context.colors.warning,
                                            width: 1.5)
                                        : BorderSide.none,
                                    borderRadius: BorderRadius.circular(10))),
                            child: n <= (_rating ?? 0)
                                ? Icon(Icons.star_rounded,
                                    color: context.colors.warning, size: 24)
                                : Text('$n',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)))));
              }));
        }),
        const SizedBox(height: 8),
        _hint(_rating == null
            ? 'Out of 10 · You can rate it later.'
            : '$_rating / 10'),
        if (widget.isRewatch && widget.previousWatch?.rating != null) ...[
          const SizedBox(height: 8),
          _hint('Previous watch: ${widget.previousWatch!.rating!.round()}/10')
        ],
      ]);
  Widget _writing() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label('Would you recommend it?'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (text, value) in [
            ('Recommend', true),
            ('No opinion', null),
            ('Not for me', false)
          ])
            FlixiePill.choice(
                label: Text(text),
                selected: _recommended == value,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _recommended = value)),
        ]),
        const SizedBox(height: 24),
        TextField(
            controller: _notes,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
                labelText: 'Watch comment (optional)',
                hintText: 'Anything to remember about this watch?')),
        if (widget.showReviewOption && widget.onReviewSelected != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _writeReview,
            onChanged: _saving
                ? null
                : (value) => setState(() => _writeReview = value ?? false),
            title: Text(widget.initial?.reviewBody?.isNotEmpty == true
                ? 'Edit review next'
                : 'Write a review next'),
            subtitle: const Text(
                'Save your watch, then add a title, review and spoiler warning.'),
          ),
      ]);
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context),
            inset = MediaQuery.viewInsetsOf(context).bottom;
        final tablet = size.shortestSide >= 600;
        final availableHeight =
            (constraints.maxHeight - inset).clamp(0.0, constraints.maxHeight);
        final height = tablet
            ? (size.height * .88).clamp(0.0, availableHeight)
            : availableHeight;
        final compactKeyboard = inset > 0 && height < 280;
        return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: SizedBox(
                height: height,
                child: Material(
                    color: context.colors.surface,
                    borderRadius: tablet
                        ? const BorderRadius.vertical(top: Radius.circular(24))
                        : BorderRadius.zero,
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                        top: false,
                        child: Column(children: [
                          if (!compactKeyboard)
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 12, 12),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            widget.initial != null
                                                ? 'Edit your watch'
                                                : widget.isRewatch
                                                    ? 'Log another watch'
                                                    : 'Log your watch',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                        if (widget.movieTitle != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                              [
                                                widget.movieTitle!,
                                                if (widget.movieYear != null)
                                                  widget.movieYear!
                                              ].join(' · '),
                                              style: TextStyle(
                                                  color: context.colors.light))
                                        ]
                                      ])),
                                  IconButton(
                                      tooltip: 'Close',
                                      onPressed: _saving
                                          ? null
                                          : () => Navigator.pop(context),
                                      icon: const Icon(Icons.close_rounded))
                                ])),
                          Divider(
                              height: 1, color: context.colors.tabBarBorder),
                          Expanded(
                              child: SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.all(20),
                                  child: LayoutBuilder(builder: (context, box) {
                                    final details = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _dateField(),
                                          Divider(
                                              color:
                                                  context.colors.tabBarBorder),
                                          _companions(),
                                          if (widget.watchPlans != null)
                                            _planChoices()
                                        ]);
                                    final thoughts = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _ratingField(),
                                          const SizedBox(height: 16),
                                          _writing()
                                        ]);
                                    return box.maxWidth >= 620 &&
                                            MediaQuery.textScalerOf(context)
                                                    .scale(1) <=
                                                1.2
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                                Expanded(child: details),
                                                const SizedBox(width: 28),
                                                Expanded(child: thoughts)
                                              ])
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                                details,
                                                const SizedBox(height: 24),
                                                thoughts
                                              ]);
                                  }))),
                          Container(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 14),
                              decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color: context.colors.tabBarBorder))),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_error != null) ...[
                                      Text(_error!,
                                          style: TextStyle(
                                              color: context.colors.danger)),
                                      const SizedBox(height: 8)
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                            child: FilledButton(
                                                onPressed:
                                                    _saving ? null : _save,
                                                style: FilledButton.styleFrom(
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                            50)),
                                                child: _saving
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors
                                                                    .white))
                                                    : Text(
                                                        _writeReview
                                                            ? (widget
                                                                        .initial
                                                                        ?.reviewBody
                                                                        ?.isNotEmpty ==
                                                                    true
                                                                ? 'Save & edit review'
                                                                : 'Save & write review')
                                                            : widget.initial ==
                                                                    null
                                                                ? 'Save watch'
                                                                : 'Save changes',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)))),
                                      ],
                                    ),
                                    if (_companion != null && inset == 0) ...[
                                      const SizedBox(height: 8),
                                      _hint(
                                          'Each person confirms their own watch.')
                                    ]
                                  ])),
                        ])))));
      });
}
