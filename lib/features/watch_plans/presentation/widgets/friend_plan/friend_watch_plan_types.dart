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
    this.message,
    this.location,
  });

  final DateTime proposedFor;
  final String? message;
  final String? location;
}
