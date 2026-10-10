import 'package:flixie_app/core/widgets/notification_opt_in.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';

import '../../controllers/watch_requests_controller.dart';
import '../social_account_sheet.dart';

Future<bool?> showWatchPlanCalendarSheet({
  required BuildContext context,
  required WatchRequestsController controller,
  required String title,
  required DateTime scheduledFor,
  bool dateOnly = false,
  String? posterPath,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SocialAccountSheet(
        viewer: controller.viewer,
        child: SingleChildScrollView(
            child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Time agreed',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 96,
                      child: posterPath == null || posterPath.isEmpty
                          ? ColoredBox(
                              color: context.colors.surfaceElevated,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: FlixieColors.primary,
                                size: 28,
                              ),
                            )
                          : Image.network(
                              'https://image.tmdb.org/t/p/w185$posterPath',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: context.colors.surfaceElevated,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: FlixieColors.primary,
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: FlixieColors.primary,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatWatchPlanDateTime(scheduledFor,
                                    dateOnly: dateOnly),
                                style: TextStyle(
                                  color: context.colors.medium,
                                  fontSize: 16,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'Keep the plan handy by adding it to your phone calendar.',
                style: TextStyle(
                  color: context.colors.medium,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const NotificationOptIn(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Add to calendar'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ))),
  );
}
