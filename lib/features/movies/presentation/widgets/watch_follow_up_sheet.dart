import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class WatchFollowUpChoice {
  const WatchFollowUpChoice({
    required this.addWatchEntry,
    required this.writeReview,
  });

  final bool addWatchEntry;
  final bool writeReview;
}

class WatchFollowUpSheet extends StatefulWidget {
  const WatchFollowUpSheet({
    super.key,
    required this.movieTitle,
    this.posterPath,
  });

  final String movieTitle;
  final String? posterPath;

  @override
  State<WatchFollowUpSheet> createState() => _WatchFollowUpSheetState();
}

class _WatchFollowUpSheetState extends State<WatchFollowUpSheet> {
  bool _addWatchEntry = true;
  bool _writeReview = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: FlixieColors.success, size: 28),
                SizedBox(width: 10),
                Text(
                  'Marked as watched',
                  style: TextStyle(
                    color: FlixieColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.movieTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 14),
            ),
            const SizedBox(height: 18),
            _FollowUpOption(
              icon: Icons.calendar_today_outlined,
              title: 'Add a watch entry',
              subtitle: 'Save when you watched it, a rating and private notes.',
              value: _addWatchEntry,
              onChanged: (value) => setState(() => _addWatchEntry = value),
            ),
            const SizedBox(height: 10),
            _FollowUpOption(
              icon: Icons.rate_review_outlined,
              title: 'Write a review',
              subtitle: 'Share a public review with the Flixie community.',
              value: _writeReview,
              onChanged: (value) => setState(() => _writeReview = value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  WatchFollowUpChoice(
                    addWatchEntry: _addWatchEntry,
                    writeReview: _writeReview,
                  ),
                ),
                child:
                    Text(_addWatchEntry || _writeReview ? 'Continue' : 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpOption extends StatelessWidget {
  const _FollowUpOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value
              ? FlixieColors.primary.withValues(alpha: 0.13)
              : FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? FlixieColors.primary.withValues(alpha: 0.7)
                : FlixieColors.tabBarBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: value ? FlixieColors.primary : FlixieColors.medium),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12)),
                ],
              ),
            ),
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          ],
        ),
      ),
    );
  }
}
