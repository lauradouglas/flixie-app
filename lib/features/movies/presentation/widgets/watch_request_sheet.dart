import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../../data/watch_composer_service.dart';
import '../controllers/watch_composer_controller.dart';
import '../watch_composer_actions.dart';
import 'watch_composer/composer_components.dart';
import 'watch_composer/composer_movie_choices.dart';
import 'watch_composer/composer_recipients.dart';
import 'watch_composer/composer_location.dart';
import 'watch_composer/composer_submit.dart';

class MovieWatchRequestSheet extends StatefulWidget {
  const MovieWatchRequestSheet({
    super.key,
    this.service = const WatchComposerService(),
    required this.movieId,
    required this.movieTitle,
    this.moviePoster,
    required this.requesterId,
    required this.friends,
    required this.onSuccess,
    required this.onError,
    this.initialFriendId,
    this.initialGroupId,
    this.initialGroupMode = false,
    this.fromMovieMatch = false,
    this.initialCinema = false,
  });

  final WatchComposerService service;
  final int? movieId;
  final String? movieTitle;
  final String? moviePoster;
  final String requesterId;
  final List<Friendship> friends;
  final VoidCallback onSuccess;
  final VoidCallback onError;
  final String? initialFriendId;
  final String? initialGroupId;
  final bool initialGroupMode;
  final bool fromMovieMatch;
  final bool initialCinema;

  @override
  State<MovieWatchRequestSheet> createState() => _MovieWatchRequestSheetState();
}

class _MovieWatchRequestSheetState extends State<MovieWatchRequestSheet> {
  final _messageController = TextEditingController();
  WatchComposerController? _controller;
  bool _accountExpired = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider?>(context);
    if (auth != null && auth.dbUser?.id != widget.requesterId) {
      _accountExpired = true;
      _controller?.dispose();
      _controller = null;
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route != null && route.isActive && !route.isFirst) {
          route.navigator?.removeRoute(route);
        }
      });
      return;
    }
    if (_accountExpired) return;
    _controller ??= WatchComposerController(
        requesterId: widget.requesterId,
        region: auth?.dbUser?.watchProviderRegion ?? 'GB',
        friends: widget.friends,
        initialFriendId: widget.initialFriendId,
        initialGroupId: widget.initialGroupId,
        initialGroupMode: widget.initialGroupMode,
        initialCinema: widget.initialCinema,
        service: widget.service,
        movie: widget.movieId == null
            ? null
            : MovieShort(
                id: widget.movieId!,
                name: widget.movieTitle ?? 'Movie',
                poster: widget.moviePoster))
      ..start();
  }

  @override
  void didUpdateWidget(covariant MovieWatchRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requesterId != widget.requesterId) {
      _controller?.dispose();
      _controller = null;
      _accountExpired = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _accountExpired) return const SizedBox.shrink();
    final actions = WatchComposerActions(context, controller,
        onSuccess: widget.onSuccess,
        onError: widget.onError,
        fromMovieMatch: widget.fromMovieMatch);
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => AbsorbPointer(
            absorbing: controller.isSending,
            child: _body(context, controller, actions)));
  }

  Widget _body(BuildContext context, WatchComposerController controller,
      WatchComposerActions actions) {
    final sheetHeight = MediaQuery.sizeOf(context).height * .92;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SizedBox(
        height: sheetHeight,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: FlixieColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: FlixieColors.primary, size: 38),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create watch plan',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Start with the people, place or date',
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: context.colors.medium),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ComposerRecipients(controller: controller),
                PlanStepHeading(
                  number: '2',
                  title: 'Movie options',
                  trailing: 'ADD UP TO ${controller.maxMovieChoices}',
                ),
                const SizedBox(height: 10),
                if (controller.movieChoices.isEmpty)
                  MovieOptionsEmptyCard(onTap: actions.browseCinemaReleases)
                else
                  SelectedPlanTitle(
                    choices: controller.movieChoices,
                    selectedMovieId: controller.selectedMovieId,
                    onSelect: controller.selectMovieChoice,
                    onRemove: controller.removeMovieChoice,
                    onAddOption: controller.movieChoices.length >=
                            controller.maxMovieChoices
                        ? null
                        : actions.addMovieChoice,
                  ),
                const SizedBox(height: 16),
                ComposerLocation(controller: controller),
                const SizedBox(height: 14),
                const PlanStepHeading(
                    number: '4', title: 'When?', trailing: 'CAN CHANGE LATER'),
                const SizedBox(height: 10),
                SchedulePicker(
                  label: controller.scheduleMode == ScheduleMode.dateOnly
                      ? 'DATE'
                      : 'DATE & TIME',
                  value: controller.selectedDate == null
                      ? 'Choose when to watch'
                      : controller.scheduleMode == ScheduleMode.dateOnly
                          ? MaterialLocalizations.of(context)
                              .formatFullDate(controller.selectedDate!)
                          : '${MaterialLocalizations.of(context).formatMediumDate(controller.selectedDate!)} at ${controller.selectedTime?.format(context) ?? 'Choose time'}',
                  onTap: actions.pickSchedule,
                ),
                const SizedBox(height: 22),
                ComposerSubmit(
                    controller: controller,
                    actions: actions,
                    messageController: _messageController),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
