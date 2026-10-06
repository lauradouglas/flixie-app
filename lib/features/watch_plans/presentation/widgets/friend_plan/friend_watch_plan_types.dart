enum FriendWatchPlanAction {
  accepting,
  maybe,
  declining,
  scheduling,
  savingMovieChoices,
  removingCandidate,
  selectingMovie,
  completing,
  deleting,
}

class FriendAcceptanceScheduleDraft {
  const FriendAcceptanceScheduleDraft({
    required this.proposedFor,
    this.dateOnly = false,
    this.message,
    this.location,
  });

  final DateTime proposedFor;
  final bool dateOnly;
  final String? message;
  final String? location;
}
