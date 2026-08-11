import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';

enum ShareCardVariant { rating, review }

enum ShareCardMediaType { movie, show }

class ShareCardData {
  const ShareCardData._({
    required this.variant,
    required this.mediaType,
    required this.mediaId,
    required this.title,
    required this.posterPath,
    required this.displayName,
    required this.username,
    required this.initials,
    required this.avatar,
    required this.profileBadges,
    required this.avatarColorValue,
    required this.rating,
    required this.recommended,
    required this.note,
    required this.reviewTitle,
    required this.reviewExcerpt,
  });

  factory ShareCardData.rating({
    required ShareCardMediaType mediaType,
    required int mediaId,
    required String title,
    required String? posterPath,
    required User user,
    required int rating,
    bool? recommended,
    String? note,
  }) =>
      ShareCardData._fromUser(
        variant: ShareCardVariant.rating,
        mediaType: mediaType,
        mediaId: mediaId,
        title: title,
        posterPath: posterPath,
        user: user,
        rating: rating,
        recommended: recommended,
        note: note,
      );

  factory ShareCardData.review({
    required ShareCardMediaType mediaType,
    required int mediaId,
    required String title,
    required String? posterPath,
    required User user,
    required Review review,
  }) =>
      ShareCardData._fromUser(
        variant: ShareCardVariant.review,
        mediaType: mediaType,
        mediaId: mediaId,
        title: title,
        posterPath: posterPath,
        user: user,
        rating: review.rating,
        recommended: review.recommended,
        reviewTitle: review.title,
        reviewExcerpt: review.body,
      );

  factory ShareCardData._fromUser({
    required ShareCardVariant variant,
    required ShareCardMediaType mediaType,
    required int mediaId,
    required String title,
    required String? posterPath,
    required User user,
    required int rating,
    bool? recommended,
    String? note,
    String? reviewTitle,
    String? reviewExcerpt,
  }) {
    final fullName = [user.firstName, user.lastName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    final displayName = fullName.isNotEmpty ? fullName : user.username;
    final initials = _clean(user.initials) ??
        displayName
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return ShareCardData._(
      variant: variant,
      mediaType: mediaType,
      mediaId: mediaId,
      title: title.trim().isEmpty ? 'A Flixie pick' : title.trim(),
      posterPath: _clean(posterPath),
      displayName: displayName,
      username: user.username,
      initials: initials.isEmpty ? 'F' : initials,
      avatar: user.avatar,
      profileBadges: user.profileBadges,
      avatarColorValue: _avatarColorValue(user.iconColor),
      rating: rating.clamp(0, 10),
      recommended: recommended,
      note: _clean(note),
      reviewTitle: _cleanReviewTitle(reviewTitle),
      reviewExcerpt: _truncate(_clean(reviewExcerpt), 280),
    );
  }

  final ShareCardVariant variant;
  final ShareCardMediaType mediaType;
  final int mediaId;
  final String title;
  final String? posterPath;
  final String displayName;
  final String username;
  final String initials;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;
  final int avatarColorValue;
  final int rating;
  final bool? recommended;
  final String? note;
  final String? reviewTitle;
  final String? reviewExcerpt;

  String? get posterUrl {
    final path = posterPath;
    if (path == null) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'https://image.tmdb.org/t/p/w780${path.startsWith('/') ? path : '/$path'}';
  }

  String get mediaLabel =>
      mediaType == ShareCardMediaType.movie ? 'movie' : 'show';

  String get deepLink =>
      'flixie://${mediaType == ShareCardMediaType.movie ? 'movies' : 'shows'}/$mediaId';

  String get fileName {
    final safeTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'flixie-${safeTitle.isEmpty ? mediaLabel : safeTitle}.png';
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static String? _cleanReviewTitle(String? value) {
    final clean = _clean(value);
    return clean?.toLowerCase() == 'untitled review' ? null : clean;
  }

  static String? _truncate(String? value, int maxCharacters) {
    if (value == null || value.length <= maxCharacters) return value;
    final shortened = value.substring(0, maxCharacters - 1).trimRight();
    final lastSpace = shortened.lastIndexOf(' ');
    return '${lastSpace > maxCharacters * .7 ? shortened.substring(0, lastSpace) : shortened}…';
  }

  static int _avatarColorValue(Map<String, dynamic>? iconColor) {
    final value = (iconColor?['hexCode'] ?? iconColor?['hex'])?.toString();
    final hex = value?.replaceAll('#', '');
    return int.tryParse('FF${hex ?? ''}', radix: 16) ?? 0xFF7C4DFF;
  }
}
