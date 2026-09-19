import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_plan_candidate_avatar.dart';
import 'package:flixie_app/models/watch_request.dart';

class WatchPlanCandidateChoicesSheet extends StatefulWidget {
  const WatchPlanCandidateChoicesSheet({
    super.key,
    required this.request,
    required this.userId,
  });

  final WatchRequest request;
  final String userId;

  @override
  State<WatchPlanCandidateChoicesSheet> createState() =>
      _WatchPlanCandidateChoicesSheetState();
}

class _WatchPlanCandidateChoicesSheetState
    extends State<WatchPlanCandidateChoicesSheet> {
  late final Set<String> _selected = widget.request.candidates
      .where((candidate) => candidate.selectedBy(widget.userId))
      .map((candidate) => candidate.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.medium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Which would you be happy to watch?',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Select every option that works for you. Choose at least one to continue.',
              style: TextStyle(color: context.colors.medium, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...widget.request.candidates.map((candidate) {
              final isSelected = _selected.contains(candidate.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      if (!_selected.add(candidate.id)) {
                        _selected.remove(candidate.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.success.withValues(alpha: 0.12)
                            : context.colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? context.colors.success
                              : context.colors.tabBarBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: SizedBox(
                              width: 36,
                              height: 54,
                              child: candidate.posterPath == null
                                  ? const _PosterPlaceholder()
                                  : CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w185${candidate.posterPath}',
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const _PosterPlaceholder(),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate.title ?? 'Untitled',
                                  style: TextStyle(
                                    color: context.colors.light,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (candidate.addedByUsername?.isNotEmpty ==
                                    true)
                                  Row(
                                    children: [
                                      WatchPlanCandidateAvatar(
                                        avatar: candidate.addedByAvatar,
                                        username: candidate.addedByUsername,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Suggested by ${candidate.addedByUsername}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: context.colors.medium,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              key: ValueKey(isSelected),
                              color: isSelected
                                  ? context.colors.success
                                  : context.colors.medium,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_selected.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Select at least one movie to save your choices.',
                  style: TextStyle(
                    color: context.colors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()),
                child: const Text('Save choices'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1E2D40),
        child: Center(
          child: Icon(Icons.movie_outlined, color: context.colors.medium),
        ),
      );
}
