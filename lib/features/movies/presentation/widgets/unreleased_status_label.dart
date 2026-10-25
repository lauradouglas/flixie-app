import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../domain/release_status.dart';

class UnreleasedStatusLabel extends StatelessWidget {
  const UnreleasedStatusLabel({super.key, this.date, this.status});
  final String? date, status;

  @override
  Widget build(BuildContext context) {
    if (!isNotReleasedYet(date: date, status: status)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.calendar_month_outlined,
            color: context.colors.warning, size: 24),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Not released yet',
              style: TextStyle(
                  color: context.colors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(expectedReleaseLabel(date),
              style: TextStyle(
                  color: context.colors.light, fontSize: 14, height: 1.4)),
        ])),
      ]),
    );
  }
}
