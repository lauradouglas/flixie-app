import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../../data/watch_composer_service.dart';
import 'watch_composer_providers.dart';

enum WatchContext { home, cinema, undecided }

enum ScheduleMode { dateOnly, dateAndTime, decideLater }

/// One sheet owns one account's recipients, choices, schedule and submission.
class WatchComposerController extends ChangeNotifier {
  WatchComposerController(
      {required this.requesterId,
      required String region,
      List<Friendship> friends = const [],
      MovieShort? movie,
      this.initialFriendId,
      String? initialGroupId,
      bool initialGroupMode = false,
      bool initialCinema = false,
      this.service = const WatchComposerService()})
      : providers = WatchComposerProviders(service, requesterId, region),
        _friends = List.of(friends),
        _movieChoices = movie == null ? [] : [movie],
        selectedMovieId = movie?.id,
        selectedGroupId = initialGroupId,
        isGroupMode = initialGroupMode || initialGroupId != null,
        watchContext = initialCinema ? WatchContext.cinema : WatchContext.home,
        scheduleMode = initialGroupMode || initialGroupId != null
            ? ScheduleMode.dateOnly
            : ScheduleMode.decideLater {
    providers.addListener(_notify);
  }
  final String requesterId;
  final String? initialFriendId;
  final WatchComposerService service;
  final WatchComposerProviders providers;
  bool _disposed = false, _started = false, _sent = false;
  bool get active => !_disposed;
  List<Friendship> _friends;
  List<Friendship> get friends => List.unmodifiable(_friends);
  List<Group> _groups = [];
  List<Group> get groups => List.unmodifiable(_groups);
  final List<MovieShort> _movieChoices;
  List<MovieShort> get movieChoices => List.unmodifiable(_movieChoices);
  bool loadingFriends = false,
      friendsLoadFailed = false,
      loadingGroups = false,
      groupsLoadFailed = false,
      isSending = false;
  bool isGroupMode;
  String? selectedFriendId, selectedGroupId;
  int? selectedMovieId;
  WatchContext watchContext;
  ScheduleMode scheduleMode;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int get maxMovieChoices => isGroupMode ? 5 : 3;
  bool get _editable => active && !isSending && !_sent;
  void _notify() {
    if (active) notifyListeners();
  }

  void start() {
    if (_started || !active) return;
    _started = true;
    if (!isGroupMode &&
        initialFriendId != null &&
        _friends.any((f) => f.friendUser?.id == initialFriendId)) {
      selectFriend(initialFriendId!);
    }
    unawaited(fetchFriends());
    unawaited(fetchGroups());
    unawaited(providers.loadSelf());
    if (selectedMovieId != null) {
      unawaited(providers.loadMovie(selectedMovieId!));
    }
    if (selectedGroupId != null) {
      unawaited(providers.selectGroup(selectedGroupId));
    }
  }

  Future<void> fetchFriends() async {
    if (!active || loadingFriends) return;
    loadingFriends = true;
    friendsLoadFailed = false;
    _notify();
    try {
      final loaded = await service.friends(requesterId);
      if (!active) return;
      _friends = List.of(loaded);
      if (!_friends.any((f) => f.friendUser?.id == selectedFriendId)) {
        selectedFriendId = null;
        unawaited(providers.selectFriend(null));
      }
      if (!isGroupMode &&
          selectedFriendId == null &&
          initialFriendId != null &&
          _friends.any((f) => f.friendUser?.id == initialFriendId)) {
        selectFriend(initialFriendId!);
      }
    } catch (_) {
      if (active) friendsLoadFailed = true;
    } finally {
      if (active) {
        loadingFriends = false;
        _notify();
      }
    }
  }

  Future<void> fetchGroups() async {
    if (!active || loadingGroups) return;
    loadingGroups = true;
    groupsLoadFailed = false;
    _notify();
    try {
      final loaded = await service.groups(requesterId);
      if (active) _groups = List.of(loaded);
    } catch (_) {
      if (active) groupsLoadFailed = true;
    } finally {
      if (active) {
        loadingGroups = false;
        _notify();
      }
    }
  }

  void setGroupMode(bool value) {
    if (!_editable || isGroupMode == value) return;
    isGroupMode = value;
    if (value) {
      selectedFriendId = null;
      unawaited(providers.selectFriend(null));
    } else {
      selectedGroupId = null;
      unawaited(providers.selectGroup(null));
    }
    _notify();
  }

