import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';

class MovieWatchHistorySection extends StatelessWidget {
  const MovieWatchHistorySection(
      {super.key,
      required this.entries,
      required this.loading,
      required this.formatDate,
      required this.onAdd,
      required this.onEdit,
      required this.onDelete});
  final List<MovieWatchEntry> entries;
  final bool loading;
  final String Function(String?) formatDate;
  final VoidCallback onAdd;
  final ValueChanged<MovieWatchEntry> onEdit;
  final ValueChanged<MovieWatchEntry> onDelete;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlixieSectionHeader(title: 'Watch History'),
        const SizedBox(height: 10),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No watches logged yet.',
                  style: TextStyle(color: context.colors.medium)),
              TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Log watch')),
            ]),
          )
        else
          ...entries.take(5).map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: context.colors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        formatDate(entry.watchedAt),
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (entry.rating != null)
                            'Rating: ${entry.rating!.toStringAsFixed(0)}/10',
                          if (entry.notes != null && entry.notes!.isNotEmpty)
                            entry.notes!,
                        ].join(' • '),
                        style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        iconColor: context.colors.light,
                        color: context.colors.tabBarBackgroundFocused,
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit(entry);
                            return;
                          }
                          onDelete(entry);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'Edit',
                              style: TextStyle(color: context.colors.light),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: context.colors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
