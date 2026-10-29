/// One explicit guest action, bound to the account that completes signup.
class SignupJourney {
  const SignupJourney(
      {required this.userId,
      required this.action,
      required this.path,
      this.title,
      this.diaryDraftId,
      this.episodeId,
      this.seasonNumber,
      this.episodeNumber,
      this.episodeTitle});
  final String userId, action, path;
  final String? title, diaryDraftId;
  final int? episodeId, seasonNumber, episodeNumber;
  final String? episodeTitle;
  bool get isShow => path.startsWith('/shows/');
  int get mediaId => int.parse(path.split('/').last);
  bool get handoff =>
      const {
        'list',
        'plan',
        'providers',
        'season',
        'post-score',
        'collection',
        'collection-plan',
        'community',
        'discussion',
        'curated-list'
      }.contains(action) ||
      path.startsWith('/people/');
  static bool supports(String? action, String? path) =>
      (action == 'guest-watchlist' && path == '/guest-watchlist') ||
      (action == 'home' && path == '/') ||
      (action == 'profile' && path == '/profile') ||
      (action == 'post-score' && path == '/play/popcorn-catch') ||
      (action == 'community' &&
          RegExp(r'^/genre-communities/[0-9]+$').hasMatch(path ?? '')) ||
      (action == 'discussion' &&
          RegExp(r'^/community/posts/[^/]+/[^/]+/[^/]+$')
              .hasMatch(path ?? '')) ||
      (const {'collection', 'collection-plan'}.contains(action) &&
          RegExp(r'^/collections/[0-9]+$').hasMatch(path ?? '')) ||
      (action == 'curated-list' &&
          RegExp(r'^/flixie-lists/[a-zA-Z0-9-]+$').hasMatch(path ?? '')) ||
      (action == 'favorite' &&
          RegExp(r'^/people/[0-9]+$').hasMatch(path ?? '')) ||
      (const {
            'watchlist',
            'rate',
            'review',
            'log',
            'episode',
            'favorite',
            'season',
            'list',
            'plan',
            'providers'
          }.contains(action) &&
          RegExp(r'^/(movies|shows)/[0-9]+$').hasMatch(path ?? '') &&
          (action != 'log' || path!.startsWith('/movies/')));
}
