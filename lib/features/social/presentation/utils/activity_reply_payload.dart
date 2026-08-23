import 'package:flixie_app/models/activity_list_item.dart';

class ActivityReplyPayload {
  const ActivityReplyPayload({
    required this.username,
    required this.activityLabel,
    required this.title,
    required this.link,
    required this.posterUrl,
    this.rating,
    this.recommended,
    this.reviewTitle,
    this.reviewBody,
    this.containsSpoilers = false,
    this.listName,
    this.listLink,
    this.message = '',
  });

  factory ActivityReplyPayload.fromActivity(ActivityListItem item) {
    final isReview = item.type == ActivityListType.movieReview ||
        item.type == ActivityListType.showReview;
    final isListAddition = item.type == ActivityListType.movieListAdded;
    final activityLabel = isReview
        ? 'review'
        : isListAddition
            ? 'list addition'
            : item.type == ActivityListType.movieRating ||
                    item.type == ActivityListType.showRating
                ? 'rating'
                : 'activity';
    final link = item.movieId != null
        ? 'flixie://movies/${item.movieId}'
        : item.showId != null
            ? 'flixie://shows/${item.showId}'
            : '';
    final poster = item.mediaPosterPath?.trim() ?? '';
    return ActivityReplyPayload(
      username: item.username.trim().isNotEmpty
          ? item.username.trim()
          : '${item.firstName} ${item.lastName}'.trim(),
      activityLabel: activityLabel,
      title: item.mediaTitle?.trim() ?? '',
      link: link,
      posterUrl: poster.isEmpty || poster.startsWith('http')
          ? poster
          : 'https://image.tmdb.org/t/p/w342$poster',
      rating: item.mediaRating,
      recommended: item.recommended,
      reviewTitle: isReview ? item.reviewData?.title : null,
      reviewBody: isReview ? item.reviewData?.body : null,
      containsSpoilers:
          isReview && (item.reviewData?.containsSpoilers ?? false),
      listName: isListAddition ? item.listName : null,
      listLink: isListAddition &&
              item.listId != null &&
              item.listOwnerId != null
          ? 'flixie://lists/${item.listId}?owner=${Uri.encodeQueryComponent(item.listOwnerId!)}&name=${Uri.encodeQueryComponent(item.listName ?? 'List')}'
          : null,
    );
  }

  final String username;
  final String activityLabel;
  final String title;
  final String link;
  final String posterUrl;
  final double? rating;
  final bool? recommended;
  final String? reviewTitle;
  final String? reviewBody;
  final bool containsSpoilers;
  final String? listName;
  final String? listLink;
  final String message;

  bool get isUsable => title.isNotEmpty && link.isNotEmpty;

  String withMessage(String value) {
    String field(String key, Object? fieldValue) =>
        '$key=${Uri.encodeComponent(fieldValue?.toString() ?? '')}';
    return [
      '[FLIXIE_ACTIVITY_REPLY]',
      field('message', value),
      field('username', username),
      field('activity', activityLabel),
      field('title', title),
      field('link', link),
      field('poster', posterUrl),
      field('rating', rating),
      field('recommended', recommended),
      field('reviewTitle', reviewTitle),
      field('reviewBody', reviewBody),
      field('spoilers', containsSpoilers),
      field('listName', listName),
      field('listLink', listLink),
      '[/FLIXIE_ACTIVITY_REPLY]',
    ].join('\n');
  }
}

ActivityReplyPayload? parseActivityReplyPayload(String text) {
  final match = RegExp(
    r'\[FLIXIE_ACTIVITY_REPLY\]([\s\S]*?)\[/FLIXIE_ACTIVITY_REPLY\]',
    multiLine: true,
  ).firstMatch(text);
  if (match == null) return null;

  final values = <String, String>{};
  for (final rawLine in (match.group(1) ?? '').split('\n')) {
    final line = rawLine.trim();
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    final encoded = line.substring(separator + 1).trim();
    try {
      values[key] = Uri.decodeComponent(encoded);
    } on FormatException {
      values[key] = encoded;
    }
  }

  final payload = ActivityReplyPayload(
    username: values['username']?.trim() ?? '',
    activityLabel: values['activity']?.trim() ?? 'activity',
    title: values['title']?.trim() ?? '',
    link: values['link']?.trim() ?? '',
    posterUrl: values['poster']?.trim() ?? '',
    rating: double.tryParse(values['rating'] ?? ''),
    recommended: values['recommended'] == 'true'
        ? true
        : values['recommended'] == 'false'
            ? false
            : null,
    reviewTitle: _nonEmpty(values['reviewTitle']),
    reviewBody: _nonEmpty(values['reviewBody']),
    containsSpoilers: values['spoilers'] == 'true',
    listName: _nonEmpty(values['listName']),
    listLink: _nonEmpty(values['listLink']),
    message: values['message']?.trim() ?? '',
  );
  return payload.isUsable ? payload : null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
