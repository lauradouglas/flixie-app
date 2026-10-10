import 'package:flutter/material.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class GroupDetailTitle extends StatelessWidget {
  const GroupDetailTitle(
      {super.key,
      required this.group,
      required this.loading,
      required this.memberCount});
  final Group? group;
  final bool loading;
  final int memberCount;
  static const List<Color> _palette = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.success,
    FlixieColors.warning,
  ];

  Color _groupColor(String name) {
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  String _groupAbbr(Group group) {
    if (group.abbreviation != null && group.abbreviation!.isNotEmpty) {
      return group.abbreviation!.toUpperCase();
    }
    final words = group.name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return group.name.isEmpty
        ? '?'
        : group.name.substring(0, group.name.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _groupColor(group?.name ?? '');
    return loading
        ? const ContentPlaceholder(
            label: 'Loading group', style: ContentPlaceholderStyle.compact)
        : Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: color.withValues(alpha: 0.24),
                child: SizedBox(
                  width: 27,
                  height: 27,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      group != null ? _groupAbbr(group!) : '',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          group?.name ?? 'Group',
                          style: TextStyle(
                            color: context.colors.light,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        )),
                    Text(
                      '$memberCount member${memberCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}
