class ProfileMilestone {
  const ProfileMilestone(
      {required this.id,
      required this.family,
      required this.group,
      required this.title,
      required this.description,
      required this.target,
      required this.progress,
      required this.earned,
      this.earnedAt});
  final String id, family, group, title, description;
  final int target, progress;
  final bool earned;
  final DateTime? earnedAt;
  factory ProfileMilestone.fromJson(Map<String, dynamic> json) =>
      ProfileMilestone(
        id: json['id'] as String,
        family: json['family'] as String,
        group: json['group'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        target: (json['target'] as num).toInt(),
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        earned: json['earned'] == true,
        earnedAt: DateTime.tryParse(json['earnedAt'] as String? ?? ''),
      );
}

class ProfileMilestones {
  const ProfileMilestones(
      {required this.items,
      required this.owner,
      this.collectionsPending = false});
  final List<ProfileMilestone> items;
  final bool owner, collectionsPending;
  factory ProfileMilestones.fromJson(Map<String, dynamic> json) =>
      ProfileMilestones(
        items: (json['items'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ProfileMilestone.fromJson)
            .toList(),
        owner: json['visibility'] == 'owner',
        collectionsPending: json['collectionsPending'] == true,
      );
  List<ProfileMilestone> get earned =>
      items.where((item) => item.earned).toList()
        ..sort((a, b) {
          final date =
              (b.earnedAt ?? DateTime(0)).compareTo(a.earnedAt ?? DateTime(0));
          return date != 0 ? date : b.target.compareTo(a.target);
        });
  List<ProfileMilestone> get next {
    final families = <String>{};
    return items
        .where((item) => !item.earned && families.add(item.family))
        .toList();
  }
}
