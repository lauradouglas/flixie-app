import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import 'group_plan_components.dart';
import 'group_plan_members.dart';

class GroupPlanHeader extends StatelessWidget {
  const GroupPlanHeader({
    super.key,
    required this.view,
    this.embedded = false,
    this.groupId,
    required this.onBack,
  });
  final GroupPlanViewData view;
  final bool embedded;
  final String? groupId;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final request = view.request;
    final members = view.activeMembers;
    final selected = view.selectedCandidate;
    final title =
        selected?.title ?? request.movieTitle ?? groupPlanOptionLabel(request);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          groupPlanMovieLink(
            context,
            view,
            request,
            groupPlanDetailPoster(
              context,
              embedded,
              onBack,
              selected?.posterPath ?? request.moviePosterPath,
              title,
              88,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                groupPlanStatus(context, groupPlanState(context, view)),
                const SizedBox(height: 8),
                groupPlanMovieLink(
                  context,
                  view,
                  request,
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (groupId == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    view.groupName,
                    style: TextStyle(
                      color: context.colors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  groupPlanTiming(context, request),
                  style: groupPlanBody.copyWith(color: context.colors.light),
                ),
                if (request.location?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    request.location!,
                    style: groupPlanBody.copyWith(color: context.colors.light),
                  ),
                ],
                const SizedBox(height: 10),
                groupPlanAvatars(context, view.userId, members, 38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget groupPlanCreationMessage(
  BuildContext context,
  GroupWatchRequest request,
) {
  final message = request.message?.trim();
  if (message == null || message.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      '“$message”',
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 14,
        height: 1.5,
      ),
    ),
  );
}

Widget groupPlanMovieLink(
  BuildContext context,
  GroupPlanViewData view,
  GroupWatchRequest request,
  Widget child,
) {
  final selected = view.selectedCandidate;
  final id = selected?.movieId ?? selected?.showId ?? request.mediaId;
  if (id == null) return child;
  final show =
      selected?.showId != null || request.analyticsContentType == 'show';
  return Semantics(
    button: true,
    label: 'View movie details',
    child: InkWell(
      onTap: () => context.push(show ? '/shows/$id' : '/movies/$id'),
      child: child,
    ),
  );
}

Widget groupPlanDetailPoster(
  BuildContext context,
  bool embedded,
  VoidCallback onBack,
  String? path,
  String title,
  double width,
) {
  final poster = groupPlanPoster(path, title, width);
  if (!embedded) return poster;
  return Stack(
    children: [
      poster,
      Positioned(
        top: 4,
        left: 4,
        child: Material(
          color: context.colors.background.withValues(alpha: .86),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Back to Watch Plans',
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            onPressed: () => onBack(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.colors.textPrimary,
              size: 23,
            ),
          ),
        ),
      ),
    ],
  );
}
