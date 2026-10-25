import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flutter/material.dart';
import '../controllers/profile_diary_controller.dart';
import '../diary/diary_calendar_sheet.dart';
import '../diary/diary_selection.dart';
import '../diary/diary_watch_entry.dart';

/// A small page of the same diary, backed by the full diary's account-scoped data.
class ProfileDiaryPreview extends StatelessWidget {
  const ProfileDiaryPreview(
      {super.key, required this.controller, required this.onOpen});
  final ProfileDiaryController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final week = diaryMonday(DateTime.now());
        final entries = controller.selection.week(week);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: diaryPaper, borderRadius: BorderRadius.circular(14)),
          child: DefaultTextStyle(
            style: const TextStyle(
                color: diaryInk, fontSize: 14, fontFamily: 'Manrope'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text('Dear film diary,',
                  style: FlixieTypography.sectionTitle.copyWith(color: diaryInk))),
              const SizedBox(height: 6),
              const Text('The films. The people. The little memories.',
                  style: TextStyle(color: diaryMuted)),
              const SizedBox(height: 16),
              Text(diaryWeekLabel(context, week),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (controller.loading && !controller.loaded)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()))
              else if (controller.failed && !controller.loaded)
                TextButton(
                    onPressed: () => controller.load(),
                    child: const Text('Couldn’t load your diary · Retry'))
              else ...[
                if (entries.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                          'A quiet page. Your next movie night will find a home here.')),
                for (final entry in entries.take(2))
                  DiaryWatchEntry(
                      entry: entry,
                      rewatch:
                          controller.selection.rewatches.contains(entry.id)),
              ],
              TextButton.icon(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(foregroundColor: diaryInk),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Open diary')),
            ]),
          ),
        );
      });
}
