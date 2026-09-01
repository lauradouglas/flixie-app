import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/models/watch_request.dart';

class FriendPlanActivity extends StatelessWidget {
  const FriendPlanActivity({
    super.key,
    required this.request,
    required this.watchTime,
    required this.scheduledLabel,
  });

  final WatchRequest request;
  final DateTime? watchTime;
  final String scheduledLabel;

  @override
  Widget build(BuildContext context) {
    final watched =
        request.watchConfirmations.where((entry) => entry.watched).length;
    final rated = request.watchConfirmations
        .where((entry) => entry.watched && entry.rating != null)
        .length;
    final scheduled = watchTime != null;
    final finalised = request.selectedCandidateId != null;
    final selectedTitle = request.candidates
        .where((candidate) => candidate.id == request.selectedCandidateId)
        .firstOrNull
        ?.title;
    final accepted = request.isAccepted ||
        request.isScheduled ||
        request.isCompleted ||
        request.normalizedWatchedStatus == 'WATCHED';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Plan activity',
          style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _planActivityRow(
          Icons.send_rounded, 'Invited', 'Watch plan created', true),
      _planActivityRow(Icons.check_circle_outline_rounded, 'Accepted',
          accepted ? 'You’re both in' : 'Waiting for a response', accepted),
      _planActivityRow(
          Icons.bookmark_added_outlined,
          'Choices saved',
          request.candidates.isNotEmpty
              ? '${request.candidates.length} titles considered'
              : 'No titles added yet',
          request.candidates.isNotEmpty),
      _planActivityRow(
          Icons.movie_filter_outlined,
          'Movie finalised',
          finalised
              ? '${selectedTitle ?? 'Movie'} was picked'
              : 'Pick a movie together',
          finalised),
      _planActivityRow(Icons.calendar_month_outlined, 'Scheduled',
          scheduled ? scheduledLabel : 'No time set yet', scheduled),
      _planActivityRow(
          Icons.visibility_outlined,
          'Watched',
          watched > 0
              ? '$watched of 2 watches logged'
              : 'Log your watch after the plan',
          watched > 0),
      _planActivityRow(
          Icons.star_outline_rounded,
          'Rated',
          rated > 0 ? '$rated of 2 ratings saved' : 'Ratings will appear here',
          rated > 0,
          last: true),
    ]);
  }

  Widget _planActivityRow(
          IconData icon, String title, String detail, bool complete,
          {bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 8),
        child: Row(children: [
          Icon(icon,
              size: 17,
              color: complete ? FlixieColors.success : FlixieColors.medium),
          const SizedBox(width: 8),
          Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: title,
                        style: TextStyle(
                            color: complete
                                ? FlixieColors.light
                                : FlixieColors.medium,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' · $detail',
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class FriendPlanRatingsSummary extends StatelessWidget {
  const FriendPlanRatingsSummary({
    super.key,
    required this.request,
  });

  final WatchRequest request;

  @override
  Widget build(BuildContext context) {
    final confirmations = request.watchConfirmations
        .where((confirmation) => confirmation.watched)
        .toList();
    final ratings = confirmations
        .map((confirmation) => confirmation.rating)
        .whereType<int>()
        .toList();
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((sum, rating) => sum + rating) / ratings.length;

    WatchRequestUser? userFor(String userId) {
      if (request.requester?.id == userId) return request.requester;
      if (request.recipient?.id == userId) return request.recipient;
      for (final participant in request.participants) {
        if (participant.user?.id == userId) return participant.user;
      }
      return null;
    }

    final title = request.groupName?.trim().isNotEmpty == true
        ? '${request.groupName} rating'
        : 'Watch plan ratings';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (average != null)
              Text(
                '${average.toStringAsFixed(1)}/10 avg',
                style: const TextStyle(
                  color: FlixieColors.warning,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final confirmation in confirmations) ...[
          Row(
            children: [
              _ratingAvatar(userFor(confirmation.userId)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userFor(confirmation.userId)?.username ?? 'Friend',
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                confirmation.rating == null
                    ? 'Logged'
                    : '★ ${confirmation.rating}/10',
                style: TextStyle(
                  color: confirmation.rating == null
                      ? FlixieColors.medium
                      : FlixieColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (average != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                final currentUser = context.read<AuthProvider>().dbUser;
                int? currentRating;
                for (final confirmation in confirmations) {
                  if (confirmation.userId == currentUser?.id &&
                      confirmation.rating != null) {
                    currentRating = confirmation.rating;
                    break;
                  }
                }
                final movie = request.movie;
                if (currentUser == null ||
                    currentRating == null ||
                    movie == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Log your own rating before sharing it.'),
                    ),
                  );
                  return;
                }
                showShareCardSheet(
                  context,
                  ShareCardData.rating(
                    mediaType: ShareCardMediaType.movie,
                    mediaId: movie.id,
                    title: movie.title,
                    posterPath: movie.posterPath,
                    user: currentUser,
                    rating: currentRating,
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded, size: 17),
              label: const Text('Share your rating'),
            ),
          ),
      ],
    );
  }

  Widget _ratingAvatar(WatchRequestUser? user) {
    final response =
        request.participantFor(user?.id ?? '')?.response.toUpperCase();
    final declined = response == 'DECLINED';
    final borderColor = declined ? FlixieColors.danger : Colors.transparent;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ProfileAvatarView(
          avatar: user?.avatar,
          fallbackText: user?.username.isNotEmpty == true
              ? user!.username[0].toUpperCase()
              : '?',
          fallbackColor: FlixieColors.primary,
          size: 32,
        ),
      ),
    );
  }
}