  void selectFriend(String id) {
    if (!_editable) return;
    selectedFriendId = id;
    unawaited(providers.selectFriend(id));
    _notify();
  }

  void selectGroup(String id) {
    if (!_editable) return;
    selectedGroupId = id;
    unawaited(providers.selectGroup(id));
    _notify();
  }

  void selectMovieChoice(MovieShort movie) {
    if (!_editable) return;
    selectedMovieId = movie.id;
    unawaited(providers.loadMovie(movie.id));
    _notify();
  }

  void addMovieChoice(MovieShort movie) {
    if (!_editable ||
        _movieChoices.length >= maxMovieChoices ||
        _movieChoices.any((m) => m.id == movie.id)) {
      return;
    }
    _movieChoices.add(movie);
    selectMovieChoice(movie);
  }

  void removeMovieChoice(MovieShort movie) {
    if (!_editable) return;
    _movieChoices.removeWhere((m) => m.id == movie.id);
    if (selectedMovieId == movie.id) {
      selectedMovieId = _movieChoices.firstOrNull?.id;
      if (selectedMovieId != null) {
        unawaited(providers.loadMovie(selectedMovieId!));
      }
    }
    _notify();
  }

  void setWatchContext(WatchContext value) {
    if (!_editable) return;
    watchContext = value;
    _notify();
  }

  void setSchedule(DateTime date, bool dateOnly) {
    if (!_editable) return;
    selectedDate = DateTime(date.year, date.month, date.day);
    scheduleMode = dateOnly ? ScheduleMode.dateOnly : ScheduleMode.dateAndTime;
    selectedTime = dateOnly ? null : TimeOfDay.fromDateTime(date);
    _notify();
  }

  bool get hasValidSchedule =>
      scheduleMode == ScheduleMode.decideLater ||
      (proposedDate != null &&
          !watchPlanScheduleHasPassed(proposedDate!,
              dateOnly: scheduleMode == ScheduleMode.dateOnly));
  DateTime? get proposedDate {
    if (scheduleMode == ScheduleMode.decideLater || selectedDate == null) {
      return null;
    }
    final date = selectedDate!, time = selectedTime;
    return scheduleMode != ScheduleMode.dateAndTime || time == null
        ? encodeWatchPlanDate(date)
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? get locationLabel => switch (watchContext) {
        WatchContext.home => 'At home',
        WatchContext.cinema => 'Cinema',
        WatchContext.undecided => null
      };
  String? get selectedFriendName => _friends
      .where((f) => f.friendUser?.id == selectedFriendId)
      .firstOrNull
      ?.friendUser
      ?.displayName;
  String get sendButtonLabel =>
      (isGroupMode ? selectedGroupId : selectedFriendId) != null
          ? 'Send watch plan'
          : "Choose who's watching";
  String? get validationError {
    if ((isGroupMode ? selectedGroupId : selectedFriendId) == null) {
      return "Choose who's watching";
    }
    if (_movieChoices.isEmpty) return 'Choose a movie for this invitation.';
    if (_movieChoices.length > maxMovieChoices) {
      return 'Choose up to $maxMovieChoices films for this invitation.';
    }
    if (!hasValidSchedule) return 'Choose a date and time in the future.';
    return null;
  }

  bool get canSend => _editable && validationError == null;
  Future<ComposerSubmission?> send(String message) async {
    if (!canSend) return null;
    final group = isGroupMode, movieId = _movieChoices.first.id;
    final participantCount = group
        ? (providers.groupMemberCount > 0 ? providers.groupMemberCount : null)
        : 2;
    isSending = true;
    _notify();
    try {
      final id = await service.send(
          userId: requesterId,
          recipientId: (group ? selectedGroupId : selectedFriendId)!,
          group: group,
          movies: _movieChoices.map((m) => m.id).toList(),
          message: message.trim(),
          proposedDate: proposedDate?.toUtc().toIso8601String(),
          dateOnly: scheduleMode == ScheduleMode.dateOnly,
          location: locationLabel);
      if (!active) return null;
      _sent = true;
      return ComposerSubmission(id, movieId, group, participantCount);
    } finally {
      if (active) {
        isSending = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    providers.removeListener(_notify);
    providers.dispose();
    _friends = [];
    _groups = [];
    _movieChoices.clear();
    super.dispose();
  }
}

class ComposerSubmission {
  const ComposerSubmission(
      this.id, this.movieId, this.group, this.participantCount);
  final String? id;
  final int movieId;
  final bool group;
  final int? participantCount;
}
